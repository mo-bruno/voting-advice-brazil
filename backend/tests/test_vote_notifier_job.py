from datetime import datetime, timezone

from app.core.entities.iot_device import IotDeviceLink
from app.core.entities.political_actor import OfficialEvidence, PoliticalActor
from app.core.use_cases.interfaces import (
    FollowedActorRepository,
    IotDeviceLinkRepository,
    IotMqttPublisher,
    OfficialEvidenceRepository,
    PoliticalActorRepository,
)
from app.jobs.vote_notifier import run_once

NOW = datetime(2026, 5, 27, 12, 0, tzinfo=timezone.utc)
ACTOR_ID = 42
TOKEN = "dev-token-abc"
ANON = "user-anon-1"

ACTOR = PoliticalActor(
    id=ACTOR_ID,
    source="camara",
    source_id="12345",
    normalized_name="fulano da silva",
    display_name="Fulano da Silva",
    party="PT",
    state="SP",
    role="federal_deputy",
    status="active",
    photo_url=None,
    source_url=None,
    last_indexed_at=NOW,
)

LINK = IotDeviceLink(
    device_token=TOKEN,
    anonymous_id=ANON,
    status="linked",
    created_at=NOW,
    updated_at=NOW,
    last_seen_at=None,
)

NEW_VOTE = {
    "political_actor_id": ACTOR_ID,
    "source": "camara",
    "source_id": "vote:999:12345",
    "evidence_type": "vote",
    "title": "Votou Sim",
    "summary": "PL 123/2024 — aprovação do orçamento",
    "evidence_date": NOW,
    "source_url": None,
    "normalized_payload": {"vote": "Sim", "voting_id": "999"},
    "fetched_at": NOW,
    "expires_at": NOW,
}


class FakeFollowedRepo(FollowedActorRepository):
    def get_followed(self, anonymous_id): return None
    def set_followed(self, *_): raise NotImplementedError
    def delete_followed(self, *_): return False
    def list_trending(self, **_): return []

    def list_followed_political_actor_ids(self) -> list[int]:
        return [ACTOR_ID]

    def list_anonymous_ids_by_political_actor(self, actor_id: int) -> list[str]:
        return [ANON] if actor_id == ACTOR_ID else []


class FakeActorRepo(PoliticalActorRepository):
    def get_by_id(self, actor_id: int):
        return ACTOR if actor_id == ACTOR_ID else None

    def get_by_source(self, *_): return None
    def list(self, **_): return [], 0


class FakeLinkRepo(IotDeviceLinkRepository):
    def get_by_anonymous_id(self, anonymous_id: str):
        return LINK if anonymous_id == ANON else None

    def get_by_token(self, *_): return None
    def get_conflicting_link(self, *_): return None
    def set_link(self, *_): raise NotImplementedError
    def delete_by_anonymous_id(self, *_): return False


class FakeEvidenceRepo(OfficialEvidenceRepository):
    def __init__(self, existing=None) -> None:
        self._existing = existing or []
        self.replaced: list[dict] = []

    def list_by_actor(self, actor_id: int, now: datetime):
        return self._existing, False

    def replace_for_actor_type(self, actor_id: int, evidence_type: str, rows):
        self.replaced.extend(rows)


class FakeCamaraSource:
    def __init__(self, votes: list[dict]) -> None:
        self._votes = votes

    def fetch_votes_for_actor(self, actor) -> list[dict]:
        return self._votes


class FakePublisher(IotMqttPublisher):
    def __init__(self) -> None:
        self.messages: list[tuple[str, dict]] = []

    def publish(self, topic: str, payload: dict) -> None:
        self.messages.append((topic, payload))


def test_notifies_new_vote() -> None:
    publisher = FakePublisher()
    total = run_once(
        followed_repo=FakeFollowedRepo(),
        actor_repo=FakeActorRepo(),
        link_repo=FakeLinkRepo(),
        evidence_repo=FakeEvidenceRepo(existing=[]),
        camara=FakeCamaraSource([NEW_VOTE]),
        publisher=publisher,
    )

    assert total == 1
    assert publisher.messages[0][0] == f"farol/{TOKEN}"
    assert publisher.messages[0][1]["color"] == "green"


def test_skips_already_known_vote() -> None:
    existing_evidence = [
        OfficialEvidence(
            id=1,
            political_actor_id=ACTOR_ID,
            source="camara",
            source_id="vote:999:12345",
            evidence_type="vote",
            title="Votou Sim",
            summary="PL 123/2024",
            evidence_date=NOW,
            source_url=None,
            fetched_at=NOW,
            expires_at=NOW,
        )
    ]
    publisher = FakePublisher()
    run_once(
        followed_repo=FakeFollowedRepo(),
        actor_repo=FakeActorRepo(),
        link_repo=FakeLinkRepo(),
        evidence_repo=FakeEvidenceRepo(existing=existing_evidence),
        camara=FakeCamaraSource([NEW_VOTE]),
        publisher=publisher,
    )

    assert publisher.messages == []


def test_handles_camara_failure_gracefully() -> None:
    class BrokenCamaraSource:
        def fetch_votes_for_actor(self, actor): raise RuntimeError("timeout")

    publisher = FakePublisher()
    total = run_once(
        followed_repo=FakeFollowedRepo(),
        actor_repo=FakeActorRepo(),
        link_repo=FakeLinkRepo(),
        evidence_repo=FakeEvidenceRepo(),
        camara=BrokenCamaraSource(),
        publisher=publisher,
    )

    assert total == 0
    assert publisher.messages == []
