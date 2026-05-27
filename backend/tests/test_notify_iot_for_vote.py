from datetime import datetime, timezone

import pytest

from app.core.entities.iot_device import IotDeviceLink
from app.core.entities.political_actor import FollowedActor
from app.core.use_cases.notify_iot_for_vote import VoteEventInput, notify_iot_for_vote, _vote_color

NOW = datetime(2026, 5, 27, 12, 0, tzinfo=timezone.utc)
TOKEN = "abc-token-123"
ANON = "user-anon-1"
ACTOR_ID = 42


class FakeFollowedRepo:
    def __init__(self, anon_ids: list[str]) -> None:
        self._anon_ids = anon_ids

    def get_followed(self, anonymous_id: str) -> FollowedActor | None:
        return None

    def set_followed(self, anonymous_id: str, actor_id: int) -> FollowedActor:
        raise NotImplementedError

    def delete_followed(self, anonymous_id: str) -> bool:
        return False

    def list_trending(self, limit: int = 10, min_followers: int = 2) -> list:
        return []

    def list_followed_political_actor_ids(self) -> list[int]:
        return []

    def list_anonymous_ids_by_political_actor(self, actor_id: int) -> list[str]:
        return self._anon_ids if actor_id == ACTOR_ID else []


class FakeLinkRepo:
    def __init__(self, link: IotDeviceLink | None) -> None:
        self._link = link

    def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None:
        return self._link if anonymous_id == ANON else None

    def get_by_token(self, device_token: str) -> IotDeviceLink | None:
        return None

    def get_conflicting_link(self, anonymous_id: str, device_token: str) -> IotDeviceLink | None:
        return None

    def set_link(self, anonymous_id: str, device_token: str, now: datetime) -> IotDeviceLink:
        raise NotImplementedError

    def delete_by_anonymous_id(self, anonymous_id: str) -> bool:
        return False


class FakePublisher:
    def __init__(self) -> None:
        self.messages: list[tuple[str, dict[str, str]]] = []

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        self.messages.append((topic, payload))


def _link() -> IotDeviceLink:
    return IotDeviceLink(
        device_token=TOKEN,
        anonymous_id=ANON,
        status="linked",
        created_at=NOW,
        updated_at=NOW,
        last_seen_at=None,
    )


def _vote(vote_type: str = "Sim") -> VoteEventInput:
    return VoteEventInput(
        political_actor_id=ACTOR_ID,
        deputy_name="Deputado Teste",
        vote_summary="PL 123/2024 aprovado",
        vote_type=vote_type,
        timestamp_utc="2026-05-27T12:00:00+00:00",
    )


def test_publishes_to_linked_device() -> None:
    publisher = FakePublisher()
    count = notify_iot_for_vote(
        _vote(),
        FakeFollowedRepo([ANON]),
        FakeLinkRepo(_link()),
        publisher,
    )

    assert count == 1
    topic, payload = publisher.messages[0]
    assert topic == f"farol/{TOKEN}"
    assert payload["type"] == "vote_update"
    assert payload["color"] == "green"
    assert payload["deputy_name"] == "Deputado Teste"
    assert payload["vote_summary"] == "PL 123/2024 aprovado"


def test_skips_user_without_linked_device() -> None:
    publisher = FakePublisher()
    count = notify_iot_for_vote(
        _vote(),
        FakeFollowedRepo([ANON]),
        FakeLinkRepo(None),
        publisher,
    )

    assert count == 0
    assert publisher.messages == []


def test_notifies_multiple_devices() -> None:
    anon2 = "user-anon-2"
    token2 = "token-xyz"
    link2 = IotDeviceLink(
        device_token=token2,
        anonymous_id=anon2,
        status="linked",
        created_at=NOW,
        updated_at=NOW,
        last_seen_at=None,
    )

    class MultiLinkRepo:
        def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None:
            if anonymous_id == ANON:
                return _link()
            if anonymous_id == anon2:
                return link2
            return None

        def get_by_token(self, *_): return None
        def get_conflicting_link(self, *_): return None
        def set_link(self, *_): raise NotImplementedError
        def delete_by_anonymous_id(self, *_): return False

    publisher = FakePublisher()
    count = notify_iot_for_vote(
        _vote(),
        FakeFollowedRepo([ANON, anon2]),
        MultiLinkRepo(),
        publisher,
    )

    assert count == 2
    topics = [m[0] for m in publisher.messages]
    assert f"farol/{TOKEN}" in topics
    assert f"farol/{token2}" in topics


@pytest.mark.parametrize("vote_type,expected_color", [
    ("Sim", "green"),
    ("sim", "green"),
    ("Não", "red"),
    ("nao", "red"),
    ("Abstenção", "yellow"),
    ("abstencao", "yellow"),
    ("Outro", "yellow"),
    ("", "yellow"),
])
def test_vote_color_mapping(vote_type: str, expected_color: str) -> None:
    assert _vote_color(vote_type) == expected_color
