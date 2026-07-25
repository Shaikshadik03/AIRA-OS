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

    async def _execute_tool(self, user_id: str, name: str, arguments_str: str) -> str:
        """Execute a tool requested by the AI."""
        import json
        from app.services.google_service import GoogleService
        from app.services.agent_service import AgentService
        from app.services.planner_service import PlannerService
        
        try:
            args = json.loads(arguments_str) if arguments_str else {}
        except json.JSONDecodeError:
            return "Error: Invalid JSON arguments."

        try:
            if name == "create_task":
                planner = PlannerService()
                task = await planner.create_task(user_id, {
                    "title": args.get("title"),
                    "description": args.get("description", ""),
                    "due_date": args.get("due_date")
                })
                return f"Task created successfully: {json.dumps(task)}"
            
            elif name == "draft_email":
                google_service = GoogleService()
                result = await google_service.draft_email(
                    user_id=user_id,
                    to=args.get("to"),
                    subject=args.get("subject"),
                    body=args.get("body")
                )
                return f"Email drafted. Link: {result.get('draft_url')}"

            elif name == "get_calendar_events":
                google_service = GoogleService()
                events = await google_service.get_upcoming_events(user_id, days=args.get("days", 7))
                return json.dumps(events)
                
            elif name == "search_web":
                agent = AgentService()
                result = await agent.search_web(args.get("query"))
                return result
            
            else:
                return f"Error: Tool {name} not found."
        except Exception as e:
            logger.error(f"Error executing tool {name}: {e}")
            return f"Error executing tool: {e}"

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
        from app.core.tools import AIRA_TOOLS
        
        while True:
            ai_msg = await self.ai.generate_response(messages, memories=memories, tools=AIRA_TOOLS)
            
            if ai_msg.tool_calls:
                messages.append({
                    "role": "assistant",
                    "content": ai_msg.content,
                    "tool_calls": [
                        {
                            "id": tc.id, 
                            "type": "function", 
                            "function": {"name": tc.function.name, "arguments": tc.function.arguments}
                        }
                        for tc in ai_msg.tool_calls
                    ]
                })
                
                for tc in ai_msg.tool_calls:
                    tool_result = await self._execute_tool(user_id, tc.function.name, tc.function.arguments)
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "name": tc.function.name,
                        "content": tool_result
                    })
            else:
                ai_response = ai_msg.content
                break

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

        # Stream the response with tool support
        from app.core.tools import AIRA_TOOLS
        
        overall_response = ""
        
        while True:
            full_response = ""
            tool_calls_to_execute = None
            
            async for chunk in self.ai.generate_stream(messages, memories=memories, tools=AIRA_TOOLS):
                if chunk["type"] == "content":
                    full_response += chunk["content"]
                    overall_response += chunk["content"]
                    yield chunk["content"]
                elif chunk["type"] == "tool_calls":
                    tool_calls_to_execute = chunk["tool_calls"]
            
            if tool_calls_to_execute:
                messages.append({
                    "role": "assistant",
                    "content": full_response,
                    "tool_calls": tool_calls_to_execute
                })
                
                for tc in tool_calls_to_execute:
                    yield f"\n\n*[Executing {tc['function']['name']}...]*\n\n"
                    overall_response += f"\n\n*[Executing {tc['function']['name']}...]*\n\n"
                    
                    tool_result = await self._execute_tool(user_id, tc["function"]["name"], tc["function"]["arguments"])
                    
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tc["id"],
                        "name": tc["function"]["name"],
                        "content": tool_result
                    })
            else:
                break

        # Save complete assistant message
        self.db.table("messages").insert({
            "conversation_id": conversation_id,
            "user_id": user_id,
            "role": "assistant",
            "content": overall_response,
        }).execute()

        # Update conversation
        self.db.table("conversations").update(
            {"updated_at": "now()"}
        ).eq("id", conversation_id).execute()

        # Extract memories in background
        messages.append({"role": "assistant", "content": overall_response})
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
