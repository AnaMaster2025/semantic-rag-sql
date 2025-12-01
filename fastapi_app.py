import time
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Dict, Any

from langgraph.graph import StateGraph, MessagesState, START, END

from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from langchain_core.runnables import RunnableLambda
from dotenv import load_dotenv
from dataclasses import dataclass
import os

# Cargar variables del archivo .env
load_dotenv()
# Ruta a la base de datos SQLite (misma que usa mcp_server)
HERE = Path(__file__).parent
DB_PATH = os.getenv("DB_PATH", str(HERE / "db.sqlite"))
# Opcional: verifica que se cargó
print("OPENAI_API_KEY:", os.getenv("OPENAI_API_KEY")[:10], "...")
# =========================
# 1. MODELOS LLM
# =========================

# LLM principal para los equipos y el manager
llm = ChatOpenAI(
    model="gpt-4o-mini",
    temperature=0.3,
)

# LLM evaluador para alucinaciones (puede ser el mismo modelo u otro más estricto)
judge_llm = ChatOpenAI(
    model="gpt-4o-mini",
    temperature=0,
)

@dataclass
class UsageAccumulator:
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0

usage_acc = UsageAccumulator()


def reset_usage():
    usage_acc.prompt_tokens = 0
    usage_acc.completion_tokens = 0
    usage_acc.total_tokens = 0


def add_usage_from_response(resp):
    """
    Extrae usage_metadata de la respuesta del LLM (si existe)
    y lo acumula en usage_acc.
    """
    usage = getattr(resp, "usage_metadata", None)
    if not usage:
        return

    # En langchain-openai normalmente tienes:
    # {'input_tokens': ..., 'output_tokens': ..., 'total_tokens': ...}
    usage_acc.prompt_tokens += int(usage.get("input_tokens", 0) or 0)
    usage_acc.completion_tokens += int(usage.get("output_tokens", 0) or 0)
    usage_acc.total_tokens += int(usage.get("total_tokens", 0) or 0)


def call_llm(model, messages):
    """
    Wrapper para invocar al LLM y acumular tokens.
    """
    resp = model.invoke(messages)
    add_usage_from_response(resp)
    return resp

# =========================
# 2. NODOS DEL GRAFO
# =========================

def main_manager(state: MessagesState) -> Dict[str, Any]:
    """
    Nodo manager: decide a qué equipo mandar la consulta.
    Devuelve 'next' = 'research' o 'dev'.
    """
    msgs = state["messages"]
    response = call_llm.invoke(
        llm,
        [
            SystemMessage(
                content=(
                    "Eres un manager que decide a qué equipo asignar la tarea. "
                    "Responde SOLO con una palabra: 'research' o 'dev'."
                )
            ),
            *msgs,
        ]
    )
    decision_raw = response.content.strip().lower()

    if "research" in decision_raw:
        next_step = "research"
    elif "dev" in decision_raw:
        next_step = "dev"
    else:
        # fallback por si el modelo se pone creativo
        next_step = "research"

    return {"next": next_step}


def research_team_node(state: MessagesState) -> Dict[str, Any]:
    msgs = state["messages"]
    response = call_llm(
        llm,
        [
            SystemMessage(
                content=(
                    "Eres un equipo de investigación especializado. "
                    "Proporciona análisis detallados de tecnologías emergentes, "
                    "tendencias del mercado y mejores prácticas. "
                    "Sé estructurado y cita supuestos claramente."
                )
            ),
            *msgs,
        ]
    )
    return {
        "messages": msgs + [AIMessage(content=response.content)]
    }

def dev_team_node(state: MessagesState) -> Dict[str, Any]:
    msgs = state["messages"]
    response = call_llm(
        llm,
        [
            SystemMessage(
                content=(
                    "Eres un equipo de desarrollo experto. "
                    "Proporciona soluciones técnicas, arquitecturas y "
                    "recomendaciones de implementación detalladas. "
                    "Aclara supuestos y limita lo especulativo."
                )
            ),
            *msgs,
        ]
    )
    return {
        "messages": msgs + [AIMessage(content=response.content)]
    }


# =========================
# 3. GRAFO DE LANGGRAPH
# =========================

workflow = StateGraph(MessagesState)

workflow.add_node("manager", main_manager)
workflow.add_node("research_team", research_team_node)
workflow.add_node("dev_team", dev_team_node)

workflow.add_edge(START, "manager")

workflow.add_conditional_edges(
    "manager",
    lambda state: state["next"],
    path_map={
        "research": "research_team",
        "dev": "dev_team",
    },
)

workflow.add_edge("research_team", END)
workflow.add_edge("dev_team", END)

app = workflow.compile()


# =========================
# 4. EVALUADOR DE ALUCINACIONES
# =========================

def hallucination_detector(inputs: Dict[str, str]) -> Dict[str, Any]:
    """
    Evaluador simple de alucinaciones:
    - Recibe 'question' y 'answer'
    - Devuelve un dict con nivel de riesgo y explicación

    IMPORTANTE: sin 'ground truth' real solo es una estimación,
    el LLM juzga si la respuesta parece hacer afirmaciones
    muy concretas sin justificar, o claramente incorrectas.
    """
    question = inputs["question"]
    answer = inputs["answer"]

    prompt = f"""
Eres un evaluador crítico de respuestas de IA.

Usuario preguntó:
\"\"\"{question}\"\"\"

La IA respondió:
\"\"\"{answer}\"\"\"

TAREA:
1. Valora si la respuesta contiene posibles ALUCINACIONES
   (afirmaciones muy concretas o numéricas sin fuente clara,
    hechos dudosos o inconsistentes).
2. Devuelve tu juicio en este esquema:

- riesgo_alucinacion: bajo / medio / alto
- explicacion: texto breve explicando por qué

Responde en formato conciso de texto, por ejemplo:
"riesgo_alucinacion: medio
explicacion: La respuesta hace suposiciones sobre datos históricos sin citarlos..."
"""

    evaluation = call_llm(judge_llm, prompt)
    return {
        "raw_evaluation": evaluation.content
    }


hallucination_checker = RunnableLambda(hallucination_detector)

def extract_riesgo(raw_eval: str) -> str:
    """
    Extrae 'riesgo_alucinacion: X' de la salida del evaluador.
    Si no lo encuentra, devuelve 'desconocido'.
    """
    if not raw_eval:
        return "desconocido"

    for line in str(raw_eval).splitlines():
        line_low = line.strip().lower()
        if line_low.startswith("riesgo_alucinacion"):
            # Puede venir como "riesgo_alucinacion: medio"
            parts = line.split(":", 1)
            if len(parts) == 2:
                return parts[1].strip().lower()
    return "desconocido"

def log_metrics_to_db(
    question: str,
    total_tokens: int,
    cost_usd: float,
    raw_hallu_eval: str
) -> None:
    """
    Inserta un registro de observabilidad en SQLite:
    - timestamp (UTC, ISO)
    - question (texto de la consulta)
    - total_tokens
    - cost_usd
    - riesgo_alucinacion (parseado del texto del evaluador)
    """
    ts = datetime.utcnow().isoformat()
    riesgo = extract_riesgo(raw_hallu_eval)

    try:
        conn = sqlite3.connect(DB_PATH)
        cur = conn.cursor()

        # Crear tabla si no existe
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS agent_observability (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts TEXT NOT NULL,
                question TEXT NOT NULL,
                total_tokens INTEGER NOT NULL,
                cost_usd REAL NOT NULL,
                riesgo_alucinacion TEXT NOT NULL
            )
            """
        )

        # Insertar fila
        cur.execute(
            """
            INSERT INTO agent_observability
                (ts, question, total_tokens, cost_usd, riesgo_alucinacion)
            VALUES (?, ?, ?, ?, ?)
            """,
            (ts, question, int(total_tokens), float(cost_usd), riesgo),
        )

        conn.commit()
    except Exception as e:
        # No queremos romper la respuesta al usuario si falla el log
        print(f"[WARN] Error al guardar métricas en SQLite: {e}")
    finally:
        try:
            conn.close()
        except:
            pass
# =========================
# 5. FUNCIÓN DE EJECUCIÓN CON MÉTRICAS
# =========================

def run_with_metrics(user_query: str) -> Dict[str, Any]:
    """
    Ejecuta el grafo:
    - Mide tiempo de respuesta total
    - Devuelve la última respuesta del equipo
    - Ejecuta evaluación de alucinación sobre esa respuesta
    - Registra un histórico en SQLite con:
      timestamp, question, total_tokens, cost_usd, riesgo_alucinacion
    """
    # 1) Tiempo de respuesta
    t0 = time.perf_counter()
    result_state = app.invoke(
        {
            "messages": [HumanMessage(content=user_query)]
        }
    )
    elapsed = time.perf_counter() - t0

    # 2) Último mensaje del grafo
    final_message = result_state["messages"][-1]
    answer_text = final_message.content

    # 3) Evaluación de alucinaciones
    hallu_result = hallucination_checker.invoke(
        {"question": user_query, "answer": answer_text}
    )
    raw_eval = hallu_result["raw_evaluation"]

    # 4) (Opcional) Métricas de tokens/coste
    # De momento lo dejamos a 0 para no romper nada.
    # Más adelante podemos sustituir esto por valores reales.
    total_tokens = 0
    cost_usd = 0.0

    # 5) Guardar histórico en SQLite
    log_metrics_to_db(
        question=user_query,
        total_tokens=total_tokens,
        cost_usd=cost_usd,
        raw_hallu_eval=raw_eval,
    )

    return {
        "answer": answer_text,
        "elapsed_seconds": elapsed,
        "hallucination_evaluation": raw_eval,
        # Si más tarde amplías el schema de respuesta:
        # "total_tokens": total_tokens,
        # "cost_usd": cost_usd,
    }
# =========================
# 6. EJEMPLO DE USO
# =========================

if __name__ == "__main__":
    query = "Necesito investigar nuevas tecnologías para data governance y calidad del dato en entornos Fabric y SAP."
    result = run_with_metrics(query)

    print("=== RESPUESTA DEL EQUIPO ===")
    print(result["answer"])
    print("\n=== TIEMPO (s) ===")
    print(result["elapsed_seconds"])
    print("\n=== EVALUACIÓN DE ALUCINACIONES ===")
    print(result["hallucination_evaluation"])

