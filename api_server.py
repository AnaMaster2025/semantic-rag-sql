# api_server.py
import json
import uuid
import sqlite3
import pathlib
from fastapi import FastAPI
from pydantic import BaseModel
from fastapi_app import run_with_metrics  # import existing evaluator

app = FastAPI(title="LangGraph Teams API with History")

DB_PATH = pathlib.Path("metrics.sqlite").resolve()


def ensure_schema():
    conn = sqlite3.connect(str(DB_PATH))
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE IF NOT EXISTS llm_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_uuid TEXT NOT NULL UNIQUE,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        elapsed_seconds REAL,
        prompt_tokens INTEGER,
        completion_tokens INTEGER,
        total_tokens INTEGER,
        cost_usd REAL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS hallucination_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        llm_run_id INTEGER NOT NULL,
        is_hallucination INTEGER,
        hallucination_evaluation TEXT,
        raw_json TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(llm_run_id) REFERENCES llm_runs(id)
    );
    """)

    conn.commit()
    conn.close()


def infer_is_hallucination(evaluation: str) -> int:
    if not evaluation:
        return None
    text = evaluation.lower()
    if "sin alucinación" in text or "no hay alucinación" in text:
        return 0
    if "alucinación" in text:
        return 1
    return None


class QueryRequest(BaseModel):
    question: str


class QueryResponse(BaseModel):
    answer: str
    elapsed_seconds: float
    hallucination_evaluation: str
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    cost_usd: float
    run_uuid: str
    is_hallucination: int | None


@app.post("/ask", response_model=QueryResponse)
async def ask(req: QueryRequest):
    ensure_schema()

    result = run_with_metrics(req.question)

    is_hall = infer_is_hallucination(result.get("hallucination_evaluation", ""))
    run_uuid = str(uuid.uuid4())

    conn = sqlite3.connect(str(DB_PATH))
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO llm_runs (
            run_uuid, question, answer, elapsed_seconds,
            prompt_tokens, completion_tokens, total_tokens, cost_usd
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        run_uuid,
        req.question,
        result["answer"],
        float(result["elapsed_seconds"]),
        int(result["prompt_tokens"]),
        int(result["completion_tokens"]),
        int(result["total_tokens"]),
        float(result["cost_usd"]),
    ))
    llm_run_id = cur.lastrowid

    cur.execute("""
        INSERT INTO hallucination_metrics (
            llm_run_id, is_hallucination, hallucination_evaluation, raw_json
        )
        VALUES (?, ?, ?, ?)
    """, (
        llm_run_id,
        is_hall,
        result["hallucination_evaluation"],
        json.dumps(result, ensure_ascii=False),
    ))

    conn.commit()
    conn.close()

    return QueryResponse(
        answer=result["answer"],
        elapsed_seconds=result["elapsed_seconds"],
        hallucination_evaluation=result["hallucination_evaluation"],
        prompt_tokens=result["prompt_tokens"],
        completion_tokens=result["completion_tokens"],
        total_tokens=result["total_tokens"],
        cost_usd=result["cost_usd"],
        run_uuid=run_uuid,
        is_hallucination=is_hall,
    )
