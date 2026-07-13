"""Conversation and message Pydantic models."""

from datetime import datetime
from pydantic import BaseModel


class MessageCreate(BaseModel):
    """Request body for sending a message."""
    content: str


class MessageResponse(BaseModel):
    """Single message in a conversation."""
    id: str
    conversation_id: str
    role: str
    content: str
    metadata: dict | None = None
    created_at: datetime | None = None


class ConversationCreate(BaseModel):
    """Request body for creating a conversation."""
    title: str | None = None


class ConversationResponse(BaseModel):
    """Conversation with optional messages."""
    id: str
    user_id: str
    title: str | None = None
    summary: str | None = None
    is_pinned: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None
    messages: list[MessageResponse] | None = None


class ChatResponse(BaseModel):
    """Response from sending a message (includes both user and AI messages)."""
    user_message: MessageResponse
    assistant_message: MessageResponse
