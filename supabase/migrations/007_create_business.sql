-- ============================================
-- TABLE: business_clients
-- CRM / Client directory for AIRA Business Mode
-- ============================================
CREATE TABLE IF NOT EXISTS business_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    company TEXT,
    email TEXT,
    phone TEXT,
    notes TEXT,
    status TEXT DEFAULT 'lead' CHECK (status IN ('lead', 'active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE business_clients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own business clients" ON business_clients
    FOR ALL USING (auth.uid() = user_id);
