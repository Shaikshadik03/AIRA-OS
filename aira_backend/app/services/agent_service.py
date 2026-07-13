"""Agent Service - Async custom agent operations (Web Search, Email Drafts)."""

import logging
import httpx
from bs4 import BeautifulSoup
from app.core.ai_engine import get_ai_engine

logger = logging.getLogger("aira.agents")


class AgentService:
    """Manages autonomous agent actions like web searching and email drafting."""

    def __init__(self) -> None:
        self.ai = get_ai_engine()

    async def search_web(self, query: str) -> str:
        """Search the web using DuckDuckGo HTML parsing and compile a summary using Groq."""
        try:
            logger.info(f"Agent searching web for: {query}")
            headers = {
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/119.0.0.0 Safari/537.36"
                )
            }
            # DuckDuckGo HTML search endpoint
            url = f"https://html.duckduckgo.com/html/?q={query}"
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, headers=headers)
                
            if response.status_code != 200:
                logger.warning(f"DuckDuckGo search returned status: {response.status_code}")
                return await self._generate_offline_search_summary(query)

            # Parse results
            soup = BeautifulSoup(response.text, "html.parser")
            results = []
            for link in soup.find_all("a", class_="result__snippet")[:4]:
                results.append(link.get_text().strip())

            if not results:
                logger.warning("No search snippets parsed from page.")
                return await self._generate_offline_search_summary(query)

            search_context = "\n".join(f"- {res}" for res in results)
            
            # Synthesize search results using Groq LLM
            prompt = (
                "You are an AI research assistant. Summarize these web search results "
                f"for the query: '{query}' into a clear, concise, and structured summary. "
                "Cite findings appropriately based on the provided context.\n\n"
                f"Context:\n{search_context}"
            )
            
            summary = await self.ai.generate_response(
                messages=[{"role": "user", "content": prompt}],
                system_prompt="You are a precise research assistant. Be concise."
            )
            return summary

        except Exception as e:
            logger.error(f"Web search failed: {e}")
            return await self._generate_offline_search_summary(query)

    async def draft_email(self, prompt: str) -> dict:
        """Generate a complete email draft (Subject & Body)."""
        logger.info(f"Agent drafting email for: {prompt}")
        
        system_prompt = (
            "You are an executive assistant. Generate a highly professional email "
            "based on the user's prompt. Return ONLY a JSON object in this format:\n"
            '{"subject": "...", "body": "..."}\n'
            "Use markdown or standard spacing for the email body layout. Do not write anything else."
        )

        response = await self.ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt=system_prompt
        )

        # Parse JSON output
        import json
        try:
            content = response.strip()
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
            data = json.loads(content)
            return {"subject": data.get("subject", ""), "body": data.get("body", "")}
        except Exception:
            # Fallback if JSON format fails
            return {
                "subject": "Draft Email",
                "body": response
            }

    async def _generate_offline_search_summary(self, query: str) -> str:
        """Fallback helper if DuckDuckGo scrape fails (uses LLM knowledge base)."""
        prompt = (
            f"Write a summary about: '{query}' based on your knowledge base. "
            "Note at the beginning that this is offline compiled data."
        )
        return await self.ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt="You are a helpful research assistant."
        )


def get_agent_service() -> AgentService:
    """Get agent service instance."""
    return AgentService()
