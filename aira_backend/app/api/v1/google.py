"""Google OAuth and Workspace integration endpoints."""

import os
import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import RedirectResponse
from google_auth_oauthlib.flow import Flow
from app.core.middleware import get_current_user
from app.config.database import get_supabase_admin_client

logger = logging.getLogger("aira.google_api")

router = APIRouter(prefix="/google", tags=["Google Workspace"])

# Required scopes for AIRA
SCOPES = [
    'https://www.googleapis.com/auth/tasks',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/gmail.send'
]


def _get_client_config():
    """Build client config from environment variables."""
    return {
        "web": {
            "client_id": os.getenv("GOOGLE_CLIENT_ID", ""),
            "client_secret": os.getenv("GOOGLE_CLIENT_SECRET", ""),
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": [os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/api/v1/google/callback")]
        }
    }


@router.get("/auth")
async def google_auth_start(user_id: str = Depends(get_current_user)):
    """Initiate Google OAuth flow."""
    client_id = os.getenv("GOOGLE_CLIENT_ID")
    if not client_id:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Google integration is not configured on the server."
        )

    # Use state to pass user_id through the OAuth flow
    flow = Flow.from_client_config(
        _get_client_config(),
        scopes=SCOPES,
        state=user_id
    )
    # Required for getting a refresh token
    flow.redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/api/v1/google/callback")
    
    auth_url, _ = flow.authorization_url(
        access_type='offline',
        include_granted_scopes='true',
        prompt='consent'
    )

    return {"auth_url": auth_url}


@router.get("/callback")
async def google_auth_callback(request: Request):
    """Handle Google OAuth callback."""
    code = request.query_params.get("code")
    state = request.query_params.get("state") # Contains user_id
    error = request.query_params.get("error")

    if error or not code or not state:
        return {"success": False, "error": error or "Missing parameters"}

    try:
        flow = Flow.from_client_config(
            _get_client_config(),
            scopes=SCOPES,
            state=state
        )
        flow.redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8000/api/v1/google/callback")
        
        # Exchange code for tokens
        # The request url needs to be HTTPS if running in production, but oauthlib allows HTTP for localhost.
        # So we reconstruct the full URL.
        flow.fetch_token(authorization_response=str(request.url))
        credentials = flow.credentials
        
        user_id = state
        db = get_supabase_admin_client()

        # Upsert the token
        record = {
            "user_id": user_id,
            "provider": "google",
            "access_token": credentials.token,
            "refresh_token": credentials.refresh_token,
            "token_expiry": credentials.expiry.isoformat() if credentials.expiry else None,
            "scopes": SCOPES
        }
        
        # Check if exists
        existing = db.table("user_integrations").select("id").eq("user_id", user_id).eq("provider", "google").execute()
        
        if existing.data:
            db.table("user_integrations").update(record).eq("user_id", user_id).eq("provider", "google").execute()
        else:
            db.table("user_integrations").insert(record).execute()

        # In a real app, redirect to a success page or deep link back to the Flutter app
        return {"success": True, "message": "Google Workspace connected successfully!"}

    except Exception as e:
        logger.error(f"Google OAuth callback failed: {e}")
        return {"success": False, "error": str(e)}


@router.get("/status")
async def get_google_status(user_id: str = Depends(get_current_user)):
    """Check if the user is connected to Google Workspace."""
    db = get_supabase_admin_client()
    result = db.table("user_integrations").select("id").eq("user_id", user_id).eq("provider", "google").execute()
    
    return {"connected": bool(result.data)}
