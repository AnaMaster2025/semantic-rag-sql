PRAGMA foreign_keys = ON;

-- =========================================================
-- 1) VENTAS / NEGOCIO
-- =========================================================

------------------------------------------------------------
-- 1.1 Catálogo de productos
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS product_categories (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id       INTEGER,
    name            TEXT NOT NULL,
    description     TEXT,
    FOREIGN KEY (parent_id) REFERENCES product_categories(id)
);

CREATE TABLE IF NOT EXISTS products (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    sku                 TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL,
    description         TEXT,
    category_id         INTEGER,
    unit_of_measure     TEXT NOT NULL DEFAULT 'unit', -- 'unit', 'kg', etc.
    is_active           INTEGER NOT NULL DEFAULT 1,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES product_categories(id)
);

CREATE TABLE IF NOT EXISTS price_lists (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT NOT NULL UNIQUE,         -- 'STD_ES', 'B2B_FR', etc.
    name            TEXT NOT NULL,
    currency        TEXT NOT NULL DEFAULT 'EUR',
    valid_from      DATE,
    valid_to        DATE
);

CREATE TABLE IF NOT EXISTS product_prices (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id      INTEGER NOT NULL,
    price_list_id   INTEGER NOT NULL,
    unit_price      NUMERIC NOT NULL,
    currency        TEXT NOT NULL DEFAULT 'EUR',
    valid_from      DATE,
    valid_to        DATE,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (price_list_id) REFERENCES price_lists(id)
);

------------------------------------------------------------
-- 1.2 Clientes y direcciones
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS customers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    external_code   TEXT,
    name            TEXT NOT NULL,
    tax_id          TEXT,
    email           TEXT,
    phone           TEXT,
    country_code    TEXT,               -- usado en tu filtro por país
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS customer_addresses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id     INTEGER NOT NULL,
    address_type    TEXT NOT NULL,      -- 'billing', 'shipping'
    line1           TEXT NOT NULL,
    line2           TEXT,
    city            TEXT,
    state           TEXT,
    postal_code     TEXT,
    country_code    TEXT NOT NULL,
    is_default      INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

------------------------------------------------------------
-- 1.3 Proveedores y compras
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS suppliers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    tax_id          TEXT,
    email           TEXT,
    phone           TEXT,
    country_code    TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS supplier_addresses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id     INTEGER NOT NULL,
    address_type    TEXT NOT NULL,      -- 'billing','shipping'
    line1           TEXT NOT NULL,
    line2           TEXT,
    city            TEXT,
    state           TEXT,
    postal_code     TEXT,
    country_code    TEXT NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

CREATE TABLE IF NOT EXISTS supplier_products (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id     INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    supplier_sku    TEXT,
    purchase_price  NUMERIC NOT NULL,
    currency        TEXT NOT NULL DEFAULT 'EUR',
    lead_time_days  INTEGER,
    min_order_qty   NUMERIC,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id     INTEGER NOT NULL,
    order_number    TEXT NOT NULL UNIQUE,
    order_date      DATE NOT NULL,
    expected_date   DATE,
    status          TEXT NOT NULL DEFAULT 'open', -- 'open','partial','closed','cancelled'
    currency        TEXT NOT NULL DEFAULT 'EUR',
    comments        TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_order_id   INTEGER NOT NULL,
    product_id          INTEGER NOT NULL,
    ordered_qty         NUMERIC NOT NULL,
    received_qty        NUMERIC NOT NULL DEFAULT 0,
    unit_price          NUMERIC NOT NULL,
    tax_rate            NUMERIC,
    FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

------------------------------------------------------------
-- 1.4 Almacenes e inventario
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS warehouses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    country_code    TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inventory_balance (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    warehouse_id        INTEGER NOT NULL,
    product_id          INTEGER NOT NULL,
    quantity_on_hand    NUMERIC NOT NULL DEFAULT 0,
    quantity_reserved   NUMERIC NOT NULL DEFAULT 0,
    last_updated        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (warehouse_id, product_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS inventory_movements (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    warehouse_id    INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    movement_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    movement_type   TEXT NOT NULL,      -- 'purchase_receipt','sale_shipment','adjustment',...
    quantity        NUMERIC NOT NULL,   -- + entrada, - salida
    related_doc_type TEXT,
    related_doc_id  INTEGER,
    comments        TEXT,
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

------------------------------------------------------------
-- 1.5 Pedidos de venta (sales_orders) + líneas
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sales_orders (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id         INTEGER NOT NULL,
    order_number        TEXT NOT NULL UNIQUE,
    order_date          DATE NOT NULL,
    status              TEXT NOT NULL DEFAULT 'open', -- 'open','partial','shipped','cancelled'
    currency            TEXT NOT NULL DEFAULT 'EUR',
    price_list_id       INTEGER,
    billing_address_id  INTEGER,
    shipping_address_id INTEGER,
    payment_terms       TEXT,
    comments            TEXT,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (price_list_id) REFERENCES price_lists(id),
    FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(id),
    FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(id)
);

CREATE TABLE IF NOT EXISTS sales_order_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    sales_order_id      INTEGER NOT NULL,
    product_id          INTEGER NOT NULL,
    ordered_qty         NUMERIC NOT NULL,
    shipped_qty         NUMERIC NOT NULL DEFAULT 0,
    unit_price          NUMERIC NOT NULL,
    discount_percent    NUMERIC NOT NULL DEFAULT 0,
    tax_rate            NUMERIC,
    line_total          NUMERIC,
    FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

------------------------------------------------------------
-- 1.6 Entregas / envíos
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS carriers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    contact_info    TEXT,
    tracking_url    TEXT
);

CREATE TABLE IF NOT EXISTS deliveries (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    sales_order_id      INTEGER NOT NULL,
    delivery_number     TEXT NOT NULL UNIQUE,
    warehouse_id        INTEGER NOT NULL,
    carrier_id          INTEGER,
    ship_date           DATE,
    delivery_date       DATE,
    status              TEXT NOT NULL DEFAULT 'in_progress',  -- 'in_progress','shipped','delivered','cancelled'
    tracking_code       TEXT,
    comments            TEXT,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
    FOREIGN KEY (carrier_id) REFERENCES carriers(id)
);

CREATE TABLE IF NOT EXISTS delivery_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    delivery_id         INTEGER NOT NULL,
    sales_order_item_id INTEGER NOT NULL,
    product_id          INTEGER NOT NULL,
    quantity            NUMERIC NOT NULL,
    FOREIGN KEY (delivery_id) REFERENCES deliveries(id),
    FOREIGN KEY (sales_order_item_id) REFERENCES sales_order_items(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

------------------------------------------------------------
-- 1.7 Facturación y cobros
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS invoices (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number      TEXT NOT NULL UNIQUE,
    customer_id         INTEGER NOT NULL,
    sales_order_id      INTEGER,
    invoice_date        DATE NOT NULL,
    due_date            DATE,
    status              TEXT NOT NULL DEFAULT 'open', -- 'open','paid','cancelled','partial'
    currency            TEXT NOT NULL DEFAULT 'EUR',
    total_without_tax   NUMERIC,
    total_tax           NUMERIC,
    total_with_tax      NUMERIC,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (sales_order_id) REFERENCES sales_orders(id)
);

CREATE TABLE IF NOT EXISTS invoice_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id          INTEGER NOT NULL,
    product_id          INTEGER,
    description         TEXT NOT NULL,
    quantity            NUMERIC NOT NULL,
    unit_price          NUMERIC NOT NULL,
    discount_percent    NUMERIC NOT NULL DEFAULT 0,
    tax_rate            NUMERIC,
    line_total          NUMERIC,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE IF NOT EXISTS payments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id     INTEGER NOT NULL,
    payment_date    DATE NOT NULL,
    amount          NUMERIC NOT NULL,
    currency        TEXT NOT NULL DEFAULT 'EUR',
    method          TEXT,
    reference       TEXT,
    comments        TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

CREATE TABLE IF NOT EXISTS invoice_payments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id      INTEGER NOT NULL,
    payment_id      INTEGER NOT NULL,
    amount          NUMERIC NOT NULL,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id),
    FOREIGN KEY (payment_id) REFERENCES payments(id)
);

------------------------------------------------------------
-- 1.8 Devoluciones
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sales_returns (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id         INTEGER NOT NULL,
    original_invoice_id INTEGER,
    return_number       TEXT NOT NULL UNIQUE,
    return_date         DATE NOT NULL,
    status              TEXT NOT NULL DEFAULT 'open', -- 'open','processed','rejected'
    comments            TEXT,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (original_invoice_id) REFERENCES invoices(id)
);

CREATE TABLE IF NOT EXISTS sales_return_items (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    sales_return_id     INTEGER NOT NULL,
    product_id          INTEGER NOT NULL,
    quantity            NUMERIC NOT NULL,
    reason_code         TEXT,
    comments            TEXT,
    FOREIGN KEY (sales_return_id) REFERENCES sales_returns(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

------------------------------------------------------------
-- 1.9 Vistas de compatibilidad: orders / order_items
--     (para no romper tu capa semántica actual)
------------------------------------------------------------

DROP VIEW IF EXISTS orders;
DROP VIEW IF EXISTS order_items;

CREATE VIEW orders AS
SELECT
    so.id            AS id,
    so.order_number  AS order_number,
    so.customer_id   AS customer_id,
    so.order_date    AS order_date,
    so.status        AS status,
    so.currency      AS currency,
    so.price_list_id AS price_list_id,
    so.created_at    AS created_at
FROM sales_orders so;

CREATE VIEW order_items AS
SELECT
    soi.id             AS id,
    soi.sales_order_id AS order_id,
    soi.product_id     AS product_id,
    soi.ordered_qty    AS quantity,
    soi.unit_price     AS unit_price,
    soi.discount_percent AS discount_percent,
    soi.tax_rate       AS tax_rate,
    soi.line_total     AS line_total
FROM sales_order_items soi;

-- =========================================================
-- 2) OBSERVABILIDAD / EXPERIMENTOS LLM
-- =========================================================

------------------------------------------------------------
-- 2.1 Usuarios / organización LLM
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    external_id     TEXT,
    name            TEXT NOT NULL,
    email           TEXT UNIQUE,
    role            TEXT,
    country_code    TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS teams (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS team_members (
    team_id     INTEGER NOT NULL,
    user_id     INTEGER NOT NULL,
    role        TEXT,
    joined_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (team_id, user_id),
    FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- 2.2 Proveedores y modelos LLM
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS llm_providers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL UNIQUE,       -- 'anthropic','openai',...
    base_url        TEXT,
    extra_config    TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS llm_models (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    provider_id         INTEGER NOT NULL,
    name                TEXT NOT NULL,
    family              TEXT,
    context_window_tok  INTEGER,
    is_active           INTEGER NOT NULL DEFAULT 1,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (provider_id) REFERENCES llm_providers(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_llm_models_provider_name
    ON llm_models(provider_id, name);

------------------------------------------------------------
-- 2.3 Experimentos, variantes y prompts
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS experiments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    description     TEXT,
    status          TEXT NOT NULL DEFAULT 'active',
    owner_user_id   INTEGER,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS experiment_variants (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id   INTEGER NOT NULL,
    name            TEXT NOT NULL,
    description     TEXT,
    model_id        INTEGER,
    temperature     REAL,
    top_p           REAL,
    max_tokens      INTEGER,
    other_params    TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (experiment_id) REFERENCES experiments(id) ON DELETE CASCADE,
    FOREIGN KEY (model_id) REFERENCES llm_models(id)
);

CREATE INDEX IF NOT EXISTS idx_experiment_variants_experiment
    ON experiment_variants(experiment_id);

CREATE TABLE IF NOT EXISTS prompts (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_variant_id   INTEGER NOT NULL,
    version                 INTEGER NOT NULL,
    name                    TEXT,
    system_prompt           TEXT,
    user_prompt_template    TEXT NOT NULL,
    metadata                TEXT,
    created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (experiment_variant_id) REFERENCES experiment_variants(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_prompts_variant_version
    ON prompts(experiment_variant_id, version);

------------------------------------------------------------
-- 2.4 Datasets y items de test
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS datasets (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL UNIQUE,
    description     TEXT,
    task_type       TEXT,
    source          TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dataset_items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    dataset_id      INTEGER NOT NULL,
    external_id     TEXT,
    input_text      TEXT NOT NULL,
    expected_output TEXT,
    metadata        TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (dataset_id) REFERENCES datasets(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dataset_items_dataset
    ON dataset_items(dataset_id);

------------------------------------------------------------
-- 2.5 Runs de LLM
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS llm_runs (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    run_uuid                TEXT NOT NULL UNIQUE,
    experiment_variant_id   INTEGER,
    prompt_id               INTEGER,
    dataset_item_id         INTEGER,
    user_id                 INTEGER,
    model_id                INTEGER,
    customer_id             INTEGER,           -- enlace opcional a customers.id
    question                TEXT NOT NULL,
    answer                  TEXT NOT NULL,
    elapsed_seconds         REAL,
    prompt_tokens           INTEGER,
    completion_tokens       INTEGER,
    total_tokens            INTEGER,
    cost_usd                REAL,
    temperature             REAL,
    top_p                   REAL,
    max_tokens              INTEGER,
    country_code            TEXT,
    context_json            TEXT,
    created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (experiment_variant_id) REFERENCES experiment_variants(id),
    FOREIGN KEY (prompt_id)               REFERENCES prompts(id),
    FOREIGN KEY (dataset_item_id)         REFERENCES dataset_items(id),
    FOREIGN KEY (user_id)                 REFERENCES users(id),
    FOREIGN KEY (model_id)                REFERENCES llm_models(id),
    FOREIGN KEY (customer_id)             REFERENCES customers(id)
);

CREATE INDEX IF NOT EXISTS idx_llm_runs_created_at
    ON llm_runs(created_at);

CREATE INDEX IF NOT EXISTS idx_llm_runs_experiment_variant
    ON llm_runs(experiment_variant_id);

CREATE INDEX IF NOT EXISTS idx_llm_runs_dataset_item
    ON llm_runs(dataset_item_id);

------------------------------------------------------------
-- 2.6 Evaluaciones de alucinación y otras métricas
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hallucination_evaluations (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    llm_run_id              INTEGER NOT NULL,
    evaluator_name          TEXT NOT NULL,
    score                   REAL,
    is_hallucination        INTEGER,
    method                  TEXT,
    explanation             TEXT,
    raw_json                TEXT,
    created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (llm_run_id) REFERENCES llm_runs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_hallucination_eval_run
    ON hallucination_evaluations(llm_run_id);

CREATE TABLE IF NOT EXISTS quality_metrics (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    llm_run_id      INTEGER NOT NULL,
    metric_name     TEXT NOT NULL,
    metric_value    REAL,
    metric_json     TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (llm_run_id) REFERENCES llm_runs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_quality_metrics_run
    ON quality_metrics(llm_run_id);

CREATE INDEX IF NOT EXISTS idx_quality_metrics_metric_name
    ON quality_metrics(metric_name);

------------------------------------------------------------
-- 2.7 Tags de runs y agregados diarios
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tags (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL UNIQUE,
    description     TEXT,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS run_tags (
    llm_run_id      INTEGER NOT NULL,
    tag_id          INTEGER NOT NULL,
    PRIMARY KEY (llm_run_id, tag_id),
    FOREIGN KEY (llm_run_id) REFERENCES llm_runs(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)     REFERENCES tags(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS daily_run_aggregates (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    day                     DATE NOT NULL,
    experiment_variant_id   INTEGER,
    model_id                INTEGER,
    total_runs              INTEGER NOT NULL,
    total_hallucinations    INTEGER NOT NULL,
    avg_hallucination_score REAL,
    total_cost_usd          REAL,
    avg_latency_seconds     REAL,
    created_at              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (experiment_variant_id) REFERENCES experiment_variants(id),
    FOREIGN KEY (model_id)  REFERENCES llm_models(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_agg_unique
    ON daily_run_aggregates(day, experiment_variant_id, model_id);

PRAGMA foreign_keys = ON;

-- =========================================================
-- DATOS DE NEGOCIO / VENTAS
-- =========================================================

------------------------------------------------------------
-- 1) Categorías y productos
------------------------------------------------------------



-- =========================================================
-- DATOS DE OBSERVABILIDAD LLM
-- =========================================================

------------------------------------------------------------
-- 9) Usuarios / equipos LLM
------------------------------------------------------------



------------------------------------------------------------
-- 10) Proveedores y modelos LLM
------------------------------------------------------------


------------------------------------------------------------
-- 11) Experimentos, variantes y prompts
------------------------------------------------------------


------------------------------------------------------------
-- 12) Datasets y items
------------------------------------------------------------

------------------------------------------------------------
-- 13) Tags
------------------------------------------------------------

------------------------------------------------------------
-- 14) LLM runs (4 ejemplos)
------------------------------------------------------------

-- Run 1: offline eval, baseline_haiku sobre dataset item 1 (sin alucinación)


------------------------------------------------------------
-- 15) Evaluaciones de alucinación
------------------------------------------------------------


------------------------------------------------------------
-- 17) Tags aplicados a runs
------------------------------------------------------------


------------------------------------------------------------
-- 18) Agregados diarios
------------------------------------------------------------