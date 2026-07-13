"""Aggregated API v1 router."""

from fastapi import APIRouter
from app.api.v1 import health, auth, chat, memory, planner, finance, agents, study, coding, voice, creative, business

router = APIRouter()

router.include_router(health.router)
router.include_router(auth.router)
router.include_router(chat.router)
router.include_router(memory.router)
router.include_router(planner.router)
router.include_router(finance.router)
router.include_router(agents.router)
router.include_router(study.router)
router.include_router(coding.router)
router.include_router(voice.router)
router.include_router(creative.router)
router.include_router(business.router)
