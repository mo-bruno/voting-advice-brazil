import time

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.schemas.health import HealthResponse
from app.core.config import settings
from app.infrastructure.database.session import get_db

router = APIRouter(tags=["Health"])

_START_TIME = time.monotonic()


@router.get("/health", response_model=HealthResponse, summary="Health check do serviço")
def health(db: Session = Depends(get_db)) -> HealthResponse:
    db_connected = False
    try:
        db.execute(text("SELECT 1"))
        db_connected = True
    except Exception:
        pass

    return HealthResponse(
        status="ok" if db_connected else "degraded",
        version=settings.app_version,
        db_connected=db_connected,
        uptime_seconds=round(time.monotonic() - _START_TIME, 2),
    )
