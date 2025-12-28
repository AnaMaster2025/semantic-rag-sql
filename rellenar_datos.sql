PRAGMA foreign_keys = ON;
BEGIN TRANSACTION;

-- =========================================================
-- DATOS DE NEGOCIO / VENTAS (dataset ampliado 2025 + enero 2026)
-- SQLite-friendly. Usa subqueries por claves naturales para evitar
-- depender de IDs autoincrement.
-- =========================================================

------------------------------------------------------------
-- 1) Categorías y productos
------------------------------------------------------------
INSERT INTO product_categories (id, parent_id, name, description) VALUES
(1, NULL, 'Electronics', 'Electrónica de consumo y accesorios'),
(2, NULL, 'Furniture',   'Mobiliario y oficina'),
(3, 1,    'Peripherals', 'Periféricos'),
(4, 1,    'Computers',   'Ordenadores'),
(5, 2,    'Desks',       'Mesas y escritorios'),
(6, 2,    'Chairs',      'Sillas');

INSERT INTO products (id, sku, name, description, category_id, unit_of_measure, is_active) VALUES
(1, 'SKU-LAP-15', 'Laptop Pro 15',   'Portátil 15 pulgadas', 4, 'unit', 1),
(2, 'SKU-LAP-13', 'Laptop Air 13',   'Portátil 13 pulgadas', 4, 'unit', 1),
(3, 'SKU-MON-27', 'Monitor 4K 27',   'Monitor 27 pulgadas',  1, 'unit', 1),
(4, 'SKU-MOU-WL', 'Wireless Mouse',  'Ratón inalámbrico',     3, 'unit', 1),
(5, 'SKU-KBD-ME', 'Mechanical KB',   'Teclado mecánico',      3, 'unit', 1),
(6, 'SKU-DSK-ST', 'Standing Desk',   'Escritorio elevable',   5, 'unit', 1),
(7, 'SKU-CHR-ER', 'Ergo Chair',      'Silla ergonómica',      6, 'unit', 1);

------------------------------------------------------------
-- 2) Tarifas (listas de precio) y precios por país
------------------------------------------------------------
INSERT INTO price_lists (id, code, name, currency, valid_from, valid_to) VALUES
(1, 'STD_ES', 'Standard España', 'EUR', '2024-01-01', NULL),
(2, 'STD_FR', 'Standard Francia','EUR', '2024-01-01', NULL),
(3, 'STD_DE', 'Standard Alemania','EUR','2024-01-01', NULL),
(4, 'STD_IT', 'Standard Italia','EUR', '2024-01-01', NULL),
(5, 'STD_GB', 'Standard UK',    'GBP', '2024-01-01', NULL),
(6, 'STD_US', 'Standard USA',   'USD', '2024-01-01', NULL),
(7, 'B2B_EU', 'B2B Europa',     'EUR', '2024-01-01', NULL);

INSERT INTO product_prices (product_id, price_list_id, unit_price, currency, valid_from, valid_to) VALUES
-- ES (EUR)
(1,1,1499,'EUR','2024-01-01',NULL),(2,1,1099,'EUR','2024-01-01',NULL),(3,1, 399,'EUR','2024-01-01',NULL),
(4,1,  29,'EUR','2024-01-01',NULL),(5,1,  89,'EUR','2024-01-01',NULL),(6,1, 499,'EUR','2024-01-01',NULL),(7,1, 269,'EUR','2024-01-01',NULL),
-- FR (EUR)
(1,2,1529,'EUR','2024-01-01',NULL),(2,2,1119,'EUR','2024-01-01',NULL),(3,2, 409,'EUR','2024-01-01',NULL),
(4,2,  31,'EUR','2024-01-01',NULL),(5,2,  95,'EUR','2024-01-01',NULL),(6,2, 519,'EUR','2024-01-01',NULL),(7,2, 279,'EUR','2024-01-01',NULL),
-- DE (EUR)
(1,3,1479,'EUR','2024-01-01',NULL),(2,3,1079,'EUR','2024-01-01',NULL),(3,3, 389,'EUR','2024-01-01',NULL),
(4,3,  28,'EUR','2024-01-01',NULL),(5,3,  85,'EUR','2024-01-01',NULL),(6,3, 489,'EUR','2024-01-01',NULL),(7,3, 259,'EUR','2024-01-01',NULL),
-- IT (EUR)
(1,4,1509,'EUR','2024-01-01',NULL),(2,4,1109,'EUR','2024-01-01',NULL),(3,4, 405,'EUR','2024-01-01',NULL),
(4,4,  30,'EUR','2024-01-01',NULL),(5,4,  92,'EUR','2024-01-01',NULL),(6,4, 509,'EUR','2024-01-01',NULL),(7,4, 275,'EUR','2024-01-01',NULL),
-- GB (GBP)
(1,5,1299,'GBP','2024-01-01',NULL),(2,5, 949,'GBP','2024-01-01',NULL),(3,5, 349,'GBP','2024-01-01',NULL),
(4,5,  25,'GBP','2024-01-01',NULL),(5,5,  79,'GBP','2024-01-01',NULL),(6,5, 439,'GBP','2024-01-01',NULL),(7,5, 239,'GBP','2024-01-01',NULL),
-- US (USD)
(1,6,1599,'USD','2024-01-01',NULL),(2,6,1199,'USD','2024-01-01',NULL),(3,6, 429,'USD','2024-01-01',NULL),
(4,6,  32,'USD','2024-01-01',NULL),(5,6,  99,'USD','2024-01-01',NULL),(6,6, 549,'USD','2024-01-01',NULL),(7,6, 289,'USD','2024-01-01',NULL),
-- B2B EU (EUR) con descuento implícito
(1,7,1399,'EUR','2024-01-01',NULL),(2,7, 999,'EUR','2024-01-01',NULL),(3,7, 369,'EUR','2024-01-01',NULL),
(4,7,  26,'EUR','2024-01-01',NULL),(5,7,  79,'EUR','2024-01-01',NULL),(6,7, 459,'EUR','2024-01-01',NULL),(7,7, 245,'EUR','2024-01-01',NULL);

------------------------------------------------------------
-- 3) Clientes y direcciones (multi-país)
------------------------------------------------------------
INSERT INTO customers (id, external_code, name, tax_id, email, phone, country_code) VALUES
(1,'CUST-ES-001','Iberia Retail S.L.','ESB12345678','ventas@iberiaretail.es','+34-910000001','ES'),
(2,'CUST-FR-001','Paris Distribution','FR123456789','contact@parisdist.fr','+33-140000001','FR'),
(3,'CUST-DE-001','Berlin Tech GmbH','DE123456789','info@berlintech.de','+49-300000001','DE'),
(4,'CUST-IT-001','Milano Office SRL','IT123456789','acquisti@milanooffice.it','+39-020000001','IT'),
(5,'CUST-GB-001','London Supplies Ltd','GB123456789','sales@londonsupplies.co.uk','+44-200000001','GB'),
(6,'CUST-US-001','NYC Enterprises Inc','US12-3456789','procurement@nycenterprises.com','+1-212-000-0001','US');

INSERT INTO customer_addresses (customer_id, address_type, line1, city, state, postal_code, country_code, is_default) VALUES
(1,'billing','C/ Gran Vía 1','Madrid','Madrid','28013','ES',1),
(1,'shipping','Av. Diagonal 100','Barcelona','Cataluña','08019','ES',1),
(2,'billing','10 Rue de Rivoli','Paris','Île-de-France','75001','FR',1),
(2,'shipping','20 Avenue de France','Paris','Île-de-France','75013','FR',1),
(3,'billing','Alexanderplatz 5','Berlin','Berlin','10178','DE',1),
(3,'shipping','Potsdamer Platz 2','Berlin','Berlin','10785','DE',1),
(4,'billing','Via Roma 12','Milano','Lombardia','20121','IT',1),
(4,'shipping','Via Torino 8','Milano','Lombardia','20123','IT',1),
(5,'billing','221 Baker Street','London','England','NW1','GB',1),
(5,'shipping','1 Canary Wharf','London','England','E14','GB',1),
(6,'billing','5th Avenue 350','New York','NY','10018','US',1),
(6,'shipping','Madison Ave 10','New York','NY','10010','US',1);

------------------------------------------------------------
-- 4) Proveedores y compras (multi-país)
------------------------------------------------------------
INSERT INTO suppliers (id, name, tax_id, email, phone, country_code) VALUES
(1,'Shenzhen Components Co.','CN-998877','sales@szcomponents.cn','+86-755-000001','CN'),
(2,'Bavaria Screens AG','DE-556677','orders@bavariascreens.de','+49-89-000001','DE'),
(3,'Lombardia Furniture SPA','IT-778899','export@lbfurn.it','+39-02-000002','IT'),
(4,'US Peripherals LLC','US-88-776655','b2b@usperipherals.com','+1-408-000003','US');

INSERT INTO supplier_addresses (supplier_id, address_type, line1, city, state, postal_code, country_code) VALUES
(1,'billing','Nanshan District 1','Shenzhen','Guangdong','518000','CN'),
(2,'billing','Marienplatz 1','Munich','Bayern','80331','DE'),
(3,'billing','Piazza Duomo 3','Milano','Lombardia','20121','IT'),
(4,'billing','Market Street 10','San Jose','CA','95113','US');

INSERT INTO supplier_products (supplier_id, product_id, supplier_sku, purchase_price, currency, lead_time_days, min_order_qty) VALUES
(1,1,'SZ-LAP-15',1100,'USD',21,5),
(1,2,'SZ-LAP-13', 800,'USD',21,5),
(2,3,'BV-MON-27', 260,'EUR',14,10),
(4,4,'US-MOU-WL',  15,'USD',10,50),
(4,5,'US-KBD-ME',  45,'USD',10,30),
(3,6,'IT-DSK-ST',  310,'EUR',20,5),
(3,7,'IT-CHR-ER',  160,'EUR',20,10);

-- Purchase orders (2025 + enero 2026)
INSERT INTO purchase_orders (supplier_id, order_number, order_date, expected_date, status, currency, comments) VALUES
(1,'PO-2025-0001','2025-11-15','2025-12-10','closed','USD','Reposición laptops'),
(2,'PO-2025-0002','2025-12-01','2025-12-20','closed','EUR','Monitores Q4'),
(3,'PO-2025-0003','2026-01-05','2026-01-28','open','EUR','Mobiliario Q1'),
(4,'PO-2025-0004','2025-12-10','2025-12-22','closed','USD','Periféricos'),
-- ampliación 2025
(1,'PO-2025-0005','2025-03-10','2025-04-05','closed','USD','Laptops primavera'),
(2,'PO-2025-0006','2025-06-02','2025-06-18','closed','EUR','Monitores H1'),
(4,'PO-2025-0007','2025-09-12','2025-09-25','closed','USD','Periféricos back-to-work'),
(3,'PO-2025-0008','2025-10-20','2025-11-12','closed','EUR','Mobiliario Q4'),
-- ampliación enero 2026
(2,'PO-2026-0009','2026-01-12','2026-01-30','open','EUR','Monitores Q1 (reposición)'),
(4,'PO-2026-0010','2026-01-18','2026-01-28','closed','USD','Periféricos urgentes');

-- Items PO (referencia por order_number)
-- PO-2025-0001
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 1, 20, 20, 1100, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0001';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 2, 30, 30,  800, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0001';

-- PO-2025-0002
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 3, 50, 50, 260, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0002';

-- PO-2025-0003 (parcial recibido en enero)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 6, 10,  5, 310, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0003';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 7, 20, 10, 160, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0003';

-- PO-2025-0004
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 4, 200, 200, 15, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0004';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 5, 150, 150, 45, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0004';

-- PO-2025-0005 (primavera)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 1, 15, 15, 1090, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0005';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 2, 25, 25,  790, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0005';

-- PO-2025-0006 (monitores H1)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 3, 80, 80, 255, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0006';

-- PO-2025-0007 (periféricos)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 4, 400, 400, 14, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0007';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 5, 250, 250, 44, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0007';

-- PO-2025-0008 (mobiliario)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 6, 20, 20, 305, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0008';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 7, 35, 35, 158, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2025-0008';

-- PO-2026-0009 (open, aún no recibido)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 3, 60, 0, 258, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2026-0009';

-- PO-2026-0010 (cerrado en enero)
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 4, 300, 300, 15, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2026-0010';
INSERT INTO purchase_order_items (purchase_order_id, product_id, ordered_qty, received_qty, unit_price, tax_rate)
SELECT po.id, 5, 200, 200, 45, 0.00 FROM purchase_orders po WHERE po.order_number='PO-2026-0010';

------------------------------------------------------------
-- 5) Almacenes + inventario + movimientos (multi-país)
------------------------------------------------------------
INSERT INTO warehouses (id, code, name, country_code) VALUES
(1,'WH-ES-MAD','Warehouse Madrid','ES'),
(2,'WH-FR-PAR','Warehouse Paris','FR'),
(3,'WH-DE-BER','Warehouse Berlin','DE'),
(4,'WH-IT-MIL','Warehouse Milan','IT'),
(5,'WH-GB-LON','Warehouse London','GB'),
(6,'WH-US-NYC','Warehouse New York','US');

-- Balance inicial por almacén/producto
INSERT INTO inventory_balance (warehouse_id, product_id, quantity_on_hand, quantity_reserved) VALUES
(1,1,40,2),(1,2,35,1),(1,3,60,3),(1,4,300,10),(1,5,200,6),(1,6,15,1),(1,7,25,2),
(2,1,25,1),(2,2,20,1),(2,3,40,2),(2,4,200,8),(2,5,140,4),(2,6,10,1),(2,7,18,1),
(3,1,30,1),(3,2,22,1),(3,3,45,2),(3,4,180,6),(3,5,130,4),(3,6, 8,1),(3,7,16,1),
(4,1,20,1),(4,2,18,1),(4,3,35,2),(4,4,160,5),(4,5,120,3),(4,6,12,1),(4,7,20,2),
(5,1,22,1),(5,2,16,1),(5,3,38,2),(5,4,140,5),(5,5,110,3),(5,6, 9,1),(5,7,14,1),
(6,1,28,1),(6,2,24,1),(6,3,42,2),(6,4,260,8),(6,5,170,5),(6,6,11,1),(6,7,19,1);

-- Movimientos: entradas por compras (2025 + 2026-01)
INSERT INTO inventory_movements (warehouse_id, product_id, movement_date, movement_type, quantity, related_doc_type, related_doc_id, comments) VALUES
-- Recepciones Q4 2025 (como tu base)
(1,1,'2025-12-10','purchase_receipt', 20,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0001'),'Recepción laptops ES'),
(1,2,'2025-12-10','purchase_receipt', 30,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0001'),'Recepción laptops ES'),
(2,3,'2025-12-20','purchase_receipt', 50,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0002'),'Recepción monitores FR'),
(3,4,'2025-12-22','purchase_receipt',200,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0004'),'Recepción ratones DE'),
(3,5,'2025-12-22','purchase_receipt',150,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0004'),'Recepción teclados DE'),

-- Recepciones adicionales 2025
(1,1,'2025-04-05','purchase_receipt', 15,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0005'),'Recepción laptops primavera ES'),
(1,2,'2025-04-05','purchase_receipt', 25,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0005'),'Recepción laptops primavera ES'),
(2,3,'2025-06-18','purchase_receipt', 80,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0006'),'Recepción monitores H1 FR'),
(3,4,'2025-09-25','purchase_receipt',400,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0007'),'Recepción ratones back-to-work DE'),
(3,5,'2025-09-25','purchase_receipt',250,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0007'),'Recepción teclados back-to-work DE'),
(4,6,'2025-11-12','purchase_receipt', 20,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0008'),'Recepción mesas IT'),
(4,7,'2025-11-12','purchase_receipt', 35,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0008'),'Recepción sillas IT'),

-- Recepciones enero 2026 (mobiliario parcial + periféricos urgentes)
(4,6,'2026-01-10','purchase_receipt',  5,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0003'),'Recepción mesas IT (parcial)'),
(4,7,'2026-01-10','purchase_receipt', 10,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2025-0003'),'Recepción sillas IT (parcial)'),
(5,4,'2026-01-28','purchase_receipt',300,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2026-0010'),'Recepción ratones GB (enero)'),
(5,5,'2026-01-28','purchase_receipt',200,'PO',(SELECT id FROM purchase_orders WHERE order_number='PO-2026-0010'),'Recepción teclados GB (enero)');

------------------------------------------------------------
-- 6) Carriers
------------------------------------------------------------
INSERT INTO carriers (id, name, contact_info, tracking_url) VALUES
(1,'DHL','support@dhl.com','https://www.dhl.com/track?code={tracking}'),
(2,'UPS','support@ups.com','https://www.ups.com/track?loc=en_US&tracknum={tracking}'),
(3,'Correos','support@correos.es','https://www.correos.es/track?code={tracking}');

------------------------------------------------------------
-- 7) Sales orders + items (varios países y monedas)
--    Ampliación a lo largo de 2025 + enero 2026
------------------------------------------------------------

-- Orders
INSERT INTO sales_orders
(customer_id, order_number, order_date, status, currency, price_list_id, billing_address_id, shipping_address_id, payment_terms, comments)
VALUES
-- Base (dic 2025 / ene 2026)
(1,'SO-ES-2025-1001','2025-12-05','shipped','EUR',1,
 (SELECT id FROM customer_addresses WHERE customer_id=1 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=1 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido ES fin de año'),
(2,'SO-FR-2025-1002','2025-12-12','shipped','EUR',2,
 (SELECT id FROM customer_addresses WHERE customer_id=2 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=2 AND address_type='shipping' LIMIT 1),
 'NET15','Pedido FR'),
(3,'SO-DE-2025-1003','2025-12-18','shipped','EUR',3,
 (SELECT id FROM customer_addresses WHERE customer_id=3 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=3 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido DE'),
(5,'SO-GB-2025-1004','2025-12-20','shipped','GBP',5,
 (SELECT id FROM customer_addresses WHERE customer_id=5 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=5 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido GB'),
(6,'SO-US-2026-1005','2026-01-08','open','USD',6,
 (SELECT id FROM customer_addresses WHERE customer_id=6 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=6 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido US enero'),

-- Ampliación 2025 (spread mensual aproximado)
(1,'SO-ES-2025-0901','2025-02-11','delivered','EUR',1,
 (SELECT id FROM customer_addresses WHERE customer_id=1 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=1 AND address_type='shipping' LIMIT 1),
 'NET30','Reposición Q1 ES'),
(2,'SO-FR-2025-0902','2025-03-07','delivered','EUR',2,
 (SELECT id FROM customer_addresses WHERE customer_id=2 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=2 AND address_type='shipping' LIMIT 1),
 'NET15','Pedido FR marzo'),
(3,'SO-DE-2025-0903','2025-04-16','delivered','EUR',3,
 (SELECT id FROM customer_addresses WHERE customer_id=3 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=3 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido DE abril'),
(4,'SO-IT-2025-0904','2025-06-10','delivered','EUR',4,
 (SELECT id FROM customer_addresses WHERE customer_id=4 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=4 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido IT junio'),
(5,'SO-GB-2025-0905','2025-09-03','delivered','GBP',5,
 (SELECT id FROM customer_addresses WHERE customer_id=5 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=5 AND address_type='shipping' LIMIT 1),
 'NET30','Back-to-work GB'),
(6,'SO-US-2025-0906','2025-10-14','delivered','USD',6,
 (SELECT id FROM customer_addresses WHERE customer_id=6 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=6 AND address_type='shipping' LIMIT 1),
 'NET30','US Q4 hardware'),
(1,'SO-ES-2025-0907','2025-11-21','shipped','EUR',1,
 (SELECT id FROM customer_addresses WHERE customer_id=1 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=1 AND address_type='shipping' LIMIT 1),
 'NET30','Black Friday ES'),
(2,'SO-FR-2025-0908','2025-11-28','shipped','EUR',2,
 (SELECT id FROM customer_addresses WHERE customer_id=2 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=2 AND address_type='shipping' LIMIT 1),
 'NET15','Black Friday FR'),

-- Ampliación enero 2026 (más pedidos abiertos)
(3,'SO-DE-2026-0909','2026-01-20','open','EUR',3,
 (SELECT id FROM customer_addresses WHERE customer_id=3 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=3 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido DE enero (pendiente)'),
(4,'SO-IT-2026-0910','2026-01-25','open','EUR',4,
 (SELECT id FROM customer_addresses WHERE customer_id=4 AND address_type='billing'  LIMIT 1),
 (SELECT id FROM customer_addresses WHERE customer_id=4 AND address_type='shipping' LIMIT 1),
 'NET30','Pedido IT enero (pendiente)');

-- Items (line_total = qty * unit_price * (1-discount))
-- SO-ES-2025-1001
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 1, 2, 2, (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=1 LIMIT 1), 5, 0.21,
       2 * (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=1 LIMIT 1) * (1-0.05)
FROM sales_orders so WHERE so.order_number='SO-ES-2025-1001';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 4, 10, 10, (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=1 LIMIT 1), 0, 0.21,
       10 * (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=1 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-ES-2025-1001';

-- SO-FR-2025-1002
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 3, 3, 3, (SELECT unit_price FROM product_prices WHERE product_id=3 AND price_list_id=2 LIMIT 1), 3, 0.20,
       3 * (SELECT unit_price FROM product_prices WHERE product_id=3 AND price_list_id=2 LIMIT 1) * (1-0.03)
FROM sales_orders so WHERE so.order_number='SO-FR-2025-1002';

-- SO-DE-2025-1003
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 5, 5, 5, (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=3 LIMIT 1), 0, 0.19,
       5 * (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=3 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-DE-2025-1003';

-- SO-GB-2025-1004
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 7, 4, 4, (SELECT unit_price FROM product_prices WHERE product_id=7 AND price_list_id=5 LIMIT 1), 8, 0.20,
       4 * (SELECT unit_price FROM product_prices WHERE product_id=7 AND price_list_id=5 LIMIT 1) * (1-0.08)
FROM sales_orders so WHERE so.order_number='SO-GB-2025-1004';

-- SO-US-2026-1005 (abierto, shipped_qty=0)
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 2, 1, 0, (SELECT unit_price FROM product_prices WHERE product_id=2 AND price_list_id=6 LIMIT 1), 0, 0.00,
       1 * (SELECT unit_price FROM product_prices WHERE product_id=2 AND price_list_id=6 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-US-2026-1005';

-- Ampliación 2025: SO-ES-2025-0901
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 4, 25, 25, (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=1 LIMIT 1), 0, 0.21,
       25 * (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=1 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-ES-2025-0901';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 5, 10, 10, (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=1 LIMIT 1), 2, 0.21,
       10 * (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=1 LIMIT 1) * (1-0.02)
FROM sales_orders so WHERE so.order_number='SO-ES-2025-0901';

-- SO-FR-2025-0902
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 3, 6, 6, (SELECT unit_price FROM product_prices WHERE product_id=3 AND price_list_id=2 LIMIT 1), 4, 0.20,
       6 * (SELECT unit_price FROM product_prices WHERE product_id=3 AND price_list_id=2 LIMIT 1) * (1-0.04)
FROM sales_orders so WHERE so.order_number='SO-FR-2025-0902';

-- SO-DE-2025-0903
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 1, 1, 1, (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=3 LIMIT 1), 0, 0.19,
       1 * (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=3 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-DE-2025-0903';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 5, 12, 12, (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=3 LIMIT 1), 0, 0.19,
       12 * (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=3 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-DE-2025-0903';

-- SO-IT-2025-0904
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 6, 3, 3, (SELECT unit_price FROM product_prices WHERE product_id=6 AND price_list_id=4 LIMIT 1), 5, 0.22,
       3 * (SELECT unit_price FROM product_prices WHERE product_id=6 AND price_list_id=4 LIMIT 1) * (1-0.05)
FROM sales_orders so WHERE so.order_number='SO-IT-2025-0904';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 7, 6, 6, (SELECT unit_price FROM product_prices WHERE product_id=7 AND price_list_id=4 LIMIT 1), 0, 0.22,
       6 * (SELECT unit_price FROM product_prices WHERE product_id=7 AND price_list_id=4 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-IT-2025-0904';

-- SO-GB-2025-0905
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 4, 40, 40, (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=5 LIMIT 1), 0, 0.20,
       40 * (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=5 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-GB-2025-0905';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 5, 20, 20, (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=5 LIMIT 1), 3, 0.20,
       20 * (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=5 LIMIT 1) * (1-0.03)
FROM sales_orders so WHERE so.order_number='SO-GB-2025-0905';

-- SO-US-2025-0906
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 1, 2, 2, (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=6 LIMIT 1), 0, 0.00,
       2 * (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=6 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-US-2025-0906';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 3, 4, 4, (SELECT unit_price FROM product_prices WHERE product_id=3 AND price_list_id=6 LIMIT 1), 5, 0.00,
       4 * (SELECT unit_price FROM product_prices WHERE product_id=3 AND price_list_id=6 LIMIT 1) * (1-0.05)
FROM sales_orders so WHERE so.order_number='SO-US-2025-0906';

-- SO-ES-2025-0907
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 2, 3, 3, (SELECT unit_price FROM product_prices WHERE product_id=2 AND price_list_id=1 LIMIT 1), 6, 0.21,
       3 * (SELECT unit_price FROM product_prices WHERE product_id=2 AND price_list_id=1 LIMIT 1) * (1-0.06)
FROM sales_orders so WHERE so.order_number='SO-ES-2025-0907';

-- SO-FR-2025-0908
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 1, 1, 1, (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=2 LIMIT 1), 7, 0.20,
       1 * (SELECT unit_price FROM product_prices WHERE product_id=1 AND price_list_id=2 LIMIT 1) * (1-0.07)
FROM sales_orders so WHERE so.order_number='SO-FR-2025-0908';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 4, 15, 15, (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=2 LIMIT 1), 0, 0.20,
       15 * (SELECT unit_price FROM product_prices WHERE product_id=4 AND price_list_id=2 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-FR-2025-0908';

-- Enero 2026 abiertos (ship=0)
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 5, 10, 0, (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=3 LIMIT 1), 0, 0.19,
       10 * (SELECT unit_price FROM product_prices WHERE product_id=5 AND price_list_id=3 LIMIT 1)
FROM sales_orders so WHERE so.order_number='SO-DE-2026-0909';
INSERT INTO sales_order_items (sales_order_id, product_id, ordered_qty, shipped_qty, unit_price, discount_percent, tax_rate, line_total)
SELECT so.id, 7, 8, 0, (SELECT unit_price FROM product_prices WHERE product_id=7 AND price_list_id=4 LIMIT 1), 5, 0.22,
       8 * (SELECT unit_price FROM product_prices WHERE product_id=7 AND price_list_id=4 LIMIT 1) * (1-0.05)
FROM sales_orders so WHERE so.order_number='SO-IT-2026-0910';

------------------------------------------------------------
-- 8) Deliveries + delivery items (para pedidos shipped/delivered)
------------------------------------------------------------
-- Deliveries (shipped/delivered)
INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 1, 1, so.order_date, date(so.order_date,'+3 day'), 'delivered', 'TRK-ES-001', 'Entrega ES'
FROM sales_orders so WHERE so.order_number='SO-ES-2025-1001';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 2, 2, so.order_date, date(so.order_date,'+4 day'), 'delivered', 'TRK-FR-001', 'Entrega FR'
FROM sales_orders so WHERE so.order_number='SO-FR-2025-1002';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 3, 1, so.order_date, date(so.order_date,'+3 day'), 'delivered', 'TRK-DE-001', 'Entrega DE'
FROM sales_orders so WHERE so.order_number='SO-DE-2025-1003';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 5, 2, so.order_date, date(so.order_date,'+5 day'), 'delivered', 'TRK-GB-001', 'Entrega GB'
FROM sales_orders so WHERE so.order_number='SO-GB-2025-1004';

-- Ampliación entregas 2025 (delivered)
INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 1, 3, so.order_date, date(so.order_date,'+2 day'), 'delivered', 'TRK-ES-0901', 'Entrega ES Q1'
FROM sales_orders so WHERE so.order_number='SO-ES-2025-0901';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 2, 1, so.order_date, date(so.order_date,'+3 day'), 'delivered', 'TRK-FR-0902', 'Entrega FR marzo'
FROM sales_orders so WHERE so.order_number='SO-FR-2025-0902';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 3, 1, so.order_date, date(so.order_date,'+3 day'), 'delivered', 'TRK-DE-0903', 'Entrega DE abril'
FROM sales_orders so WHERE so.order_number='SO-DE-2025-0903';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 4, 2, so.order_date, date(so.order_date,'+4 day'), 'delivered', 'TRK-IT-0904', 'Entrega IT junio'
FROM sales_orders so WHERE so.order_number='SO-IT-2025-0904';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 5, 2, so.order_date, date(so.order_date,'+4 day'), 'delivered', 'TRK-GB-0905', 'Entrega GB septiembre'
FROM sales_orders so WHERE so.order_number='SO-GB-2025-0905';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 6, 2, so.order_date, date(so.order_date,'+5 day'), 'delivered', 'TRK-US-0906', 'Entrega US octubre'
FROM sales_orders so WHERE so.order_number='SO-US-2025-0906';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 1, 1, so.order_date, date(so.order_date,'+3 day'), 'delivered', 'TRK-ES-0907', 'Entrega ES BF'
FROM sales_orders so WHERE so.order_number='SO-ES-2025-0907';

INSERT INTO deliveries (sales_order_id, delivery_number, warehouse_id, carrier_id, ship_date, delivery_date, status, tracking_code, comments)
SELECT so.id, 'DLV-' || so.order_number, 2, 2, so.order_date, date(so.order_date,'+4 day'), 'delivered', 'TRK-FR-0908', 'Entrega FR BF'
FROM sales_orders so WHERE so.order_number='SO-FR-2025-0908';

-- Delivery items
INSERT INTO delivery_items (delivery_id, sales_order_item_id, product_id, quantity)
SELECT d.id, soi.id, soi.product_id, soi.shipped_qty
FROM deliveries d
JOIN sales_orders so ON so.id=d.sales_order_id
JOIN sales_order_items soi ON soi.sales_order_id=so.id
WHERE so.status IN ('shipped','delivered')
  AND soi.shipped_qty > 0;

------------------------------------------------------------
-- 9) Inventario: reflejar salidas por ventas (sale_shipment)
------------------------------------------------------------
INSERT INTO inventory_movements (warehouse_id, product_id, movement_date, movement_type, quantity, related_doc_type, related_doc_id, comments)
SELECT
  d.warehouse_id,
  soi.product_id,
  d.ship_date,
  'sale_shipment',
  -soi.shipped_qty,
  'SO',
  so.id,
  'Salida por entrega'
FROM deliveries d
JOIN sales_orders so ON so.id=d.sales_order_id
JOIN sales_order_items soi ON soi.sales_order_id=so.id
WHERE so.status IN ('shipped','delivered');

------------------------------------------------------------
-- 10) Facturas + items
--  - Para shipped/delivered: factura emitida
--  - Status: paid para delivered/shipped (ejemplo), open para algunas
------------------------------------------------------------
INSERT INTO invoices (invoice_number, customer_id, sales_order_id, invoice_date, due_date, status, currency, total_without_tax, total_tax, total_with_tax)
SELECT
  'INV-' || so.order_number,
  so.customer_id,
  so.id,
  date(so.order_date,'+1 day') AS invoice_date,
  date(so.order_date,'+31 day') AS due_date,
  CASE
    WHEN so.order_number IN ('SO-ES-2025-0907','SO-FR-2025-0908') THEN 'open'
    ELSE 'paid'
  END AS status,
  so.currency,
  (SELECT SUM(line_total) FROM sales_order_items soi WHERE soi.sales_order_id=so.id) AS total_without_tax,
  (SELECT SUM(line_total * COALESCE(soi.tax_rate,0)) FROM sales_order_items soi WHERE soi.sales_order_id=so.id) AS total_tax,
  (SELECT SUM(line_total) + SUM(line_total * COALESCE(soi.tax_rate,0)) FROM sales_order_items soi WHERE soi.sales_order_id=so.id) AS total_with_tax
FROM sales_orders so
WHERE so.status IN ('shipped','delivered');

INSERT INTO invoice_items (invoice_id, product_id, description, quantity, unit_price, discount_percent, tax_rate, line_total)
SELECT
  i.id,
  soi.product_id,
  p.name,
  soi.ordered_qty,
  soi.unit_price,
  soi.discount_percent,
  soi.tax_rate,
  soi.line_total
FROM invoices i
JOIN sales_orders so ON so.id=i.sales_order_id
JOIN sales_order_items soi ON soi.sales_order_id=so.id
JOIN products p ON p.id=soi.product_id;

------------------------------------------------------------
-- 11) Payments + invoice_payments
--  - Solo facturas pagadas
------------------------------------------------------------
INSERT INTO payments (customer_id, payment_date, amount, currency, method, reference, comments)
SELECT
  i.customer_id,
  date(i.invoice_date,'+10 day') AS payment_date,
  i.total_with_tax,
  i.currency,
  'bank_transfer',
  'PAY-' || i.invoice_number,
  'Pago completo'
FROM invoices i
WHERE i.status='paid';

INSERT INTO invoice_payments (invoice_id, payment_id, amount)
SELECT
  i.id,
  p.id,
  i.total_with_tax
FROM invoices i
JOIN payments p ON p.reference = ('PAY-' || i.invoice_number);

------------------------------------------------------------
-- 12) Devoluciones (2 ejemplos: uno en enero 2026, otro en nov 2025)
------------------------------------------------------------
-- Devolución 1 (como tu base) sobre INV-SO-FR-2025-1002
INSERT INTO sales_returns (customer_id, original_invoice_id, return_number, return_date, status, comments)
SELECT
  i.customer_id,
  i.id,
  'RET-' || i.invoice_number,
  date(i.invoice_date,'+20 day'),
  'processed',
  'Devolución por defecto menor'
FROM invoices i
WHERE i.invoice_number = 'INV-SO-FR-2025-1002';

INSERT INTO sales_return_items (sales_return_id, product_id, quantity, reason_code, comments)
SELECT
  sr.id,
  3,
  1,
  'DEFECT',
  'Pixel muerto'
FROM sales_returns sr
WHERE sr.return_number = 'RET-INV-SO-FR-2025-1002';

INSERT INTO inventory_movements (warehouse_id, product_id, movement_date, movement_type, quantity, related_doc_type, related_doc_id, comments)
SELECT
  2,
  3,
  '2026-01-15',
  'adjustment',
  1,
  'RETURN',
  (SELECT id FROM sales_returns WHERE return_number='RET-INV-SO-FR-2025-1002'),
  'Entrada por devolución';

-- Devolución 2 (nov 2025) sobre INV-SO-DE-2025-0903 (teclado)
INSERT INTO sales_returns (customer_id, original_invoice_id, return_number, return_date, status, comments)
SELECT
  i.customer_id,
  i.id,
  'RET-' || i.invoice_number || '-B',
  '2025-11-05',
  'processed',
  'Devolución por preferencia (sin defecto)'
FROM invoices i
WHERE i.invoice_number = 'INV-SO-DE-2025-0903';

INSERT INTO sales_return_items (sales_return_id, product_id, quantity, reason_code, comments)
SELECT
  sr.id,
  5,
  2,
  'NO_DEFECT',
  'Cambio de modelo'
FROM sales_returns sr
WHERE sr.return_number = 'RET-INV-SO-DE-2025-0903-B';

INSERT INTO inventory_movements (warehouse_id, product_id, movement_date, movement_type, quantity, related_doc_type, related_doc_id, comments)
SELECT
  3,
  5,
  '2025-11-06',
  'adjustment',
  2,
  'RETURN',
  (SELECT id FROM sales_returns WHERE return_number='RET-INV-SO-DE-2025-0903-B'),
  'Entrada por devolución (DE)';

-- =========================================================
-- DATOS DE OBSERVABILIDAD LLM (dataset ampliado 2025 + enero 2026)
-- =========================================================

------------------------------------------------------------
-- 13) Usuarios / equipos LLM
------------------------------------------------------------
INSERT INTO users (id, external_id, name, email, role, country_code) VALUES
(1,'u-001','Ana Pérez','ana.perez@company.com','analyst','ES'),
(2,'u-002','Jean Martin','jean.martin@company.com','data_scientist','FR'),
(3,'u-003','Klara Schmidt','klara.schmidt@company.com','engineer','DE'),
(4,'u-004','John Smith','john.smith@company.com','product_owner','GB'),
(5,'u-005','Emily Johnson','emily.johnson@company.com','analyst','US');

INSERT INTO teams (id, name, description) VALUES
(1,'Data Management','Gobierno del dato e IA'),
(2,'AI Lab','Experimentación con LLMs');

INSERT INTO team_members (team_id, user_id, role) VALUES
(1,1,'member'),
(1,3,'member'),
(2,2,'member'),
(2,4,'member'),
(2,5,'member');

------------------------------------------------------------
-- 14) Proveedores y modelos LLM
------------------------------------------------------------
INSERT INTO llm_providers (id, name, base_url, extra_config) VALUES
(1,'anthropic','https://api.anthropic.com',NULL),
(2,'openai','https://api.openai.com',NULL);

INSERT INTO llm_models (id, provider_id, name, family, context_window_tok, is_active) VALUES
(1,1,'claude-3-haiku','claude-3',200000,1),
(2,1,'claude-3-sonnet','claude-3',200000,1),
(3,2,'gpt-4o-mini','gpt',128000,1);

------------------------------------------------------------
-- 15) Experimentos, variantes y prompts
------------------------------------------------------------
INSERT INTO experiments (id, code, name, description, status, owner_user_id) VALUES
(1,'EXP-SALES-NL2SQL','NL→SQL Sales Analytics','Experimento de consultas de ventas en lenguaje natural','active',1);

INSERT INTO experiment_variants (id, experiment_id, name, description, model_id, temperature, top_p, max_tokens, other_params) VALUES
(1,1,'baseline_haiku','Baseline rápido',1,0.2,0.9,800,NULL),
(2,1,'baseline_sonnet','Mayor razonamiento',2,0.2,0.9,1200,NULL),
(3,1,'mini_gpt4o','Económico y rápido',3,0.1,0.9,900,'{"reasoning":"low"}');

INSERT INTO prompts (experiment_variant_id, version, name, system_prompt, user_prompt_template, metadata) VALUES
(1,1,'sales_query_v1','Eres un asistente que traduce preguntas a SQL seguro.','Pregunta: {{question}}', '{"schema":"sales"}'),
(2,1,'sales_query_v1','Eres un asistente experto en analítica y SQL seguro.','Pregunta: {{question}}', '{"schema":"sales"}'),
(3,1,'sales_query_v2','Eres un asistente conciso que devuelve SQL y explicación breve.','Pregunta: {{question}}', '{"schema":"sales","format":"sql+notes"}');

------------------------------------------------------------
-- 16) Datasets y items (ampliado)
------------------------------------------------------------
INSERT INTO datasets (id, name, description, task_type, source) VALUES
(1,'sales_eval_small','Dataset pequeño de pruebas','nl2sql','manual'),
(2,'sales_eval_2025','Dataset anual 2025','nl2sql','manual'),
(3,'sales_eval_2026_jan','Dataset enero 2026','nl2sql','manual');

INSERT INTO dataset_items (dataset_id, external_id, input_text, expected_output, metadata) VALUES
(1,'d1','Ventas del último mes por país','SELECT ...','{"metric":"sales","period":"last_month"}'),
(1,'d2','Top 5 productos por ingresos en ES','SELECT ...','{"country":"ES"}'),
(1,'d3','Pedidos pendientes de envío','SELECT ...','{"status":"open"}'),

(2,'d2025-01','Ingresos por producto en Q1 2025','SELECT ...','{"period":"2025-Q1"}'),
(2,'d2025-02','Margen bruto por país (2025)','SELECT ...','{"metric":"gross_margin","year":2025}'),
(2,'d2025-03','Devoluciones por producto (2025)','SELECT ...','{"metric":"returns","year":2025}'),
(2,'d2025-04','Top clientes por facturación (2025)','SELECT ...','{"metric":"revenue","year":2025,"top_n":5}'),
(2,'d2025-05','Inventario bajo mínimo por almacén','SELECT ...','{"metric":"inventory","alert":"low_stock"}'),

(3,'d2026-01','Pedidos abiertos enero 2026 por país','SELECT ...','{"period":"2026-01","status":"open"}'),
(3,'d2026-02','Coste LLM por variante (enero 2026)','SELECT ...','{"metric":"llm_cost","period":"2026-01"}');

------------------------------------------------------------
-- 17) Tags
------------------------------------------------------------
INSERT INTO tags (id, name, description) VALUES
(1,'baseline','Ejecución baseline'),
(2,'nl2sql','Conversión NL→SQL'),
(3,'sales','Dominio ventas'),
(4,'hallucination','Marcado por alucinación'),
(5,'prod','Uso en producción'),
(6,'benchmark','Ejecución de benchmark');

------------------------------------------------------------
-- 18) LLM runs (ampliado a lo largo de 2025 y enero 2026)
------------------------------------------------------------
INSERT INTO llm_runs
(run_uuid, experiment_variant_id, prompt_id, dataset_item_id, user_id, model_id, customer_id,
 question, answer, elapsed_seconds, prompt_tokens, completion_tokens, total_tokens, cost_usd,
 temperature, top_p, max_tokens, country_code, context_json, created_at)
VALUES
-- Base (dic 2025)
('run-0001',1,1,1,1,1,1,'Ventas del último mes por país','SQL generado + resumen',1.2,900,220,1120,0.012,0.2,0.9,800,'ES','{"note":"offline eval"}','2025-12-21'),
('run-0002',2,2,2,3,2,1,'Top 5 productos por ingresos en ES','SQL + tabla',2.0,950,350,1300,0.030,0.2,0.9,1200,'ES','{"note":"offline eval"}','2025-12-22'),
('run-0003',2,2,3,2,2,NULL,'Pedidos pendientes de envío','SQL + explicación',1.6,920,280,1200,0.026,0.2,0.9,1200,'FR','{"note":"support"}','2025-12-23'),
('run-0004',1,1,1,4,1,2,'Ventas del último mes por país','Respuesta inconsistente',1.0,880,260,1140,0.013,0.2,0.9,800,'DE','{"note":"possible hallucination"}','2025-12-23'),

-- 2025 (spread)
('run-0101',3,3,4,1,3,1,'Top clientes por facturación (2025)','SQL + notas',0.9,700,180,880,0.008,0.1,0.9,900,'ES','{"env":"prod","trace_id":"t-0101"}','2025-02-15'),
('run-0102',2,2,5,3,2,3,'Inventario bajo mínimo por almacén','SQL + recomendaciones',1.8,980,320,1300,0.028,0.2,0.9,1200,'DE','{"env":"prod","trace_id":"t-0102"}','2025-04-20'),
('run-0103',1,1,6,2,1,NULL,'Devoluciones por producto (2025)','SQL generado',1.1,850,210,1060,0.011,0.2,0.9,800,'FR','{"env":"benchmark","trace_id":"t-0103"}','2025-06-05'),
('run-0104',3,3,2,5,3,6,'Top 5 productos por ingresos en ES','SQL + explicación breve',0.8,720,190,910,0.009,0.1,0.9,900,'US','{"env":"prod","trace_id":"t-0104"}','2025-09-09'),
('run-0105',2,2,4,4,2,5,'Margen bruto por país (2025)','SQL + tabla',2.2,1020,410,1430,0.034,0.2,0.9,1200,'GB','{"env":"benchmark","trace_id":"t-0105"}','2025-11-30'),

-- Enero 2026
('run-0201',3,3,7,5,3,6,'Pedidos abiertos enero 2026 por país','SQL + notas',0.95,760,200,960,0.010,0.1,0.9,900,'US','{"env":"prod","trace_id":"t-0201"}','2026-01-09'),
('run-0202',2,2,8,1,2,NULL,'Coste LLM por variante (enero 2026)','SQL + explicación',1.7,940,330,1270,0.027,0.2,0.9,1200,'ES','{"env":"prod","trace_id":"t-0202"}','2026-01-17');

------------------------------------------------------------
-- 19) Evaluaciones de alucinación (ampliado)
------------------------------------------------------------
INSERT INTO hallucination_evaluations (llm_run_id, evaluator_name, score, is_hallucination, method, explanation, raw_json)
VALUES
((SELECT id FROM llm_runs WHERE run_uuid='run-0001'),'rule_based',0.10,0,'heuristic','OK',NULL),
((SELECT id FROM llm_runs WHERE run_uuid='run-0004'),'rule_based',0.85,1,'heuristic','Detectada inconsistencia vs datos',NULL),
((SELECT id FROM llm_runs WHERE run_uuid='run-0101'),'llm_judge',0.08,0,'judge','Respuesta consistente', '{"judge":"gpt"}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0102'),'llm_judge',0.22,0,'judge','Join correcto, resultado plausible', '{"judge":"gpt"}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0103'),'rule_based',0.15,0,'heuristic','OK',NULL),
((SELECT id FROM llm_runs WHERE run_uuid='run-0105'),'llm_judge',0.35,0,'judge','Cubre el periodo completo, pequeñas omisiones', '{"judge":"gpt"}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0202'),'rule_based',0.12,0,'heuristic','OK',NULL);

------------------------------------------------------------
-- 20) Quality metrics (ampliado)
------------------------------------------------------------
INSERT INTO quality_metrics (llm_run_id, metric_name, metric_value, metric_json)
VALUES
((SELECT id FROM llm_runs WHERE run_uuid='run-0001'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0002'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0003'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0004'),'sql_valid',0,'{"error":"bad_join"}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0002'),'answer_relevance',0.92,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0004'),'answer_relevance',0.40,'{}'),

((SELECT id FROM llm_runs WHERE run_uuid='run-0101'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0101'),'answer_relevance',0.90,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0102'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0102'),'answer_relevance',0.88,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0103'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0105'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0201'),'sql_valid',1,'{}'),
((SELECT id FROM llm_runs WHERE run_uuid='run-0202'),'sql_valid',1,'{}');

------------------------------------------------------------
-- 21) Tags aplicados a runs (ampliado)
------------------------------------------------------------
-- baseline + nl2sql + sales para todos
INSERT INTO run_tags (llm_run_id, tag_id)
SELECT id, 1 FROM llm_runs;

INSERT INTO run_tags (llm_run_id, tag_id)
SELECT id, 2 FROM llm_runs;

INSERT INTO run_tags (llm_run_id, tag_id)
SELECT id, 3 FROM llm_runs;

-- hallucination solo run-0004
INSERT INTO run_tags (llm_run_id, tag_id)
SELECT id, 4 FROM llm_runs WHERE run_uuid IN ('run-0004');

-- prod para runs de producción
INSERT INTO run_tags (llm_run_id, tag_id)
SELECT id, 5 FROM llm_runs WHERE run_uuid IN ('run-0101','run-0102','run-0104','run-0201','run-0202');

-- benchmark para algunas
INSERT INTO run_tags (llm_run_id, tag_id)
SELECT id, 6 FROM llm_runs WHERE run_uuid IN ('run-0103','run-0105');

------------------------------------------------------------
-- 22) Agregados diarios (ampliado: 2025 + enero 2026)
------------------------------------------------------------
INSERT INTO daily_run_aggregates (day, experiment_variant_id, model_id, total_runs, total_hallucinations, avg_hallucination_score, total_cost_usd, avg_latency_seconds)
VALUES
('2025-02-15',3,3,1,0,0.08,0.008,0.9),
('2025-04-20',2,2,1,0,0.22,0.028,1.8),
('2025-06-05',1,1,1,0,0.15,0.011,1.1),
('2025-09-09',3,3,1,0,0.10,0.009,0.8),
('2025-11-30',2,2,1,0,0.35,0.034,2.2),

('2025-12-21',1,1,1,0,0.10,0.012,1.2),
('2025-12-22',2,2,1,0,0.05,0.030,2.0),
('2025-12-23',2,2,1,0,0.20,0.026,1.6),
('2025-12-23',1,1,1,1,0.85,0.013,1.0),

('2026-01-09',3,3,1,0,0.10,0.010,0.95),
('2026-01-17',2,2,1,0,0.12,0.027,1.7);

COMMIT;
