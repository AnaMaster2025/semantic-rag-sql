# fastapi_app.py
import os
import re
import json
import time
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
load_dotenv()  # ✅ SIEMPRE ANTES DE OpenAI

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from openai import OpenAI

from semantic_layer import build_semantic_layer

# -------------------------
# CLIENTES Y CONFIG GLOBAL
# -------------------------
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
DB_PATH = os.getenv("DB_PATH", "db.sqlite")
HERE = Path(__file__).parent

def get_db_path() -> str:
    return os.getenv("DB_PATH", str(HERE / "db.sqlite"))

def get_db_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(get_db_path())
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn

# -------------------------
# Guardrails SQL (gobernanza)
# -------------------------
SQL_MULTI_STMT_RE = re.compile(r";\s*\S", re.MULTILINE)
FORBIDDEN_SQL_RE = re.compile(
    r"\b(drop|delete|truncate|alter|update|insert|attach|detach|pragma|vacuum)\b",
    re.IGNORECASE,
)

def assert_sql_safe(sql: str) -> None:
    s = (sql or "").strip()
    if not s:
        raise HTTPException(status_code=400, detail="SQL vacío")

    if not (s.lower().startswith("select") or s.lower().startswith("with")):
        raise HTTPException(status_code=400, detail="Solo se permiten consultas SELECT/CTE")

    if SQL_MULTI_STMT_RE.search(s):
        raise HTTPException(status_code=400, detail="SQL contiene múltiples sentencias (bloqueado)")

    if FORBIDDEN_SQL_RE.search(s):
        raise HTTPException(status_code=400, detail="SQL contiene palabras clave prohibidas (bloqueado)")

# -------------------------
# Observabilidad (simple)
# -------------------------
def ensure_observability_table(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS agent_observability (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            question TEXT,
            sql_text TEXT,
            rows_returned INTEGER NOT NULL,
            elapsed_seconds REAL NOT NULL,
            total_tokens INTEGER NOT NULL,
            cost_usd REAL NOT NULL,
            riesgo_alucinacion TEXT NOT NULL
        )
        """
    )

def log_observability(
    question: Optional[str],
    sql_text: str,
    rows_returned: int,
    elapsed_seconds: float,
    total_tokens: int = 0,
    cost_usd: float = 0.0,
    riesgo_alucinacion: str = "desconocido",
) -> None:
    try:
        conn = get_db_conn()
        ensure_observability_table(conn)
        conn.execute(
            """
            INSERT INTO agent_observability
            (ts, question, sql_text, rows_returned, elapsed_seconds, total_tokens, cost_usd, riesgo_alucinacion)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                datetime.utcnow().isoformat(),
                question,
                sql_text,
                int(rows_returned),
                float(elapsed_seconds),
                int(total_tokens),
                float(cost_usd),
                str(riesgo_alucinacion),
            ),
        )
        conn.commit()
    except Exception as e:
        print(f"[WARN] observability log failed: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass

# -------------------------
# API models
# -------------------------
class SQLRequest(BaseModel):
    sql: str = Field(..., description="Consulta SQL (solo SELECT/CTE)")
    params: Dict[str, Any] = Field(default_factory=dict, description="Parámetros nombrados opcionales")

class SQLResponse(BaseModel):
    sql: str
    params: Dict[str, Any]
    rows: List[Dict[str, Any]]
    rowcount: int
    elapsed_seconds: float

class QueryRequest(BaseModel):
    question: str = Field(..., description="Pregunta para trazabilidad/observabilidad")
    sql: str = Field(..., description="SQL generado por el agente respetando la capa semántica")
    params: Dict[str, Any] = Field(default_factory=dict)

class QueryResponse(BaseModel):
    question: str
    sql: str
    params: Dict[str, Any]
    rows: List[Dict[str, Any]]
    rowcount: int
    elapsed_seconds: float

# -------------------------
# FastAPI
# -------------------------
api = FastAPI(title="Semantic Governance Data API", version="1.0.0")

@api.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}

@api.get("/semantic")
def semantic() -> Dict[str, Any]:
    """
    Devuelve la capa semántica inferida (tablas, columnas, relaciones).
    Útil para que tu agente/LLM construya SQL con gobernanza.
    """
    db_path = get_db_path()
    if not Path(db_path).exists():
        raise HTTPException(status_code=404, detail=f"No existe la DB en DB_PATH={db_path}")
    return build_semantic_layer(db_path)

@api.post("/sql", response_model=SQLResponse)
def run_sql(req: SQLRequest) -> SQLResponse:
    """
    Ejecuta SQL con guardrails (solo SELECT/CTE).
    Diseñado para ejecución segura de consultas generadas por tu capa semántica/LLM.
    """
    assert_sql_safe(req.sql)

    t0 = time.perf_counter()
    conn = get_db_conn()
    try:
        cur = conn.cursor()
        cur.execute(req.sql, req.params or {})
        rows = [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
    elapsed = time.perf_counter() - t0

    return SQLResponse(
        sql=req.sql,
        params=req.params or {},
        rows=rows,
        rowcount=len(rows),
        elapsed_seconds=elapsed,
    )

@api.post("/query", response_model=QueryResponse)
def query(req: QueryRequest) -> QueryResponse:
    """
    Endpoint “gobernado” para tu flujo NL→SQL:
    - El agente genera SQL usando /semantic
    - Llama a /query enviando (question + sql + params)
    - La API ejecuta con guardrails y registra observabilidad
    """
    q = (req.question or "").strip()
    if not q:
        raise HTTPException(status_code=400, detail="question is required")
    assert_sql_safe(req.sql)

    t0 = time.perf_counter()
    conn = get_db_conn()
    try:
        cur = conn.cursor()
        cur.execute(req.sql, req.params or {})
        rows = [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
    elapsed = time.perf_counter() - t0

    # Observabilidad (en tu proyecto luego puedes meter tokens/coste/risks reales)
    log_observability(
        question=q,
        sql_text=req.sql,
        rows_returned=len(rows),
        elapsed_seconds=elapsed,
        total_tokens=0,
        cost_usd=0.0,
        riesgo_alucinacion="desconocido",
    )

    return QueryResponse(
        question=q,
        sql=req.sql,
        params=req.params or {},
        rows=rows,
        rowcount=len(rows),
        elapsed_seconds=elapsed,
    )


class Text2SQLReq(BaseModel):
    question: str

SQL_SYSTEM = """Eres un asistente de analítica de datos que genera SQL SOLO de lectura para SQLite.
Reglas OBLIGATORIAS DE SALIDA:

Cuando devuelvas datos de ventas (invoices):
- La columna de tiempo DEBE llamarse:
  - `month` (YYYY-MM) si es mensual
  - `day` (YYYY-MM-DD) si es diaria

- La dimensión de país DEBE llamarse:
  - `country_code`

- La métrica de ventas DEBE llamarse:
  - `sales_total`

Ejemplo correcto:
SELECT
  strftime('%Y-%m', i.invoice_date) AS month,
  c.country_code AS country_code,
  SUM(i.total_with_tax) AS sales_total
FROM invoices i
JOIN customers c ON c.id = i.customer_id
WHERE i.status IN ('open','paid','partial')
GROUP BY month, country_code
Devuelve SOLO JSON con este formato exacto:
{
  "sql": "...",
  "params": {},
  "notes": "breve"
}
"""

def safe_json(obj, max_chars=6000):
    s = json.dumps(obj, ensure_ascii=False)
    return s[:max_chars] + ("…" if len(s) > max_chars else "")

@api.post("/text2sql")
def text2sql(req: Text2SQLReq):
    try:
        semantic = build_semantic_layer(DB_PATH)
        semantic_context = {
            "summary": semantic.get("summary", ""),
            "tables": semantic.get("schema", {}).get("tables", []),
        }

        messages = [
            {"role": "system", "content": SQL_SYSTEM},
            {"role": "user", "content": f"SEMANTIC_MODEL:\n{safe_json(semantic_context)}\n\nQUESTION:\n{req.question}"}
        ]

        resp = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=messages,
            temperature=0.1,
        )
        text = resp.choices[0].message.content.strip()
        pack = json.loads(text)

        return {
            "sql": (pack.get("sql") or "").strip(),
            "params": pack.get("params") or {},
            "notes": pack.get("notes") or ""
        }

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="El modelo no devolvió JSON válido en /text2sql.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
if __name__ == "__main__":
    # Ejemplo local rápido (sin uvicorn)
    print(json.dumps(build_semantic_layer(get_db_path())["summary"], ensure_ascii=False, indent=2))
