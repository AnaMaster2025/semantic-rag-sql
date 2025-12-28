# Semantic RAG → SQL (MCP + Claude + FastAPI)

## Instalación
```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## Crear BD de ejemplo
```bash
python - <<'PY'
import sqlite3, pathlib
sql = pathlib.Path('seed.sql').read_text(encoding='utf-8')
conn = sqlite3.connect('db.sqlite')
conn.executescript(sql); conn.commit(); conn.close()
print('BD creada en db.sqlite')
PY
```

## Ejecutar MCP server
```bash
python mcp_server.py
```
Configura Claude Desktop para usar este comando del venv y el `DB_PATH`.

## Ejecutar FastAPI (NL→SQL con Claude)
```bash
export ANTHROPIC_API_KEY=sk-ant-...
export DB_PATH=$PWD/db.sqlite
uvicorn fastapi_app:app --reload --port 8000
```
- `GET /schema` → capa semántica
- `POST /ask`  → `{ "question": "¿Ventas por país?" }`

## Cómo funciona
- `semantic_layer.py` infiere relaciones con FKs y heurísticas `*_id` y resume la capa en NL.
- `mcp_server.py` expone tools `get_semantic_layer` y `run_sql` (solo SELECT).
- `fastapi_app.py` genera SQL con Claude (Anthropic) usando la capa semántica y ejecuta la consulta.
