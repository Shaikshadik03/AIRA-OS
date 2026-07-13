"""Chat service - business logic for conversations and AI responses."""

from app.config.database import get_supabase_admin_client
from app.core.ai_engine import get_ai_engine


class ChatService:
    """Handles conversation CRUD and AI response generation."""

    def __init__(self) -> None:
        self.db = get_supabase_admin_client()
        self.ai = get_ai_engine()

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
        """Send a user message and generate an AI response.

        1. Save the user's message
        2. Fetch recent conversation history for context
        3. Generate AI response via Groq
        4. Save the assistant's response
        5. Return both messages
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

        # Generate AI response
        ai_response = await self.ai.generate_response(messages)

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

        # Update conversation timestamp
        self.db.table("conversations").update(
            {"updated_at": "now()"}
        ).eq("id", conversation_id).execute()

        return {
            "user_message": user_msg.data[0] if user_msg.data else {},
            "assistant_message": assistant_msg.data[0] if assistant_msg.data else {},
        }

    async def delete_conversation(self, user_id: str, conversation_id: str) -> bool:
        """Delete a conversation and its messages."""
        self.db.table("conversations").delete().eq(
            "id", conversation_id
        ).eq("user_id", user_id).execute()
        return True


def get_chat_service() -> ChatService:
    """Get chat service instance."""
    return ChatService()
