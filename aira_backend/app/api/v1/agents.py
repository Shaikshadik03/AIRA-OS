"""Agent API endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from app.core.middleware import get_current_user
from app.services.agent_service import get_agent_service

router = APIRouter(prefix="/agents", tags=["Agents"])


class SearchRequest(BaseModel):
    query: str


class EmailDraftRequest(BaseModel):
    prompt: str


class EmailDraftResponse(BaseModel):
    subject: str
    body: str


@router.post("/web-search")
async def web_search(
    body: SearchRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Perform web search scraper query."""
    if not body.query.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Query cannot be empty",
        )
    service = get_agent_service()
    summary = await service.search_web(body.query)
    return {"query": body.query, "summary": summary}


@router.post("/email-draft", response_model=EmailDraftResponse)
async def email_draft(
    body: EmailDraftRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Generate an email draft."""
    if not body.prompt.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Prompt cannot be empty",
        )
    service = get_agent_service()
    return await service.draft_email(body.prompt)


class DelegationRequest(BaseModel):
    goal: str
    task_id: str | None = None

@router.post("/delegate")
async def delegate_task(
    body: DelegationRequest,
    user_id: str = Depends(get_current_user),
) -> dict:
    """Delegate a complex goal to the autonomous background agent."""
    from app.core.scheduler import scheduler
    from app.jobs.background_agent import run_delegation_loop
    
    if not body.goal.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Goal cannot be empty",
        )
        
    # Schedule the agent loop to run immediately in the background
    scheduler.add_job(
        run_delegation_loop,
        kwargs={"user_id": user_id, "task_id": body.task_id, "goal": body.goal},
        id=f"delegate_{user_id}_{body.task_id or 'adhoc'}",
        replace_existing=True
    )
    
    return {
        "success": True,
        "message": "Autonomous agent dispatched.",
        "goal": body.goal
    }
