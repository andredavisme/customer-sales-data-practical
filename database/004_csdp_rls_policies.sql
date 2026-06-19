-- ============================================================
-- Migration: 004_csdp_rls_policies.sql
-- Description: RLS for csdp schema — public read, no write
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE csdp.customer   ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.request    ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.estimate   ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.quote      ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.order      ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.delivery   ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.adjustment ENABLE ROW LEVEL SECURITY;
ALTER TABLE csdp.response   ENABLE ROW LEVEL SECURITY;

-- Public SELECT policies (anon + authenticated)
CREATE POLICY "public_read_customer"   ON csdp.customer   FOR SELECT USING (true);
CREATE POLICY "public_read_request"    ON csdp.request    FOR SELECT USING (true);
CREATE POLICY "public_read_estimate"   ON csdp.estimate   FOR SELECT USING (true);
CREATE POLICY "public_read_quote"      ON csdp.quote      FOR SELECT USING (true);
CREATE POLICY "public_read_order"      ON csdp.order      FOR SELECT USING (true);
CREATE POLICY "public_read_delivery"   ON csdp.delivery   FOR SELECT USING (true);
CREATE POLICY "public_read_adjustment" ON csdp.adjustment FOR SELECT USING (true);
CREATE POLICY "public_read_response"   ON csdp.response   FOR SELECT USING (true);
