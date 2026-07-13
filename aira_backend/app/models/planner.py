"""Planner Pydantic models (Tasks, Habits, Logs, Reminders)."""

from datetime import date, time, datetime
from pydantic import BaseModel, Field


# ──────────────────── Tasks ────────────────────

class TaskCreate(BaseModel):
    title: str
    description: str | None = None
    due_date: date | None = None
    due_time: time | None = None
    priority: str = Field(default="medium", pattern="^(low|medium|high|urgent)$")
    category: str | None = None
    recurrence: dict | None = None


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    due_date: date | None = None
    due_time: time | None = None
    priority: str | None = Field(default=None, pattern="^(low|medium|high|urgent)$")
    status: str | None = Field(default=None, pattern="^(pending|in_progress|completed|cancelled)$")
    category: str | None = None
    recurrence: dict | None = None
    completed_at: datetime | None = None


class TaskResponse(BaseModel):
    id: str
    user_id: str
    title: str
    description: str | None = None
    due_date: date | None = None
    due_time: time | None = None
    priority: str
    status: str
    category: str | None = None
    recurrence: dict | None = None
    created_at: datetime
    completed_at: datetime | None = None


# ──────────────────── Habits ────────────────────

class HabitCreate(BaseModel):
    name: str
    description: str | None = None
    frequency: str = "daily"
    target_count: int = 1
    icon: str | None = None
    color: str | None = None


class HabitLogCreate(BaseModel):
    logged_date: date
    count: int = 1
    notes: str | None = None


class HabitResponse(BaseModel):
    id: str
    user_id: str
    name: str
    description: str | None = None
    frequency: str
    target_count: int
    icon: str | None = None
    color: str | None = None
    current_streak: int
    longest_streak: int
    is_active: bool
    created_at: datetime


class HabitLogResponse(BaseModel):
    id: str
    habit_id: str
    user_id: str
    logged_date: date
    count: int
    notes: str | None = None
