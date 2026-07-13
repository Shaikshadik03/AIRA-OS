"""Utility helper functions."""

import uuid
from datetime import datetime, timezone


def generate_uuid() -> str:
    """Generate a new UUID4 string."""
    return str(uuid.uuid4())


def get_current_timestamp() -> str:
    """Get current UTC timestamp as ISO 8601 string."""
    return datetime.now(timezone.utc).isoformat()


def sanitize_input(text: str) -> str:
    """Strip and sanitize user input text."""
    return text.strip() if text else ""
