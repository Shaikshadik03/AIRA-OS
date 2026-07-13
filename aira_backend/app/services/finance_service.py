"""Finance Service - business logic for personal transactions and budgets."""

import logging
from datetime import date
from decimal import Decimal
from app.config.database import get_supabase_admin_client

logger = logging.getLogger("aira.finance")


class FinanceService:
    """Manages transactions, categories, and budget balance checking."""

    def __init__(self) -> None:
        self.db = get_supabase_admin_client()

    # ──────────────────── Categories ────────────────────

    async def list_categories(self, user_id: str) -> list[dict]:
        """List categories available to the user (defaults + user-defined)."""
        res = (
            self.db.table("finance_categories")
            .select("*")
            .or_(f"user_id.eq.{user_id},is_default.eq.true")
            .order("type")
            .order("name")
            .execute()
        )
        return res.data or []

    # ──────────────────── Transactions ────────────────────

    async def list_transactions(self, user_id: str, limit: int = 50) -> list[dict]:
        """List recent transactions."""
        res = (
            self.db.table("finance_transactions")
            .select("*, finance_categories(name, icon, color)")
            .eq("user_id", user_id)
            .order("transaction_date", desc=True)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return res.data or []

    async def create_transaction(self, user_id: str, tx_data: dict) -> dict:
        """Create a new transaction and format decimal fields."""
        data = {**tx_data, "user_id": user_id}
        # Format amount to float for JSON compatibility
        if isinstance(data.get("amount"), Decimal):
            data["amount"] = float(data["amount"])

        res = self.db.table("finance_transactions").insert(data).execute()
        return res.data[0] if res.data else {}

    async def delete_transaction(self, user_id: str, tx_id: str) -> bool:
        """Delete a transaction."""
        self.db.table("finance_transactions").delete().eq("id", tx_id).eq(
            "user_id", user_id
        ).execute()
        return True

    # ──────────────────── Budgets ────────────────────

    async def list_budgets(self, user_id: str) -> list[dict]:
        """List active budgets with calculated spent aggregates for the period."""
        # Fetch budgets
        budgets_res = (
            self.db.table("finance_budgets")
            .select("*, finance_categories(name, icon, color)")
            .eq("user_id", user_id)
            .execute()
        )
        budgets = budgets_res.data or []

        if not budgets:
            return []

        # Enumerate each budget and compute the current spent amount
        # based on transactions of the matching category within the budget dates.
        for budget in budgets:
            category_id = budget["category_id"]
            start_date = budget["start_date"]
            end_date = budget["end_date"]

            # Query spent transactions
            tx_q = (
                self.db.table("finance_transactions")
                .select("amount")
                .eq("user_id", user_id)
                .eq("category_id", category_id)
                .eq("type", "expense")
                .gte("transaction_date", start_date)
            )
            if end_date:
                tx_q = tx_q.lte("transaction_date", end_date)

            tx_res = tx_q.execute()
            spent = sum(float(t["amount"]) for t in (tx_res.data or []))
            budget["spent"] = spent

        return budgets

    async def create_budget(self, user_id: str, budget_data: dict) -> dict:
        """Create a budget limit for a category."""
        data = {**budget_data, "user_id": user_id}
        if isinstance(data.get("amount"), Decimal):
            data["amount"] = float(data["amount"])

        res = self.db.table("finance_budgets").insert(data).execute()
        return res.data[0] if res.data else {}


def get_finance_service() -> FinanceService:
    """Get finance service instance."""
    return FinanceService()
