"""Memory CRUD and search endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.core.memory_engine import get_memory_engine

router = APIRouter(prefix="/memory", tags=["Memory"])


class MemoryResponse(BaseModel):
    id: str
    content: str
    category: str
    importance_score: float | None = None
    created_at: str | None = None


@router.get("/", response_model=list[MemoryResponse])
async def list_memories(
    category: str | None = None,
    limit: int = 50,
    offset: int = 0,
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """List user's stored memories with optional category filter."""
    engine = get_memory_engine()
    return await engine.list_memories(user_id, category, limit, offset)


@router.get("/search", response_model=list[MemoryResponse])
async def search_memories(
    q: str,
    category: str | None = None,
    limit: int = 10,
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Search memories by text content."""
    if not q.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Search query cannot be empty",
        )
    engine = get_memory_engine()
    return await engine.search_memories(user_id, q, category, limit)


@router.delete("/{memory_id}")
async def delete_memory(
    memory_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delete a specific memory."""
    engine = get_memory_engine()
    await engine.delete_memory(user_id, memory_id)
    return {"success": True, "message": "Memory deleted"}
