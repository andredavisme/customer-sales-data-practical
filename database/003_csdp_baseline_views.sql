-- ============================================================
-- Migration: 003_csdp_baseline_views.sql
-- Description: The 6 baseline business questions as SQL views
-- ============================================================

-- 1. How many open orders exist?
-- (Orders with no corresponding delivery record)
CREATE OR REPLACE VIEW csdp.v_open_orders AS
SELECT
  o.ord_id,
  c.cust_name,
  c.cust_branch,
  o.ord_exp_date,
  o.ord_price
FROM csdp.order o
JOIN csdp.customer c ON c.cust_id = o.cust_id
LEFT JOIN csdp.delivery d ON d.ord_id = o.ord_id
WHERE d.ord_id IS NULL;

-- 2. How many customers do we have?
CREATE OR REPLACE VIEW csdp.v_customer_count AS
SELECT
  cust_type,
  COUNT(*) AS customer_count
FROM csdp.customer
GROUP BY cust_type
ORDER BY customer_count DESC;

-- 3. What is our delivery rate?
-- (Orders delivered on or before expected date vs. total delivered)
CREATE OR REPLACE VIEW csdp.v_delivery_rate AS
SELECT
  COUNT(*) AS total_deliveries,
  SUM(CASE WHEN d.del_date <= o.ord_exp_date THEN 1 ELSE 0 END) AS on_time,
  SUM(CASE WHEN d.del_date > o.ord_exp_date THEN 1 ELSE 0 END) AS late,
  ROUND(
    100.0 * SUM(CASE WHEN d.del_date <= o.ord_exp_date THEN 1 ELSE 0 END) / COUNT(*), 1
  ) AS on_time_pct
FROM csdp.delivery d
JOIN csdp.order o ON o.ord_id = d.ord_id;

-- 4. How is our customer satisfaction?
-- (All customer responses with linked customer info)
CREATE OR REPLACE VIEW csdp.v_customer_satisfaction AS
SELECT
  c.cust_name,
  c.cust_type,
  c.cust_branch,
  r.cust_response
FROM csdp.response r
JOIN csdp.customer c ON c.cust_id = r.cust_id
ORDER BY c.cust_name;

-- 5. Who are our most profitable customers?
-- (Total revenue = ord_price + any adj_price, net of adjustments)
CREATE OR REPLACE VIEW csdp.v_most_profitable_customers AS
SELECT
  c.cust_id,
  c.cust_name,
  c.cust_type,
  o.ord_price,
  COALESCE(SUM(a.adj_price), 0) AS total_adjustments,
  o.ord_price + COALESCE(SUM(a.adj_price), 0) AS net_revenue
FROM csdp.customer c
JOIN csdp.order o ON o.cust_id = c.cust_id
LEFT JOIN csdp.adjustment a ON a.cust_id = c.cust_id
GROUP BY c.cust_id, c.cust_name, c.cust_type, o.ord_price
ORDER BY net_revenue DESC;

-- 6. Who are our new customers?
-- (Customers with only one request on record)
CREATE OR REPLACE VIEW csdp.v_new_customers AS
SELECT
  c.cust_id,
  c.cust_name,
  c.cust_type,
  c.cust_branch,
  COUNT(r.req_id) AS total_requests
FROM csdp.customer c
JOIN csdp.request r ON r.cust_id = c.cust_id
GROUP BY c.cust_id, c.cust_name, c.cust_type, c.cust_branch
HAVING COUNT(r.req_id) = 1
ORDER BY c.cust_name;
