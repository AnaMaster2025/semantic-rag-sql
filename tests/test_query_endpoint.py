import sqlite3
import os

def test_query_executes_and_logs_observability(client):
    payload = {
        "question": "Pedidos por país",
        "sql": """
            SELECT c.country_code, COUNT(*) AS n
            FROM sales_orders so
            JOIN customers c ON c.id = so.customer_id
            GROUP BY c.country_code
        """,
        "params": {}
    }
    r = client.post("/query", json=payload)
    assert r.status_code == 200
    data = r.json()
    assert data["rowcount"] == 2

    # Verifica que agent_observability tiene al menos 1 fila
    db_path = os.getenv("DB_PATH")
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    n = cur.execute("SELECT COUNT(*) FROM agent_observability").fetchone()[0]
    conn.close()
    assert n >= 1
