def test_sql_blocks_non_select(client):
    r = client.post("/sql", json={"sql": "DELETE FROM customers"})
    assert r.status_code == 400

def test_sql_blocks_multiple_statements(client):
    r = client.post("/sql", json={"sql": "SELECT 1; SELECT 2"})
    assert r.status_code == 400

def test_sql_allows_select(client):
    r = client.post("/sql", json={"sql": "SELECT COUNT(*) AS n FROM customers"})
    assert r.status_code == 200
    body = r.json()
    assert body["rowcount"] == 1
    assert "rows" in body
    assert body["rows"][0]["n"] == 2
