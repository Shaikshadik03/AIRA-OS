"""AI Engine - Groq LLM provider (direct SDK, no langchain)."""

from functools import lru_cache
from groq import AsyncGroq
from app.config.settings import get_settings


AIRA_SYSTEM_PROMPT = """You are AIRA (Artificial Intelligent Responsive Assistant), an intelligent personal AI operating system and second brain.

You are helpful, friendly, proactive, and deeply personalized. You:
- Remember important information about the user
- Provide personalized assistance based on their context and history
- Help with daily planning, productivity, learning, coding, finance, and creativity
- Communicate naturally and adapt your tone based on the user's AI personality preference
- Are concise when the user wants quick answers, and detailed when they need thorough explanations
- Proactively suggest improvements, reminders, and actionable insights
- Format responses with markdown when helpful (headers, bullet points, code blocks)

Always be supportive, knowledgeable, and efficient. You are not just a chatbot — you are the user's AI companion."""


MEMORY_EXTRACTION_PROMPT = """You are a memory extraction engine. Analyze the conversation and extract important facts about the user that should be remembered long-term.

Rules:
- Extract ONLY concrete facts, preferences, habits, or goals
- Each memory should be a single, clear sentence
- Do NOT extract greetings, small talk, or temporary information
- Categorize each memory as: preference, fact, habit, goal, or note
- Return as JSON array: [{"content": "...", "category": "..."}]
- If nothing worth remembering, return: []

Examples of good memories:
- {"content": "User's name is Arshan", "category": "fact"}
- {"content": "User prefers dark mode in all apps", "category": "preference"}
- {"content": "User is building an app called AIRA OS", "category": "fact"}
- {"content": "User wants to publish AIRA on Play Store", "category": "goal"}
- {"content": "User meditates daily", "category": "habit"}"""


class AIEngine:
    """Groq-powered LLM provider for AIRA using direct SDK."""

    def __init__(self) -> None:
        settings = get_settings()
        self.client = AsyncGroq(api_key=settings.groq_api_key)
        self.model = "llama-3.3-70b-versatile"

    async def generate_response(
        self,
        messages: list[dict],
        system_prompt: str | None = None,
        memories: list[str] | None = None,
        tools: list[dict] | None = None,
    ):
        """Generate an AI response.

        Args:
            messages: List of {"role": "user"|"assistant", "content": "..."}
            system_prompt: Optional system prompt override.
            memories: Optional list of relevant memory strings to inject.
            tools: Optional list of tool definitions.

        Returns:
            The assistant's response object.
        """
        prompt = system_prompt or AIRA_SYSTEM_PROMPT

        # Inject memories into context
        if memories:
            memory_block = "\n".join(f"- {m}" for m in memories)
            prompt += f"\n\n## What you remember about this user:\n{memory_block}"

        api_messages = [{"role": "system", "content": prompt}]

        for msg in messages:
            # Pass along tool_calls and tool responses if they exist in the history
            if msg.get("role") in ("user", "assistant", "tool"):
                # Copy the msg to avoid modifying the original list
                api_msg = {k: v for k, v in msg.items() if v is not None}
                api_messages.append(api_msg)

        # Detect if any message contains an image to switch to a vision model
        current_model = self.model
        has_vision = False
        for msg in api_messages:
            if isinstance(msg.get("content"), list):
                for part in msg["content"]:
                    if isinstance(part, dict) and part.get("type") == "image_url":
                        has_vision = True
                        break
        
        if has_vision:
            current_model = "llama-3.2-90b-vision-preview"

        kwargs = {
            "model": current_model,
            "messages": api_messages,
            "temperature": 0.7,
            "max_tokens": 2048,
        }
        if tools:
            kwargs["tools"] = tools
            kwargs["tool_choice"] = "auto"

        response = await self.client.chat.completions.create(**kwargs)

        return response.choices[0].message

    async def generate_stream(
        self,
        messages: list[dict],
        system_prompt: str | None = None,
        memories: list[str] | None = None,
        tools: list[dict] | None = None,
    ):
        """Generate a streaming AI response (async generator yielding tokens)."""
        prompt = system_prompt or AIRA_SYSTEM_PROMPT

        if memories:
            memory_block = "\n".join(f"- {m}" for m in memories)
            prompt += f"\n\n## What you remember about this user:\n{memory_block}"

        api_messages = [{"role": "system", "content": prompt}]

        for msg in messages:
            if msg.get("role") in ("user", "assistant", "tool"):
                api_msg = {k: v for k, v in msg.items() if v is not None}
                api_messages.append(api_msg)

        current_model = self.model
        has_vision = False
        for msg in api_messages:
            if isinstance(msg.get("content"), list):
                for part in msg["content"]:
                    if isinstance(part, dict) and part.get("type") == "image_url":
                        has_vision = True
                        break
        
        if has_vision:
            current_model = "llama-3.2-90b-vision-preview"

        kwargs = {
            "model": current_model,
            "messages": api_messages,
            "temperature": 0.7,
            "max_tokens": 2048,
            "stream": True,
        }
        
        # Tools in stream can be tricky with Groq, but they are supported as delta tool_calls
        if tools:
            kwargs["tools"] = tools
            kwargs["tool_choice"] = "auto"

        stream = await self.client.chat.completions.create(**kwargs)

        # In streaming tool mode, we need to assemble the tool call
        tool_calls = []

        async for chunk in stream:
            delta = chunk.choices[0].delta
            
            if delta.tool_calls:
                for tc_delta in delta.tool_calls:
                    # Append new tool calls
                    if tc_delta.index >= len(tool_calls):
                        tool_calls.append({
                            "id": tc_delta.id or "",
                            "type": "function",
                            "function": {"name": tc_delta.function.name or "", "arguments": tc_delta.function.arguments or ""}
                        })
                    else:
                        # Append arguments to existing tool call
                        if tc_delta.function.arguments:
                            tool_calls[tc_delta.index]["function"]["arguments"] += tc_delta.function.arguments
            
            if delta.content:
                yield {"type": "content", "content": delta.content}
                
        if tool_calls:
            yield {"type": "tool_calls", "tool_calls": tool_calls}

    async def extract_memories(self, messages: list[dict]) -> list[dict]:
        """Extract memorable facts from a conversation.

        Args:
            messages: Recent conversation messages.

        Returns:
            List of {"content": "...", "category": "..."} dicts.
        """
        # Build conversation text for analysis
        conversation_text = "\n".join(
            f"{m.get('role', 'user')}: {m.get('content', '')}"
            for m in messages[-10:]  # Last 10 messages only
        )

        api_messages = [
            {"role": "system", "content": MEMORY_EXTRACTION_PROMPT},
            {"role": "user", "content": f"Analyze this conversation:\n\n{conversation_text}"},
        ]

        response = await self.client.chat.completions.create(
            model="llama-3.1-8b-instant",  # Faster model for extraction
            messages=api_messages,
            temperature=0.1,
            max_tokens=1024,
        )

        # Parse JSON response
        import json
        try:
            content = response.choices[0].message.content.strip()
            # Handle markdown code blocks
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
            memories = json.loads(content)
            if isinstance(memories, list):
                return memories
        except (json.JSONDecodeError, IndexError, KeyError):
            pass

        return []


@lru_cache()
def get_ai_engine() -> AIEngine:
    """Get cached AI engine instance."""
    return AIEngine()
