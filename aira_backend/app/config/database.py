"""Supabase database client initialization."""

from functools import lru_cache
from supabase import create_client, Client
from app.config.settings import get_settings


@lru_cache()
def get_supabase_client() -> Client:
    """Get Supabase client with anon key (respects RLS)."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_key)


@lru_cache()
def get_supabase_admin_client() -> Client:
    """Get Supabase client with service role key (bypasses RLS)."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_service_role_key)
