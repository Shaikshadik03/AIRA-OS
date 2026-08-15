"""Daily Briefing API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.config.database import get_supabase_admin_client
from app.jobs.daily_brief import generate_daily_brief
from app.jobs.night_brief import generate_night_brief

router = APIRouter(prefix="/briefing", tags=["Briefing"])


class BriefingItem(BaseModel):
    mode: str
    content: str
    created_at: str | None = None


class BriefingResponse(BaseModel):
    morning: BriefingItem | None = None
    night: BriefingItem | None = None


@router.get("/latest", response_model=BriefingResponse)
async def get_latest_briefing(user_id: str = Depends(get_current_user)) -> dict:
    """Get the most recent morning and night briefings."""
    db = get_supabase_admin_client()

    response_data = {"morning": None, "night": None}

    for mode in ["morning", "night"]:
        res = (
            db.table("briefings")
            .select("mode, content, created_at")
            .eq("mode", mode)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if res.data and len(res.data) > 0:
            response_data[mode] = res.data[0]

    return response_data


@router.post("/trigger/{mode}")
async def trigger_briefing(mode: str, user_id: str = Depends(get_current_user)):
    """Manually trigger a briefing generation on demand ('morning' or 'night')."""
    if mode == "morning":
        await generate_daily_brief()
        return {"status": "success", "message": "Morning briefing generated"}
    elif mode == "night":
        await generate_night_brief()
        return {"status": "success", "message": "Night briefing generated"}
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mode must be 'morning' or 'night'",
        )
