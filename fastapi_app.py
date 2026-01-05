# fastapi_app.py
import os, re, json, time, sqlite3, uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from openai import OpenAI

from semantic_layer import build_semantic_layer

def extract_json_object(text: str) -> Dict[str, Any]:
    # elimina fences ```json ... ```
    cleaned = re.sub(r"```(?:json)?", "", text, flags=re.IGNORECASE).replace("```", "").strip()

    # intento directo
    try:
        obj = json.loads(cleaned)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass

    # intenta recortar desde el primer { hasta el último }
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end != -1 and end > start:
        candidate = cleaned[start:end+1]
        obj = json.loads(candidate)
        if isinstance(obj, dict):
            return obj

    raise ValueError("No se pudo extraer un JSON válido")

# -------------------------
# CLIENTE OPENAI
# -------------------------
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
HERE = Path(__file__).parent

def get_db_path() -> str:
    return os.getenv("SQLITE_PATH") or os.getenv("DB_PATH") or str(HERE / "db.sqlite")

def get_db_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(get_db_path(), timeout=10, check_same_thread=False)
    conn.row_factory = sqlite3.Row

    # Recomendado para cloud
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA busy_timeout=5000;")

    return conn

# -------------------------
# Helpers observabilidad oficial
# -------------------------
def new_run_uuid() -> str:
    return f"run-{uuid.uuid4()}"

def jdump(obj: Any) -> str:
    try:
        return json.dumps(obj, ensure_ascii=False)
    except Exception:
        return "{}"

def insert_llm_run(
    *,
    run_uuid: str,
    question: str,
    answer: str,
    elapsed_seconds: float,
    experiment_variant_id: Optional[int] = None,
    prompt_id: Optional[int] = None,
    dataset_item_id: Optional[int] = None,
    user_id: Optional[int] = None,
    model_id: Optional[int] = None,
    customer_id: Optional[int] = None,
    prompt_tokens: Optional[int] = None,
    completion_tokens: Optional[int] = None,
    total_tokens: Optional[int] = None,
    cost_usd: Optional[float] = None,
    temperature: Optional[float] = None,
    top_p: Optional[float] = None,
    max_tokens: Optional[int] = None,
    country_code: Optional[str] = None,
    context_json: Optional[dict] = None,
) -> None:
    conn = get_db_conn()
    try:
        conn.execute(
            """
            INSERT INTO llm_runs
            (run_uuid, experiment_variant_id, prompt_id, dataset_item_id, user_id, model_id, customer_id,
             question, answer, elapsed_seconds, prompt_tokens, completion_tokens, total_tokens, cost_usd,
             temperature, top_p, max_tokens, country_code, context_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_uuid, experiment_variant_id, prompt_id, dataset_item_id, user_id, model_id, customer_id,
                question, answer, float(elapsed_seconds),
                prompt_tokens, completion_tokens, total_tokens, cost_usd,
                temperature, top_p, max_tokens, country_code, jdump(context_json or {})
            ),
        )
        conn.commit()
    finally:
        conn.close()

def add_quality_metric(run_uuid: str, metric_name: str, metric_value: float, metric_json: Optional[dict] = None) -> None:
    conn = get_db_conn()
    try:
        conn.execute(
            """
            INSERT INTO quality_metrics (llm_run_id, metric_name, metric_value, metric_json)
            VALUES ((SELECT id FROM llm_runs WHERE run_uuid=?), ?, ?, ?)
            """,
            (run_uuid, metric_name, float(metric_value), jdump(metric_json or {})),
        )
        conn.commit()
    finally:
        conn.close()

def add_hallucination_eval(
    run_uuid: str,
    evaluator_name: str,
    score: Optional[float],
    is_hallucination: Optional[int],
    method: Optional[str],
    explanation: Optional[str],
    raw_json: Optional[dict] = None,
) -> None:
    conn = get_db_conn()
    try:
        conn.execute(
            """
            INSERT INTO hallucination_evaluations
            (llm_run_id, evaluator_name, score, is_hallucination, method, explanation, raw_json)
            VALUES ((SELECT id FROM llm_runs WHERE run_uuid=?), ?, ?, ?, ?, ?, ?)
            """,
            (run_uuid, evaluator_name, score, is_hallucination, method, explanation, jdump(raw_json or {})),
        )
        conn.commit()
    finally:
        conn.close()

# -------------------------
# Guardrails SQL
# -------------------------
SQL_MULTI_STMT_RE = re.compile(r";\s*\S", re.MULTILINE)
FORBIDDEN_SQL_RE = re.compile(r"\b(drop|delete|truncate|alter|update|insert|attach|detach|pragma|vacuum)\b", re.IGNORECASE)

def assert_sql_safe(sql: str) -> None:
    s = (sql or "").strip()
    if not s:
        raise HTTPException(status_code=400, detail="SQL vacío")
    if not (s.lower().startswith("select") or s.lower().startswith("with")):
        raise HTTPException(status_code=400, detail="Solo SELECT/CTE")
    if SQL_MULTI_STMT_RE.search(s):
        raise HTTPException(status_code=400, detail="Múltiples sentencias (bloqueado)")
    if FORBIDDEN_SQL_RE.search(s):
        raise HTTPException(status_code=400, detail="Keyword prohibida (bloqueado)")

# -------------------------
# API models
# -------------------------
class SQLRequest(BaseModel):
    sql: str
    params: Dict[str, Any] = Field(default_factory=dict)

class SQLResponse(BaseModel):
    sql: str
    params: Dict[str, Any]
    rows: List[Dict[str, Any]]
    rowcount: int
    elapsed_seconds: float

class QueryRequest(BaseModel):
    parent_run_uuid: Optional[str] = None
    question: str
    sql: str
    params: Dict[str, Any] = Field(default_factory=dict)

class QueryResponse(BaseModel):
    run_uuid: str
    parent_run_uuid: Optional[str]
    question: str
    sql: str
    params: Dict[str, Any]
    rows: List[Dict[str, Any]]
    rowcount: int
    elapsed_seconds: float

class Text2SQLReq(BaseModel):
    parent_run_uuid: Optional[str] = None
    question: str

class Text2SQLResp(BaseModel):
    run_uuid: str
    parent_run_uuid: Optional[str]
    sql: str
    params: Dict[str, Any]
    notes: str
    elapsed_seconds: float

# -------------------------
# FastAPI
# -------------------------
api = FastAPI(title="Semantic Governance Data API", version="1.1.0")

@api.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok", "db": get_db_path()}

@api.get("/semantic")
def semantic() -> Dict[str, Any]:
    db_path = get_db_path()
    if not Path(db_path).exists():
        raise HTTPException(status_code=404, detail=f"No existe DB_PATH={db_path}")
    return build_semantic_layer(db_path)

@api.post("/sql", response_model=SQLResponse)
def run_sql(req: SQLRequest) -> SQLResponse:
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
    return SQLResponse(sql=req.sql, params=req.params or {}, rows=rows, rowcount=len(rows), elapsed_seconds=elapsed)

@api.post("/query", response_model=QueryResponse)
def query(req: QueryRequest) -> QueryResponse:
    q = (req.question or "").strip()
    if not q:
        raise HTTPException(status_code=400, detail="question required")
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

    run_uuid = new_run_uuid()

    # Insert run de ejecución SQL (NO es invocación LLM, pero se registra en el mismo modelo)
    insert_llm_run(
        run_uuid=run_uuid,
        question=q,
        answer=f"OK: {len(rows)} filas",
        elapsed_seconds=elapsed,
        context_json={
            "stage": "query_exec",
            "endpoint": "/query",
            "parent_run_uuid": req.parent_run_uuid,
            "sql": req.sql,
            "params": req.params,
            "rowcount": len(rows),
        },
    )
    add_quality_metric(run_uuid, "sql_valid", 1)
    add_quality_metric(run_uuid, "rows_returned", len(rows))
    add_quality_metric(run_uuid, "latency_seconds", elapsed)

    return QueryResponse(
        run_uuid=run_uuid,
        parent_run_uuid=req.parent_run_uuid,
        question=q,
        sql=req.sql,
        params=req.params or {},
        rows=rows,
        rowcount=len(rows),
        elapsed_seconds=elapsed,
    )

SQL_SYSTEM = """Eres un asistente de analítica de datos que genera SQL SOLO de lectura para SQLite.

REGLAS OBLIGATORIAS:
- Responde SOLO con un objeto JSON válido. Sin texto adicional. Sin Markdown. Sin bloques ``` .
- El JSON debe tener EXACTAMENTE estas claves: sql, params, notes
- sql debe ser una consulta SELECT (o WITH + SELECT). Prohibido: INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, PRAGMA.
- params debe ser un objeto JSON (puede ser {}).
- notes debe ser una frase breve.

FORMATO DE SALIDA (ejemplo):
{"sql":"SELECT 1","params":{},"notes":"ok"}
"""


def safe_json(obj, max_chars=6000):
    s = json.dumps(obj, ensure_ascii=False)
    return s[:max_chars] + ("…" if len(s) > max_chars else "")

@api.post("/text2sql", response_model=Text2SQLResp)
def text2sql(req: Text2SQLReq) -> Text2SQLResp:
    t0 = time.perf_counter()

    semantic = build_semantic_layer(get_db_path())
    semantic_context = {
        "summary": semantic.get("summary", ""),
        "tables": semantic.get("schema", {}).get("tables", []),
    }

    messages = [
        {"role": "system", "content": SQL_SYSTEM},
        {"role": "user", "content": f"SEMANTIC_MODEL:\n{safe_json(semantic_context)}\n\nQUESTION:\n{req.question}"},
    ]

    resp = client.chat.completions.create(
        model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
        messages=messages,
        temperature=0.1,
    )
    elapsed = time.perf_counter() - t0

    text = (resp.choices[0].message.content or "").strip()

    def log_json_fail(raw_text: str, reason: str):
        run_uuid_fail = new_run_uuid()
        insert_llm_run(
            run_uuid=run_uuid_fail,
            question=req.question,
            answer=f"ERROR: {reason}",
            elapsed_seconds=elapsed,
            temperature=0.1,
            context_json={
                "stage": "text2sql",
                "endpoint": "/text2sql",
                "parent_run_uuid": req.parent_run_uuid,
                "reason": reason,
                "raw": raw_text[:1000],
            },
        )
        add_quality_metric(run_uuid_fail, "ok", 0, {"reason": reason})
        add_quality_metric(run_uuid_fail, "latency_seconds", elapsed)

    try:
        pack = extract_json_object(text)
        used_resp = resp
    except Exception:
        messages_retry = [
            {
                "role": "system",
                "content": SQL_SYSTEM
                + "\nULTIMO AVISO: Responde SOLO JSON válido. Sin texto extra. Sin Markdown.\n",
            },
            {
                "role": "user",
                "content": f"SEMANTIC_MODEL:\n{safe_json(semantic_context)}\n\nQUESTION:\n{req.question}\n\nRESPUESTA (solo JSON):",
            },
        ]
        resp2 = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=messages_retry,
            temperature=0.0,
        )
        text2 = (resp2.choices[0].message.content or "").strip()

        try:
            pack = extract_json_object(text2)
            used_resp = resp2
        except Exception:
            log_json_fail(text2, "json_decode_retry_failed")
            raise HTTPException(
                status_code=500,
                detail="El modelo no devolvió JSON válido (tras reintento).",
            )

    if "sql" not in pack or "params" not in pack:
        log_json_fail(json.dumps(pack)[:1000], "json_missing_keys")
        raise HTTPException(status_code=500, detail="JSON inválido: faltan claves sql o params")

    sql_out = (pack.get("sql") or "").strip()
    params = pack.get("params") or {}
    notes = pack.get("notes") or ""

    forbidden = ("insert", "update", "delete", "drop", "alter", "create", "pragma")
    if any(tok in sql_out.lower() for tok in forbidden):
        run_uuid_fail = new_run_uuid()
        insert_llm_run(
            run_uuid=run_uuid_fail,
            question=req.question,
            answer="ERROR: SQL no permitido",
            elapsed_seconds=elapsed,
            temperature=0.1,
            context_json={
                "stage": "text2sql",
                "endpoint": "/text2sql",
                "parent_run_uuid": req.parent_run_uuid,
                "sql": sql_out[:500],
            },
        )
        add_quality_metric(run_uuid_fail, "ok", 0, {"reason": "forbidden_sql"})
        add_quality_metric(run_uuid_fail, "latency_seconds", elapsed)
        raise HTTPException(status_code=400, detail="SQL generado no permitido (solo lectura).")

    usage = getattr(used_resp, "usage", None)
    pt = getattr(usage, "prompt_tokens", None)
    ct = getattr(usage, "completion_tokens", None)
    tt = getattr(usage, "total_tokens", None)

    run_uuid = new_run_uuid()
    insert_llm_run(
        run_uuid=run_uuid,
        question=req.question,
        answer=sql_out if sql_out else "(empty sql)",
        elapsed_seconds=elapsed,
        prompt_tokens=pt,
        completion_tokens=ct,
        total_tokens=tt,
        temperature=0.1,
        context_json={
            "stage": "text2sql",
            "endpoint": "/text2sql",
            "parent_run_uuid": req.parent_run_uuid,
            "notes": notes,
        },
    )
    add_quality_metric(run_uuid, "sql_valid", 1 if sql_out else 0)
    add_quality_metric(run_uuid, "latency_seconds", elapsed)

    return Text2SQLResp(
        run_uuid=run_uuid,
        parent_run_uuid=req.parent_run_uuid,
        sql=sql_out,
        params=params,
        notes=notes,
        elapsed_seconds=elapsed,
    )
