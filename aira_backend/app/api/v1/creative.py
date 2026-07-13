"""Creative Studio image generation API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.services.creative_service import get_creative_service

router = APIRouter(prefix="/creative", tags=["Creative Studio"])


class ImageGenRequest(BaseModel):
    prompt: str


@router.post("/generate-image")
async def generate_image(
    body: ImageGenRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Generate an AI image based on a prompt."""
    if not body.prompt.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prompt cannot be empty",
        )
    
    service = get_creative_service()
    image_url = await service.generate_image(body.prompt)
    return {"prompt": body.prompt, "image_url": image_url}
