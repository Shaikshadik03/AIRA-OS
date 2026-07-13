"""Finance Pydantic models (Transactions, Budgets, Categories)."""

from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel, Field


# ──────────────────── Categories ────────────────────

class FinanceCategoryResponse(BaseModel):
    id: str
    user_id: str
    name: str
    icon: str | None = None
    color: str | None = None
    type: str  # income | expense
    is_default: bool


# ──────────────────── Transactions ────────────────────

class TransactionCreate(BaseModel):
    amount: Decimal
    type: str = Field(pattern="^(income|expense)$")
    title: str
    category_id: str | None = None
    notes: str | None = None
    transaction_date: date | None = None
    is_recurring: bool = False
    recurrence: dict | None = None


class TransactionResponse(BaseModel):
    id: str
    user_id: str
    category_id: str | None = None
    amount: Decimal
    type: str
    title: str
    notes: str | None = None
    transaction_date: date
    is_recurring: bool
    recurrence: dict | None = None
    created_at: datetime


# ──────────────────── Budgets ────────────────────

class BudgetCreate(BaseModel):
    category_id: str
    amount: Decimal
    period: str = Field(default="monthly", pattern="^(weekly|monthly|yearly)$")
    start_date: date
    end_date: date | None = None


class BudgetResponse(BaseModel):
    id: str
    user_id: str
    category_id: str
    amount: Decimal
    period: str
    start_date: date
    end_date: date | None = None
    created_at: datetime
    # Computed fields injected in service layer
    spent: Decimal | None = None
