from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

from app.api.routers import (
    candidates,
    community,
    health,
    iot_devices,
    political_actors,
    quiz,
    themes,
)
from app.core.config import settings

limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    # Schema é gerenciado por Alembic via Cloud Build pré-deploy.
    # Lifespan apenas popula dados estáticos (idempotente: retorna cedo
    # se PartyModel.count() > 0 dentro de seed()). Em ambiente de teste,
    # o conftest configura o DB próprio e a seed é dispensável.
    if settings.app_env != "test":
        from app.infrastructure.database.seed import seed
        from app.infrastructure.database.session import SessionLocal
        from app.infrastructure.scheduler import start as start_scheduler

        with SessionLocal() as db:
            seed(db)

        start_scheduler()

    print(
        f"farol-politico-api startup: env={settings.app_env} "
        f"version={settings.app_version}"
    )
    yield

    if settings.app_env != "test":
        from app.infrastructure.scheduler import stop as stop_scheduler

        stop_scheduler()


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
app.add_exception_handler(
    RateLimitExceeded,
    _rate_limit_exceeded_handler,  # type: ignore[arg-type]
)
app.add_middleware(SlowAPIMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "X-Farol-Anonymous-Id"],
)

PREFIX = "/api/v1"
app.include_router(quiz.router, prefix=PREFIX)
app.include_router(candidates.router, prefix=PREFIX)
app.include_router(political_actors.router, prefix=PREFIX)
app.include_router(political_actors.me_router, prefix=PREFIX)
app.include_router(iot_devices.router, prefix=PREFIX)
app.include_router(iot_devices.me_router, prefix=PREFIX)
app.include_router(themes.router, prefix=PREFIX)
app.include_router(community.router, prefix=PREFIX)
app.include_router(health.router)

_data_path = Path(settings.data_dir)
if _data_path.is_dir():
    app.mount("/data", StaticFiles(directory=str(_data_path)), name="data")
