-- ============================================================
-- Migration: 001_csdp_initial_schema.sql
-- Description: Initial schema for Customer Sales Data Practical
-- Schema: csdp (isolated from other schemas in this project)
-- ============================================================

CREATE SCHEMA IF NOT EXISTS csdp;

-- 1. Customer
CREATE TABLE csdp.customer (
  cust_id     SERIAL PRIMARY KEY,
  cust_type   TEXT NOT NULL,
  cust_name   TEXT NOT NULL,
  cust_branch TEXT
);

-- 2. Request
CREATE TABLE csdp.request (
  req_id   SERIAL PRIMARY KEY,
  cust_id  INT NOT NULL REFERENCES csdp.customer(cust_id),
  req_type TEXT NOT NULL,
  cust_req TEXT NOT NULL
);

-- 3. Estimate
CREATE TABLE csdp.estimate (
  est_id            SERIAL PRIMARY KEY,
  req_id            INT NOT NULL REFERENCES csdp.request(req_id),
  cust_id           INT NOT NULL REFERENCES csdp.customer(cust_id),
  est_shipment_date DATE,
  est_cost          NUMERIC(12,2),
  est_price         NUMERIC(12,2),
  est_alerts        TEXT
);

-- 4. Quote
CREATE TABLE csdp.quote (
  qte_id            SERIAL PRIMARY KEY,
  est_id            INT NOT NULL REFERENCES csdp.estimate(est_id),
  req_id            INT NOT NULL REFERENCES csdp.request(req_id),
  cust_id           INT NOT NULL REFERENCES csdp.customer(cust_id),
  qte_shipment_date DATE,
  qte_cost          NUMERIC(12,2),
  qte_price         NUMERIC(12,2)
);

-- 5. Order
CREATE TABLE csdp.order (
  ord_id       SERIAL PRIMARY KEY,
  qte_id       INT NOT NULL REFERENCES csdp.quote(qte_id),
  est_id       INT NOT NULL REFERENCES csdp.estimate(est_id),
  req_id       INT NOT NULL REFERENCES csdp.request(req_id),
  cust_id      INT NOT NULL REFERENCES csdp.customer(cust_id),
  ord_exp_date DATE,
  ord_cost     NUMERIC(12,2),
  ord_price    NUMERIC(12,2)
);

-- 6. Delivery
CREATE TABLE csdp.delivery (
  del_id   SERIAL PRIMARY KEY,
  ord_id   INT NOT NULL REFERENCES csdp.order(ord_id),
  qte_id   INT NOT NULL REFERENCES csdp.quote(qte_id),
  est_id   INT NOT NULL REFERENCES csdp.estimate(est_id),
  req_id   INT NOT NULL REFERENCES csdp.request(req_id),
  cust_id  INT NOT NULL REFERENCES csdp.customer(cust_id),
  del_date DATE
);

-- 7. Adjustment
CREATE TABLE csdp.adjustment (
  adj_id     SERIAL PRIMARY KEY,
  del_id     INT NOT NULL REFERENCES csdp.delivery(del_id),
  ord_id     INT NOT NULL REFERENCES csdp.order(ord_id),
  qte_id     INT NOT NULL REFERENCES csdp.quote(qte_id),
  est_id     INT NOT NULL REFERENCES csdp.estimate(est_id),
  req_id     INT NOT NULL REFERENCES csdp.request(req_id),
  cust_id    INT NOT NULL REFERENCES csdp.customer(cust_id),
  adj_type   TEXT,
  adj_reason TEXT,
  adj_del    DATE,
  adj_cost   NUMERIC(12,2),
  adj_price  NUMERIC(12,2)
);

-- 8. Response
CREATE TABLE csdp.response (
  resp_id       SERIAL PRIMARY KEY,
  del_id        INT NOT NULL REFERENCES csdp.delivery(del_id),
  ord_id        INT NOT NULL REFERENCES csdp.order(ord_id),
  qte_id        INT NOT NULL REFERENCES csdp.quote(qte_id),
  est_id        INT NOT NULL REFERENCES csdp.estimate(est_id),
  req_id        INT NOT NULL REFERENCES csdp.request(req_id),
  cust_id       INT NOT NULL REFERENCES csdp.customer(cust_id),
  cust_response TEXT
);
