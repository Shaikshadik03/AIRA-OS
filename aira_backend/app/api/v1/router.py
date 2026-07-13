"""Aggregated API v1 router."""

from fastapi import APIRouter
from app.api.v1 import health, auth, chat, memory, planner, finance

router = APIRouter()

router.include_router(health.router)
router.include_router(auth.router)
router.include_router(chat.router)
router.include_router(memory.router)
router.include_router(planner.router)
router.include_router(finance.router)
