"""Chat service - business logic for conversations and AI responses."""

import asyncio
import logging
from app.config.database import get_supabase_admin_client
from app.core.ai_engine import get_ai_engine
from app.core.memory_engine import get_memory_engine

logger = logging.getLogger("aira.chat")


class ChatService:
    """Handles conversation CRUD and AI response generation."""

    def __init__(self) -> None:
        self.db = get_supabase_admin_client()
        self.ai = get_ai_engine()
        self.memory = get_memory_engine()

    async def create_conversation(self, user_id: str, title: str | None = None) -> dict:
        """Create a new conversation."""
        result = (
            self.db.table("conversations")
            .insert({"user_id": user_id, "title": title or "New Chat"})
            .execute()
        )
        return result.data[0] if result.data else {}

    async def list_conversations(self, user_id: str, limit: int = 20) -> list[dict]:
        """List user's conversations ordered by most recent."""
        result = (
            self.db.table("conversations")
            .select("*")
            .eq("user_id", user_id)
            .order("updated_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data or []

    async def get_conversation(self, user_id: str, conversation_id: str) -> dict:
        """Get a conversation with its messages."""
        conv_result = (
            self.db.table("conversations")
            .select("*")
            .eq("id", conversation_id)
            .eq("user_id", user_id)
            .single()
            .execute()
        )
        conversation = conv_result.data

        msg_result = (
            self.db.table("messages")
            .select("*")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=False)
            .execute()
        )
        conversation["messages"] = msg_result.data or []
        return conversation

    async def send_message(self, user_id: str, conversation_id: str, content: str) -> dict:
        """Send a user message and generate an AI response with memory context.

        1. Save the user's message
        2. Fetch relevant memories for context
        3. Fetch recent conversation history
        4. Generate AI response via Groq (with memories injected)
        5. Save the assistant's response
        6. Trigger async memory extraction
        7. Return both messages
        """
        # Save user message
        user_msg = (
            self.db.table("messages")
            .insert({
                "conversation_id": conversation_id,
                "user_id": user_id,
                "role": "user",
                "content": content,
            })
            .execute()
        )

        # Fetch relevant memories
        memories = await self.memory.get_relevant_context(user_id, content)

        # Fetch recent messages for context (last 20)
        history = (
            self.db.table("messages")
            .select("role, content")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=False)
            .limit(20)
            .execute()
        )

        messages = [{"role": m["role"], "content": m["content"]} for m in (history.data or [])]

        # Generate AI response with memory context
        ai_response = await self.ai.generate_response(messages, memories=memories)

        # Save assistant message
        assistant_msg = (
            self.db.table("messages")
            .insert({
                "conversation_id": conversation_id,
                "user_id": user_id,
                "role": "assistant",
                "content": ai_response,
            })
            .execute()
        )

        # Update conversation title if it's the first message
        conv = (
            self.db.table("conversations")
            .select("title")
            .eq("id", conversation_id)
            .single()
            .execute()
        )
        if conv.data and conv.data.get("title") == "New Chat":
            # Auto-generate title from first message
            short_title = content[:50].strip()
            if len(content) > 50:
                short_title += "..."
            self.db.table("conversations").update(
                {"title": short_title, "updated_at": "now()"}
            ).eq("id", conversation_id).execute()
        else:
            self.db.table("conversations").update(
                {"updated_at": "now()"}
            ).eq("id", conversation_id).execute()

        # Trigger async memory extraction (non-blocking)
        asyncio.create_task(
            self._extract_memories_background(user_id, messages, conversation_id)
        )

        return {
            "user_message": user_msg.data[0] if user_msg.data else {},
            "assistant_message": assistant_msg.data[0] if assistant_msg.data else {},
        }

    async def get_stream_response(self, user_id: str, conversation_id: str, content: str):
        """Stream an AI response token by token.

        Saves the user message, generates streaming response, saves the
        complete assistant response afterward.

        Yields:
            String tokens as they arrive.
        """
        # Save user message
        self.db.table("messages").insert({
            "conversation_id": conversation_id,
            "user_id": user_id,
            "role": "user",
            "content": content,
        }).execute()

        # Fetch memories and history
        memories = await self.memory.get_relevant_context(user_id, content)

        history = (
            self.db.table("messages")
            .select("role, content")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=False)
            .limit(20)
            .execute()
        )

        messages = [{"role": m["role"], "content": m["content"]} for m in (history.data or [])]

        # Stream the response
        full_response = ""
        async for token in self.ai.generate_stream(messages, memories=memories):
            full_response += token
            yield token

        # Save complete assistant message
        self.db.table("messages").insert({
            "conversation_id": conversation_id,
            "user_id": user_id,
            "role": "assistant",
            "content": full_response,
        }).execute()

        # Update conversation
        self.db.table("conversations").update(
            {"updated_at": "now()"}
        ).eq("id", conversation_id).execute()

        # Extract memories in background
        messages.append({"role": "assistant", "content": full_response})
        asyncio.create_task(
            self._extract_memories_background(user_id, messages, conversation_id)
        )

    async def delete_conversation(self, user_id: str, conversation_id: str) -> bool:
        """Delete a conversation and its messages."""
        self.db.table("conversations").delete().eq(
            "id", conversation_id
        ).eq("user_id", user_id).execute()
        return True

    async def _extract_memories_background(
        self,
        user_id: str,
        messages: list[dict],
        conversation_id: str,
    ) -> None:
        """Background task to extract and store memories."""
        try:
            stored = await self.memory.extract_and_store(
                user_id, messages, conversation_id
            )
            if stored:
                logger.info(
                    f"Extracted {len(stored)} memories from conversation {conversation_id}"
                )
        except Exception as e:
            logger.error(f"Background memory extraction failed: {e}")


def get_chat_service() -> ChatService:
    """Get chat service instance."""
    return ChatService()
