def test_semantic_endpoint_returns_schema(client):
    r = client.get("/semantic")
    assert r.status_code == 200
    data = r.json()

    assert "schema" in data
    assert "tables" in data["schema"]
    assert "customers" in data["schema"]["tables"]
    assert "sales_orders" in data["schema"]["tables"]

    assert "summary" in data
    assert isinstance(data["summary"], str)

