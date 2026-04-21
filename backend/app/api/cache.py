import time
from typing import Any

_store: dict[str, tuple[Any, float]] = {}


def cache_get(key: str) -> Any | None:
    entry = _store.get(key)
    if entry is None:
        return None
    value, expires_at = entry
    if time.monotonic() > expires_at:
        del _store[key]
        return None
    return value


def cache_set(key: str, value: Any, ttl_seconds: int) -> None:
    _store[key] = (value, time.monotonic() + ttl_seconds)


def cache_delete_prefix(prefix: str) -> None:
    keys = [k for k in _store if k.startswith(prefix)]
    for k in keys:
        del _store[k]
