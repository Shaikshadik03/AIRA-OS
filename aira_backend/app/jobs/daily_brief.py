"""Daily brief generation job."""

import logging
from datetime import datetime
from app.config.database import get_supabase_admin_client
from app.services.google_service import GoogleService
from app.core.ai_engine import get_ai_engine

logger = logging.getLogger("aira.jobs.daily_brief")

async def generate_daily_brief():
    """Generate a daily morning brief for all active users."""
    logger.info("Starting daily brief generation...")
    db = get_supabase_admin_client()
    ai = get_ai_engine()
    
    # In a real system, you'd iterate through users who opted in or have activity
    # For now, we'll fetch all users.
    users = db.table("user_profiles").select("id, display_name").execute()
    if not users.data:
        return
        
    today_str = datetime.now().strftime("%A, %B %d")
    
    for user in users.data:
        user_id = user["id"]
        name = user.get("display_name", "User")
        
        # Gather context for the brief
        context = []
        
        # 1. Fetch pending tasks
        tasks = db.table("tasks").select("*").eq("user_id", user_id).eq("status", "pending").execute()
        if tasks.data:
            context.append(f"Pending tasks ({len(tasks.data)}):")
            for t in tasks.data[:5]:
                context.append(f"- {t.get('title')} (Priority: {t.get('priority')})")
        
        # 2. Fetch today's calendar events if Google is connected
        gs = GoogleService(user_id)
        if gs.is_connected():
            events = gs.get_upcoming_events(max_results=5)
            if events:
                context.append(f"Upcoming Calendar Events ({len(events)}):")
                for e in events:
                    title = e.get('summary', 'Busy')
                    start = e.get('start', {}).get('dateTime', e.get('start', {}).get('date'))
                    context.append(f"- {title} at {start}")
                    
        # 3. Generate summary with AI
        prompt = (
            f"Generate a personalized morning briefing for {name} for {today_str}. "
            "Use the following context to highlight their day's priorities in a motivating, "
            "executive-assistant tone. Keep it concise (1-2 short paragraphs). "
            f"Context:\n{chr(10).join(context)}"
        )
        
        try:
            brief = await ai.generate_response(
                messages=[{"role": "user", "content": prompt}],
                system_prompt="You are an encouraging, proactive executive AI assistant."
            )
            
            # 4. Save to memories/dashboard as a system message
            db.table("conversations").insert({
                "user_id": user_id,
                "title": f"Morning Brief: {today_str}",
                "is_active": False
            }).execute()
            
            # Alternately, we can push to a dedicated notifications table or store as memory.
            # For simplicity, we'll store it as a 'brief' memory category so it shows up in insights.
            db.table("memories").insert({
                "user_id": user_id,
                "content": brief,
                "category": "system_brief",
                "importance": 5
            }).execute()
            
            logger.info(f"Generated daily brief for {user_id}")
            
        except Exception as e:
            logger.error(f"Failed to generate brief for {user_id}: {e}")

