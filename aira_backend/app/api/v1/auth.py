"""Authentication and profile endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from app.core.middleware import get_current_user
from app.config.database import get_supabase_admin_client
from app.models.user import UserProfileUpdate, UserProfileResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(user_id: str = Depends(get_current_user)) -> dict:
    """Get the current user's profile."""
    db = get_supabase_admin_client()
    result = db.table("user_profiles").select("*").eq("id", user_id).single().execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    return {"success": True, "data": result.data}


@router.put("/profile", response_model=UserProfileResponse)
async def update_my_profile(
    updates: UserProfileUpdate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Update the current user's profile."""
    db = get_supabase_admin_client()

    update_data = updates.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update",
        )

    result = (
        db.table("user_profiles")
        .update(update_data)
        .eq("id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    return {"success": True, "data": result.data[0]}
