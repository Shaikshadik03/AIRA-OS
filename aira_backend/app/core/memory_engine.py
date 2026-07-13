"""Memory Engine - Extract, store, and retrieve semantic memories."""

import logging
from app.config.database import get_supabase_admin_client
from app.core.ai_engine import get_ai_engine

logger = logging.getLogger("aira.memory")


class MemoryEngine:
    """Handles memory extraction, storage, and retrieval."""

    def __init__(self) -> None:
        self.db = get_supabase_admin_client()
        self.ai = get_ai_engine()

    async def extract_and_store(
        self,
        user_id: str,
        messages: list[dict],
        conversation_id: str | None = None,
    ) -> list[dict]:
        """Extract memories from conversation and store them.

        Args:
            user_id: The user's ID.
            messages: Recent conversation messages.
            conversation_id: Optional source conversation ID.

        Returns:
            List of stored memory records.
        """
        try:
            extracted = await self.ai.extract_memories(messages)

            if not extracted:
                return []

            stored = []
            for memory in extracted:
                content = memory.get("content", "").strip()
                category = memory.get("category", "general")

                if not content or len(content) < 5:
                    continue

                # Validate category
                valid_categories = {"general", "preference", "fact", "habit", "goal", "note"}
                if category not in valid_categories:
                    category = "general"

                # Check for duplicate memories
                existing = (
                    self.db.table("memories")
                    .select("id")
                    .eq("user_id", user_id)
                    .ilike("content", f"%{content[:50]}%")
                    .limit(1)
                    .execute()
                )

                if existing.data:
                    logger.info(f"Skipping duplicate memory: {content[:50]}...")
                    continue

                # Store the memory
                record = {
                    "user_id": user_id,
                    "content": content,
                    "category": category,
                    "importance_score": self._calculate_importance(category),
                    "source_conversation_id": conversation_id,
                }

                result = self.db.table("memories").insert(record).execute()
                if result.data:
                    stored.append(result.data[0])
                    logger.info(f"Stored memory [{category}]: {content[:60]}...")

            return stored

        except Exception as e:
            logger.error(f"Memory extraction failed: {e}")
            return []

    async def search_memories(
        self,
        user_id: str,
        query: str | None = None,
        category: str | None = None,
        limit: int = 10,
    ) -> list[dict]:
        """Search user's memories by text or category.

        Uses text-based search (trigram similarity) since we're not
        generating embeddings in this phase. Vector search comes later.
        """
        q = self.db.table("memories").select("*").eq("user_id", user_id)

        if category:
            q = q.eq("category", category)

        if query:
            q = q.ilike("content", f"%{query}%")

        q = q.order("importance_score", desc=True).order("created_at", desc=True)
        q = q.limit(limit)

        result = q.execute()
        return result.data or []

    async def get_relevant_context(self, user_id: str, message: str) -> list[str]:
        """Get memories relevant to the current message for context injection.

        Args:
            user_id: The user's ID.
            message: The user's current message.

        Returns:
            List of memory content strings.
        """
        # Get all user memories (simple approach for now)
        # In future: use vector embeddings for semantic search
        result = (
            self.db.table("memories")
            .select("content, category, importance_score")
            .eq("user_id", user_id)
            .order("importance_score", desc=True)
            .limit(15)
            .execute()
        )

        if not result.data:
            return []

        # Return formatted memory strings
        memories = []
        for m in result.data:
            category = m.get("category", "general")
            content = m.get("content", "")
            memories.append(f"[{category}] {content}")

        return memories

    async def list_memories(
        self,
        user_id: str,
        category: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[dict]:
        """List user's memories with pagination."""
        q = self.db.table("memories").select("*").eq("user_id", user_id)

        if category:
            q = q.eq("category", category)

        q = q.order("created_at", desc=True).range(offset, offset + limit - 1)

        result = q.execute()
        return result.data or []

    async def delete_memory(self, user_id: str, memory_id: str) -> bool:
        """Delete a specific memory."""
        self.db.table("memories").delete().eq("id", memory_id).eq(
            "user_id", user_id
        ).execute()
        return True

    def _calculate_importance(self, category: str) -> float:
        """Assign importance score based on memory category."""
        scores = {
            "fact": 0.8,
            "preference": 0.7,
            "goal": 0.9,
            "habit": 0.6,
            "note": 0.5,
            "general": 0.4,
        }
        return scores.get(category, 0.5)


def get_memory_engine() -> MemoryEngine:
    """Get memory engine instance."""
    return MemoryEngine()
