"""Planner routes for Tasks and Habits."""

from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.middleware import get_current_user
from app.models.planner import (
    TaskCreate,
    TaskUpdate,
    TaskResponse,
    HabitCreate,
    HabitResponse,
    HabitLogResponse,
)
from app.services.planner_service import get_planner_service

router = APIRouter(prefix="/planner", tags=["Planner"])


# ──────────────────── Tasks ────────────────────

@router.get("/tasks", response_model=list[TaskResponse])
async def list_tasks(
    status: str | None = None,
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Get all tasks for the user."""
    service = get_planner_service()
    return await service.list_tasks(user_id, status)


@router.post("/tasks", response_model=TaskResponse)
async def create_task(
    body: TaskCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Create a task."""
    service = get_planner_service()
    return await service.create_task(user_id, body.model_dump())


@router.patch("/tasks/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    body: TaskUpdate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Update a task's details."""
    service = get_planner_service()
    # Filter out None values to avoid overwriting existing properties
    update_data = {k: v for k, v in body.model_dump().items() if v is not None}
    return await service.update_task(user_id, task_id, update_data)


@router.delete("/tasks/{task_id}")
async def delete_task(
    task_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delete a task."""
    service = get_planner_service()
    await service.delete_task(user_id, task_id)
    return {"success": True, "message": "Task deleted"}


# ──────────────────── Habits ────────────────────

@router.get("/habits", response_model=list[HabitResponse])
async def list_habits(
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Get active habits."""
    service = get_planner_service()
    return await service.list_habits(user_id)


@router.post("/habits", response_model=HabitResponse)
async def create_habit(
    body: HabitCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Create a habit tracker."""
    service = get_planner_service()
    return await service.create_habit(user_id, body.model_dump())


@router.post("/habits/{habit_id}/log", response_model=HabitLogResponse)
async def log_habit(
    habit_id: str,
    logged_date: date | None = None,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Log a habit check-in."""
    target_date = logged_date or date.today()
    service = get_planner_service()
    return await service.log_habit(user_id, habit_id, target_date)


@router.delete("/habits/{habit_id}")
async def delete_habit(
    habit_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delete a habit."""
    service = get_planner_service()
    await service.delete_habit(user_id, habit_id)
    return {"success": True, "message": "Habit deleted"}
