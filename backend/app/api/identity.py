from __future__ import annotations

import hashlib
from typing import Annotated
from uuid import UUID

from fastapi import Header, HTTPException

_RequiredAnonymousHeader = Annotated[str, Header(alias="X-Farol-Anonymous-Id")]
_OptionalAnonymousHeader = Annotated[str | None, Header(alias="X-Farol-Anonymous-Id")]


def _validated_uuid4(raw: str) -> str:
    try:
        parsed = UUID(raw)
    except ValueError:
        raise HTTPException(status_code=422, detail="Anonymous ID must be a UUID v4.") from None
    if parsed.version != 4:
        raise HTTPException(status_code=422, detail="Anonymous ID must be a UUID v4.")
    return str(parsed)


def require_anonymous_id(value: _RequiredAnonymousHeader) -> str:
    return _validated_uuid4(value)


def optional_anonymous_id(value: _OptionalAnonymousHeader = None) -> str | None:
    return None if value is None else _validated_uuid4(value)


def public_author_alias(anonymous_id: str) -> str:
    digest = hashlib.sha256(anonymous_id.encode("utf-8")).hexdigest()
    return f"u/{digest[:10]}"
