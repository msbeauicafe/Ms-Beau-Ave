-- ============================================================================
-- MS BEAU AVE — demo dataset (GENERATED — do not hand-edit)
--
-- Regenerate with: bash scripts/make-seed-sql.sh
--
-- Built by running scripts/seed-mvp.js against a clean database and dumping
-- the result, so the rows are exactly what the engine's own functions produced:
-- 70/20/10 pool allocations, FEFO-picked order lines, invoices with the
-- past-due block, and a reconciling stock ledger.
--
-- Table names are unqualified, so this loads into whatever search_path points
-- at. Replication role is switched to `replica` for the load because the
-- movement journal and audit log are append-only by trigger and would reject
-- back-dated historical rows.
-- ============================================================================
set session_replication_role = replica;
--
-- PostgreSQL database dump
--


-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: commission_plans; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: employees; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: resellers; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO resellers (id, name, email, tier, credit_limit, payment_terms_days, status, docs_verified, avg_monthly_order, blocked, blocked_reason, created_at, agent_employee_id) OVERRIDING SYSTEM VALUE VALUES (1, 'Bella Skin Manila', 'orders@bellaskin.ph', 3, 500000.00, 45, 'ACTIVE', true, 320000.00, false, NULL, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO resellers (id, name, email, tier, credit_limit, payment_terms_days, status, docs_verified, avg_monthly_order, blocked, blocked_reason, created_at, agent_employee_id) OVERRIDING SYSTEM VALUE VALUES (2, 'Cebu Glow Distributors', 'buyer@cebuglow.ph', 2, 150000.00, 30, 'ACTIVE', true, 110000.00, false, NULL, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO resellers (id, name, email, tier, credit_limit, payment_terms_days, status, docs_verified, avg_monthly_order, blocked, blocked_reason, created_at, agent_employee_id) OVERRIDING SYSTEM VALUE VALUES (4, 'Iloilo Radiance Store', 'hello@iloiloradiance.ph', 1, 0.00, 0, 'ACTIVE', true, 25000.00, false, NULL, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO resellers (id, name, email, tier, credit_limit, payment_terms_days, status, docs_verified, avg_monthly_order, blocked, blocked_reason, created_at, agent_employee_id) OVERRIDING SYSTEM VALUE VALUES (5, 'Baguio Beaute Corner', 'apply@baguiobeaute.ph', 1, 0.00, 0, 'PENDING', false, 0.00, false, NULL, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO resellers (id, name, email, tier, credit_limit, payment_terms_days, status, docs_verified, avg_monthly_order, blocked, blocked_reason, created_at, agent_employee_id) OVERRIDING SYSTEM VALUE VALUES (3, 'Davao Beauty Hub', 'admin@davaobeauty.ph', 2, 120000.00, 30, 'ACTIVE', true, 90000.00, true, 'PAST_DUE_INVOICE', '2026-08-10 21:45:18.234306+00', NULL);


--
-- Data for Name: app_users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO app_users (id, username, display_name, password_hash, role, reseller_id, active, created_at) OVERRIDING SYSTEM VALUE VALUES (1, 'admin', 'Ms Beau (Owner)', 'scrypt$irkE2890krNfffm76Two5Q==$Hw4BnSWsVNgJ2H6EhHLnOXuvdBGOFGWtrWYgK8FYEPY=', 'OWNER_ADMIN', NULL, true, '2026-08-10 21:45:18.234306+00');
INSERT INTO app_users (id, username, display_name, password_hash, role, reseller_id, active, created_at) OVERRIDING SYSTEM VALUE VALUES (2, 'warehouse', 'Warehouse Staff', 'scrypt$RAflU3voqSN8LfIMZdP8cg==$443CRum4AcrKlQdYagpcc2j5w6c2fMBeqCz33IkDm60=', 'WAREHOUSE', NULL, true, '2026-08-10 21:45:18.234306+00');
INSERT INTO app_users (id, username, display_name, password_hash, role, reseller_id, active, created_at) OVERRIDING SYSTEM VALUE VALUES (3, 'cashier', 'Store Cashier', 'scrypt$dw3QdeguvSCYR93iFT83DQ==$OP/CbxyKUHlfQlnt6p2JP51BDsmHMKMJ1AZYjO+rHyg=', 'RETAIL_CASHIER', NULL, true, '2026-08-10 21:45:18.234306+00');
INSERT INTO app_users (id, username, display_name, password_hash, role, reseller_id, active, created_at) OVERRIDING SYSTEM VALUE VALUES (4, 'reseller', 'Cebu Glow Distributors', 'scrypt$iRsX5qZ3noRDAq3GmtNmpA==$U5QWoM5cdgiqCm0DSQBC6ORwEjkj4zcLh8ImyBA8ShU=', 'RESELLER', 2, true, '2026-08-10 21:45:18.234306+00');
INSERT INTO app_users (id, username, display_name, password_hash, role, reseller_id, active, created_at) OVERRIDING SYSTEM VALUE VALUES (5, 'blocked', 'Davao Beauty Hub', 'scrypt$xvRzQXfv69vSWeGctqN1Qg==$hFoJq09copWGx1261VKhsjUbQlBZgha42kTTCiVjsT4=', 'RESELLER', 3, true, '2026-08-10 21:45:18.234306+00');


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SER-001', 'Radiance Vitamin C Serum 30ml', 'Beau Glow', 'Serums', 210.00, 380.00, 650.00, 690.00, 24, NULL, NULL, NULL, 'A', true, '2026-08-10 21:45:18.234306+00', 6, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SER-002', 'Retinoid Night Active Serum 30ml', 'Aurea Lab', 'Serums', 295.00, 520.00, 890.00, 950.00, 18, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 4, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SER-003', 'Niacinamide Clarifying Serum 30ml', 'Beau Glow', 'Serums', 185.00, 340.00, 580.00, 620.00, 24, NULL, NULL, NULL, 'B', true, '2026-08-10 21:45:18.234306+00', 6, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SER-004', 'Hyaluronic Hydra Boost Serum 30ml', 'Luna Derm', 'Serums', 225.00, 410.00, 700.00, 740.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 5, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SER-005', 'Peptide Firming Serum 30ml', 'Aurea Lab', 'Serums', 340.00, 610.00, 1050.00, 1120.00, 18, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 3, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SER-006', 'Centella Calming Ampoule 30ml', 'Isla Naturals', 'Serums', 195.00, 355.00, 610.00, 650.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 4, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('CRM-001', 'Photoprotectant Day Cream 50ml', 'Luna Derm', 'Creams', 240.00, 430.00, 740.00, 780.00, 24, NULL, NULL, NULL, 'B', true, '2026-08-10 21:45:18.234306+00', 5, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('CRM-002', 'Barrier Repair Night Cream 50ml', 'Luna Derm', 'Creams', 265.00, 470.00, 810.00, 850.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 4, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('CRM-003', 'Brightening Underarm Cream 30ml', 'Rosa Botanica', 'Creams', 120.00, 225.00, 390.00, 420.00, 24, NULL, NULL, NULL, 'A', true, '2026-08-10 21:45:18.234306+00', 8, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('CRM-004', 'Ceramide Moisture Gel 50ml', 'Isla Naturals', 'Creams', 175.00, 320.00, 550.00, 590.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 5, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('CRM-005', 'Anti-Melasma Spot Cream 15ml', 'Aurea Lab', 'Creams', 280.00, 500.00, 860.00, 900.00, 18, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 3, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('CRM-006', 'Rice Water Sleeping Mask 60ml', 'Isla Naturals', 'Creams', 160.00, 295.00, 510.00, 545.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 6, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('LIP-001', 'Rose Tint Lip & Cheek 6ml', 'Rosa Botanica', 'Lip', 85.00, 165.00, 290.00, 310.00, 30, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 10, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('LIP-002', 'Velvet Matte Lipstick — Dusty Pink', 'Rosa Botanica', 'Lip', 110.00, 210.00, 360.00, 390.00, 36, NULL, NULL, NULL, 'A', true, '2026-08-10 21:45:18.234306+00', 10, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('LIP-003', 'Hydrating Lip Sleeping Mask 8g', 'Beau Glow', 'Lip', 95.00, 180.00, 310.00, 330.00, 30, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 8, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('LIP-004', 'Peptide Lip Serum 5ml', 'Aurea Lab', 'Lip', 140.00, 260.00, 450.00, 480.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 6, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('LIP-005', 'Tinted Lip Balm SPF15 4g', 'Luna Derm', 'Lip', 75.00, 145.00, 250.00, 270.00, 30, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 12, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SOP-001', 'Micro-Exfoliating Beauty Soap 120g', 'Beau Glow', 'Soaps', 55.00, 110.00, 190.00, 205.00, 36, NULL, NULL, NULL, 'A', true, '2026-08-10 21:45:18.234306+00', 20, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SOP-002', 'Clarifying Kojic Soap 120g', 'Beau Glow', 'Soaps', 60.00, 120.00, 210.00, 225.00, 36, NULL, NULL, NULL, 'B', true, '2026-08-10 21:45:18.234306+00', 20, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SOP-003', 'Brightening Papaya Soap 120g', 'Rosa Botanica', 'Soaps', 48.00, 95.00, 165.00, 180.00, 36, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 24, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SOP-004', 'Charcoal Detox Soap 120g', 'Isla Naturals', 'Soaps', 52.00, 105.00, 180.00, 195.00, 36, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 18, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SOP-005', 'Goat Milk Gentle Soap 120g', 'Isla Naturals', 'Soaps', 58.00, 115.00, 200.00, 215.00, 36, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 16, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SOP-006', 'Sulfur Acne Bar 100g', 'Aurea Lab', 'Soaps', 65.00, 130.00, 225.00, 240.00, 30, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 12, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('TON-001', 'Peeling Toner / Keratolytic 120ml', 'Aurea Lab', 'Toners', 190.00, 350.00, 600.00, 640.00, 18, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 5, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('TON-002', 'Rose Hydrating Toner 200ml', 'Rosa Botanica', 'Toners', 135.00, 250.00, 430.00, 460.00, 24, NULL, NULL, NULL, 'A', true, '2026-08-10 21:45:18.234306+00', 8, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('TON-003', 'BHA Pore Clarifying Toner 150ml', 'Beau Glow', 'Toners', 165.00, 305.00, 525.00, 560.00, 18, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 6, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('TON-004', 'Green Tea Balancing Toner 200ml', 'Isla Naturals', 'Toners', 125.00, 235.00, 405.00, 435.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 8, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SUN-001', 'Daily Shield Sunscreen SPF50 50ml', 'Luna Derm', 'Sunscreen', 235.00, 425.00, 730.00, 770.00, 24, NULL, NULL, NULL, 'A', true, '2026-08-10 21:45:18.234306+00', 8, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SUN-002', 'Tinted Mineral Sunscreen SPF40 40ml', 'Beau Glow', 'Sunscreen', 260.00, 470.00, 810.00, 860.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 5, 12);
INSERT INTO products (sku, name, brand, category, unit_cost, wholesale_price, srp, retail_price, shelf_life_months, alloc_b2b, alloc_retail, alloc_safety, abc_class, active, created_at, retail_min_qty, reseller_floor_months) VALUES ('SUN-003', 'Sunscreen Stick SPF50 15g', 'Rosa Botanica', 'Sunscreen', 195.00, 360.00, 620.00, 660.00, 24, NULL, NULL, NULL, 'C', true, '2026-08-10 21:45:18.234306+00', 6, 12);


--
-- Data for Name: vendors; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: purchase_orders; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: batches; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (1, 'SER-001', 'B1001', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (2, 'SER-001', 'B1002', '2026-12-10', 60, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (3, 'SER-001', 'B1003', '2027-10-10', 180, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (4, 'SER-002', 'B1004', '2028-02-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (5, 'SER-002', 'B1005', '2027-06-10', 90, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (6, 'SER-003', 'B1006', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (7, 'SER-004', 'B1007', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (8, 'SER-004', 'B1008', '2027-01-10', 40, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (9, 'SER-005', 'B1009', '2028-02-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (10, 'SER-006', 'B1010', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (11, 'CRM-001', 'B1011', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (12, 'CRM-001', 'B1012', '2027-07-10', 120, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (13, 'CRM-002', 'B1013', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (14, 'CRM-003', 'B1014', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (15, 'CRM-003', 'B1015', '2026-11-10', 50, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (16, 'CRM-004', 'B1016', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (17, 'CRM-005', 'B1017', '2028-02-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (18, 'CRM-006', 'B1018', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (19, 'LIP-001', 'B1019', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (20, 'LIP-002', 'B1020', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (21, 'LIP-002', 'B1021', '2027-11-10', 200, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (22, 'LIP-003', 'B1022', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (23, 'LIP-004', 'B1023', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (24, 'LIP-005', 'B1024', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (25, 'SOP-001', 'B1025', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (26, 'SOP-001', 'B1026', '2027-05-10', 240, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (27, 'SOP-002', 'B1027', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (28, 'SOP-003', 'B1028', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (29, 'SOP-004', 'B1029', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (30, 'SOP-005', 'B1030', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (31, 'SOP-006', 'B1031', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (32, 'TON-001', 'B1032', '2028-02-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (33, 'TON-001', 'B1033', '2027-01-10', 70, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (34, 'TON-002', 'B1034', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (35, 'TON-003', 'B1035', '2028-02-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (36, 'TON-004', 'B1036', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (37, 'SUN-001', 'B1037', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (38, 'SUN-001', 'B1038', '2027-09-10', 150, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (39, 'SUN-002', 'B1039', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO batches (id, sku, batch_number, expiry_date, qty_received, received_at, vendor_po_id) OVERRIDING SYSTEM VALUE VALUES (40, 'SUN-003', 'B1040', '2028-06-10', 400, '2026-08-10 21:45:18.234306+00', NULL);


--
-- Data for Name: cash_drops; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (1, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-11 21:45:18.315+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (2, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-12 21:45:18.333+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (3, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-13 21:45:18.339+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (4, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-15 21:45:18.342+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (5, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-16 21:45:18.346+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (6, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-17 21:45:18.35+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (7, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-18 21:45:18.355+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (8, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-19 21:45:18.359+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (9, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-20 21:45:18.362+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (10, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-22 21:45:18.366+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (11, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-23 21:45:18.369+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (12, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-24 21:45:18.373+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (13, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-25 21:45:18.378+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (14, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-26 21:45:18.382+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (15, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-27 21:45:18.389+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (16, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-06-29 21:45:18.395+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (17, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-06-30 21:45:18.4+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (18, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-01 21:45:18.406+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (19, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-02 21:45:18.41+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (20, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-03 21:45:18.412+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (21, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-04 21:45:18.416+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (22, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-06 21:45:18.419+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (23, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-07 21:45:18.422+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (24, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-08 21:45:18.426+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (25, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-09 21:45:18.429+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (26, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-10 21:45:18.432+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (27, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-11 21:45:18.435+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (28, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-13 21:45:18.44+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (29, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-14 21:45:18.444+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (30, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-15 21:45:18.448+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (31, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-16 21:45:18.451+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (32, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-17 21:45:18.455+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (33, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-18 21:45:18.458+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (34, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-20 21:45:18.461+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (35, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-21 21:45:18.465+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (36, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-22 21:45:18.469+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (37, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-23 21:45:18.472+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (38, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-24 21:45:18.477+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (39, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-25 21:45:18.481+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (40, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-27 21:45:18.485+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (41, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-28 21:45:18.49+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (42, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-29 21:45:18.494+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (43, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-07-30 21:45:18.499+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (44, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-07-31 21:45:18.503+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (45, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-08-01 21:45:18.508+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (46, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-08-03 21:45:18.513+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (47, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-08-04 21:45:18.519+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (48, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-08-05 21:45:18.522+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (49, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-08-06 21:45:18.526+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (50, 'RETAIL', NULL, 'FULFILLED', 1725.00, 0.00, 1725.00, 'cashier', '2026-08-07 21:45:18.53+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (51, 'RETAIL', NULL, 'FULFILLED', 2545.00, 0.00, 2545.00, 'cashier', '2026-08-08 21:45:18.534+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (52, 'B2B', 1, 'FULFILLED', 56500.00, 0.00, 56500.00, 'agent', '2026-06-21 21:45:18.544+00', '2026-08-10 21:45:18.234306+00');
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (53, 'B2B', 1, 'FULFILLED', 33800.00, 0.00, 33800.00, 'agent', '2026-07-29 21:45:18.556+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (54, 'B2B', 2, 'FULFILLED', 26900.00, 0.00, 26900.00, 'agent', '2026-07-01 21:45:18.561+00', '2026-08-10 21:45:18.234306+00');
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (55, 'B2B', 3, 'FULFILLED', 35550.00, 0.00, 35550.00, 'agent', '2026-06-11 21:45:18.569+00', '2026-08-10 21:45:18.234306+00');
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (56, 'B2B', 4, 'FULFILLED', 11500.00, 0.00, 11500.00, 'agent', '2026-08-02 21:45:18.575+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (57, 'B2B', 2, 'PLACED', 22800.00, 0.00, 22800.00, 'agent', '2026-08-10 21:45:18.234306+00', NULL);
INSERT INTO orders (id, channel, reseller_id, status, subtotal, discount, total, created_by, created_at, delivered_at) OVERRIDING SYSTEM VALUE VALUES (58, 'RETAIL', NULL, 'FULFILLED', 660.00, 0.00, 660.00, 'cashier', '2026-08-10 21:45:18.234306+00', NULL);


--
-- Data for Name: commission_entries; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: cycle_counts; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: documents_201; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO invoices (id, order_id, reseller_id, issued_at, due_date, amount, paid_amount, discount_applied, status, paid_at) OVERRIDING SYSTEM VALUE VALUES (1, 52, 1, '2026-06-21', '2026-08-05', 56500.00, 56500.00, 0.00, 'PAID', '2026-07-21');
INSERT INTO invoices (id, order_id, reseller_id, issued_at, due_date, amount, paid_amount, discount_applied, status, paid_at) OVERRIDING SYSTEM VALUE VALUES (2, 53, 1, '2026-07-29', '2026-09-12', 33800.00, 0.00, 0.00, 'OPEN', NULL);
INSERT INTO invoices (id, order_id, reseller_id, issued_at, due_date, amount, paid_amount, discount_applied, status, paid_at) OVERRIDING SYSTEM VALUE VALUES (3, 54, 2, '2026-07-01', '2026-07-31', 26900.00, 26900.00, 538.00, 'PAID', '2026-07-07');
INSERT INTO invoices (id, order_id, reseller_id, issued_at, due_date, amount, paid_amount, discount_applied, status, paid_at) OVERRIDING SYSTEM VALUE VALUES (4, 55, 3, '2026-06-11', '2026-07-11', 35550.00, 0.00, 0.00, 'OPEN', NULL);
INSERT INTO invoices (id, order_id, reseller_id, issued_at, due_date, amount, paid_amount, discount_applied, status, paid_at) OVERRIDING SYSTEM VALUE VALUES (5, 56, 4, '2026-08-02', '2026-09-01', 11500.00, 11500.00, 0.00, 'PAID', '2026-08-02');
INSERT INTO invoices (id, order_id, reseller_id, issued_at, due_date, amount, paid_amount, discount_applied, status, paid_at) OVERRIDING SYSTEM VALUE VALUES (6, 57, 2, '2026-08-10', '2026-09-09', 22800.00, 0.00, 0.00, 'OPEN', NULL);


--
-- Data for Name: order_lines; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (1, 1, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (2, 1, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (3, 1, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (4, 1, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (5, 2, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (6, 2, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (7, 2, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (8, 2, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (9, 3, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (10, 3, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (11, 3, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (12, 3, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (13, 4, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (14, 4, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (15, 4, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (16, 4, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (17, 5, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (18, 5, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (19, 5, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (20, 5, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (21, 6, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (22, 6, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (23, 6, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (24, 6, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (25, 7, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (26, 7, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (27, 7, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (28, 7, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (29, 8, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (30, 8, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (31, 8, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (32, 8, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (33, 9, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (34, 9, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (35, 9, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (36, 9, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (37, 10, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (38, 10, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (39, 10, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (40, 10, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (41, 11, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (42, 11, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (43, 11, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (44, 11, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (45, 12, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (46, 12, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (47, 12, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (48, 12, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (49, 13, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (50, 13, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (51, 13, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (52, 13, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (53, 14, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (54, 14, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (55, 14, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (56, 14, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (57, 15, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (58, 15, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (59, 15, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (60, 15, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (61, 16, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (62, 16, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (63, 16, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (64, 16, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (65, 17, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (66, 17, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (67, 17, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (68, 17, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (69, 18, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (70, 18, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (71, 18, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (72, 18, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (73, 19, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (74, 19, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (75, 19, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (76, 19, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (77, 20, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (78, 20, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (79, 20, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (80, 20, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (81, 21, 'CRM-003', 15, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (82, 21, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (83, 21, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (84, 21, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (85, 22, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (86, 22, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (87, 22, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (88, 22, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (89, 23, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (90, 23, 'SER-001', 2, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (91, 23, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (92, 23, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (93, 24, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (94, 24, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (95, 24, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (96, 24, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (97, 25, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (98, 25, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (99, 25, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (100, 25, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (101, 26, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (102, 26, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (103, 26, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (104, 26, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (105, 27, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (106, 27, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (107, 27, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (108, 27, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (109, 28, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (110, 28, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (111, 28, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (112, 28, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (113, 29, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (114, 29, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (115, 29, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (116, 29, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (117, 30, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (118, 30, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (119, 30, 'SOP-001', 26, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (120, 30, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (121, 31, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (122, 31, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (123, 31, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (124, 31, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (125, 32, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (126, 32, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (127, 32, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (128, 32, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (129, 33, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (130, 33, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (131, 33, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (132, 33, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (133, 34, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (134, 34, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (135, 34, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (136, 34, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (137, 35, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (138, 35, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (139, 35, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (140, 35, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (141, 36, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (142, 36, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (143, 36, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (144, 36, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (145, 37, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (146, 37, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (147, 37, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (148, 37, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (149, 38, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (150, 38, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (151, 38, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (152, 38, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (153, 39, 'LIP-002', 21, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (154, 39, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (155, 39, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (156, 39, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (157, 40, 'LIP-002', 20, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (158, 40, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (159, 40, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (160, 40, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (161, 41, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (162, 41, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (163, 41, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (164, 41, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (165, 42, 'LIP-002', 20, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (166, 42, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (167, 42, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (168, 42, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (169, 43, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (170, 43, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (171, 43, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (172, 43, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (173, 44, 'LIP-002', 20, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (174, 44, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (175, 44, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (176, 44, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (177, 45, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (178, 45, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (179, 45, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (180, 45, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (181, 46, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (182, 46, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (183, 46, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (184, 46, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (185, 47, 'LIP-002', 20, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (186, 47, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (187, 47, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (188, 47, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (189, 48, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (190, 48, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (191, 48, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (192, 48, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (193, 49, 'LIP-002', 20, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (194, 49, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (195, 49, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (196, 49, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (197, 50, 'CRM-003', 14, 1, 420.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (198, 50, 'LIP-001', 19, 1, 310.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (199, 50, 'SOP-002', 27, 1, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (200, 50, 'SUN-001', 38, 1, 770.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (201, 51, 'LIP-002', 20, 2, 390.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (202, 51, 'SER-001', 3, 1, 690.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (203, 51, 'SOP-001', 25, 3, 205.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (204, 51, 'TON-002', 34, 1, 460.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (205, 52, 'CRM-001', 11, 40, 430.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (206, 52, 'SER-001', 3, 60, 380.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (207, 52, 'SOP-001', 25, 150, 110.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (208, 53, 'LIP-002', 21, 80, 210.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (209, 53, 'SUN-001', 38, 40, 425.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (210, 54, 'SOP-002', 27, 120, 120.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (211, 54, 'TON-002', 34, 50, 250.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (212, 55, 'CRM-003', 14, 90, 225.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (213, 55, 'SER-003', 6, 45, 340.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (214, 56, 'LIP-005', 24, 40, 145.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (215, 56, 'SOP-003', 28, 60, 95.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (216, 57, 'SER-004', 7, 30, 410.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (217, 57, 'SOP-004', 29, 100, 105.00, 0.00);
INSERT INTO order_lines (id, order_id, sku, batch_id, qty, unit_price, discount) OVERRIDING SYSTEM VALUE VALUES (218, 58, 'LIP-003', 22, 2, 330.00, 0.00);


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO payments (id, invoice_id, amount, paid_on, recorded_by, ts) OVERRIDING SYSTEM VALUE VALUES (1, 1, 56500.00, '2026-07-21', 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO payments (id, invoice_id, amount, paid_on, recorded_by, ts) OVERRIDING SYSTEM VALUE VALUES (2, 3, 26900.00, '2026-07-07', 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO payments (id, invoice_id, amount, paid_on, recorded_by, ts) OVERRIDING SYSTEM VALUE VALUES (3, 5, 11500.00, '2026-08-02', 'seed', '2026-08-10 21:45:18.234306+00');


--
-- Data for Name: payroll_runs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: payroll_lines; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ph_holidays; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: po_lines; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: pos_events; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: reseller_documents; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (1, 1, 'BUSINESS_LICENSE', 'bella-skin-manila-dti.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (2, 1, 'TAX_DOCUMENT', 'bella-skin-manila-bir2303.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (3, 2, 'BUSINESS_LICENSE', 'cebu-glow-distributors-dti.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (4, 2, 'TAX_DOCUMENT', 'cebu-glow-distributors-bir2303.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (5, 3, 'BUSINESS_LICENSE', 'davao-beauty-hub-dti.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (6, 3, 'TAX_DOCUMENT', 'davao-beauty-hub-bir2303.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (7, 4, 'BUSINESS_LICENSE', 'iloilo-radiance-store-dti.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (8, 4, 'TAX_DOCUMENT', 'iloilo-radiance-store-bir2303.pdf', '2026-08-10 21:45:18.234306+00', true, 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (9, 5, 'BUSINESS_LICENSE', 'baguio-beaute-corner-dti.pdf', '2026-08-10 21:45:18.234306+00', false, 'seed', NULL);
INSERT INTO reseller_documents (id, reseller_id, doc_type, file_ref, uploaded_at, verified, verified_by, verified_at) OVERRIDING SYSTEM VALUE VALUES (10, 5, 'TAX_DOCUMENT', 'baguio-beaute-corner-bir2303.pdf', '2026-08-10 21:45:18.234306+00', false, 'seed', NULL);


--
-- Data for Name: reseller_events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO reseller_events (id, reseller_id, event_type, details, actor, ts) OVERRIDING SYSTEM VALUE VALUES (1, 1, 'DOCS_VERIFIED', '{"by": "seed"}', 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_events (id, reseller_id, event_type, details, actor, ts) OVERRIDING SYSTEM VALUE VALUES (2, 2, 'DOCS_VERIFIED', '{"by": "seed"}', 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_events (id, reseller_id, event_type, details, actor, ts) OVERRIDING SYSTEM VALUE VALUES (3, 3, 'DOCS_VERIFIED', '{"by": "seed"}', 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_events (id, reseller_id, event_type, details, actor, ts) OVERRIDING SYSTEM VALUE VALUES (4, 4, 'DOCS_VERIFIED', '{"by": "seed"}', 'seed', '2026-08-10 21:45:18.234306+00');
INSERT INTO reseller_events (id, reseller_id, event_type, details, actor, ts) OVERRIDING SYSTEM VALUE VALUES (5, 3, 'AUTO_BLOCK', '{"reason": "PAST_DUE_INVOICE"}', 'seed-finance', '2026-08-10 21:45:18.234306+00');


--
-- Data for Name: reseller_locations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: restock_requests; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO restock_requests (id, sku, note, status, requested_by, ts, done_by, done_at) OVERRIDING SYSTEM VALUE VALUES (1, 'LIP-003', 'AUTO: shelf at 0 after sale OR-20260811-00001 — move stock to the storefront', 'OPEN', 'cashier', '2026-08-10 21:45:18.234306+00', NULL, NULL);


--
-- Data for Name: retail_returns; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: retail_sales; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (1, 1, 'OR-20260611-00001', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-11 21:45:18.315+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (2, 2, 'OR-20260612-00002', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-12 21:45:18.333+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (3, 3, 'OR-20260613-00003', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-13 21:45:18.339+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (4, 4, 'OR-20260615-00004', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-15 21:45:18.342+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (5, 5, 'OR-20260616-00005', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-16 21:45:18.346+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (6, 6, 'OR-20260617-00006', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-17 21:45:18.35+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (7, 7, 'OR-20260618-00007', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-18 21:45:18.355+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (8, 8, 'OR-20260619-00008', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-19 21:45:18.359+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (9, 9, 'OR-20260620-00009', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-20 21:45:18.362+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (10, 10, 'OR-20260622-00010', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-22 21:45:18.366+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (11, 11, 'OR-20260623-00011', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-23 21:45:18.369+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (12, 12, 'OR-20260624-00012', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-24 21:45:18.373+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (13, 13, 'OR-20260625-00013', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-25 21:45:18.378+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (14, 14, 'OR-20260626-00014', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-26 21:45:18.382+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (15, 15, 'OR-20260627-00015', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-27 21:45:18.389+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (16, 16, 'OR-20260629-00016', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-06-29 21:45:18.395+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (17, 17, 'OR-20260630-00017', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-06-30 21:45:18.4+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (18, 18, 'OR-20260701-00018', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-01 21:45:18.406+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (19, 19, 'OR-20260702-00019', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-02 21:45:18.41+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (20, 20, 'OR-20260703-00020', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-03 21:45:18.412+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (21, 21, 'OR-20260704-00021', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-04 21:45:18.416+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (22, 22, 'OR-20260706-00022', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-06 21:45:18.419+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (23, 23, 'OR-20260707-00023', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-07 21:45:18.422+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (24, 24, 'OR-20260708-00024', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-08 21:45:18.426+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (25, 25, 'OR-20260709-00025', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-09 21:45:18.429+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (26, 26, 'OR-20260710-00026', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-10 21:45:18.432+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (27, 27, 'OR-20260711-00027', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-11 21:45:18.435+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (28, 28, 'OR-20260713-00028', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-13 21:45:18.44+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (29, 29, 'OR-20260714-00029', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-14 21:45:18.444+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (30, 30, 'OR-20260715-00030', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-15 21:45:18.448+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (31, 31, 'OR-20260716-00031', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-16 21:45:18.451+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (32, 32, 'OR-20260717-00032', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-17 21:45:18.455+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (33, 33, 'OR-20260718-00033', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-18 21:45:18.458+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (34, 34, 'OR-20260720-00034', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-20 21:45:18.461+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (35, 35, 'OR-20260721-00035', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-21 21:45:18.465+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (36, 36, 'OR-20260722-00036', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-22 21:45:18.469+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (37, 37, 'OR-20260723-00037', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-23 21:45:18.472+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (38, 38, 'OR-20260724-00038', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-24 21:45:18.477+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (39, 39, 'OR-20260725-00039', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-25 21:45:18.481+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (40, 40, 'OR-20260727-00040', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-27 21:45:18.485+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (41, 41, 'OR-20260728-00041', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-28 21:45:18.49+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (42, 42, 'OR-20260729-00042', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-29 21:45:18.494+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (43, 43, 'OR-20260730-00043', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-07-30 21:45:18.499+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (44, 44, 'OR-20260731-00044', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-07-31 21:45:18.503+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (45, 45, 'OR-20260801-00045', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-08-01 21:45:18.508+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (46, 46, 'OR-20260803-00046', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-08-03 21:45:18.513+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (47, 47, 'OR-20260804-00047', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-08-04 21:45:18.519+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (48, 48, 'OR-20260805-00048', 'CASH', 1725.00, 1725.00, 0.00, 'cashier', '2026-08-05 21:45:18.522+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (49, 49, 'OR-20260806-00049', 'CASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-08-06 21:45:18.526+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (50, 50, 'OR-20260807-00050', 'CARD', 1725.00, 1725.00, 0.00, 'cashier', '2026-08-07 21:45:18.53+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (51, 51, 'OR-20260808-00051', 'GCASH', 2545.00, 2545.00, 0.00, 'cashier', '2026-08-08 21:45:18.534+00');
INSERT INTO retail_sales (id, order_id, receipt_no, payment_method, amount_due, tendered, change, cashier, ts) OVERRIDING SYSTEM VALUE VALUES (52, 58, 'OR-20260811-00001', 'CASH', 660.00, 1000.00, 340.00, 'cashier', '2026-08-10 21:45:18.234306+00');


--
-- Data for Name: return_requests; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: rop_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('SER-001', 10, 15, 60, 75, 525, 1125, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('SER-002', 4, 7, 60, 80, 320, 560, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('SER-003', 6, 10, 45, 60, 330, 600, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('CRM-001', 5, 9, 50, 70, 380, 630, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('CRM-003', 8, 14, 40, 55, 450, 770, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('LIP-002', 12, 20, 35, 50, 580, 1000, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('SOP-001', 25, 40, 30, 45, 1050, 1800, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('SOP-002', 18, 30, 30, 45, 810, 1350, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('TON-001', 5, 9, 60, 80, 420, 720, '2026-08-10 21:45:18.234306+00', 3);
INSERT INTO rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days, max_lead_days, safety_stock, rop, last_recalc, target_months_cover) VALUES ('SUN-001', 7, 12, 45, 65, 465, 780, '2026-08-10 21:45:18.234306+00', 3);


--
-- Data for Name: stock_ledger; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (1, 1, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (2, 1, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (3, 1, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (4, 2, 'B2B_POOL', 42, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (6, 2, 'SAFETY', 6, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (9, 3, 'SAFETY', 18, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (10, 4, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (11, 4, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (12, 4, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (13, 5, 'B2B_POOL', 63, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (14, 5, 'RETAIL_SHELF', 18, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (15, 5, 'SAFETY', 9, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (17, 6, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (18, 6, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (20, 7, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (21, 7, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (22, 8, 'B2B_POOL', 28, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (23, 8, 'RETAIL_SHELF', 8, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (24, 8, 'SAFETY', 4, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (25, 9, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (26, 9, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (27, 9, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (28, 10, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (29, 10, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (30, 10, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (32, 11, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (33, 11, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (34, 12, 'B2B_POOL', 84, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (35, 12, 'RETAIL_SHELF', 24, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (36, 12, 'SAFETY', 12, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (37, 13, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (38, 13, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (39, 13, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (42, 14, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (43, 15, 'B2B_POOL', 35, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (45, 15, 'SAFETY', 5, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (46, 16, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (47, 16, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (48, 16, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (49, 17, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (50, 17, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (51, 17, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (52, 18, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (53, 18, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (54, 18, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (55, 19, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (57, 19, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (58, 20, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (60, 20, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (63, 21, 'SAFETY', 20, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (66, 22, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (67, 23, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (68, 23, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (69, 23, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (71, 24, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (72, 24, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (75, 25, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (76, 26, 'B2B_POOL', 168, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (78, 26, 'SAFETY', 24, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (81, 27, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (83, 28, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (84, 28, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (86, 29, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (87, 29, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (88, 30, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (89, 30, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (90, 30, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (91, 31, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (92, 31, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (93, 31, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (94, 32, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (95, 32, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (96, 32, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (97, 33, 'B2B_POOL', 49, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (98, 33, 'RETAIL_SHELF', 14, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (99, 33, 'SAFETY', 7, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (102, 34, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (103, 35, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (104, 35, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (105, 35, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (106, 36, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (107, 36, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (108, 36, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (109, 37, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (110, 37, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (111, 37, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (114, 38, 'SAFETY', 15, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (115, 39, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (116, 39, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (117, 39, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (118, 40, 'B2B_POOL', 280, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (119, 40, 'RETAIL_SHELF', 80, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (120, 40, 'SAFETY', 40, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (44, 15, 'RETAIL_SHELF', 0, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (5, 2, 'RETAIL_SHELF', 0, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (77, 26, 'RETAIL_SHELF', 0, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (62, 21, 'RETAIL_SHELF', 0, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (41, 14, 'RETAIL_SHELF', 65, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (56, 19, 'RETAIL_SHELF', 55, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (80, 27, 'RETAIL_SHELF', 55, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (113, 38, 'RETAIL_SHELF', 5, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (8, 3, 'RETAIL_SHELF', 22, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (59, 20, 'RETAIL_SHELF', 68, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (74, 25, 'RETAIL_SHELF', 50, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (101, 34, 'RETAIL_SHELF', 54, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (7, 3, 'B2B_POOL', 66, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (31, 11, 'B2B_POOL', 240, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (73, 25, 'B2B_POOL', 130, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (61, 21, 'B2B_POOL', 60, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (112, 38, 'B2B_POOL', 65, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (79, 27, 'B2B_POOL', 160, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (100, 34, 'B2B_POOL', 230, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (16, 6, 'B2B_POOL', 235, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (40, 14, 'B2B_POOL', 190, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (70, 24, 'B2B_POOL', 240, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (82, 28, 'B2B_POOL', 220, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (19, 7, 'B2B_POOL', 280, 30);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (85, 29, 'B2B_POOL', 280, 100);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (64, 22, 'B2B_POOL', 358, 0);
INSERT INTO stock_ledger (id, batch_id, pool, qty_on_hand, qty_committed) OVERRIDING SYSTEM VALUE VALUES (65, 22, 'RETAIL_SHELF', 0, 0);


--
-- Data for Name: stock_movements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (1, 1, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (2, 1, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (3, 1, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (4, 2, NULL, 'B2B_POOL', 42, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (5, 2, NULL, 'RETAIL_SHELF', 12, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (6, 2, NULL, 'SAFETY', 6, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (7, 3, NULL, 'B2B_POOL', 126, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (8, 3, NULL, 'RETAIL_SHELF', 36, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (9, 3, NULL, 'SAFETY', 18, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (10, 4, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (11, 4, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (12, 4, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (13, 5, NULL, 'B2B_POOL', 63, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (14, 5, NULL, 'RETAIL_SHELF', 18, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (15, 5, NULL, 'SAFETY', 9, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (16, 6, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (17, 6, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (18, 6, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (19, 7, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (20, 7, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (21, 7, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (22, 8, NULL, 'B2B_POOL', 28, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (23, 8, NULL, 'RETAIL_SHELF', 8, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (24, 8, NULL, 'SAFETY', 4, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (25, 9, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (26, 9, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (27, 9, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (28, 10, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (29, 10, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (30, 10, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (31, 11, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (32, 11, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (33, 11, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (34, 12, NULL, 'B2B_POOL', 84, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (35, 12, NULL, 'RETAIL_SHELF', 24, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (36, 12, NULL, 'SAFETY', 12, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (37, 13, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (38, 13, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (39, 13, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (40, 14, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (41, 14, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (42, 14, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (43, 15, NULL, 'B2B_POOL', 35, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (44, 15, NULL, 'RETAIL_SHELF', 10, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (45, 15, NULL, 'SAFETY', 5, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (46, 16, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (47, 16, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (48, 16, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (49, 17, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (50, 17, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (51, 17, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (52, 18, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (53, 18, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (54, 18, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (55, 19, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (56, 19, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (57, 19, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (58, 20, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (59, 20, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (60, 20, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (61, 21, NULL, 'B2B_POOL', 140, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (62, 21, NULL, 'RETAIL_SHELF', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (63, 21, NULL, 'SAFETY', 20, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (64, 22, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (65, 22, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (66, 22, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (67, 23, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (68, 23, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (69, 23, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (70, 24, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (71, 24, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (72, 24, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (73, 25, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (74, 25, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (75, 25, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (76, 26, NULL, 'B2B_POOL', 168, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (77, 26, NULL, 'RETAIL_SHELF', 48, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (78, 26, NULL, 'SAFETY', 24, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (79, 27, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (80, 27, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (81, 27, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (82, 28, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (83, 28, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (84, 28, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (85, 29, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (86, 29, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (87, 29, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (88, 30, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (89, 30, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (90, 30, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (91, 31, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (92, 31, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (93, 31, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (94, 32, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (95, 32, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (96, 32, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (97, 33, NULL, 'B2B_POOL', 49, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (98, 33, NULL, 'RETAIL_SHELF', 14, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (99, 33, NULL, 'SAFETY', 7, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (100, 34, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (101, 34, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (102, 34, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (103, 35, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (104, 35, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (105, 35, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (106, 36, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (107, 36, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (108, 36, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (109, 37, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (110, 37, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (111, 37, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (112, 38, NULL, 'B2B_POOL', 105, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (113, 38, NULL, 'RETAIL_SHELF', 30, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (114, 38, NULL, 'SAFETY', 15, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (115, 39, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (116, 39, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (117, 39, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (118, 40, NULL, 'B2B_POOL', 280, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (119, 40, NULL, 'RETAIL_SHELF', 80, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (120, 40, NULL, 'SAFETY', 40, 'RECEIVE_ALLOCATION', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (121, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-11 21:45:18.315+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (122, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-11 21:45:18.315+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (123, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-11 21:45:18.315+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (124, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-11 21:45:18.315+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (125, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-12 21:45:18.333+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (126, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-12 21:45:18.333+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (127, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-12 21:45:18.333+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (128, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-12 21:45:18.333+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (129, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-13 21:45:18.339+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (130, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-13 21:45:18.339+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (131, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-13 21:45:18.339+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (132, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-13 21:45:18.339+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (133, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-15 21:45:18.342+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (134, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-15 21:45:18.342+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (135, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-15 21:45:18.342+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (136, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-15 21:45:18.342+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (137, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-16 21:45:18.346+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (138, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-16 21:45:18.346+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (139, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-16 21:45:18.346+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (140, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-16 21:45:18.346+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (141, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-17 21:45:18.35+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (142, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-17 21:45:18.35+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (143, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-17 21:45:18.35+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (144, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-17 21:45:18.35+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (145, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-18 21:45:18.355+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (146, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-18 21:45:18.355+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (147, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-18 21:45:18.355+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (148, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-18 21:45:18.355+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (149, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-19 21:45:18.359+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (150, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-19 21:45:18.359+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (151, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-19 21:45:18.359+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (152, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-19 21:45:18.359+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (153, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-20 21:45:18.362+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (154, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-20 21:45:18.362+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (155, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-20 21:45:18.362+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (156, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-20 21:45:18.362+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (157, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-22 21:45:18.366+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (158, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-22 21:45:18.366+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (159, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-22 21:45:18.366+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (160, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-22 21:45:18.366+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (161, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-23 21:45:18.369+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (162, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-23 21:45:18.369+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (163, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-23 21:45:18.369+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (164, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-23 21:45:18.369+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (165, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-24 21:45:18.373+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (166, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-24 21:45:18.373+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (167, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-24 21:45:18.373+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (168, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-24 21:45:18.373+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (169, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-25 21:45:18.378+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (170, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-25 21:45:18.378+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (171, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-25 21:45:18.378+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (172, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-25 21:45:18.378+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (173, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-26 21:45:18.382+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (174, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-26 21:45:18.382+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (175, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-26 21:45:18.382+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (176, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-26 21:45:18.382+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (177, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-27 21:45:18.389+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (178, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-27 21:45:18.389+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (179, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-27 21:45:18.389+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (180, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-27 21:45:18.389+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (181, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-29 21:45:18.395+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (182, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-06-29 21:45:18.395+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (183, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-06-29 21:45:18.395+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (184, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-29 21:45:18.395+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (185, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-30 21:45:18.4+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (186, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-30 21:45:18.4+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (187, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-30 21:45:18.4+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (188, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-06-30 21:45:18.4+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (189, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-01 21:45:18.406+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (190, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-01 21:45:18.406+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (191, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-01 21:45:18.406+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (192, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-01 21:45:18.406+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (193, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-02 21:45:18.41+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (194, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-02 21:45:18.41+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (195, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-02 21:45:18.41+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (196, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-02 21:45:18.41+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (197, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-03 21:45:18.412+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (198, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-03 21:45:18.412+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (199, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-03 21:45:18.412+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (200, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-03 21:45:18.412+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (201, 15, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-04 21:45:18.416+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (202, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-04 21:45:18.416+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (203, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-04 21:45:18.416+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (204, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-04 21:45:18.416+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (205, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-06 21:45:18.419+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (206, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-06 21:45:18.419+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (207, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-06 21:45:18.419+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (208, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-06 21:45:18.419+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (209, 2, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-07 21:45:18.422+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (210, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-07 21:45:18.422+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (211, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-07 21:45:18.422+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (212, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-07 21:45:18.422+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (213, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-08 21:45:18.426+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (214, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-08 21:45:18.426+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (215, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-08 21:45:18.426+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (216, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-08 21:45:18.426+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (217, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-09 21:45:18.429+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (218, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-09 21:45:18.429+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (219, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-09 21:45:18.429+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (220, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-09 21:45:18.429+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (221, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-10 21:45:18.432+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (222, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-10 21:45:18.432+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (223, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-10 21:45:18.432+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (224, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-10 21:45:18.432+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (225, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-11 21:45:18.435+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (226, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-11 21:45:18.435+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (227, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-11 21:45:18.435+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (228, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-11 21:45:18.435+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (229, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-13 21:45:18.44+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (230, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-13 21:45:18.44+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (231, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-13 21:45:18.44+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (232, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-13 21:45:18.44+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (233, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-14 21:45:18.444+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (234, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-14 21:45:18.444+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (235, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-14 21:45:18.444+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (236, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-14 21:45:18.444+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (237, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-15 21:45:18.448+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (238, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-15 21:45:18.448+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (239, 26, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-15 21:45:18.448+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (240, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-15 21:45:18.448+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (241, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-16 21:45:18.451+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (242, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-16 21:45:18.451+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (243, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-16 21:45:18.451+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (244, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-16 21:45:18.451+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (245, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-17 21:45:18.455+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (246, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-17 21:45:18.455+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (247, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-17 21:45:18.455+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (248, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-17 21:45:18.455+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (249, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-18 21:45:18.458+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (250, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-18 21:45:18.458+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (251, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-18 21:45:18.458+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (252, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-18 21:45:18.458+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (253, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-20 21:45:18.461+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (254, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-20 21:45:18.461+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (255, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-20 21:45:18.461+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (256, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-20 21:45:18.461+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (257, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-21 21:45:18.465+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (258, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-21 21:45:18.465+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (259, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-21 21:45:18.465+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (260, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-21 21:45:18.465+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (261, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-22 21:45:18.469+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (262, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-22 21:45:18.469+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (263, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-22 21:45:18.469+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (264, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-22 21:45:18.469+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (265, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-23 21:45:18.472+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (266, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-23 21:45:18.472+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (267, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-23 21:45:18.472+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (268, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-23 21:45:18.472+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (269, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-24 21:45:18.477+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (270, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-24 21:45:18.477+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (271, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-24 21:45:18.477+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (272, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-24 21:45:18.477+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (273, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-25 21:45:18.481+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (274, 21, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-25 21:45:18.481+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (275, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-25 21:45:18.481+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (276, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-25 21:45:18.481+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (277, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-27 21:45:18.485+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (278, 20, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-27 21:45:18.485+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (279, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-27 21:45:18.485+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (280, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-27 21:45:18.485+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (281, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-28 21:45:18.49+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (282, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-28 21:45:18.49+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (283, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-28 21:45:18.49+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (284, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-28 21:45:18.49+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (285, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-29 21:45:18.494+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (286, 20, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-29 21:45:18.494+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (287, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-29 21:45:18.494+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (288, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-29 21:45:18.494+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (289, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-30 21:45:18.499+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (290, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-30 21:45:18.499+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (291, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-30 21:45:18.499+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (292, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-30 21:45:18.499+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (293, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-31 21:45:18.503+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (294, 20, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-07-31 21:45:18.503+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (295, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-07-31 21:45:18.503+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (296, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-07-31 21:45:18.503+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (297, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-01 21:45:18.508+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (298, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-01 21:45:18.508+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (299, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-01 21:45:18.508+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (300, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-01 21:45:18.508+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (301, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-03 21:45:18.513+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (302, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-03 21:45:18.513+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (303, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-03 21:45:18.513+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (304, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-03 21:45:18.513+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (305, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-04 21:45:18.519+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (306, 20, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-08-04 21:45:18.519+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (307, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-08-04 21:45:18.519+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (308, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-04 21:45:18.519+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (309, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-05 21:45:18.522+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (310, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-05 21:45:18.522+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (311, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-05 21:45:18.522+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (312, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-05 21:45:18.522+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (313, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-06 21:45:18.526+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (314, 20, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-08-06 21:45:18.526+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (315, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-08-06 21:45:18.526+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (316, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-06 21:45:18.526+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (317, 14, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-07 21:45:18.53+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (318, 19, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-07 21:45:18.53+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (319, 27, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-07 21:45:18.53+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (320, 38, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-07 21:45:18.53+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (321, 3, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-08 21:45:18.534+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (322, 20, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-08-08 21:45:18.534+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (323, 25, 'RETAIL_SHELF', NULL, 3, 'POS_SALE', 'cashier', '2026-08-08 21:45:18.534+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (324, 34, 'RETAIL_SHELF', NULL, 1, 'POS_SALE', 'cashier', '2026-08-08 21:45:18.534+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (325, 3, 'B2B_POOL', NULL, 60, 'B2B_SHIP', 'seed-warehouse', '2026-06-21 21:45:18.553+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (326, 11, 'B2B_POOL', NULL, 40, 'B2B_SHIP', 'seed-warehouse', '2026-06-21 21:45:18.553+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (327, 25, 'B2B_POOL', NULL, 150, 'B2B_SHIP', 'seed-warehouse', '2026-06-21 21:45:18.553+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (328, 21, 'B2B_POOL', NULL, 80, 'B2B_SHIP', 'seed-warehouse', '2026-07-29 21:45:18.558+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (329, 38, 'B2B_POOL', NULL, 40, 'B2B_SHIP', 'seed-warehouse', '2026-07-29 21:45:18.558+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (330, 27, 'B2B_POOL', NULL, 120, 'B2B_SHIP', 'seed-warehouse', '2026-07-01 21:45:18.566+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (331, 34, 'B2B_POOL', NULL, 50, 'B2B_SHIP', 'seed-warehouse', '2026-07-01 21:45:18.566+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (332, 6, 'B2B_POOL', NULL, 45, 'B2B_SHIP', 'seed-warehouse', '2026-06-11 21:45:18.572+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (333, 14, 'B2B_POOL', NULL, 90, 'B2B_SHIP', 'seed-warehouse', '2026-06-11 21:45:18.572+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (334, 24, 'B2B_POOL', NULL, 40, 'B2B_SHIP', 'seed-warehouse', '2026-08-02 21:45:18.579+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (335, 28, 'B2B_POOL', NULL, 60, 'B2B_SHIP', 'seed-warehouse', '2026-08-02 21:45:18.579+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (336, 22, 'RETAIL_SHELF', 'B2B_POOL', 78, 'REBALANCE', 'seed-warehouse', '2026-08-10 21:45:18.234306+00');
INSERT INTO stock_movements (id, batch_id, from_pool, to_pool, qty, reason, actor, ts) OVERRIDING SYSTEM VALUE VALUES (337, 22, 'RETAIL_SHELF', NULL, 2, 'POS_SALE', 'cashier', '2026-08-10 21:45:18.234306+00');


--
-- Data for Name: tester_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: training_modules; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: training_records; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Name: app_users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('app_users_id_seq', 5, true);


--
-- Name: attendance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('attendance_id_seq', 1, false);


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('audit_log_id_seq', 932, true);


--
-- Name: batches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('batches_id_seq', 40, true);


--
-- Name: cash_drops_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('cash_drops_id_seq', 1, false);


--
-- Name: commission_entries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('commission_entries_id_seq', 1, false);


--
-- Name: commission_plans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('commission_plans_id_seq', 1, false);


--
-- Name: cycle_counts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('cycle_counts_id_seq', 1, false);


--
-- Name: documents_201_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('documents_201_id_seq', 1, false);


--
-- Name: employees_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('employees_id_seq', 1, false);


--
-- Name: invoices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('invoices_id_seq', 6, true);


--
-- Name: order_lines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('order_lines_id_seq', 218, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('orders_id_seq', 58, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('payments_id_seq', 3, true);


--
-- Name: payroll_lines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('payroll_lines_id_seq', 1, false);


--
-- Name: payroll_runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('payroll_runs_id_seq', 1, false);


--
-- Name: po_lines_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('po_lines_id_seq', 1, false);


--
-- Name: purchase_orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('purchase_orders_id_seq', 1, false);


--
-- Name: receipt_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('receipt_seq', 1, true);


--
-- Name: reseller_documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('reseller_documents_id_seq', 10, true);


--
-- Name: reseller_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('reseller_events_id_seq', 5, true);


--
-- Name: reseller_locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('reseller_locations_id_seq', 1, false);


--
-- Name: resellers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('resellers_id_seq', 5, true);


--
-- Name: restock_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('restock_requests_id_seq', 1, true);


--
-- Name: retail_returns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('retail_returns_id_seq', 1, false);


--
-- Name: retail_sales_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('retail_sales_id_seq', 52, true);


--
-- Name: return_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('return_requests_id_seq', 1, false);


--
-- Name: stock_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('stock_ledger_id_seq', 121, true);


--
-- Name: stock_movements_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('stock_movements_id_seq', 337, true);


--
-- Name: tester_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('tester_logs_id_seq', 1, false);


--
-- Name: training_modules_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('training_modules_id_seq', 1, false);


--
-- Name: training_records_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('training_records_id_seq', 1, false);


--
-- Name: vendors_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('vendors_id_seq', 1, false);


--
-- PostgreSQL database dump complete
--


reset session_replication_role;
