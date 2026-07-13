"""Coding API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.services.coding_service import get_coding_service

router = APIRouter(prefix="/coding", tags=["Coding"])


class CodeRequest(BaseModel):
    code: str
    language: str


@router.post("/debug")
async def debug_code(
    body: CodeRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Debug code snippet."""
    if not body.code.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code cannot be empty",
        )
    service = get_coding_service()
    result = await service.debug_code(body.code, body.language)
    return {"result": result}


@router.post("/explain")
async def explain_code(
    body: CodeRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Explain code snippet."""
    if not body.code.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code cannot be empty",
        )
    service = get_coding_service()
    result = await service.explain_code(body.code, body.language)
    return {"result": result}
