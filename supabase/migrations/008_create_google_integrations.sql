-- Migration: Create Google Integrations table
-- Description: Stores Google OAuth tokens and maps Supabase entities to Google entities.

-- Google OAuth Tokens table
CREATE TABLE IF NOT EXISTS public.user_integrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'google',
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expiry TIMESTAMP WITH TIME ZONE,
    scopes TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, provider)
);

-- Enable RLS
ALTER TABLE public.user_integrations ENABLE ROW LEVEL SECURITY;

-- Policies for user_integrations
CREATE POLICY "Users can view their own integrations"
    ON public.user_integrations FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own integrations"
    ON public.user_integrations FOR ALL
    USING (auth.uid() = user_id);


-- Google Task Mappings table
-- Used for two-way sync between tasks and Google Tasks
CREATE TABLE IF NOT EXISTS public.google_task_mappings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    local_task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    google_task_list_id TEXT NOT NULL,
    google_task_id TEXT NOT NULL,
    last_synced_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(local_task_id),
    UNIQUE(google_task_id)
);

-- Enable RLS
ALTER TABLE public.google_task_mappings ENABLE ROW LEVEL SECURITY;

-- Policies for google_task_mappings
CREATE POLICY "Users can view their own task mappings"
    ON public.google_task_mappings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own task mappings"
    ON public.google_task_mappings FOR ALL
    USING (auth.uid() = user_id);
