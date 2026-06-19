-- ============================================================
-- Migration: 002_csdp_seed_data.sql
-- Description: Dummy seed data for csdp schema
-- 5 customers flowing through the full 8-step journey
-- ============================================================

-- Customers
INSERT INTO csdp.customer (cust_type, cust_name, cust_branch) VALUES
  ('Retail', 'Harborview Supply Co.', 'Portland'),
  ('Wholesale', 'Granite Peak Distributors', 'Bangor'),
  ('Retail', 'Coastal Outfitters', 'York Harbor'),
  ('Government', 'Maine Dept. of Transportation', 'Augusta'),
  ('Wholesale', 'Northwood Industrial', 'Lewiston');

-- Requests
INSERT INTO csdp.request (cust_id, req_type, cust_req) VALUES
  (1, 'Product', 'Request for 200 units of industrial shelving'),
  (2, 'Service', 'Annual maintenance contract for warehouse equipment'),
  (3, 'Product', 'Custom signage for retail storefront'),
  (4, 'Service', 'Road marking materials for seasonal repaving'),
  (5, 'Product', 'Bulk order of safety equipment — 500 units');

-- Estimates
INSERT INTO csdp.estimate (req_id, cust_id, est_shipment_date, est_cost, est_price, est_alerts) VALUES
  (1, 1, '2026-07-15', 8200.00, 11500.00, NULL),
  (2, 2, '2026-08-01', 3100.00, 4800.00, 'Lead time may extend if parts delayed'),
  (3, 3, '2026-07-10', 1400.00, 2200.00, NULL),
  (4, 4, '2026-09-01', 22000.00, 31000.00, 'Seasonal pricing in effect'),
  (5, 5, '2026-07-20', 18500.00, 24000.00, NULL);

-- Quotes
INSERT INTO csdp.quote (est_id, req_id, cust_id, qte_shipment_date, qte_cost, qte_price) VALUES
  (1, 1, 1, '2026-07-18', 8200.00, 11500.00),
  (2, 2, 2, '2026-08-05', 3100.00, 4800.00),
  (3, 3, 3, '2026-07-12', 1400.00, 2200.00),
  (4, 4, 4, '2026-09-05', 22000.00, 31000.00),
  (5, 5, 5, '2026-07-22', 18500.00, 24000.00);

-- Orders
INSERT INTO csdp.order (qte_id, est_id, req_id, cust_id, ord_exp_date, ord_cost, ord_price) VALUES
  (1, 1, 1, 1, '2026-07-18', 8200.00, 11500.00),
  (2, 2, 2, 2, '2026-08-05', 3100.00, 4800.00),
  (3, 3, 3, 3, '2026-07-12', 1400.00, 2200.00),
  (4, 4, 4, 4, '2026-09-05', 22000.00, 31000.00),
  (5, 5, 5, 5, '2026-07-22', 18500.00, 24000.00);

-- Deliveries
INSERT INTO csdp.delivery (ord_id, qte_id, est_id, req_id, cust_id, del_date) VALUES
  (1, 1, 1, 1, 1, '2026-07-18'),
  (2, 2, 2, 2, 2, '2026-08-07'),
  (3, 3, 3, 3, 3, '2026-07-11'),
  (4, 4, 4, 4, 4, '2026-09-10'),
  (5, 5, 5, 5, 5, '2026-07-25');

-- Adjustments (2 customers had changes)
INSERT INTO csdp.adjustment (del_id, ord_id, qte_id, est_id, req_id, cust_id, adj_type, adj_reason, adj_del, adj_cost, adj_price) VALUES
  (2, 2, 2, 2, 2, 2, 'Delivery Delay', 'Parts shortage from supplier', '2026-08-07', 0.00, 0.00),
  (4, 4, 4, 4, 4, 4, 'Price Adjustment', 'Government contract discount applied', NULL, -2000.00, -3000.00);

-- Responses
INSERT INTO csdp.response (del_id, ord_id, qte_id, est_id, req_id, cust_id, cust_response) VALUES
  (1, 1, 1, 1, 1, 1, 'Satisfied — shelving arrived on time and in good condition.'),
  (2, 2, 2, 2, 2, 2, 'Disappointed with the delay but understood the reason. Service quality was good.'),
  (3, 3, 3, 3, 3, 3, 'Very satisfied — signage exceeded expectations, delivered early.'),
  (4, 4, 4, 4, 4, 4, 'Satisfied with discount accommodation. Minor delay noted.'),
  (5, 5, 5, 5, 5, 5, 'Satisfied — bulk order complete and accurate.');
