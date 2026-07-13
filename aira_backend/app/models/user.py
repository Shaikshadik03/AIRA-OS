"""User-related Pydantic models."""

from datetime import datetime
from pydantic import BaseModel


class UserProfile(BaseModel):
    """User profile data."""
    id: str
    display_name: str
    avatar_url: str | None = None
    timezone: str = "Asia/Kolkata"
    preferred_language: str = "en"
    preferred_voice: str = "default"
    ai_personality: str = "mentor"
    onboarding_complete: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None


class UserProfileUpdate(BaseModel):
    """Fields that can be updated on a user profile."""
    display_name: str | None = None
    avatar_url: str | None = None
    timezone: str | None = None
    preferred_language: str | None = None
    ai_personality: str | None = None


class UserProfileResponse(BaseModel):
    """API response wrapper for user profile."""
    success: bool = True
    data: UserProfile
