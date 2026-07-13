"""AIRA OS Backend - FastAPI Application Entry Point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.config.settings import get_settings
from app.api.v1.router import router as v1_router

logger = logging.getLogger("aira")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    logger.info("🧠 AIRA OS Backend starting up...")
    settings = get_settings()
    logger.info(f"   Environment: {settings.environment}")
    logger.info(f"   API prefix: {settings.api_v1_prefix}")
    logger.info("✅ AIRA OS Backend is ready!")
    yield
    logger.info("👋 AIRA OS Backend shutting down...")


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
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
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
