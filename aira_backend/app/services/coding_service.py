"""Coding Service - business logic for AI Code Debugger and Explainer."""

import logging
from app.core.ai_engine import get_ai_engine

logger = logging.getLogger("aira.coding")


class CodingService:
    """Manages AI code helpers."""

    def __init__(self) -> None:
        self.ai = get_ai_engine()

    async def debug_code(self, code: str, language: str) -> str:
        """Inspect code for errors, explain details, and show corrections."""
        logger.info(f"Debugging code in: {language}")
        
        prompt = (
            f"Debug the following {language} code snippet:\n\n"
            f"```\n{code}\n```\n\n"
            "Analyze it and return your analysis in this structured format:\n"
            "1. 🐛 **Errors Found**: List of syntax, logic, or semantic mistakes.\n"
            "2. 💡 **Explanation**: Why these mistakes happen.\n"
            "3. 🛠️ **Fixed Code**: Provide the corrected code inside a fenced code block with appropriate language tag."
        )

        result = await self.ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt="You are a senior compiler engineer and programming assistant. Be concise and precise."
        )
        return result

    async def explain_code(self, code: str, language: str) -> str:
        """Provide code analysis line-by-line."""
        logger.info(f"Explaining code in: {language}")
        
        prompt = (
            f"Explain the following {language} code snippet:\n\n"
            f"```\n{code}\n```\n\n"
            "Provide a high-level summary of what the code does, followed by a step-by-step or line-by-line explanation."
        )

        result = await self.ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt="You are a helpful computer science instructor. Explain clearly for beginners."
        )
        return result


def get_coding_service() -> CodingService:
    """Get coding service instance."""
    return CodingService()
