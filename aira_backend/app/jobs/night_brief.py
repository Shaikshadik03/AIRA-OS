"""Night brief generation job — AIRA OS.

Runs at 10:00 PM IST (16:30 UTC) via APScheduler.
Recaps major AI/tech events of the day, urgent deadlines (3 days),
generates 1 interview technical question with answer for 1st-year CSE,
and saves to 'briefings' table in Supabase.
"""

import logging
from datetime import datetime, timezone
from app.config.database import get_supabase_admin_client
from app.services.agent_service import AgentService
from app.core.ai_engine import get_ai_engine
from app.jobs.daily_brief import AIRA_PROFILE

logger = logging.getLogger("aira.jobs.night_brief")


async def _search(agent: AgentService, query: str) -> str:
    """Run a search and return summary."""
    try:
        return await agent.search_web(query)
    except Exception as e:
        logger.warning(f"Search failed for '{query}': {e}")
        return ""


async def generate_night_brief():
    """Generate the 10 PM night recap brief."""
    logger.info("🌙 Starting night brief generation...")
    db = get_supabase_admin_client()
    ai = get_ai_engine()
    agent = AgentService()
    p = AIRA_PROFILE
    today_str = datetime.now().strftime("%A, %B %d, %Y")

    # 1. Web searches for today's recap & urgent deadlines
    day_recap = await _search(agent, f"major AI tech news announcements today {today_str}")
    urgent_deadlines = await _search(agent, "hackathon internship deadline closing soon India 2025 engineering")

    prompt = f"""
You are AIRA — personal AI assistant for {p['name']} ({p['year']}, {p['college']}, India).
It is 10:00 PM on {today_str}.

Research data:
TODAY'S AI/TECH RECAP:
{day_recap[:800]}

UPCOMING / URGENT DEADLINES:
{urgent_deadlines[:600]}

Instructions:
1. Summarize the biggest 2-3 AI/tech breakthroughs that happened today.
2. Provide ONE concise technical interview question suitable for a 1st year CSE student (Python/DSA/OS concepts) with a crystal clear answer for rapid doubt clarification.
3. List any urgent hackathon/internship deadlines closing in the next 3 days.
4. Provide a strong, inspiring 1-line closing thought.

Format output cleanly with emojis (plain text, no markdown codeblocks):

🌙 Good Evening, {p['name']}!

📡 TODAY IN AI & TECH
[2-3 highlights from today]

🧠 TONIGHT'S TECH QUESTION
Q: [Interview Question]
A: [Clear 2-3 sentence answer]

⏰ URGENT DEADLINES (Next 3 Days)
[Urgent deadlines or 'No urgent deadlines in the next 72 hours.']

🌟 END WELL
[One original, memorable closing quote]
"""

    try:
        brief_msg = await ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt="You are AIRA, a sharp and motivating AI operating system."
        )
        brief = brief_msg.content if hasattr(brief_msg, "content") else str(brief_msg)

        db.table("briefings").insert({
            "mode": "night",
            "content": brief,
            "created_at": datetime.now(timezone.utc).isoformat()
        }).execute()

        logger.info("✅ Night brief saved to Supabase.")

    except Exception as e:
        logger.error(f"Night brief generation failed: {e}")

