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

INSERT INTO product_categories (id, parent_id, name, description) VALUES
  (1, NULL, 'Electrónica', 'Dispositivos electrónicos'),
  (2, NULL, 'Accesorios', 'Accesorios para dispositivos'),
  (3, 1, 'Portátiles', 'Ordenadores portátiles'),
  (4, 1, 'Móviles', 'Teléfonos móviles');

INSERT INTO products (id, sku, name, description, category_id, unit_of_measure, is_active) VALUES
  (1, 'LAP-ES-001', 'Portátil Pro 14"', 'Portátil 14" gama profesional', 3, 'unit', 1),
  (2, 'LAP-ES-002', 'Portátil Basic 13"', 'Portátil 13" gama básica', 3, 'unit', 1),
  (3, 'MOB-ES-001', 'Smartphone X', 'Smartphone gama alta', 4, 'unit', 1),
  (4, 'ACC-ES-001', 'Ratón inalámbrico', 'Ratón óptico inalámbrico', 2, 'unit', 1);

INSERT INTO price_lists (id, code, name, currency, valid_from, valid_to) VALUES
  (1, 'STD_ES', 'Tarifa estándar España', 'EUR', '2024-01-01', NULL),
  (2, 'STD_FR', 'Tarifa estándar Francia', 'EUR', '2024-01-01', NULL);

INSERT INTO product_prices (id, product_id, price_list_id, unit_price, currency, valid_from, valid_to) VALUES
  (1, 1, 1, 1200.00, 'EUR', '2024-01-01', NULL),
  (2, 2, 1, 800.00,  'EUR', '2024-01-01', NULL),
  (3, 3, 1, 900.00,  'EUR', '2024-01-01', NULL),
  (4, 4, 1, 25.00,   'EUR', '2024-01-01', NULL),

  (5, 1, 2, 1250.00, 'EUR', '2024-01-01', NULL),
  (6, 2, 2, 820.00,  'EUR', '2024-01-01', NULL),
  (7, 3, 2, 910.00,  'EUR', '2024-01-01', NULL),
  (8, 4, 2, 27.00,   'EUR', '2024-01-01', NULL);

------------------------------------------------------------
-- 2) Clientes y direcciones
------------------------------------------------------------

INSERT INTO customers (id, external_code, name, tax_id, email, phone, country_code) VALUES
  (1, 'CUST-ES-001', 'Cliente España SA', 'ES12345678A', 'contacto@cliente-es.com', '+34 600 000 001', 'ES'),
  (2, 'CUST-FR-001', 'Client France SARL', 'FR99887766', 'contact@client-fr.fr', '+33 600 000 002', 'FR');

INSERT INTO customer_addresses (id, customer_id, address_type, line1, line2, city, state, postal_code, country_code, is_default) VALUES
  (1, 1, 'billing',  'Calle Mayor 1',   NULL, 'Madrid',  'Madrid', '28001', 'ES', 1),
  (2, 1, 'shipping', 'Polígono Norte',  NULL, 'Madrid',  'Madrid', '28050', 'ES', 1),
  (3, 2, 'billing',  '10 Rue Centrale', NULL, 'Paris',   NULL,     '75001', 'FR', 1),
  (4, 2, 'shipping', 'ZAC Industrielle',NULL, 'Lyon',    NULL,     '69000', 'FR', 1);

-- Clientes extra para PT y BE
INSERT INTO customers (id, external_code, name, tax_id, email, phone, country_code) VALUES
  (3, 'CUST-PT-001', 'Cliente Portugal LDA', 'PT123456789',
      'info@cliente-pt.pt', '+351 210 000 003', 'PT'),
  (4, 'CUST-BE-001', 'Client Belgium SPRL', 'BE987654321',
      'contact@client-be.be', '+32 210 000 004', 'BE');

-- Direcciones extra (ids 5–8) que usan tus nuevos pedidos
INSERT INTO customer_addresses
(id, customer_id, address_type, line1, line2, city, state, postal_code, country_code, is_default)
VALUES
  (5, 3, 'billing',  'Rua das Flores 10', NULL, 'Lisboa',   NULL, '1100-001', 'PT', 1),
  (6, 3, 'shipping', 'Parque Industrial Sul', NULL, 'Lisboa', NULL, '1990-001', 'PT', 1),
  (7, 4, 'billing',  'Rue du Marché 5', NULL, 'Bruxelles', NULL, '1000', 'BE', 1),
  (8, 4, 'shipping', 'Parc Logistique', NULL, 'Liège', NULL, '4000', 'BE', 1);

------------------------------------------------------------
-- 3) Proveedores y compras
------------------------------------------------------------

INSERT INTO suppliers (id, name, tax_id, email, phone, country_code) VALUES
  (1, 'Proveedor Tech Global', 'PTG123456', 'ventas@techglobal.com', '+49 600 000 010', 'DE'),
  (2, 'Distribuidor Accesorios SL', 'DASL9988', 'sales@accesorios.com', '+34 600 000 011', 'ES');

INSERT INTO supplier_addresses (id, supplier_id, address_type, line1, line2, city, state, postal_code, country_code) VALUES
  (1, 1, 'billing',  'Industriestrasse 1', NULL, 'Berlin',  NULL, '10115', 'DE'),
  (2, 2, 'billing',  'Av. Industrial 50',  NULL, 'Barcelona', 'Barcelona', '08020', 'ES');

INSERT INTO supplier_products (id, supplier_id, product_id, supplier_sku, purchase_price, currency, lead_time_days, min_order_qty) VALUES
  (1, 1, 1, 'TP-LAP-PRO14', 800.00, 'EUR', 10, 5),
  (2, 1, 2, 'TP-LAP-BASIC', 550.00, 'EUR', 10, 5),
  (3, 1, 3, 'TP-MOB-X',     600.00, 'EUR', 7,  10),
  (4, 2, 4, 'ACC-MOUSE-01', 10.00,  'EUR', 5,  20);

-- Pedido de compra
INSERT INTO purchase_orders (id, supplier_id, order_number, order_date, expected_date, status, currency, comments) VALUES
  (1, 1, 'PO-2024-0001', '2024-11-10', '2024-11-20', 'open', 'EUR', 'Reposición portátiles y móviles');

INSERT INTO purchase_order_items (id, purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate) VALUES
  (1, 1, 1, 10, 5, 800.00, 21.0),
  (2, 1, 3, 20, 10, 600.00, 21.0);

------------------------------------------------------------
-- 4) Almacenes e inventario
------------------------------------------------------------

INSERT INTO warehouses (id, code, name, country_code) VALUES
  (1, 'MAD', 'Almacén Madrid', 'ES'),
  (2, 'LYO', 'Entrepôt Lyon',  'FR');

INSERT INTO inventory_balance (id, warehouse_id, product_id, quantity_on_hand, quantity_reserved, last_updated) VALUES
  (1, 1, 1, 5,  0, '2024-11-20 10:00:00'),
  (2, 1, 3, 10, 2, '2024-11-20 10:00:00'),
  (3, 1, 4, 50, 5, '2024-11-20 10:00:00'),
  (4, 2, 2, 3,  0, '2024-11-20 10:00:00'),
  (5, 2, 4, 30, 0, '2024-11-20 10:00:00');

INSERT INTO inventory_movements (id, warehouse_id, product_id, movement_date, movement_type, quantity, related_doc_type, related_doc_id, comments) VALUES
  (1, 1, 1, '2024-11-19 09:00:00', 'purchase_receipt',  5, 'purchase_order', 1, 'Recepción parcial PO-2024-0001'),
  (2, 1, 3, '2024-11-19 09:00:00', 'purchase_receipt', 10, 'purchase_order', 1, 'Recepción parcial PO-2024-0001');

------------------------------------------------------------
-- 5) Pedidos de venta
------------------------------------------------------------

INSERT INTO sales_orders (id, customer_id, order_number, order_date, status, currency,
                          price_list_id, billing_address_id, shipping_address_id, payment_terms, comments)
VALUES
  (1, 1, 'SO-2024-0001', '2024-11-21', 'open',    'EUR', 1, 1, 2, '30d', 'Pedido inicial España'),
  (2, 2, 'SO-2024-0002', '2024-11-22', 'shipped', 'EUR', 2, 3, 4, '30d', 'Pedido Francia');

INSERT INTO sales_order_items (id, sales_order_id, product_id, ordered_qty, shipped_qty,
                               unit_price, discount_percent, tax_rate, line_total)
VALUES
  (1, 1, 1, 2, 0, 1200.00, 0.0, 21.0, 2400.00),
  (2, 1, 4, 5, 0, 25.00,   0.0, 21.0, 125.00),
  (3, 2, 2, 1, 1, 820.00,  5.0, 20.0, 779.00),
  (4, 2, 4, 3, 3, 27.00,   0.0, 20.0, 81.00);

------------------------------------------------------------
-- 6) Entregas
------------------------------------------------------------

INSERT INTO carriers (id, name, contact_info, tracking_url) VALUES
  (1, 'Transporte Express', 'support@texpress.com', 'https://tracking.texpress.com');

INSERT INTO deliveries (id, sales_order_id, delivery_number, warehouse_id, carrier_id,
                        ship_date, delivery_date, status, tracking_code, comments)
VALUES
  (1, 2, 'DEL-2024-0001', 2, 1, '2024-11-23', '2024-11-24', 'delivered', 'TRK123456', 'Entrega completa pedido Francia');

INSERT INTO delivery_items (id, delivery_id, sales_order_item_id, product_id, quantity) VALUES
  (1, 1, 3, 2, 1),
  (2, 1, 4, 4, 3);

-- Movimientos de salida asociados a la entrega
INSERT INTO inventory_movements (id, warehouse_id, product_id, movement_date, movement_type,
                                 quantity, related_doc_type, related_doc_id, comments)
VALUES
  (3, 2, 2, '2024-11-23 15:00:00', 'sale_shipment', -1, 'delivery', 1, 'Envio SO-2024-0002'),
  (4, 2, 4, '2024-11-23 15:00:00', 'sale_shipment', -3, 'delivery', 1, 'Envio SO-2024-0002');

------------------------------------------------------------
-- 7) Facturación y pagos
------------------------------------------------------------

INSERT INTO invoices (id, invoice_number, customer_id, sales_order_id, invoice_date,
                      due_date, status, currency, total_without_tax, total_tax, total_with_tax)
VALUES
  (1, 'INV-2024-0001', 2, 2, '2024-11-24', '2024-12-24', 'open', 'EUR', 860.00, 172.00, 1032.00);

INSERT INTO invoice_items (id, invoice_id, product_id, description, quantity,
                           unit_price, discount_percent, tax_rate, line_total)
VALUES
  (1, 1, 2, 'Portátil Basic 13"', 1, 820.00, 5.0, 20.0, 779.00),
  (2, 1, 4, 'Ratón inalámbrico',  3, 27.00,  0.0, 20.0, 81.00);

INSERT INTO payments (id, customer_id, payment_date, amount, currency, method, reference, comments) VALUES
  (1, 2, '2024-11-28', 516.00, 'EUR', 'transfer', 'TRF-2024-0001', 'Pago parcial 50%'),
  (2, 2, '2024-12-20', 516.00, 'EUR', 'transfer', 'TRF-2024-0002', 'Pago restante');

INSERT INTO invoice_payments (id, invoice_id, payment_id, amount) VALUES
  (1, 1, 1, 516.00),
  (2, 1, 2, 516.00);

------------------------------------------------------------
-- 8) Devoluciones
------------------------------------------------------------

INSERT INTO sales_returns (id, customer_id, original_invoice_id, return_number,
                           return_date, status, comments)
VALUES
  (1, 2, 1, 'RET-2024-0001', '2024-11-30', 'processed', 'Devolución 1 ratón defectuoso');

INSERT INTO sales_return_items (id, sales_return_id, product_id, quantity, reason_code, comments) VALUES
  (1, 1, 4, 1, 'damaged', 'No funciona el botón');

-- Podrías añadir aquí movimientos de inventario de devolución si lo deseas
INSERT INTO inventory_movements (id, warehouse_id, product_id, movement_date, movement_type,
                                 quantity, related_doc_type, related_doc_id, comments)
VALUES
  (5, 2, 4, '2024-11-30 11:00:00', 'adjustment', 1, 'sales_return', 1, 'Entrada por devolución RET-2024-0001');



-- =========================================================
-- DATOS DE OBSERVABILIDAD LLM
-- =========================================================

------------------------------------------------------------
-- 9) Usuarios / equipos LLM
------------------------------------------------------------

INSERT INTO users (id, external_id, name, email, role, country_code) VALUES
  (1, 'u-ext-001', 'Ana Data',   'ana.data@example.com',   'data_scientist', 'ES'),
  (2, 'u-ext-002', 'Carlos ML',  'carlos.ml@example.com',  'ml_engineer',    'FR');

INSERT INTO teams (id, name, description) VALUES
  (1, 'Equipo IA Producto', 'Equipo responsable de los modelos de IA en producción');

INSERT INTO team_members (team_id, user_id, role) VALUES
  (1, 1, 'owner'),
  (1, 2, 'member');

------------------------------------------------------------
-- 10) Proveedores y modelos LLM
------------------------------------------------------------

INSERT INTO llm_providers (id, name, base_url, extra_config) VALUES
  (1, 'anthropic', 'https://api.anthropic.com', '{"region": "eu"}'),
  (2, 'openai',    'https://api.openai.com',    '{"region": "us"}');

INSERT INTO llm_models (id, provider_id, name, family, context_window_tok, is_active) VALUES
  (1, 1, 'claude-3-haiku-20240307',  'claude-3', 200000, 1),
  (2, 1, 'claude-3-sonnet-20240229', 'claude-3', 200000, 1),
  (3, 2, 'gpt-4o-mini',              'gpt-4',   128000, 1);

------------------------------------------------------------
-- 11) Experimentos, variantes y prompts
------------------------------------------------------------

INSERT INTO experiments (id, code, name, description, status, owner_user_id) VALUES
  (1, 'exp_rag_sql_v1', 'RAG SQL baseline', 'Primera versión de RAG sobre base SQL', 'active', 1),
  (2, 'exp_rag_sql_v2', 'RAG SQL mejorado', 'Versión con mejoras en prompts y ranking', 'active', 2);

INSERT INTO experiment_variants
  (id, experiment_id, name, description, model_id, temperature, top_p, max_tokens, other_params)
VALUES
  (1, 1, 'baseline_haiku',  'Baseline con Haiku, temperatura baja', 1, 0.2, 0.9, 1024, '{"retriever": "bm25"}'),
  (2, 1, 'baseline_sonnet', 'Baseline con Sonnet',                  2, 0.3, 0.9, 1024, '{"retriever": "bm25"}'),
  (3, 2, 'improved_haiku',  'Prompt mejorado con Haiku',            1, 0.2, 0.9, 2048, '{"retriever": "hybrid"}');

INSERT INTO prompts
  (id, experiment_variant_id, version, name, system_prompt, user_prompt_template, metadata)
VALUES
  (1, 1, 1, 'prompt_principal',
   'Eres un asistente experto en bases de datos y calidad de datos.',
   'Responde a la siguiente pregunta del usuario usando la información disponible:\n\n{{question}}',
   '{"author": "Ana", "notes": "versión inicial"}'),

  (2, 2, 1, 'prompt_principal',
   'Eres un asistente de datos que responde con precisión y sin alucinaciones.',
   'Contesta a la pregunta:\n{{question}}\nSi no tienes datos, dilo explícitamente.',
   '{"author": "Carlos"}'),

  (3, 3, 2, 'prompt_mejorado',
   'Eres un asistente RAG para SQL. Debes citar siempre las tablas usadas.',
   'Pregunta del usuario:\n{{question}}\n\nDevuelve también una explicación paso a paso.',
   '{"changelog": "añadidas instrucciones de explicabilidad"}');

------------------------------------------------------------
-- 12) Datasets y items
------------------------------------------------------------

INSERT INTO datasets (id, name, description, task_type, source) VALUES
  (1, 'qa_sql_sintetico', 'Preguntas sintéticas sobre clientes y pedidos', 'qa', 'synthetic'),
  (2, 'qa_sql_regresion', 'Casos de regresión reales de producción',       'qa', 'prod-logs');

INSERT INTO dataset_items
  (id, dataset_id, external_id, input_text, expected_output, metadata)
VALUES
  (1, 1, 'q-001',
   '¿Cuántos pedidos tuvo el cliente con id 1 en 2024?',
   'El cliente 1 tuvo 1 pedido en 2024.',
   '{"difficulty": "easy"}'),

  (2, 1, 'q-002',
   'Lista los productos vendidos al cliente 2 en 2024.',
   'Portátil Basic 13" y Ratón inalámbrico.',
   '{"difficulty": "medium"}'),

  (3, 2, 'reg-001',
   '¿Cuál es el país del cliente 2?',
   'FR',
   '{"source_ticket": "INC-2024-001"}');

------------------------------------------------------------
-- 13) Tags
------------------------------------------------------------

INSERT INTO tags (id, name, description) VALUES
  (1, 'production',      'Runs ejecutados en tráfico real de producción'),
  (2, 'offline_eval',    'Ejecuciones en modo evaluación offline'),
  (3, 'regression_test', 'Casos específicos de regresión');

------------------------------------------------------------
-- 14) LLM runs (4 ejemplos)
------------------------------------------------------------

-- Run 1: offline eval, baseline_haiku sobre dataset item 1 (sin alucinación)
INSERT INTO llm_runs
  (id, run_uuid, experiment_variant_id, prompt_id, dataset_item_id,
   user_id, model_id, customer_id, question, answer,
   elapsed_seconds, prompt_tokens, completion_tokens, total_tokens,
   cost_usd, temperature, top_p, max_tokens, country_code, context_json, created_at)
VALUES
  (1, '11111111-1111-1111-1111-111111111111',
   1, 1, 1,
   NULL, 1, 1,
   '¿Cuántos pedidos tuvo el cliente con id 1 en 2024?',
   'He consultado la tabla orders: el cliente 1 tuvo 1 pedido en 2024.',
   1.23, 120, 80, 200,
   0.0025, 0.2, 0.9, 1024, 'ES',
   '{"tables_used": ["orders"], "mode": "offline_eval"}',
   '2024-11-29 09:00:00');

-- Run 2: offline eval, improved_haiku sobre dataset item 2 (alucinación parcial)
INSERT INTO llm_runs
  (id, run_uuid, experiment_variant_id, prompt_id, dataset_item_id,
   user_id, model_id, customer_id, question, answer,
   elapsed_seconds, prompt_tokens, completion_tokens, total_tokens,
   cost_usd, temperature, top_p, max_tokens, country_code, context_json, created_at)
VALUES
  (2, '22222222-2222-2222-2222-222222222222',
   3, 3, 2,
   NULL, 1, 2,
   'Lista los productos vendidos al cliente 2 en 2024.',
   'Según los datos, los productos vendidos fueron Portátil Basic 13" y Smartphone X.',
   1.80, 150, 110, 260,
   0.0035, 0.2, 0.9, 2048, 'FR',
   '{"tables_used": ["sales_orders","sales_order_items","products"], "mode": "offline_eval"}',
   '2024-11-29 10:00:00');

-- Run 3: producción, pregunta real de Ana
INSERT INTO llm_runs
  (id, run_uuid, experiment_variant_id, prompt_id, dataset_item_id,
   user_id, model_id, customer_id, question, answer,
   elapsed_seconds, prompt_tokens, completion_tokens, total_tokens,
   cost_usd, temperature, top_p, max_tokens, country_code, context_json, created_at)
VALUES
  (3, '33333333-3333-3333-3333-333333333333',
   3, 3, NULL,
   1, 1, 1,
   'Explícame el pipeline de calidad de datos que tenemos sobre pedidos.',
   'Tu pipeline de calidad de datos sobre pedidos tiene estas etapas: ingesta, validación de esquema, reglas de negocio y monitorización de métricas...',
   2.50, 200, 180, 380,
   0.0050, 0.2, 0.9, 2048, 'ES',
   '{"mode": "production", "feature_flags": ["dq_monitoring"]}',
   '2024-11-29 11:00:00');

-- Run 4: producción, pregunta real cliente francés (alucinación fuerte)
INSERT INTO llm_runs
  (id, run_uuid, experiment_variant_id, prompt_id, dataset_item_id,
   user_id, model_id, customer_id, question, answer,
   elapsed_seconds, prompt_tokens, completion_tokens, total_tokens,
   cost_usd, temperature, top_p, max_tokens, country_code, context_json, created_at)
VALUES
  (4, '44444444-4444-4444-4444-444444444444',
   2, 2, NULL,
   2, 2, 2,
   '¿Cuántos clientes activos tenemos en Canadá ahora mismo?',
   'Actualmente tenemos 2500 clientes activos en Canadá.',
   2.10, 180, 140, 320,
   0.0040, 0.3, 0.9, 1024, 'FR',
   '{"mode": "production", "feature_flags": ["multi_region"]}',
   '2024-11-29 12:00:00');

------------------------------------------------------------
-- 15) Evaluaciones de alucinación
------------------------------------------------------------

INSERT INTO hallucination_evaluations
  (id, llm_run_id, evaluator_name, score, is_hallucination,
   method, explanation, raw_json, created_at)
VALUES
  (1, 1, 'ask_teams_with_metrics_v1', 0.05, 0,
   'llm',
   'La respuesta coincide con los datos de orders, sin señales de alucinación.',
   '{"hallucination_score": 0.05, "verdict": "no_hallucination"}',
   '2024-11-29 09:05:00'),

  (2, 2, 'ask_teams_with_metrics_v1', 0.40, 1,
   'llm',
   'Uno de los productos listados (Smartphone X) no coincide con los datos de ventas.',
   '{"hallucination_score": 0.40, "verdict": "partial_hallucination"}',
   '2024-11-29 10:05:00'),

  (3, 3, 'ask_teams_with_metrics_v1', 0.10, 0,
   'llm',
   'Descripción consistente con la configuración de calidad de datos conocida.',
   '{"hallucination_score": 0.10, "verdict": "no_hallucination"}',
   '2024-11-29 11:05:00'),

  (4, 4, 'ask_teams_with_metrics_v1', 0.90, 1,
   'llm',
   'La respuesta da una cifra exacta sin tener acceso a datos en tiempo real de clientes en Canadá.',
   '{"hallucination_score": 0.90, "verdict": "strong_hallucination"}',
   '2024-11-29 12:05:00');

------------------------------------------------------------
-- 16) Métricas de calidad adicionales
------------------------------------------------------------

INSERT INTO quality_metrics
  (id, llm_run_id, metric_name, metric_value, metric_json, created_at)
VALUES
  (1, 1, 'exact_match', 1.0, '{"expected": "1 pedido", "observed": "1 pedido"}', '2024-11-29 09:06:00'),
  (2, 1, 'latency_seconds', 1.23, '{}', '2024-11-29 09:06:10'),

  (3, 2, 'exact_match', 0.5, '{"expected_products": 2, "correct_products": 1}', '2024-11-29 10:06:00'),
  (4, 2, 'latency_seconds', 1.80, '{}', '2024-11-29 10:06:10'),

  (5, 3, 'human_score', 0.9, '{"rater": "Ana", "comment": "Muy clara"}', '2024-11-29 11:06:00'),
  (6, 3, 'latency_seconds', 2.50, '{}', '2024-11-29 11:06:10'),

  (7, 4, 'latency_seconds', 2.10, '{}', '2024-11-29 12:06:10');

------------------------------------------------------------
-- 17) Tags aplicados a runs
------------------------------------------------------------

INSERT INTO run_tags (llm_run_id, tag_id) VALUES
  (1, 2),  -- offline_eval
  (2, 2),  -- offline_eval
  (2, 3),  -- regression_test
  (3, 1),  -- production
  (4, 1),  -- production
  (4, 3);  -- regression_test

------------------------------------------------------------
-- 18) Agregados diarios
------------------------------------------------------------

INSERT INTO daily_run_aggregates
  (id, day, experiment_variant_id, model_id,
   total_runs, total_hallucinations, avg_hallucination_score,
   total_cost_usd, avg_latency_seconds, created_at)
VALUES
  (1, '2024-11-29', 1, 1,
   1, 0, 0.05,
   0.0025, 1.23, '2024-11-29 23:00:00'),

  (2, '2024-11-29', 3, 1,
   2, 1, 0.25,  -- media aproximada (0.40 y 0.10)
   0.0085, 2.15, '2024-11-29 23:05:00'),

  (3, '2024-11-29', 2, 2,
   1, 1, 0.90,
   0.0040, 2.10, '2024-11-29 23:10:00');


INSERT INTO sales_orders
(id, customer_id, order_number, order_date, status, currency,
 price_list_id, billing_address_id, shipping_address_id, payment_terms, comments, created_at)
VALUES
  -- SEPTIEMBRE 2025
  (3, 1, 'SO-2025-0905-ES-1', '2025-09-05', 'shipped', 'EUR', 1, 1, 2, '30d', 'Pedido ES mañana', '2025-09-05 09:05:00'),
  (4, 2, 'SO-2025-0905-FR-1', '2025-09-05', 'shipped', 'EUR', 2, 3, 4, '30d', 'Pedido FR tarde',  '2025-09-05 16:20:00'),

  (5, 3, 'SO-2025-0918-PT-1', '2025-09-18', 'shipped', 'EUR', 1, 5, 6, '30d', 'Pedido PT mañana', '2025-09-18 09:10:00'),
  (6, 4, 'SO-2025-0918-BE-1', '2025-09-18', 'open',    'EUR', 1, 7, 8, '30d', 'Pedido BE tarde',  '2025-09-18 17:45:00'),

  -- OCTUBRE 2025
  (7, 1, 'SO-2025-1005-ES-1', '2025-10-05', 'shipped', 'EUR', 1, 1, 2, '30d', 'Pedido ES mañana', '2025-10-05 09:15:00'),
  (8, 2, 'SO-2025-1005-FR-1', '2025-10-05', 'shipped', 'EUR', 2, 3, 4, '30d', 'Pedido FR tarde',  '2025-10-05 16:35:00'),

  (9, 3, 'SO-2025-1018-PT-1', '2025-10-18', 'shipped', 'EUR', 1, 5, 6, '30d', 'Pedido PT mañana', '2025-10-18 09:20:00'),
  (10,4, 'SO-2025-1018-BE-1', '2025-10-18', 'shipped', 'EUR', 1, 7, 8, '30d', 'Pedido BE tarde',  '2025-10-18 17:10:00'),

  -- NOVIEMBRE 2025
  (11,1, 'SO-2025-1105-ES-1', '2025-11-05', 'shipped', 'EUR', 1, 1, 2, '30d', 'Pedido ES mañana', '2025-11-05 09:30:00'),
  (12,2, 'SO-2025-1105-FR-1', '2025-11-05', 'shipped', 'EUR', 2, 3, 4, '30d', 'Pedido FR tarde',  '2025-11-05 16:10:00'),

  (13,3, 'SO-2025-1118-PT-1', '2025-11-18', 'shipped', 'EUR', 1, 5, 6, '30d', 'Pedido PT mañana', '2025-11-18 09:40:00'),
  (14,4, 'SO-2025-1118-BE-1', '2025-11-18', 'shipped', 'EUR', 1, 7, 8, '30d', 'Pedido BE tarde',  '2025-11-18 17:05:00');

INSERT INTO invoices
(id, invoice_number, customer_id, sales_order_id, invoice_date,
 due_date, status, currency, total_without_tax, total_tax, total_with_tax, created_at)
VALUES
  -- SEPTIEMBRE
  (2,  'INV-2025-0905-ES-1', 1, 3,  '2025-09-05', '2025-10-05', 'paid', 'EUR', NULL, NULL, NULL, '2025-09-05 10:15:00'),
  (3,  'INV-2025-0905-FR-1', 2, 4,  '2025-09-05', '2025-10-05', 'paid', 'EUR', NULL, NULL, NULL, '2025-09-05 17:10:00'),
  (4,  'INV-2025-0918-PT-1', 3, 5,  '2025-09-18', '2025-10-18', 'paid', 'EUR', NULL, NULL, NULL, '2025-09-18 10:20:00'),
  (5,  'INV-2025-0918-BE-1', 4, 6,  '2025-09-18', '2025-10-18', 'open', 'EUR', NULL, NULL, NULL, '2025-09-18 18:00:00'),

  -- OCTUBRE
  (6,  'INV-2025-1005-ES-1', 1, 7,  '2025-10-05', '2025-11-05', 'paid', 'EUR', NULL, NULL, NULL, '2025-10-05 10:30:00'),
  (7,  'INV-2025-1005-FR-1', 2, 8,  '2025-10-05', '2025-11-05', 'paid', 'EUR', NULL, NULL, NULL, '2025-10-05 17:20:00'),
  (8,  'INV-2025-1018-PT-1', 3, 9,  '2025-10-18', '2025-11-17', 'paid', 'EUR', NULL, NULL, NULL, '2025-10-18 10:25:00'),
  (9,  'INV-2025-1018-BE-1', 4, 10, '2025-10-18', '2025-11-17', 'paid', 'EUR', NULL, NULL, NULL, '2025-10-18 18:05:00'),

  -- NOVIEMBRE
  (10, 'INV-2025-1105-ES-1', 1, 11, '2025-11-05', '2025-12-05', 'paid', 'EUR', NULL, NULL, NULL, '2025-11-05 10:40:00'),
  (11, 'INV-2025-1105-FR-1', 2, 12, '2025-11-05', '2025-12-05', 'paid', 'EUR', NULL, NULL, NULL, '2025-11-05 17:15:00'),
  (12, 'INV-2025-1118-PT-1', 3, 13, '2025-11-18', '2025-12-18', 'open', 'EUR', NULL, NULL, NULL, '2025-11-18 10:50:00'),
  (13, 'INV-2025-1118-BE-1', 4, 14, '2025-11-18', '2025-12-18', 'open', 'EUR', NULL, NULL, NULL, '2025-11-18 18:10:00');

INSERT INTO invoice_items
(id, invoice_id, product_id, description, quantity,
 unit_price, discount_percent, tax_rate, line_total)
VALUES
  -- INV 2 (SO 3)
  (3,  2, 1, 'Portátil Pro 14"', 1, 1200.00, 0.0, 21.0, 1200.00),
  (4,  2, 4, 'Ratón inalámbrico', 2,  25.00, 0.0, 21.0,   50.00),

  -- INV 3 (SO 4)
  (5,  3, 2, 'Portátil Basic 13"', 1, 820.00, 0.0, 20.0, 820.00),
  (6,  3, 4, 'Ratón inalámbrico',  3,  27.00, 0.0, 20.0,  81.00),

  -- INV 4 (SO 5)
  (7,  4, 3, 'Smartphone X', 2, 900.00, 0.0, 23.0, 1800.00),
  (8,  4, 4, 'Ratón inalámbrico', 2,  25.00, 0.0, 23.0,   50.00),

  -- INV 5 (SO 6)
  (9,  5, 3, 'Smartphone X', 1, 900.00, 0.0, 21.0, 900.00),
  (10, 5, 4, 'Ratón inalámbrico', 4,  25.00, 0.0, 21.0, 100.00),

  -- INV 6 (SO 7)
  (11, 6, 1, 'Portátil Pro 14"', 2, 1200.00, 0.0, 21.0, 2400.00),
  (12, 6, 4, 'Ratón inalámbrico', 3,   25.00, 0.0, 21.0,   75.00),

  -- INV 7 (SO 8)
  (13, 7, 2, 'Portátil Basic 13"', 2, 820.00, 0.0, 20.0, 1640.00),
  (14, 7, 4, 'Ratón inalámbrico',  2,  27.00, 0.0, 20.0,   54.00),

  -- INV 8 (SO 9)
  (15, 8, 3, 'Smartphone X', 1, 900.00, 0.0, 23.0, 900.00),
  (16, 8, 1, 'Portátil Pro 14"', 1, 1200.00, 0.0, 23.0, 1200.00),

  -- INV 9 (SO 10)
  (17, 9, 3, 'Smartphone X', 2, 900.00, 0.0, 21.0, 1800.00),
  (18, 9, 4, 'Ratón inalámbrico', 1,  25.00, 0.0, 21.0,   25.00),

  -- INV 10 (SO 11)
  (19,10, 2, 'Portátil Basic 13"', 1, 800.00, 0.0, 21.0, 800.00),
  (20,10, 4, 'Ratón inalámbrico',  2,  25.00, 0.0, 21.0,  50.00),

  -- INV 11 (SO 12)
  (21,11, 3, 'Smartphone X', 1, 910.00, 0.0, 20.0, 910.00),
  (22,11, 4, 'Ratón inalámbrico', 2,  27.00, 0.0, 20.0,  54.00),

  -- INV 12 (SO 13)
  (23,12, 1, 'Portátil Pro 14"', 1, 1200.00, 0.0, 23.0, 1200.00),
  (24,12, 4, 'Ratón inalámbrico', 1,   25.00, 0.0, 23.0,   25.00),

  -- INV 13 (SO 14)
  (25,13, 2, 'Portátil Basic 13"', 1, 800.00, 0.0, 21.0, 800.00),
  (26,13, 4, 'Ratón inalámbrico',  3,  25.00, 0.0, 21.0,  75.00);
INSERT INTO payments
(id, customer_id, payment_date, amount, currency, method, reference, comments)
VALUES
  (3, 1, '2025-09-10', 1250.00, 'EUR', 'transfer', 'TRF-2025-0901', 'Pago INV-2025-0905-ES-1'),
  (4, 2, '2025-09-12', 901.00,  'EUR', 'card',     'CARD-2025-0902', 'Pago INV-2025-0905-FR-1'),
  (5, 3, '2025-09-22', 1850.00, 'EUR', 'transfer', 'TRF-2025-0903', 'Pago INV-2025-0918-PT-1'),
  (6, 1, '2025-10-10', 2475.00, 'EUR', 'transfer', 'TRF-2025-1001', 'Pago INV-2025-1005-ES-1'),
  (7, 2, '2025-10-12', 1694.00, 'EUR', 'card',     'CARD-2025-1002', 'Pago INV-2025-1005-FR-1'),
  (8, 3, '2025-10-25', 2100.00, 'EUR', 'transfer', 'TRF-2025-1003', 'Pago INV-2025-1018-PT-1'),
  (9, 4, '2025-10-28', 1825.00, 'EUR', 'transfer', 'TRF-2025-1004', 'Pago INV-2025-1018-BE-1'),
  (10,1, '2025-11-10', 850.00,  'EUR', 'transfer', 'TRF-2025-1101', 'Pago INV-2025-1105-ES-1'),
  (11,2, '2025-11-12', 964.00,  'EUR', 'card',     'CARD-2025-1102', 'Pago INV-2025-1105-FR-1'),
  (12,3, '2025-11-25', 600.00,  'EUR', 'transfer', 'TRF-2025-1103', 'Pago parcial INV-2025-1118-PT-1'),
  (13,4, '2025-11-26', 400.00,  'EUR', 'transfer', 'TRF-2025-1104', 'Pago parcial INV-2025-1118-BE-1'),
  (14,4, '2025-11-29', 300.00,  'EUR', 'transfer', 'TRF-2025-1105', 'Pago adicional INV-2025-1118-BE-1');

-- ==============================================
-- VENTAS 2025: nuevos pedidos (ids 15–22)
-- ==============================================

INSERT INTO sales_orders
(id, customer_id, order_number, order_date, status, currency,
 price_list_id, billing_address_id, shipping_address_id, payment_terms, comments, created_at)
VALUES
  -- ENERO 2025
  (15, 1, 'SO-2025-0115-ES-1', '2025-01-15', 'shipped', 'EUR', 1, 1, 2,
   '30d', 'Pedido ES enero mañana', '2025-01-15 09:10:00'),
  (16, 2, 'SO-2025-0115-FR-1', '2025-01-15', 'shipped', 'EUR', 2, 3, 4,
   '30d', 'Pedido FR enero tarde',  '2025-01-15 16:45:00'),

  -- MARZO 2025
  (17, 3, 'SO-2025-0320-PT-1', '2025-03-20', 'shipped', 'EUR', 1, 5, 6,
   '30d', 'Pedido PT marzo mañana', '2025-03-20 10:05:00'),
  (18, 4, 'SO-2025-0320-BE-1', '2025-03-20', 'shipped', 'EUR', 1, 7, 8,
   '30d', 'Pedido BE marzo tarde',  '2025-03-20 17:20:00'),

  -- JUNIO 2025
  (19, 1, 'SO-2025-0610-ES-1', '2025-06-10', 'shipped', 'EUR', 1, 1, 2,
   '30d', 'Pedido ES junio mañana', '2025-06-10 09:30:00'),
  (20, 2, 'SO-2025-0610-FR-1', '2025-06-10', 'shipped', 'EUR', 2, 3, 4,
   '30d', 'Pedido FR junio tarde',  '2025-06-10 16:40:00'),

  -- AGOSTO 2025
  (21, 3, 'SO-2025-0825-PT-1', '2025-08-25', 'shipped', 'EUR', 1, 5, 6,
   '30d', 'Pedido PT agosto mañana', '2025-08-25 09:50:00'),
  (22, 4, 'SO-2025-0825-BE-1', '2025-08-25', 'shipped', 'EUR', 1, 7, 8,
   '30d', 'Pedido BE agosto tarde',  '2025-08-25 17:05:00');
-- ==============================================
-- LÍNEAS DE PEDIDO 2025 (ids 29–44)
-- ==============================================

INSERT INTO sales_order_items
(id, sales_order_id, product_id, ordered_qty, shipped_qty,
 unit_price, discount_percent, tax_rate, line_total)
VALUES
  -- SO 15 (ES) : 1x Pro 14 + 1x ratón
  (29, 15, 1, 1, 1, 1200.00, 0.0, 21.0, 1200.00),
  (30, 15, 4, 1, 1,   25.00, 0.0, 21.0,   25.00),

  -- SO 16 (FR) : 1x Basic 13 + 2x ratón (FR)
  (31, 16, 2, 1, 1,  820.00, 0.0, 20.0,  820.00),
  (32, 16, 4, 2, 2,   27.00, 0.0, 20.0,   54.00),

  -- SO 17 (PT) : 1x Smartphone + 2x ratón
  (33, 17, 3, 1, 1,  900.00, 0.0, 23.0,  900.00),
  (34, 17, 4, 2, 2,   25.00, 0.0, 23.0,   50.00),

  -- SO 18 (BE) : 1x Basic 13 + 1x ratón (tarifa ES)
  (35, 18, 2, 1, 1,  800.00, 0.0, 21.0,  800.00),
  (36, 18, 4, 1, 1,   25.00, 0.0, 21.0,   25.00),

  -- SO 19 (ES) : 1x Smartphone + 3x ratón
  (37, 19, 3, 1, 1,  900.00, 0.0, 21.0,  900.00),
  (38, 19, 4, 3, 3,   25.00, 0.0, 21.0,   75.00),

  -- SO 20 (FR) : 1x Pro 14 + 1x ratón (FR)
  (39, 20, 1, 1, 1, 1250.00, 0.0, 20.0, 1250.00),
  (40, 20, 4, 1, 1,   27.00, 0.0, 20.0,   27.00),

  -- SO 21 (PT) : 1x Basic 13 + 2x ratón
  (41, 21, 2, 1, 1,  800.00, 0.0, 23.0,  800.00),
  (42, 21, 4, 2, 2,   25.00, 0.0, 23.0,   50.00),

  -- SO 22 (BE) : 1x Smartphone + 2x ratón
  (43, 22, 3, 1, 1,  900.00, 0.0, 21.0,  900.00),
  (44, 22, 4, 2, 2,   25.00, 0.0, 21.0,   50.00);
-- ==============================================
-- FACTURAS 2025 (ids 14–21)
-- ==============================================

INSERT INTO invoices
(id, invoice_number, customer_id, sales_order_id, invoice_date,
 due_date, status, currency, total_without_tax, total_tax, total_with_tax, created_at)
VALUES
  -- ENERO
  (14, 'INV-2025-0115-ES-1', 1, 15, '2025-01-16', '2025-02-15',
   'paid', 'EUR', NULL, NULL, NULL, '2025-01-16 11:00:00'),
  (15, 'INV-2025-0115-FR-1', 2, 16, '2025-01-16', '2025-02-15',
   'paid', 'EUR', NULL, NULL, NULL, '2025-01-16 17:30:00'),

  -- MARZO
  (16, 'INV-2025-0320-PT-1', 3, 17, '2025-03-21', '2025-04-20',
   'paid', 'EUR', NULL, NULL, NULL, '2025-03-21 11:10:00'),
  (17, 'INV-2025-0320-BE-1', 4, 18, '2025-03-21', '2025-04-20',
   'paid', 'EUR', NULL, NULL, NULL, '2025-03-21 18:05:00'),

  -- JUNIO
  (18, 'INV-2025-0610-ES-1', 1, 19, '2025-06-11', '2025-07-11',
   'paid', 'EUR', NULL, NULL, NULL, '2025-06-11 10:20:00'),
  (19, 'INV-2025-0610-FR-1', 2, 20, '2025-06-11', '2025-07-11',
   'paid', 'EUR', NULL, NULL, NULL, '2025-06-11 17:00:00'),

  -- AGOSTO (dejamos estas como abiertas/parciales)
  (20, 'INV-2025-0825-PT-1', 3, 21, '2025-08-26', '2025-09-25',
   'open', 'EUR', NULL, NULL, NULL, '2025-08-26 10:30:00'),
  (21, 'INV-2025-0825-BE-1', 4, 22, '2025-08-26', '2025-09-25',
   'partial', 'EUR', NULL, NULL, NULL, '2025-08-26 18:20:00');
-- ==============================================
-- LÍNEAS DE FACTURA 2025 (ids 27–42)
-- ==============================================

INSERT INTO invoice_items
(id, invoice_id, product_id, description, quantity,
 unit_price, discount_percent, tax_rate, line_total)
VALUES
  -- INV 14 (SO 15)
  (27, 14, 1, 'Portátil Pro 14"', 1, 1200.00, 0.0, 21.0, 1200.00),
  (28, 14, 4, 'Ratón inalámbrico', 1,   25.00, 0.0, 21.0,   25.00),

  -- INV 15 (SO 16)
  (29, 15, 2, 'Portátil Basic 13"', 1, 820.00, 0.0, 20.0, 820.00),
  (30, 15, 4, 'Ratón inalámbrico',  2,  27.00, 0.0, 20.0,  54.00),

  -- INV 16 (SO 17)
  (31, 16, 3, 'Smartphone X', 1, 900.00, 0.0, 23.0, 900.00),
  (32, 16, 4, 'Ratón inalámbrico', 2,  25.00, 0.0, 23.0,  50.00),

  -- INV 17 (SO 18)
  (33, 17, 2, 'Portátil Basic 13"', 1, 800.00, 0.0, 21.0, 800.00),
  (34, 17, 4, 'Ratón inalámbrico',  1,  25.00, 0.0, 21.0,  25.00),

  -- INV 18 (SO 19)
  (35, 18, 3, 'Smartphone X', 1, 900.00, 0.0, 21.0, 900.00),
  (36, 18, 4, 'Ratón inalámbrico', 3,  25.00, 0.0, 21.0,  75.00),

  -- INV 19 (SO 20)
  (37, 19, 1, 'Portátil Pro 14"', 1, 1250.00, 0.0, 20.0, 1250.00),
  (38, 19, 4, 'Ratón inalámbrico', 1,   27.00, 0.0, 20.0,   27.00),

  -- INV 20 (SO 21)
  (39, 20, 2, 'Portátil Basic 13"', 1, 800.00, 0.0, 23.0, 800.00),
  (40, 20, 4, 'Ratón inalámbrico',  2,  25.00, 0.0, 23.0,  50.00),

  -- INV 21 (SO 22)
  (41, 21, 3, 'Smartphone X', 1, 900.00, 0.0, 21.0, 900.00),
  (42, 21, 4, 'Ratón inalámbrico', 2,  25.00, 0.0, 21.0,  50.00);
-- ==============================================
-- PAGOS 2025 (ids 15–22)
-- ==============================================

INSERT INTO payments
(id, customer_id, payment_date, amount, currency, method, reference, comments)
VALUES
  -- Pagos completos de enero
  (15, 1, '2025-01-25', 1225.00, 'EUR', 'transfer', 'TRF-2025-0101', 'Pago completo INV-2025-0115-ES-1'),
  (16, 2, '2025-01-27', 874.00,  'EUR', 'card',     'CARD-2025-0102', 'Pago completo INV-2025-0115-FR-1'),

  -- Pagos completos de marzo
  (17, 3, '2025-03-30', 950.00,  'EUR', 'transfer', 'TRF-2025-0301', 'Pago completo INV-2025-0320-PT-1'),
  (18, 4, '2025-03-29', 825.00,  'EUR', 'transfer', 'TRF-2025-0302', 'Pago completo INV-2025-0320-BE-1'),

  -- Pagos completos de junio
  (19, 1, '2025-06-20', 975.00,  'EUR', 'transfer', 'TRF-2025-0601', 'Pago completo INV-2025-0610-ES-1'),
  (20, 2, '2025-06-22', 1277.00, 'EUR', 'card',     'CARD-2025-0602', 'Pago completo INV-2025-0610-FR-1'),

  -- Pagos parciales agosto
  (21, 3, '2025-09-05', 400.00,  'EUR', 'transfer', 'TRF-2025-0901', 'Pago parcial INV-2025-0825-PT-1'),
  (22, 4, '2025-09-06', 600.00,  'EUR', 'transfer', 'TRF-2025-0902', 'Pago parcial INV-2025-0825-BE-1');
-- ==============================================
-- INVOICE_PAYMENTS 2025 (ids 15–22)
-- ==============================================

INSERT INTO invoice_payments (id, invoice_id, payment_id, amount) VALUES
  (15, 14, 15, 1225.00),
  (16, 15, 16,  874.00),
  (17, 16, 17,  950.00),
  (18, 17, 18,  825.00),
  (19, 18, 19,  975.00),
  (20, 19, 20, 1277.00),
  (21, 20, 21,  400.00),  -- parcial PT
  (22, 21, 22,  600.00);  -- parcial BE
