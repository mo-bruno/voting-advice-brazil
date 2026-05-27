from datetime import datetime, timezone

from app.core.entities.iot_device import IotDeviceEvent, IotDeviceLink
from app.core.use_cases.vote_notifier import run_vote_notifier


class FakeFollowedActorRepository:
    def __init__(self, rows: list[tuple[int, str]]) -> None:
        self._rows = rows

    def list_all_followed(self) -> list[tuple[int, str]]:
        return list(self._rows)


class FakeIotDeviceLinkRepository:
    def __init__(self, links: dict[str, IotDeviceLink]) -> None:
        self._links = links

    def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None:
        return self._links.get(anonymous_id)


class FakeIotDeviceEventRepository:
    def __init__(self) -> None:
        self.recorded: list[dict[str, object]] = []
        self._next_id = 1

    def record(
        self,
        device_token: str,
        event_type: str,
        payload: dict[str, object],
        now: datetime,
    ) -> IotDeviceEvent:
        event = IotDeviceEvent(
            id=self._next_id,
            device_token=device_token,
            event_type=event_type,
            payload=payload,
            published_at=now,
        )
        self._next_id += 1
        self.recorded.append(
            {
                "device_token": device_token,
                "event_type": event_type,
                "payload": payload,
                "now": now,
            }
        )
        return event


class FakeIotMqttPublisher:
    def __init__(self) -> None:
        self.published: list[dict[str, object]] = []

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        self.published.append({"topic": topic, "payload": payload})


def test_run_vote_notifier_publishes_and_records():
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    followed_repo = FakeFollowedActorRepository([(10, "anon-1"), (20, "anon-2")])
    link_repo = FakeIotDeviceLinkRepository(
        {
            "anon-1": IotDeviceLink(
                device_token="tok-1",
                anonymous_id="anon-1",
                status="linked",
                created_at=now,
                updated_at=now,
                last_seen_at=None,
            )
        }
    )
    event_repo = FakeIotDeviceEventRepository()
    publisher = FakeIotMqttPublisher()

    notified = run_vote_notifier(
        followed_repo=followed_repo,
        link_repo=link_repo,
        event_repo=event_repo,
        publisher=publisher,
        political_actor_id=10,
        deputy_name="Deputy A",
        party="ABC",
        state="SP",
        vote="Sim",
        alignment="aligned",
        now=now,
    )

    assert notified == 1
    assert publisher.published == [
        {
            "topic": "farol/tok-1",
            "payload": {
                "type": "vote_alert",
                "deputy_name": "Deputy A",
                "party": "ABC",
                "state": "SP",
                "vote": "Sim",
                "alignment": "aligned",
                "color": "green",
                "description": "Voto alinhado ao usuario.",
                "timestamp_utc": "2026-01-01T00:00:00Z",
            },
        }
    ]
    assert event_repo.recorded == [
        {
            "device_token": "tok-1",
            "event_type": "vote_alert",
            "payload": publisher.published[0]["payload"],
            "now": now,
        }
    ]


def test_run_vote_notifier_defaults_to_pending_alignment():
    now = datetime(2026, 1, 2, tzinfo=timezone.utc)
    followed_repo = FakeFollowedActorRepository([(10, "anon-1")])
    link_repo = FakeIotDeviceLinkRepository(
        {
            "anon-1": IotDeviceLink(
                device_token="tok-2",
                anonymous_id="anon-1",
                status="linked",
                created_at=now,
                updated_at=now,
                last_seen_at=None,
            )
        }
    )
    event_repo = FakeIotDeviceEventRepository()
    publisher = FakeIotMqttPublisher()

    run_vote_notifier(
        followed_repo=followed_repo,
        link_repo=link_repo,
        event_repo=event_repo,
        publisher=publisher,
        political_actor_id=10,
        deputy_name="Deputy B",
        party=None,
        state=None,
        vote="Obstrucao",
        alignment="unknown",
        now=now,
    )

    payload = publisher.published[0]["payload"]
    assert payload["color"] == "blue"
    assert payload["description"] == "Voto pendente."
    assert payload["party"] == ""
    assert payload["state"] == ""
