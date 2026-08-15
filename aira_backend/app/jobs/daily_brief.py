"""Daily brief generation job — AIRA OS (Upgraded).

Runs at 7:00 AM IST (01:30 UTC) via APScheduler.
Uses Tavily for real web search, GoogleService for Gmail scan,
and Groq AI for personalized briefing generation.
Saves result to 'briefings' table in Supabase.
"""

import logging
from datetime import datetime, timezone
from app.config.database import get_supabase_admin_client
from app.services.google_service import GoogleService
from app.services.agent_service import AgentService
from app.core.ai_engine import get_ai_engine

logger = logging.getLogger("aira.jobs.daily_brief")

# Your personal profile — used to personalize every search and prompt
AIRA_PROFILE = {
    "name": "Arsha",
    "year": "First-year CSE student",
    "college": "Your College",
    "location": "India",
    "skills": ["Python", "Flutter", "AI/ML basics", "FastAPI"],
    "building": ["AIRA OS"],
    "goals": ["Top internships", "IIT hackathons", "Scholarships"],
    "interests": ["AI tools", "Systems", "Competitive programming"],
}


async def _search(agent: AgentService, query: str) -> str:
    """Run a Tavily search and return the summary."""
    try:
        return await agent.search_web(query)
    except Exception as e:
        logger.warning(f"Search failed for '{query}': {e}")
        return ""


async def generate_daily_brief():
    """Generate the morning briefing for the AIRA user."""
    logger.info("🌅 Starting morning brief generation...")
    db = get_supabase_admin_client()
    ai = get_ai_engine()
    agent = AgentService()
    p = AIRA_PROFILE
    today_str = datetime.now().strftime("%A, %B %d, %Y")

    # ── 1. Real web searches ──────────────────────────────────────────
    skills_str = ", ".join(p["skills"])

    ai_news      = await _search(agent, "latest AI tools released this week 2025 India tech")
    hackathons   = await _search(agent, f"hackathons India 2025 open registration IIT college beginner {today_str[:10]}")
    internships  = await _search(agent, f"internship first year CSE student India 2025 {skills_str} remote")
    scholarships = await _search(agent, "scholarships engineering students India 2025 open application deadline")
    skill_tip    = await _search(agent, f"most in-demand programming skill to learn 2025 {' '.join(p['interests'])}")

    # ── 2. Gmail inbox scan ───────────────────────────────────────────
    inbox_summary = "Inbox scan not available."
    try:
        users = db.table("user_profiles").select("id").execute()
        if users.data:
            user_id = users.data[0]["id"]
            gs = GoogleService(user_id)
            if gs.is_connected():
                # Get today's emails — filter for urgent keywords
                events = gs.get_upcoming_events(max_results=3)
                if events:
                    lines = [f"- {e.get('summary','?')} at {e.get('start',{}).get('dateTime','?')}" for e in events]
                    inbox_summary = "📅 Today's Calendar:\n" + "\n".join(lines)
                else:
                    inbox_summary = "No urgent calendar events today."
    except Exception as e:
        logger.warning(f"Gmail/Calendar scan failed: {e}")

    # ── 3. Build AI prompt ────────────────────────────────────────────
    prompt = f"""
You are AIRA — a sharp, personal AI assistant for {p['name']}.
Today is {today_str}.

{p['name']}'s Profile:
- {p['year']} | {p['college']} | {p['location']}
- Skills: {skills_str}
- Building: {', '.join(p['building'])}
- Goals: {', '.join(p['goals'])}

Here is today's research data (from real web searches):

AI & TECH NEWS:
{ai_news[:800]}

HACKATHONS (India):
{hackathons[:600]}

INTERNSHIPS:
{internships[:600]}

SCHOLARSHIPS:
{scholarships[:500]}

SKILL OF THE WEEK:
{skill_tip[:400]}

INBOX / CALENDAR:
{inbox_summary}

Instructions:
- Filter ONLY what is relevant to a first-year CSE student in India aiming for top internships and IIT hackathons.
- Remove generic noise. Every line must add value.
- Write in this exact format using emojis (plain text, no markdown):

🌅 Good Morning, {p['name']}!

📰 AI & TECH NEWS
[2-3 most relevant items with links if available]

🏆 OPEN HACKATHONS
[2-3 with deadlines]

💼 INTERNSHIPS FOR YOU
[2-3 relevant ones]

🎓 SCHOLARSHIPS
[1-2 open ones]

📚 SKILL OF THE WEEK
[One skill + one-line reason]

📬 INBOX ALERTS
[Calendar/email summary or "No urgent alerts today"]

✨ START STRONG
[One original motivational line — not cliché]
"""

    try:
        brief_msg = await ai.generate_response(
            messages=[{"role": "user", "content": prompt}],
            system_prompt="You are AIRA, a sharp personal AI. Be concise, direct, and genuinely useful."
        )
        brief = brief_msg.content if hasattr(brief_msg, "content") else str(brief_msg)

        # ── 4. Save to Supabase briefings table ───────────────────────
        db.table("briefings").insert({
            "mode": "morning",
            "content": brief,
            "created_at": datetime.now(timezone.utc).isoformat()
        }).execute()

        logger.info("✅ Morning brief saved to Supabase.")

    except Exception as e:
        logger.error(f"Morning brief generation failed: {e}")

