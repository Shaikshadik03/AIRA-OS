"""Study Service - business logic for Note Maker and Quiz Generator."""

import logging
import json
from app.core.ai_engine import get_ai_engine

logger = logging.getLogger("aira.study")


class StudyService:
    """Manages academic study aids: notes and quiz generation."""

    def __init__(self) -> None:
        self.ai = get_ai_engine()

    async def generate_notes(self, topic: str) -> str:
        """Generate structured Markdown study notes on a topic."""
        logger.info(f"Generating notes for: {topic}")
        
        prompt = (
            f"Generate a comprehensive, premium study note on the topic: '{topic}'.\n\n"
            "Include these sections:\n"
            "1. 📚 Executive Summary (High-level overview)\n"
            "2. 🔑 Core Definitions & Terms (Bullet point explanations)\n"
            "3. 🧠 Deep Dive Concepts (Detailed explanations of core sub-topics)\n"
            "4. 📝 Practice Questions (3 self-test questions without answers for study checks)\n\n"
            "Format the entire output beautifully with clear Markdown headers, bold text, and bullet points."
        )

        notes = await self.ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt="You are an elite academic tutor. Write notes that are structured and easy to learn from."
        )
        return notes

    async def generate_quiz(self, topic: str) -> list[dict]:
        """Generate a multiple-choice quiz on a topic."""
        logger.info(f"Generating quiz for: {topic}")
        
        system_prompt = (
            "You are an academic test designer. Create a multiple-choice quiz with "
            "5 high-quality questions on the topic provided. Return ONLY a valid JSON array "
            "of objects in this exact format:\n"
            "[\n"
            "  {\n"
            '    "question": "...",\n'
            '    "options": ["A", "B", "C", "D"],\n'
            '    "correct_answer": "correct string option matching exactly one of the option strings",\n'
            '    "explanation": "concise explanation why it is correct"\n'
            "  }\n"
            "]\n"
            "Do not output markdown codeblocks, only raw JSON."
        )

        response = await self.ai.generate_response(
            messages=[{"role": "user", "content": topic}],
            system_prompt=system_prompt
        )

        try:
            content = response.strip()
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
            quiz = json.loads(content)
            if isinstance(quiz, list):
                return quiz
        except Exception as e:
            logger.error(f"Quiz parsing failed: {e}. Output was: {response[:200]}")
            
        # Return fallback quiz structure if JSON extraction fails
        return [
            {
                "question": f"What is the core focus of {topic}?",
                "options": ["Option A", "Option B", "Option C", "Option D"],
                "correct_answer": "Option A",
                "explanation": "This is a placeholder explanation since the generator failed."
            }
        ]


def get_study_service() -> StudyService:
    """Get study service instance."""
    return StudyService()
