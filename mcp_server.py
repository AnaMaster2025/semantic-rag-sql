#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import json
import sqlite3
import pathlib
import logging
from typing import Any, Dict, Optional, List

from mcp.server.fastmcp import FastMCP, Image  # Image si lo usas en tools futuras
from semantic_layer import build_semantic_layer

# -----------------------------------------------------------------------------
# MCP App
# -----------------------------------------------------------------------------
mcp = FastMCP("semantic-rag-sql")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
_COUNTRY_KEYS = ("country", "country_code", "pais")


def _resolve_db(inline_path: Optional[str]) -> pathlib.Path:
    """
    Resuelve ruta de DB en orden:
    1) argumento db_path (si viene)
    2) variable de entorno DB_PATH
    3) ./db.sqlite junto al script
    """
    if inline_path:
        return pathlib.Path(inline_path).expanduser().resolve()

    env_p = os.getenv("DB_PATH")
    if env_p:
        return pathlib.Path(env_p).expanduser().resolve()

    here = pathlib.Path(__file__).parent
    return (here / "db.sqlite").resolve()


def _parse_countries(user_countries: Optional[str]) -> Optional[List[str]]:
    """
    Convierte "ES,FR" -> ["ES","FR"] (strip + upper).
    Si None o cadena vacía -> None (usuario global, sin filtro).
    """
    if not user_countries:
        return None
    items = [c.strip().upper() for c in user_countries.split(",") if c.strip()]
    return items or None


def _filter_rows_by_country(rows: List[Dict[str, Any]], allowed: Optional[List[str]]) -> Dict[str, Any]:
    """
    Si allowed es None -> no filtra (usuario global).
    Si allowed tiene países -> filtra por columnas de país si existen.
    """
    if allowed is None:
        return {
            "rows": rows,
            "rowcount": len(rows),
            "access_filter_applied": False,
            "access_note": "GLOBAL_USER: sin filtrado por país (se devolvió todo el resultado).",
        }

    country_key_present = None
    for key in _COUNTRY_KEYS:
        if any(key in r for r in rows):
            country_key_present = key
            break

    if not country_key_present:
        return {
            "rows": rows,
            "rowcount": len(rows),
            "access_filter_applied": False,
            "access_note": (
                "RESTRICTED_USER: no se encontró columna de país en el resultado "
                "('country', 'country_code' o 'pais'); no se puede filtrar filas."
            ),
        }

    filtered: List[Dict[str, Any]] = []
    for r in rows:
        val = r.get(country_key_present)
        if isinstance(val, str) and val.upper() in allowed:
            filtered.append(r)

    return {
        "rows": filtered,
        "rowcount": len(filtered),
        "access_filter_applied": True,
        "access_note": f"Filtrado por país en columna '{country_key_present}' · allowed={allowed}",
    }


def _is_readonly_sql(sql: str) -> bool:
    """
    Permite SELECT/CTE (WITH ... SELECT). Bloquea mutaciones y PRAGMA.
    Nota: esto es un guardrail básico; no sustituye un SQL parser.
    """
    s = sql.strip().lower()
    if not s:
        return False

    # Permite SELECT directo o WITH (CTE)
    if s.startswith("select") or s.startswith("with"):
        return True

    return False


def _contains_forbidden_keywords(sql: str) -> Optional[str]:
    """
    Bloquea keywords típicas de escritura/DDL. Devuelve el keyword si se detecta.
    """
    forbidden = [
        "insert", "update", "delete", "drop", "alter", "create",
        "pragma", "attach", "detach", "vacuum", "reindex", "replace"
    ]
    s = sql.lower()
    for kw in forbidden:
        # búsqueda simple (puedes endurecer con regex si quieres)
        if kw in s:
            return kw
    return None


# -----------------------------------------------------------------------------
# MCP Tools
# -----------------------------------------------------------------------------
@mcp.tool()
async def get_semantic_layer(db_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Devuelve la capa semántica (metadatos).
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
    Ejecuta SQL en modo lectura contra SQLite y (opcionalmente) filtra filas por país.
    - Solo permite SELECT/CTE.
    - limit: máximo de filas devueltas.
    - user_countries: "ES" o "ES,FR" para filtrado.
    """
    if not _is_readonly_sql(sql):
        return {"error": "Solo se permiten consultas SELECT o WITH (CTE)."}

    forbidden_hit = _contains_forbidden_keywords(sql)
    if forbidden_hit:
        return {"error": f"SQL bloqueado: detectado keyword prohibido '{forbidden_hit}' (solo lectura)."}

    p = _resolve_db(db_path)
    if not p.exists():
        return {"error": f"DB no encontrada: {p}", "db": str(p)}

    allowed = _parse_countries(user_countries)

    conn: Optional[sqlite3.Connection] = None
    try:
        conn = sqlite3.connect(f"file:{p}?mode=ro", uri=True, timeout=10, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute(sql)

        rows_db = cur.fetchmany(max(1, int(limit)))  # límite antes del filtrado
        cols = [c[0] for c in cur.description] if cur.description else []
        rows = [{cols[i]: r[i] for i in range(len(cols))} for r in rows_db]

        filtered_info = _filter_rows_by_country(rows, allowed)
        final_rows = filtered_info["rows"][: max(1, int(limit))]

        return {
            "rows": final_rows,
            "rowcount": len(final_rows),
            "columns": cols,
            "db": str(p),
            "access_filter_applied": filtered_info["access_filter_applied"],
            "access_note": filtered_info["access_note"],
        }
    except Exception as e:
        # OJO: nunca print a stdout. Logs a stderr via logging.
        logging.exception("Error en run_sql")
        return {"error": f"{type(e).__name__}: {e}", "db": str(p)}
    finally:
        if conn is not None:
            try:
                conn.close()
            except Exception:
                pass


@mcp.tool()
async def ask_teams_with_metrics(question: str) -> Dict[str, Any]:
    """
    Llama al grafo (LangGraph / tu lógica) y devuelve métricas.
    Import LAZY para evitar side-effects al arrancar el servidor MCP (stdio).
    """
    try:
        from fastapi_app import run_with_metrics  # <-- IMPORT PEREZOSO
        result = run_with_metrics(question)
        # Se espera dict: {"answer": str, "elapsed_seconds": float, "hallucination_evaluation": str}
        if not isinstance(result, dict):
            return {"error": "run_with_metrics devolvió un tipo no dict", "type": str(type(result))}
        return result
    except Exception as e:
        logging.exception("Error en ask_teams_with_metrics")
        return {"error": f"{type(e).__name__}: {e}"}


@mcp.tool()
async def anthropic_env_check() -> str:
    """
    Comprueba si el proceso tiene ANTHROPIC_API_KEY (no hace llamadas).
    No imprime prefijos de la clave (seguridad).
    """
    key = os.getenv("ANTHROPIC_API_KEY")
    py = sys.executable
    return f"{'OK' if key else 'SIN CLAVE'}: ANTHROPIC_API_KEY {'presente' if key else 'NO presente'} · py={py}"


@mcp.tool()
async def anthropic_ping(model: str = "claude-3-haiku-20240307") -> str:
    """
    Llama a la API de Anthropic y devuelve un eco corto.
    OJO: evita logs en stdout; cualquier error va a stderr vía logging.
    """
    key = os.getenv("ANTHROPIC_API_KEY")
    if not key:
        return "SIN CLAVE: ANTHROPIC_API_KEY no está en este proceso"

    try:
        from anthropic import Anthropic
        client = Anthropic(api_key=key)
        msg = client.messages.create(
            model=model,
            max_tokens=8,
            messages=[{"role": "user", "content": "ping"}],
        )
        text = getattr(msg.content[0], "text", str(msg.content))[:60]
        return f"OK: Claude respondió · model={model} · '{text}'"
    except Exception as e:
        logging.exception("Error en anthropic_ping")
        return f"ERROR llamando a Anthropic: {type(e).__name__}: {e}"


@mcp.tool()
async def db_env_check() -> str:
    p = os.getenv("DB_PATH")
    exists = pathlib.Path(p).exists() if p else False
    return f"DB_PATH={p} · exists={exists}"


# -----------------------------------------------------------------------------
# Main (STDIO transport)
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    # IMPORTANTÍSIMO: nada de prints a stdout (rompe MCP).
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)

    logging.info("🚀 MCP server 'semantic-rag-sql' (STDIO) iniciado")
    # Ejecuta en stdio para Claude Desktop
    mcp.run(transport="stdio")
