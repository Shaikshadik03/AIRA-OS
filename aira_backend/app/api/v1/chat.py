"""Chat and conversation endpoints with streaming support."""

import json
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from app.core.middleware import get_current_user
from app.models.conversation import (
    ConversationCreate,
    ConversationResponse,
    MessageCreate,
    ChatResponse,
)
from app.services.chat_service import get_chat_service

router = APIRouter(prefix="/chat", tags=["Chat"])


@router.post("/conversations", response_model=ConversationResponse)
async def create_conversation(
    body: ConversationCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Create a new conversation."""
    service = get_chat_service()
    conversation = await service.create_conversation(user_id, body.title)
    return conversation


@router.get("/conversations", response_model=list[ConversationResponse])
async def list_conversations(
    limit: int = 20,
    user_id: str = Depends(get_current_user),
) -> list[dict]:
    """List the user's conversations."""
    service = get_chat_service()
    return await service.list_conversations(user_id, limit)


@router.get("/conversations/{conversation_id}", response_model=ConversationResponse)
async def get_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Get a conversation with all its messages."""
    service = get_chat_service()
    try:
        return await service.get_conversation(user_id, conversation_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found",
        )


@router.post("/conversations/{conversation_id}/messages", response_model=ChatResponse)
async def send_message(
    conversation_id: str,
    body: MessageCreate,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Send a message and get an AI response."""
    if not body.content.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message content cannot be empty",
        )

    service = get_chat_service()
    result = await service.send_message(user_id, conversation_id, body.content)
    return result


@router.post("/conversations/{conversation_id}/stream")
async def stream_message(
    conversation_id: str,
    body: MessageCreate,
    user_id: str = Depends(get_current_user),
):
    """Send a message and get a streaming AI response via SSE."""
    if not body.content.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message content cannot be empty",
        )

    service = get_chat_service()

    async def event_generator():
        async for token in service.get_stream_response(
            user_id, conversation_id, body.content
        ):
            yield f"data: {json.dumps({'token': token})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delete a conversation."""
    service = get_chat_service()
    await service.delete_conversation(user_id, conversation_id)
    return {"success": True, "message": "Conversation deleted"}
