from fastapi import HTTPException, Request


def require_politician_follow_enabled(request: Request) -> None:
    if not request.app.state.settings.politician_follow_enabled:
        raise HTTPException(
            status_code=404,
            detail="Funcionalidade ainda nao disponivel.",
        )
