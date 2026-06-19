-- ============================================================
-- Migration: 005_csdp_grant_anon_access.sql
-- Description: Grant anon + authenticated roles usage on csdp
-- ============================================================

GRANT USAGE ON SCHEMA csdp TO anon, authenticated;

GRANT SELECT ON csdp.customer   TO anon, authenticated;
GRANT SELECT ON csdp.request    TO anon, authenticated;
GRANT SELECT ON csdp.estimate   TO anon, authenticated;
GRANT SELECT ON csdp.quote      TO anon, authenticated;
GRANT SELECT ON csdp.order      TO anon, authenticated;
GRANT SELECT ON csdp.delivery   TO anon, authenticated;
GRANT SELECT ON csdp.adjustment TO anon, authenticated;
GRANT SELECT ON csdp.response   TO anon, authenticated;

GRANT SELECT ON csdp.v_open_orders               TO anon, authenticated;
GRANT SELECT ON csdp.v_customer_count            TO anon, authenticated;
GRANT SELECT ON csdp.v_delivery_rate             TO anon, authenticated;
GRANT SELECT ON csdp.v_customer_satisfaction     TO anon, authenticated;
GRANT SELECT ON csdp.v_most_profitable_customers TO anon, authenticated;
GRANT SELECT ON csdp.v_new_customers             TO anon, authenticated;
