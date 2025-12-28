import os
import json
import requests
import pandas as pd
import streamlit as st
from dotenv import load_dotenv

load_dotenv()
FASTAPI_URL = os.getenv("FASTAPI_URL", "http://127.0.0.1:8001")

st.set_page_config(page_title="Semantic Sales Analyst", layout="wide")
st.title("💬 Semantic Sales Analyst (Invoices = Ventas)")

# -----------------------------
# Helpers: semántica + text2sql + ejecución gobernada
# -----------------------------
@st.cache_data(ttl=300)
def fetch_semantic():
    r = requests.get(f"{FASTAPI_URL}/semantic", timeout=30)
    r.raise_for_status()
    return r.json()

def backend_text2sql(question: str) -> dict:
    """
    Llama a FastAPI /text2sql (que usa semantic_layer + OpenAI en backend).
    Devuelve {"sql": "...", "params": {...}, "notes": "..."}.
    """
    r = requests.post(f"{FASTAPI_URL}/text2sql", json={"question": question}, timeout=60)
    r.raise_for_status()
    return r.json()

def run_governed_query(question: str, sql: str, params: dict | None = None):
    payload = {"question": question, "sql": sql, "params": params or {}}
    r = requests.post(f"{FASTAPI_URL}/query", json=payload, timeout=60)
    r.raise_for_status()
    return r.json()

def safe_json(obj, max_chars=6000):
    s = json.dumps(obj, ensure_ascii=False)
    return s[:max_chars] + ("…" if len(s) > max_chars else "")

# -----------------------------
# Cargar capa semántica (solo para mostrarla)
# -----------------------------
with st.sidebar:
    st.header("Configuración")
    st.write("Backend:", FASTAPI_URL)
    refresh = st.button("🔄 Refrescar semántica")

if refresh:
    st.cache_data.clear()

semantic = fetch_semantic()
semantic_summary = semantic.get("summary", "")
schema_tables = semantic.get("schema", {}).get("tables", [])

with st.sidebar:
    st.subheader("Modelo semántico")
    st.caption("Resumen (semantic_layer.py)")
    st.text_area("summary", value=semantic_summary, height=180)
    st.caption("Tablas detectadas")
    st.write(schema_tables)

# -----------------------------
# Estado de conversación
# -----------------------------
if "messages" not in st.session_state:
    st.session_state.messages = [
        {"role": "assistant", "content": "Hola. Pregúntame por ventas (invoices) o pedidos (sales_orders) por país, mes, clientes o productos."}
    ]

for m in st.session_state.messages:
    with st.chat_message(m["role"]):
        st.markdown(m["content"])

# -----------------------------
# Tendencias deterministas sobre datos
# -----------------------------
def compute_trends(df: pd.DataFrame, time_col: str, group_col: str, value_col: str) -> dict:
    out = {"series": {}, "insights": []}
    if df.empty:
        return out

    d = df.copy()
    d[time_col] = d[time_col].astype(str)
    d[value_col] = pd.to_numeric(d[value_col], errors="coerce").fillna(0)

    pivot = d.pivot_table(index=time_col, columns=group_col, values=value_col, aggfunc="sum").sort_index()
    out["series"]["pivot"] = pivot

    pct = pivot.pct_change() * 100.0
    out["series"]["pct_change"] = pct

    roll = pivot.rolling(3).mean()
    out["series"]["rolling3"] = roll

    if len(pivot.index) >= 1:
        last_t = pivot.index[-1]
        prev_t = pivot.index[-2] if len(pivot.index) >= 2 else None
        for g in pivot.columns:
            last_val = float(pivot.loc[last_t, g])
            if prev_t is not None:
                prev_val = float(pivot.loc[prev_t, g])
                mom = ((last_val - prev_val) / prev_val * 100.0) if prev_val != 0 else None
                out["insights"].append({
                    "group": str(g),
                    "last_period": str(last_t),
                    "last_value": last_val,
                    "prev_period": str(prev_t),
                    "pct_change": mom
                })
            else:
                out["insights"].append({
                    "group": str(g),
                    "last_period": str(last_t),
                    "last_value": last_val,
                    "prev_period": None,
                    "pct_change": None
                })
    return out

def pick_first(cols, candidates):
    for c in candidates:
        if c in cols:
            return c
    return None

def write_deterministic_insights(user_question: str, trend_brief: dict) -> str:
    # Resumen corto sin LLM (para no depender de OpenAI en Streamlit)
    if trend_brief.get("note"):
        return f"""**Resumen Ejecutivo**: {trend_brief["note"]}

**Hallazgos por Dimensión**:
- No se ha podido calcular una serie temporal estándar con las columnas devueltas.

**Señales/Alertas**:
- Revisa aliases devueltos por SQL (p.ej. `month/day`, `country_code`, `sales_total`) o ajusta el prompt del backend para estandarizarlos.
"""

    lines = []
    lines.append("**Resumen Ejecutivo**: Se han calculado tendencias basadas en los datos devueltos.")
    lines.append("")
    lines.append("**Hallazgos por Dimensión**:")
    last_points = trend_brief.get("last_points", [])
    # Top 5 por valor último periodo
    try:
        top = sorted(last_points, key=lambda x: (x.get("last_value") or 0), reverse=True)[:5]
        for t in top:
            ch = t.get("pct_change")
            ch_txt = "N/A" if ch is None else f"{ch:.2f}%"
            lines.append(f"- {t.get('group')}: último={t.get('last_value'):.2f}, variación={ch_txt} ({t.get('prev_period')}→{t.get('last_period')})")
    except Exception:
        lines.append("- (No se pudo construir ranking de insights)")

    lines.append("")
    lines.append("**Señales/Alertas**:")
    lines.append("- Si hay muchos `pct_change = N/A`, puede haber valores previos cero o faltantes.")
    return "\n".join(lines)

# -----------------------------
# Chat input
# -----------------------------
user_input = st.chat_input("Ej.: 'Tendencia de ventas por país en los últimos 6 meses'")

if user_input:
    st.session_state.messages.append({"role": "user", "content": user_input})
    with st.chat_message("user"):
        st.markdown(user_input)

    # 1) Generar SQL en BACKEND usando semantic_layer
    try:
        sql_pack = backend_text2sql(user_input)
        sql = (sql_pack.get("sql") or "").strip()
        params = sql_pack.get("params") or {}
    except Exception as e:
        err = f"Error llamando /text2sql: {e}"
        with st.chat_message("assistant"):
            st.error(err)
        st.session_state.messages.append({"role": "assistant", "content": err})
        st.stop()

    with st.expander("SQL propuesto (desde backend /text2sql)"):
        st.code(sql, language="sql")
        st.write("params:", params)
        st.caption(sql_pack.get("notes", ""))

    # 2) Ejecutar SQL por FastAPI /query
    try:
        api_res = run_governed_query(question=user_input, sql=sql, params=params)
        rows = api_res.get("rows", [])
        df = pd.DataFrame(rows)
    except Exception as e:
        err = f"Error ejecutando /query: {e}"
        with st.chat_message("assistant"):
            st.error(err)
        st.session_state.messages.append({"role": "assistant", "content": err})
        st.stop()

    with st.expander("Datos devueltos"):
        st.dataframe(df, use_container_width=True)

    # 3) Heurística más flexible para tendencias
    cols = list(df.columns)
    time_col  = pick_first(cols, ["month", "day", "date", "invoice_date", "order_date"])
    group_col = pick_first(cols, ["country_code", "country", "country_name"])
    value_col = pick_first(cols, ["sales_total", "orders_total", "order_count", "orders", "count", "total_with_tax", "total"])

    trend_brief = {"note": "dataset no compatible con tendencias estándar (faltan columnas de tiempo/grupo/valor)"}
    if time_col and group_col and value_col:
        trends = compute_trends(df, time_col=time_col, group_col=group_col, value_col=value_col)

        pivot = trends["series"]["pivot"]
        st.subheader("Serie temporal")
        st.line_chart(pivot)

        st.subheader("Variación % periodo a periodo")
        st.dataframe(trends["series"]["pct_change"].round(2), use_container_width=True)

        trend_brief = {
            "time_col": time_col,
            "group_col": group_col,
            "value_col": value_col,
            "last_points": trends["insights"],
        }

    # 4) Respuesta final (determinista, sin OpenAI en Streamlit)
    answer = write_deterministic_insights(user_input, trend_brief)

    with st.chat_message("assistant"):
        st.markdown(answer)

    st.session_state.messages.append({"role": "assistant", "content": answer})
