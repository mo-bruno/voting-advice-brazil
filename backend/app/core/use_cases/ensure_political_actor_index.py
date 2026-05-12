from collections.abc import Mapping, Sequence
from datetime import datetime, timedelta, timezone
from typing import Protocol


class PoliticalActorIndexRepository(Protocol):
    def count(self) -> int: ...

    def newest_indexed_at(self) -> datetime | None: ...

    def upsert_index(self, rows: Sequence[Mapping[str, object]]) -> int: ...


class PoliticalActorIndexSource(Protocol):
    def list_current_deputies_for_index(
        self,
        now: datetime,
    ) -> list[dict[str, object]]: ...


def _compatible_datetime(value: datetime, reference: datetime) -> datetime:
    if value.tzinfo is None and reference.tzinfo is not None:
        return value.replace(tzinfo=timezone.utc)
    return value


def ensure_political_actor_index(
    repo: PoliticalActorIndexRepository,
    source: PoliticalActorIndexSource,
    now: datetime,
    max_age: timedelta,
) -> bool:
    newest = repo.newest_indexed_at()
    has_rows = repo.count() > 0
    if has_rows and newest is not None:
        newest = _compatible_datetime(newest, now)
        if newest + max_age > now:
            return False

    rows = source.list_current_deputies_for_index(now)
    repo.upsert_index(rows)
    return True
