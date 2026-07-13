"""Business Service - Handles CRM clients directory and invoice layout compilation."""

import logging
from app.config.database import get_supabase_admin_client

logger = logging.getLogger("aira.business")


class BusinessService:
    """Manages CRM clients and PDF invoice formatting logs."""

    def __init__(self) -> None:
        self.db = get_supabase_admin_client()

    # ──────────────────── Clients ────────────────────

    async def list_clients(self, user_id: str) -> list[dict]:
        """List all CRM clients."""
        try:
            res = (
                self.db.table("business_clients")
                .select("*")
                .eq("user_id", user_id)
                .order("name")
                .execute()
            )
            return res.data or []
        except Exception as e:
            logger.error(f"Failed to list clients: {e}")
            return []

    async def create_client(self, user_id: str, client_data: dict) -> dict:
        """Add a client to directory."""
        data = {**client_data, "user_id": user_id}
        res = self.db.table("business_clients").insert(data).execute()
        return res.data[0] if res.data else {}

    async def delete_client(self, user_id: str, client_id: str) -> bool:
        """Delete a client from directory."""
        self.db.table("business_clients").delete().eq("id", client_id).eq(
            "user_id", user_id
        ).execute()
        return True

    # ──────────────────── Invoices ────────────────────

    async def generate_invoice(self, user_id: str, invoice_data: dict) -> dict:
        """Generate a formatted HTML/text invoice.

        Accepts items list, client details, taxes, and returns a formatted report.
        """
        logger.info("Compiling invoice layout...")
        
        client_name = invoice_data.get("client_name", "Valued Client")
        client_company = invoice_data.get("client_company", "N/A")
        items = invoice_data.get("items", [])
        invoice_number = invoice_data.get("invoice_number", "INV-1001")
        tax_rate = float(invoice_data.get("tax_rate", 0.0))

        subtotal = sum(float(i.get("price", 0.0)) * int(i.get("qty", 1)) for i in items)
        tax = subtotal * (tax_rate / 100.0)
        total = subtotal + tax

        # Create basic HTML layout for invoice rendering
        items_html = ""
        for i in items:
            desc = i.get("description", "Item")
            qty = int(i.get("qty", 1))
            price = float(i.get("price", 0.0))
            line_total = price * qty
            items_html += f"""
            <tr>
                <td style="padding: 8px; border-bottom: 1px solid #ddd;">{desc}</td>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: center;">{qty}</td>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹{price:,.2f}</td>
                <td style="padding: 8px; border-bottom: 1px solid #ddd; text-align: right;">₹{line_total:,.2f}</td>
            </tr>
            """

        html_content = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; color: #333; padding: 20px; }}
                .invoice-header {{ display: flex; justify-content: space-between; border-bottom: 2px solid #333; padding-bottom: 15px; margin-bottom: 20px; }}
                .invoice-details {{ margin-bottom: 20px; }}
                table {{ width: 100%; border-collapse: collapse; margin-bottom: 20px; }}
                th {{ background-color: #f2f2f2; padding: 8px; text-align: left; }}
                .totals {{ text-align: right; font-size: 16px; font-weight: bold; }}
            </style>
        </head>
        <body>
            <div class="invoice-header">
                <div>
                    <h2>AIRA BUSINESS INVOICE</h2>
                    <p>Invoice #: {invoice_number}</p>
                </div>
                <div style="text-align: right;">
                    <h3>Billed To:</h3>
                    <p>{client_name}<br/>{client_company}</p>
                </div>
            </div>
            <table>
                <thead>
                    <tr>
                        <th>Description</th>
                        <th style="text-align: center;">Qty</th>
                        <th style="text-align: right;">Unit Price</th>
                        <th style="text-align: right;">Total</th>
                    </tr>
                </thead>
                <tbody>
                    {items_html}
                </tbody>
            </table>
            <div class="totals">
                <p>Subtotal: ₹{subtotal:,.2f}</p>
                <p>Tax ({tax_rate}%): ₹{tax:,.2f}</p>
                <p style="font-size: 20px; color: #10B981;">Total: ₹{total:,.2f}</p>
            </div>
        </body>
        </html>
        """

        return {
            "invoice_number": invoice_number,
            "subtotal": subtotal,
            "tax": tax,
            "total": total,
            "html": html_content,
        }


def get_business_service() -> BusinessService:
    """Get business service instance."""
    return BusinessService()
