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
    news,
    political_actors,
    quiz,
    themes,
)
from app.core.config import Settings, settings

limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])


PREFIX = "/api/v1"


def create_app(app_settings: Settings = settings) -> FastAPI:
    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncGenerator[None, None]:
        # Schema é gerenciado por Alembic via Cloud Build pré-deploy.
        # Lifespan apenas popula dados estáticos (idempotente: retorna cedo
        # se PartyModel.count() > 0 dentro de seed()). Em ambiente de teste,
        # o conftest configura o DB próprio e a seed é dispensável.
        if app_settings.app_env != "test":
            from app.infrastructure.database.seed import seed
            from app.infrastructure.database.session import SessionLocal

            with SessionLocal() as db:
                seed(db)

        print(
            f"farol-politico-api startup: env={app_settings.app_env} "
            f"version={app_settings.app_version}"
        )
        yield

    application = FastAPI(
        title=app_settings.app_name,
        version=app_settings.app_version,
        description=(
            "API do **Farol Político** — Voting Advice Application para as eleições brasileiras.\n\n"
            "Baseado na metodologia Wahl-O-Mat: algoritmo City Block Distance com pesos por tese."
        ),
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    application.state.limiter = limiter
    application.add_exception_handler(
        RateLimitExceeded,
        _rate_limit_exceeded_handler,  # type: ignore[arg-type]
    )
    application.add_middleware(SlowAPIMiddleware)

    application.add_middleware(
        CORSMiddleware,
        allow_origins=app_settings.allowed_origins_list,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Content-Type", "X-Farol-Anonymous-Id"],
    )

    application.include_router(quiz.router, prefix=PREFIX)
    application.include_router(candidates.router, prefix=PREFIX)
    application.include_router(political_actors.router, prefix=PREFIX)
    application.include_router(political_actors.me_router, prefix=PREFIX)
    if app_settings.iot_feature_enabled:
        application.include_router(iot_devices.router, prefix=PREFIX)
        application.include_router(iot_devices.me_router, prefix=PREFIX)
    application.include_router(themes.router, prefix=PREFIX)
    application.include_router(community.router, prefix=PREFIX)
    application.include_router(news.router, prefix=PREFIX)
    application.include_router(health.router)

    data_path = Path(app_settings.data_dir)
    if data_path.is_dir():
        application.mount("/data", StaticFiles(directory=str(data_path)), name="data")

    return application


app = create_app()
