"""Background Agent - Autonomous delegation loops."""

import logging
import asyncio
from typing import Optional
from app.core.ai_engine import get_ai_engine
from app.services.agent_service import AgentService
from app.services.google_service import GoogleService
from app.config.database import get_supabase_admin_client

logger = logging.getLogger("aira.background_agent")

async def run_delegation_loop(user_id: str, task_id: str, goal: str):
    """Run an autonomous loop to accomplish a complex goal.
    
    This agent will:
    1. Iteratively search the web using Tavily.
    2. Compile a markdown report.
    3. Email the report to the user.
    4. Update the delegation task status in the database.
    """
    logger.info(f"Starting autonomous delegation for user {user_id}, goal: {goal}")
    
    ai = get_ai_engine()
    agent_svc = AgentService()
    google_svc = GoogleService()
    db = get_supabase_admin_client()
    
    try:
        # Step 1: Initial planning & First Search
        plan_prompt = f"You are an autonomous research agent. Your goal is: '{goal}'. What is the best search query to start with? Reply ONLY with the search query."
        
        search_query = await ai.generate_response(
            messages=[{"role": "user", "content": plan_prompt}],
            system_prompt="You are a precise agent. Output only the search query string."
        )
        search_query = search_query.strip().strip("'\"")
        
        # We will do up to 3 iterative searches
        compiled_research = ""
        
        for iteration in range(3):
            logger.info(f"Delegation loop iteration {iteration+1}, searching: {search_query}")
            search_result = await agent_svc.search_web(search_query)
            compiled_research += f"\n\nSearch: {search_query}\nResult:\n{search_result}"
            
            # Ask AI if we have enough info or need another search
            eval_prompt = (
                f"Goal: '{goal}'\n"
                f"Current Research:\n{compiled_research}\n\n"
                "Do we have enough information to fulfill the goal? "
                "If YES, reply with 'DONE'. "
                "If NO, reply ONLY with the next search query we should run to fill the gaps."
            )
            
            evaluation = await ai.generate_response(
                messages=[{"role": "user", "content": eval_prompt}],
                system_prompt="You are a precise agent evaluating research completeness."
            )
            
            # Use content since generate_response returns an object now
            evaluation_text = evaluation.content.strip().strip("'\"")
            if evaluation_text.upper() == "DONE" or evaluation_text.upper().startswith("DONE"):
                break
                
            search_query = evaluation_text
            # Add a small delay between searches
            await asyncio.sleep(2)
            
        # Step 2: Compile the final report
        report_prompt = (
            f"You are a professional analyst. Compile a comprehensive, well-structured "
            f"report fulfilling this goal: '{goal}'.\n\n"
            f"Use this research data:\n{compiled_research}\n\n"
            "Format in Markdown. Be thorough and actionable."
        )
        
        final_report_msg = await ai.generate_response(
            messages=[{"role": "user", "content": report_prompt}],
            system_prompt="You are an expert report writer."
        )
        final_report = final_report_msg.content
        
        # Step 3: Send the report via email if we have Gmail linked
        email_sent = False
        try:
            profile = db.table("user_profiles").select("email").eq("id", user_id).single().execute()
            user_email = profile.data.get("email") if profile.data else None
            
            if user_email:
                await google_svc.draft_email(
                    user_id=user_id,
                    to=user_email,
                    subject=f"AIRA Report: {goal[:50]}...",
                    body=final_report
                )
                email_sent = True
                logger.info("Delegation report drafted to Gmail successfully.")
        except Exception as e:
            logger.warning(f"Failed to draft email for delegation: {e}")
            
        # Step 4: Update the task status in the DB
        if task_id:
            db.table("tasks").update({
                "status": "completed",
                "notes": f"Delegation completed.\n\n{final_report}"
            }).eq("id", task_id).execute()
            
        logger.info(f"Autonomous delegation completed for goal: {goal}")
        
    except Exception as e:
        logger.error(f"Autonomous delegation failed: {e}")
        if task_id:
            db.table("tasks").update({
                "notes": f"Delegation failed: {str(e)}"
            }).eq("id", task_id).execute()
