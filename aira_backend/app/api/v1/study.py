"""Study API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.services.study_service import get_study_service

router = APIRouter(prefix="/study", tags=["Study"])


class TopicRequest(BaseModel):
    topic: str


@router.post("/generate-notes")
async def generate_notes(
    body: TopicRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Generate Markdown study notes on a topic."""
    if not body.topic.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Topic cannot be empty",
        )
    service = get_study_service()
    notes = await service.generate_notes(body.topic)
    return {"topic": body.topic, "notes": notes}


@router.post("/generate-quiz")
async def generate_quiz(
    body: TopicRequest,
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Generate multiple-choice quiz questions on a topic."""
    if not body.topic.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Topic cannot be empty",
        )
    service = get_study_service()
    return await service.generate_quiz(body.topic)
