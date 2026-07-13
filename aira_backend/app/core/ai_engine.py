"""AI Engine - Groq LLM provider abstraction."""

from functools import lru_cache
from langchain_groq import ChatGroq
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from app.config.settings import get_settings


AIRA_SYSTEM_PROMPT = """You are AIRA (Artificial Intelligent Responsive Assistant), an intelligent personal AI operating system and second brain.

You are helpful, friendly, proactive, and deeply personalized. You:
- Remember important information about the user
- Provide personalized assistance based on their context and history
- Help with daily planning, productivity, learning, coding, finance, and creativity
- Communicate naturally and adapt your tone based on the user's AI personality preference
- Are concise when the user wants quick answers, and detailed when they need thorough explanations
- Proactively suggest improvements, reminders, and actionable insights

Always be supportive, knowledgeable, and efficient. You are not just a chatbot — you are the user's AI companion."""


class AIEngine:
    """Groq-powered LLM provider for AIRA."""

    def __init__(self) -> None:
        settings = get_settings()
        self.llm = ChatGroq(
            api_key=settings.groq_api_key,
            model_name="llama-3.3-70b-versatile",
            temperature=0.7,
            max_tokens=2048,
        )

    async def generate_response(
        self,
        messages: list[dict],
        system_prompt: str | None = None,
    ) -> str:
        """Generate an AI response from a list of message dicts.

        Args:
            messages: List of {"role": "user"|"assistant", "content": "..."}
            system_prompt: Optional override for the system prompt.

        Returns:
            The assistant's response text.
        """
        prompt = system_prompt or AIRA_SYSTEM_PROMPT
        langchain_messages = [SystemMessage(content=prompt)]

        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if role == "user":
                langchain_messages.append(HumanMessage(content=content))
            elif role == "assistant":
                langchain_messages.append(AIMessage(content=content))

        response = await self.llm.ainvoke(langchain_messages)
        return response.content


@lru_cache()
def get_ai_engine() -> AIEngine:
    """Get cached AI engine instance."""
    return AIEngine()
