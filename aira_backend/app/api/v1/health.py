"""Health check endpoint."""

from datetime import datetime, timezone
from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check() -> dict:
    """Check if the AIRA OS API is running."""
    return {
        "status": "healthy",
        "app": "AIRA OS",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
