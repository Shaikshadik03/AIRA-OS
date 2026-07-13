"""Planner Service - business logic for Tasks and Habits."""

import logging
from datetime import date, datetime
from app.config.database import get_supabase_admin_client

logger = logging.getLogger("aira.planner")


class PlannerService:
    """Manages CRUD operations and state tracking for tasks and habits."""

    def __init__(self) -> None:
        self.db = get_supabase_admin_client()

    # ──────────────────── Tasks ────────────────────

    async def list_tasks(self, user_id: str, status: str | None = None) -> list[dict]:
        """List user tasks, with optional status filter."""
        q = self.db.table("tasks").select("*").eq("user_id", user_id)
        if status:
            q = q.eq("status", status)
        q = q.order("due_date", nulls_first=False).order("priority", desc=True)
        res = q.execute()
        return res.data or []

    async def create_task(self, user_id: str, task_data: dict) -> dict:
        """Create a new task."""
        data = {**task_data, "user_id": user_id}
        res = self.db.table("tasks").insert(data).execute()
        return res.data[0] if res.data else {}

    async def update_task(self, user_id: str, task_id: str, task_data: dict) -> dict:
        """Update a task's details or completion status."""
        # Convert date/time objects to string representations if needed
        data = {}
        for k, v in task_data.items():
            if isinstance(v, (date, datetime)):
                data[k] = v.isoformat()
            else:
                data[k] = v

        if data.get("status") == "completed":
            data["completed_at"] = datetime.now().isoformat()
        elif data.get("status") == "pending":
            data["completed_at"] = None

        res = (
            self.db.table("tasks")
            .update(data)
            .eq("id", task_id)
            .eq("user_id", user_id)
            .execute()
        )
        return res.data[0] if res.data else {}

    async def delete_task(self, user_id: str, task_id: str) -> bool:
        """Delete a task."""
        self.db.table("tasks").delete().eq("id", task_id).eq("user_id", user_id).execute()
        return True

    # ──────────────────── Habits ────────────────────

    async def list_habits(self, user_id: str) -> list[dict]:
        """List active habits for the user."""
        res = (
            self.db.table("habits")
            .select("*")
            .eq("user_id", user_id)
            .eq("is_active", True)
            .order("created_at")
            .execute()
        )
        return res.data or []

    async def create_habit(self, user_id: str, habit_data: dict) -> dict:
        """Create a new habit tracker."""
        data = {**habit_data, "user_id": user_id}
        res = self.db.table("habits").insert(data).execute()
        return res.data[0] if res.data else {}

    async def log_habit(
        self,
        user_id: str,
        habit_id: str,
        logged_date: date,
        count: int = 1,
        notes: str | None = None,
    ) -> dict:
        """Log a habit check-in for a specific date and update streaks.

        If a check-in is logged for today or yesterday, we recalculate streaks.
        """
        # Save check-in log
        log_data = {
            "habit_id": habit_id,
            "user_id": user_id,
            "logged_date": logged_date.isoformat(),
            "count": count,
            "notes": notes,
        }

        # Upsert log (since we have a unique constraint on habit_id & logged_date)
        res = (
            self.db.table("habit_logs")
            .upsert(log_data, on_conflict="habit_id,logged_date")
            .execute()
        )

        # Recalculate streak
        await self._recalculate_streak(user_id, habit_id)

        return res.data[0] if res.data else {}

    async def delete_habit(self, user_id: str, habit_id: str) -> bool:
        """Soft delete habit tracker."""
        self.db.table("habits").update({"is_active": False}).eq("id", habit_id).eq(
            "user_id", user_id
        ).execute()
        return True

    async def _recalculate_streak(self, user_id: str, habit_id: str) -> None:
        """Recalculate streak numbers by traversing past habit check-ins."""
        # Get all check-in dates for this habit sorted descending
        logs = (
            self.db.table("habit_logs")
            .select("logged_date")
            .eq("habit_id", habit_id)
            .order("logged_date", desc=True)
            .execute()
        )

        if not logs.data:
            return

        dates = [datetime.strptime(l["logged_date"], "%Y-%m-%d").date() for l in logs.data]

        current_streak = 0
        longest_streak = 0
        temp_streak = 0

        today = date.today()
        # Find if user completed habit today or yesterday to continue current streak
        has_completed_recently = dates[0] == today or dates[0] == today - date.resolution

        # Calculate current streak
        if has_completed_recently:
            current_date = dates[0]
            current_streak = 1
            for d in dates[1:]:
                if (current_date - d).days == 1:
                    current_streak += 1
                    current_date = d
                elif (current_date - d).days == 0:
                    continue  # Ignore duplicate logs on same day
                else:
                    break  # Gap found, streak ends

        # Calculate longest streak
        if dates:
            temp_streak = 1
            longest_streak = 1
            current_date = dates[0]
            for d in dates[1:]:
                diff = (current_date - d).days
                if diff == 1:
                    temp_streak += 1
                    current_date = d
                elif diff == 0:
                    continue
                else:
                    longest_streak = max(longest_streak, temp_streak)
                    temp_streak = 1
                    current_date = d
            longest_streak = max(longest_streak, temp_streak)

        # Update habit table
        self.db.table("habits").update(
            {"current_streak": current_streak, "longest_streak": longest_streak}
        ).eq("id", habit_id).eq("user_id", user_id).execute()


def get_planner_service() -> PlannerService:
    """Get planner service instance."""
    return PlannerService()
