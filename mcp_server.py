#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, sys, json, time, uuid, pathlib, logging
from typing import Any, Dict, Optional, List

import requests
from mcp.server.fastmcp import FastMCP
from semantic_layer import build_semantic_layer

mcp = FastMCP("semantic-rag-sql")

API_BASE_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000")

_COUNTRY_KEYS = ("country", "country_code", "pais")

def _new_parent_run_uuid() -> str:
    return f"parent-{uuid.uuid4()}"

def _resolve_db(inline_path: Optional[str]) -> pathlib.Path:
    if inline_path:
        return pathlib.Path(inline_path).expanduser().resolve()
    env_p = os.getenv("DB_PATH")
    if env_p:
        return pathlib.Path(env_p).expanduser().resolve()
    here = pathlib.Path(__file__).parent
    return (here / "db.sqlite").resolve()

def _parse_countries(user_countries: Optional[str]) -> Optional[List[str]]:
    if not user_countries:
        return None
    items = [c.strip().upper() for c in user_countries.split(",") if c.strip()]
    return items or None

def _filter_rows_by_country(rows: List[Dict[str, Any]], allowed: Optional[List[str]]) -> Dict[str, Any]:
    if allowed is None:
        return {"rows": rows, "rowcount": len(rows), "access_filter_applied": False, "access_note": "GLOBAL_USER"}
    country_key_present = None
    for key in _COUNTRY_KEYS:
        if any(key in r for r in rows):
            country_key_present = key
            break
    if not country_key_present:
        return {"rows": rows, "rowcount": len(rows), "access_filter_applied": False, "access_note": "NO_COUNTRY_COLUMN"}
    filtered = [r for r in rows if isinstance(r.get(country_key_present), str) and r.get(country_key_present).upper() in allowed]
    return {"rows": filtered, "rowcount": len(filtered), "access_filter_applied": True, "access_note": f"filtered_by={country_key_present} allowed={allowed}"}

@mcp.tool()
async def get_semantic_layer(db_path: Optional[str] = None) -> Dict[str, Any]:
    p = _resolve_db(db_path)
    return build_semantic_layer(str(p))

@mcp.tool()
async def ask_teams_with_metrics(question: str, user_countries: Optional[str] = None, limit: int = 200) -> Dict[str, Any]:
    """
    Flujo gobernado end-to-end:
    Claude Desktop -> MCP tool -> /text2sql (gpt-4o-mini) -> /query (SQL) -> respuesta.
    Inserta métricas en db.sqlite en las tablas oficiales vía FastAPI.
    """
    parent_run_uuid = _new_parent_run_uuid()
    t0 = time.perf_counter()
   
   # NEW: construir semantic layer en MCP (mismo db.sqlite)
    db_path = _resolve_db(None)  # o si tienes parámetro db_path, úsalo
    semantic = build_semantic_layer(str(db_path))

    # 1) text2sql
    t_text2sql = time.perf_counter()
    r1 = requests.post(f"{API_BASE_URL}/text2sql", json={"parent_run_uuid": parent_run_uuid, "question": question}, timeout=60)
    if r1.status_code != 200:
        return {"error": f"/text2sql failed: {r1.status_code} {r1.text}", "parent_run_uuid": parent_run_uuid}
    pack = r1.json()
    text2sql_run_uuid = pack.get("run_uuid")
    sql = pack.get("sql")
    params = pack.get("params") or {}
    notes = pack.get("notes") or ""
    elapsed_text2sql = time.perf_counter() - t_text2sql

    # 2) query execution
    t_query = time.perf_counter()
    r2 = requests.post(
        f"{API_BASE_URL}/query",
        json={"parent_run_uuid": parent_run_uuid, "question": question, "sql": sql, "params": params},
        timeout=60
    )
    if r2.status_code != 200:
        return {
            "error": f"/query failed: {r2.status_code} {r2.text}",
            "parent_run_uuid": parent_run_uuid,
            "text2sql_run_uuid": text2sql_run_uuid,
            "sql": sql,
            "notes": notes,
        }
    out = r2.json()
    query_run_uuid = out.get("run_uuid")
    rows = out.get("rows") or []
    elapsed_query = time.perf_counter() - t_query

    # 3) filtrado por país (si quieres mantenerlo en MCP)
    allowed = _parse_countries(user_countries)
    filtered_info = _filter_rows_by_country(rows, allowed)
    final_rows = filtered_info["rows"][: max(1, int(limit))]

    elapsed_total = time.perf_counter() - t0

    return {
        "parent_run_uuid": parent_run_uuid,
        "text2sql_run_uuid": text2sql_run_uuid,
        "query_run_uuid": query_run_uuid,
        "notes": notes,
        "sql": sql,
        "rowcount": len(final_rows),
        "rows": final_rows,
        "timing": {
            "text2sql_seconds": elapsed_text2sql,
            "query_seconds": elapsed_query,
            "total_seconds": elapsed_total,
        },
        "access_filter_applied": filtered_info["access_filter_applied"],
        "access_note": filtered_info["access_note"],
    }

if __name__ == "__main__":
    logging.basicConfig(stream=sys.stderr, level=logging.INFO)
    mcp.run(transport="stdio")
