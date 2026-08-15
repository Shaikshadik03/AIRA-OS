"""AIRA OS Backend - FastAPI Application Entry Point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.config.settings import get_settings
from app.api.v1.router import router as v1_router

logger = logging.getLogger("aira")


from app.core.scheduler import start_scheduler, stop_scheduler, scheduler
from app.jobs.daily_brief import generate_daily_brief
from app.jobs.night_brief import generate_night_brief

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    logger.info("🧠 AIRA OS Backend starting up...")
    settings = get_settings()
    logger.info(f"   Environment: {settings.environment}")
    logger.info(f"   API prefix: {settings.api_v1_prefix}")
    
    # Start background scheduler
    start_scheduler()
    
    # Schedule morning briefing job (7:00 AM)
    if not scheduler.get_job('daily_brief_job'):
        scheduler.add_job(
            generate_daily_brief,
            'cron',
            hour=7,
            minute=0,
            id='daily_brief_job',
            replace_existing=True
        )
    
    # Schedule night briefing job (10:00 PM / 22:00)
    if not scheduler.get_job('night_brief_job'):
        scheduler.add_job(
            generate_night_brief,
            'cron',
            hour=22,
            minute=0,
            id='night_brief_job',
            replace_existing=True
        )
    
    logger.info("✅ AIRA OS Backend is ready!")
    yield
    logger.info("👋 AIRA OS Backend shutting down...")
    stop_scheduler()



def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    settings = get_settings()

    app = FastAPI(
        title="AIRA OS API",
        description="Backend API for AIRA — Your Personal AI Operating System",
        version="1.0.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
    )

    # CORS
    raw_cors = settings.cors_origins
    if isinstance(raw_cors, str):
        import json
        try:
            cors_list = json.loads(raw_cors)
        except Exception:
            cors_list = [c.strip() for c in raw_cors.split(",")] if "," in raw_cors else [raw_cors]
    else:
        cors_list = raw_cors or ["*"]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


    # Include API routes
    app.include_router(v1_router, prefix=settings.api_v1_prefix)

    @app.get("/", include_in_schema=False)
    async def root():
        """Redirect root to API documentation."""
        return RedirectResponse(url="/docs")

    return app


# Create the application instance
app = create_app()
