import os
import sys
import sqlite3
import pytest
import importlib.util
from pathlib import Path
from fastapi.testclient import TestClient


def _load_module_from_path(module_name: str, path: Path):
    spec = importlib.util.spec_from_file_location(module_name, str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"No se pudo crear spec para {path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="session")
def project_root():
    # tests/ -> proyecto/
    return Path(__file__).resolve().parents[1]


@pytest.fixture()
def temp_db_path(tmp_path: Path, monkeypatch):
    db_path = tmp_path / "test.sqlite"
    monkeypatch.setenv("DB_PATH", str(db_path))
    return db_path


@pytest.fixture()
def seed_db(temp_db_path, project_root):
    conn = sqlite3.connect(temp_db_path)
    cur = conn.cursor()

    cur.executescript(
        """
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            country_code TEXT
        );

        CREATE TABLE IF NOT EXISTS sales_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            order_number TEXT NOT NULL UNIQUE,
            order_date DATE NOT NULL,
            status TEXT NOT NULL DEFAULT 'open',
            currency TEXT NOT NULL DEFAULT 'EUR',
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
        );

        INSERT INTO customers (name, country_code) VALUES
        ('Iberia Retail', 'ES'),
        ('Paris Dist', 'FR');

        INSERT INTO sales_orders (customer_id, order_number, order_date, status, currency) VALUES
        (1, 'SO-ES-1', '2025-12-05', 'shipped', 'EUR'),
        (2, 'SO-FR-1', '2025-12-12', 'shipped', 'EUR');
        """
    )

    conn.commit()
    conn.close()
    return temp_db_path


@pytest.fixture()
def db_conn(seed_db):
    conn = sqlite3.connect(seed_db)
    conn.row_factory = sqlite3.Row
    yield conn
    conn.close()


@pytest.fixture()
def client(seed_db, project_root):
    # Asegura que el root del proyecto está en el path
    if str(project_root) not in sys.path:
        sys.path.insert(0, str(project_root))

    # Busca tu archivo FastAPI (ajusta la lista si tu archivo se llama diferente)
    candidates = [
        "fastapi_app.py",
        "api_server.py",
        "app.py",
        "main.py",
        "server.py",
    ]
    api_file = None
    for name in candidates:
        p = project_root / name
        if p.exists():
            api_file = p
            break

    if api_file is None:
        raise RuntimeError(
            "No encuentro el fichero de FastAPI en la raíz. "
            "Crea fastapi_app.py o añade su nombre a candidates en tests/conftest.py."
        )

    mod = _load_module_from_path("app_under_test", api_file)

    # Tu objeto FastAPI puede llamarse api/app
    api_obj = getattr(mod, "api", None) or getattr(mod, "app", None)
    if api_obj is None:
        raise RuntimeError(
            f"Encontré {api_file.name} pero no exporta un objeto FastAPI llamado `api` o `app`."
        )

    return TestClient(api_obj)
