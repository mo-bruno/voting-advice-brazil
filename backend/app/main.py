from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

from app.api.routers import candidates, health, quiz, themes
from app.core.config import settings

limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    if settings.app_env == "dev":
        from app.infrastructure.database.seed import seed
        from app.infrastructure.database.session import SessionLocal

        with SessionLocal() as db:
            seed(db)
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description=(
        "API do **Farol Político** — Voting Advice Application para as eleições brasileiras.\n\n"
        "Baseado na metodologia Wahl-O-Mat: algoritmo City Block Distance com pesos por tese."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

PREFIX = "/api/v1"
app.include_router(quiz.router, prefix=PREFIX)
app.include_router(candidates.router, prefix=PREFIX)
app.include_router(themes.router, prefix=PREFIX)
app.include_router(health.router)
