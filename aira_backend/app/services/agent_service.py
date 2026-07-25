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
        """Search the web using Tavily API and compile a summary using Groq."""
        import os
        from tavily import AsyncTavilyClient
        
        try:
            logger.info(f"Agent searching web via Tavily for: {query}")
            api_key = os.getenv("TAVILY_API_KEY")
            
            if not api_key:
                logger.warning("No TAVILY_API_KEY found, falling back to offline search.")
                return await self._generate_offline_search_summary(query)
                
            client = AsyncTavilyClient(api_key=api_key)
            
            # Using 'advanced' search depth for high-quality technical context
            response = await client.search(
                query=query, 
                search_depth="advanced", 
                max_results=5,
                include_answer=True
            )
            
            # If Tavily provided a direct AI answer, use it, else synthesize snippets
            if response.get("answer"):
                return response["answer"]
                
            results = response.get("results", [])
            if not results:
                logger.warning("No results found via Tavily.")
                return await self._generate_offline_search_summary(query)

            search_context = "\n".join(f"- {res.get('title')}: {res.get('content')}" for res in results)
            
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
