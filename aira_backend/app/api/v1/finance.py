"""Finance routes for transactions, categories, and budgets."""

from fastapi import APIRouter, Depends, HTTPException, status
from app.core.middleware import get_current_user
from app.models.finance import (
    TransactionCreate,
    TransactionResponse,
    BudgetCreate,
    BudgetResponse,
    FinanceCategoryResponse,
)
from app.services.finance_service import get_finance_service

router = APIRouter(prefix="/finance", tags=["Finance"])


# ──────────────────── Categories ────────────────────

@router.get("/categories", response_model=list[FinanceCategoryResponse])
async def list_categories(
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Get transactions and category tags."""
    service = get_finance_service()
    return await service.list_categories(user_id)


# ──────────────────── Transactions ────────────────────

@router.get("/transactions", response_model=list[TransactionResponse])
async def list_transactions(
    limit: int = 50,
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Get user transactions."""
    service = get_finance_service()
    return await service.list_transactions(user_id, limit)


@router.post("/transactions", response_model=TransactionResponse)
async def create_transaction(
    body: TransactionCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Create a new transaction."""
    service = get_finance_service()
    return await service.create_transaction(user_id, body.model_dump())


@router.delete("/transactions/{transaction_id}")
async def delete_transaction(
    transaction_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delete a transaction."""
    service = get_finance_service()
    await service.delete_transaction(user_id, transaction_id)
    return {"success": True, "message": "Transaction deleted"}


# ──────────────────── Budgets ────────────────────

@router.get("/budgets", response_model=list[BudgetResponse])
async def list_budgets(
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Get active budget limits and calculated spent category sums."""
    service = get_finance_service()
    return await service.list_budgets(user_id)


@router.post("/budgets", response_model=BudgetResponse)
async def create_budget(
    body: BudgetCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Create a category budget limit."""
    service = get_finance_service()
    return await service.create_budget(user_id, body.model_dump())
