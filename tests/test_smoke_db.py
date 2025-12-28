def test_db_has_sales_orders(db_conn):
    cur = db_conn.cursor()
    n = cur.execute("SELECT COUNT(*) FROM sales_orders").fetchone()[0]
    assert n > 0