-- Migration 010: Create briefings table for Daily Briefing Agent (Morning 7 AM & Night 10 PM)

CREATE TABLE IF NOT EXISTS public.briefings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    mode TEXT NOT NULL CHECK (mode IN ('morning', 'night')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.briefings ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated users
CREATE POLICY "Users can view briefings"
    ON public.briefings
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow service role full access
CREATE POLICY "Service role can manage briefings"
    ON public.briefings
    FOR ALL
    TO service_role
    USING (true);

-- Index for fast queries by mode and created_at
CREATE INDEX IF NOT EXISTS idx_briefings_mode_created_at 
    ON public.briefings (mode, created_at DESC);
