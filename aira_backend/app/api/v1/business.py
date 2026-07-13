"""Business CRM and invoicing API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from app.core.middleware import get_current_user
from app.services.business_service import get_business_service

router = APIRouter(prefix="/business", tags=["Business CRM"])


class ClientCreate(BaseModel):
    name: str
    company: str | None = None
    email: EmailStr | None = None
    phone: str | None = None
    notes: str | None = None
    status: str = "lead"


class InvoiceItem(BaseModel):
    description: str
    qty: int = 1
    price: float


class InvoiceRequest(BaseModel):
    client_name: str
    client_company: str | None = None
    items: list[InvoiceItem]
    invoice_number: str
    tax_rate: float = 0.0


@router.get("/clients")
async def list_clients(
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """Get all clients in CRM directory."""
    service = get_business_service()
    return await service.list_clients(user_id)


@router.post("/clients")
async def create_client(
    body: ClientCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Create a new client contact."""
    service = get_business_service()
    return await service.create_client(user_id, body.model_dump())


@router.delete("/clients/{client_id}")
async def delete_client(
    client_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delete a client contact."""
    service = get_business_service()
    await service.delete_client(user_id, client_id)
    return {"success": True, "message": "Client deleted"}


@router.post("/invoices")
async def generate_invoice(
    body: InvoiceRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Compile print layouts for billing invoices."""
    if not body.items:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invoice must contain at least one item",
        )
    
    service = get_business_service()
    return await service.generate_invoice(user_id, body.model_dump())
