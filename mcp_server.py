import sys, json, sqlite3, pathlib, os
from typing import Any, Dict, Optional, List
import sys, json, sqlite3, pathlib, os
from typing import Any, Dict, Optional, List

from mcp.server.fastmcp import FastMCP, Image  # 👈 añade Image
from semantic_layer import build_semantic_layer
from fastapi_app import run_with_metrics  # importa tu grafo + métricas

import tempfile  # 👈 para el directorio temporal
import uuid      # 👈 para nombre único del fichero
import matplotlib.pyplot as plt  # 👈 para graficar
from semantic_layer import build_semantic_layer
from fastapi_app import run_with_metrics  # importa tu grafo + métricas


mcp = FastMCP("semantic-rag-sql")

# --- Helpers de acceso por país ---------------------------------------------

_COUNTRY_KEYS = ("country", "country_code", "pais")

def _resolve_db(inline_path: Optional[str]) -> pathlib.Path:
    if inline_path:
        return pathlib.Path(inline_path).expanduser().resolve()
    env_p = os.getenv("DB_PATH")
    if env_p:
        return pathlib.Path(env_p).expanduser().resolve()
    here = pathlib.Path(__file__).parent
    return (here / "db.sqlite").resolve()

def _parse_countries(user_countries: Optional[str]) -> Optional[List[str]]:
    """
    Convierte "ES,FR" -> ["ES","FR"] con espacios recortados y en mayúsculas.
    Si None o cadena vacía -> None (usuario global).
    """
    if not user_countries:
        return None
    items = [c.strip().upper() for c in user_countries.split(",") if c.strip()]
    return items or None

def _filter_rows_by_country(rows: List[Dict[str, Any]], allowed: Optional[List[str]]) -> Dict[str, Any]:
    """
    Si allowed es None -> usuario global (no filtra).
    Si allowed tiene países -> filtra por columnas de país si existen.
    """
    if allowed is None:
        return {
            "rows": rows,
            "rowcount": len(rows),
            "access_filter_applied": False,
            "access_note": "GLOBAL_USER: sin filtrado por país (se devolvió todo el resultado)."
        }

    # Detectar la primera columna de país disponible
    country_key_present = None
    for key in _COUNTRY_KEYS:
        if any(key in r for r in rows):
            country_key_present = key
            break

    if not country_key_present:
        # No hay columna país en el resultado -> no es posible filtrar a nivel de filas
        return {
            "rows": rows,
            "rowcount": len(rows),
            "access_filter_applied": False,
            "access_note": (
                "RESTRICTED_USER: no se encontró columna de país en el resultado "
                "('country', 'country_code' o 'pais'); no se puede filtrar filas."
            )
        }

    # Filtrar respetando allowed
    filtered = []
    for r in rows:
        val = r.get(country_key_present)
        if isinstance(val, str):
            if val.upper() in allowed:
                filtered.append(r)
        else:
            # Si el valor no es str (o es None), lo tratamos como no autorizado
            # Puedes relajar esta política si tu modelo de datos lo requiere
            pass

    return {
        "rows": filtered,
        "rowcount": len(filtered),
        "access_filter_applied": True,
        "access_note": f"Filtrado por país en columna '{country_key_present}' · allowed={allowed}"
    }

# --- Tools MCP ---------------------------------------------------------------

@mcp.tool()
async def get_semantic_layer(db_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Devuelve la capa semántica (sin filtrado por país; es metadato).
    Si quieres también recortarla por país (p.ej. ocultar tablas), se puede extender.
    """
    p = _resolve_db(db_path)
    return build_semantic_layer(str(p))

@mcp.tool()
async def run_sql(
    sql: str,
    db_path: Optional[str] = None,
    limit: int = 1000,
    user_countries: Optional[str] = None
) -> Dict[str, Any]:
    """
    Ejecuta SELECT/CTE en modo lectura y filtra filas por país (si user_countries se indica).
    - user_countries: cadena CSV con países, p.ej. "ES" o "ES,FR".
    """
    q = sql.strip().lower()
    if q.startswith(("update","delete","insert","drop","alter","create","pragma")):
        return {"error": "Solo se permiten SELECT/CTE (lectura)."}

    p = _resolve_db(db_path)
    if not p.exists():
        return {"error": f"DB no encontrada: {p}"}

    allowed = _parse_countries(user_countries)

    try:
        conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True, timeout=10, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute(sql)
        rows_db = cur.fetchmany(limit)  # límite antes del filtrado
        cols = [c[0] for c in cur.description] if cur.description else []
        rows = [{cols[i]: r[i] for i in range(len(cols))} for r in rows_db]

        filtered_info = _filter_rows_by_country(rows, allowed)
        # Reaplicar límite (por si el filtrado reduce o cambia recuento)
        final_rows = filtered_info["rows"][:limit]
        return {
            "rows": final_rows,
            "rowcount": len(final_rows),
            "db": str(p),
            "access_filter_applied": filtered_info["access_filter_applied"],
            "access_note": filtered_info["access_note"]
        }
    except Exception as e:
        return {"error": str(e), "db": str(p)}
    finally:
        try:
            conn.close()
        except:
            pass

@mcp.tool()
async def ask_teams_with_metrics(question: str) -> Dict[str, Any]:
    """
    Llama al grafo LangGraph (manager + research/dev team) y devuelve:

    - answer: respuesta del equipo
    - elapsed_seconds: tiempo de respuesta total
    - hallucination_evaluation: juicio textual de alucinaciones
    """
    result = run_with_metrics(question)
    # run_with_metrics ya devuelve un dict del tipo:
    # { "answer": str, "elapsed_seconds": float, "hallucination_evaluation": str }
    return result


@mcp.tool()
async def anthropic_env_check() -> str:
    """Comprueba si el proceso tiene ANTHROPIC_API_KEY (no hace llamadas a la API)."""
    import os, sys
    key = os.getenv("ANTHROPIC_API_KEY")
    py = sys.executable
    if key:
        return f"OK: ANTHROPIC_API_KEY presente (prefijo: {key[:10]}…) · py={py}"
    else:
        return f"SIN CLAVE: defínela en el 'env' del JSON de Claude · py={py}"

@mcp.tool()
async def anthropic_ping(model: str = "claude-3-haiku-20240307") -> str:
    """Llama a la API de Anthropic con la clave del entorno y devuelve un eco corto."""
    import os, sys
    key = os.getenv("ANTHROPIC_API_KEY")
    if not key:
        return "SIN CLAVE: ANTHROPIC_API_KEY no está en este proceso"
    try:
        from anthropic import Anthropic
        client = Anthropic(api_key=key)
        msg = client.messages.create(
            model=model,
            max_tokens=8,
            messages=[{"role": "user", "content": "ping"}]
        )
        text = getattr(msg.content[0], "text", str(msg.content))[:40]
        return f"OK: Claude respondió · model={model} · py={sys.executable} · '{text}'"
    except Exception as e:
        return f"ERROR llamando a Anthropic: {type(e).__name__}: {e}"

@mcp.tool()
async def db_env_check() -> str:
    import os, pathlib
    p = os.getenv("DB_PATH")
    return f"DB_PATH={p} · exists={pathlib.Path(p or '').exists()}"


if __name__ == "__main__":
    print("🚀 MCP server 'semantic-rag-sql' (STDIO) iniciado", file=sys.stderr)
    mcp.run(transport="stdio")
