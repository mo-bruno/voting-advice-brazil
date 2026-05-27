from datetime import datetime, timedelta, timezone

import pytest

from app.core.entities.iot_device import IotDeviceLink, IotPairingSession
from app.core.use_cases.pair_iot_device import (
    DeviceAlreadyLinkedError,
    InvalidPairingCodeError,
    create_pairing_session,
    pair_iot_device,
)

TOKEN = "550e8400-e29b-41d4-a716-446655440000"
PAIRING_CODE = "482913"
NOW = datetime(2026, 5, 22, tzinfo=timezone.utc)


class FakeLinkRepo:
    def __init__(self) -> None:
        self.by_token: dict[str, IotDeviceLink] = {}
        self.by_anonymous: dict[str, IotDeviceLink] = {}

    def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None:
        return self.by_anonymous.get(anonymous_id)

    def get_by_token(self, device_token: str) -> IotDeviceLink | None:
        return self.by_token.get(device_token)

    def get_conflicting_link(
        self,
        anonymous_id: str,
        device_token: str,
    ) -> IotDeviceLink | None:
        link = self.by_token.get(device_token)
        if link is None or link.anonymous_id == anonymous_id:
            return None
        return link

    def set_link(
        self,
        anonymous_id: str,
        device_token: str,
        now: datetime,
    ) -> IotDeviceLink:
        existing_token_link = self.by_token.get(device_token)
        if (
            existing_token_link is not None
            and existing_token_link.anonymous_id != anonymous_id
        ):
            raise ValueError("device token already linked")

        existing_anonymous_link = self.by_anonymous.get(anonymous_id)
        if (
            existing_anonymous_link is not None
            and existing_anonymous_link.device_token != device_token
        ):
            del self.by_token[existing_anonymous_link.device_token]

        link = IotDeviceLink(
            device_token=device_token,
            anonymous_id=anonymous_id,
            status="linked",
            created_at=now,
            updated_at=now,
            last_seen_at=None,
        )
        self.by_token[device_token] = link
        self.by_anonymous[anonymous_id] = link
        return link

    def delete_by_anonymous_id(self, anonymous_id: str) -> bool:
        link = self.by_anonymous.pop(anonymous_id, None)
        if link is None:
            return False
        del self.by_token[link.device_token]
        return True


class FakeSessionRepo:
    def __init__(self) -> None:
        self.created: list[IotPairingSession] = []
        self.consumed: list[int] = []

    def create_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        qr_payload: str,
        firmware_version: str | None,
        now: datetime,
        expires_at: datetime,
    ) -> IotPairingSession:
        session = IotPairingSession(
            id=len(self.created) + 1,
            device_token=device_token,
            pairing_code_hash=pairing_code_hash,
            qr_payload=qr_payload,
            firmware_version=firmware_version,
            created_at=now,
            expires_at=expires_at,
            consumed_at=None,
        )
        self.created.append(session)
        return session

    def get_active_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        now: datetime,
    ) -> IotPairingSession | None:
        for session in self.created:
            if (
                session.device_token == device_token
                and session.pairing_code_hash == pairing_code_hash
                and session.consumed_at is None
                and session.expires_at > now
                and session.id not in self.consumed
            ):
                return session
        return None

    def consume_session(self, session_id: int, now: datetime) -> None:
        self.consumed.append(session_id)


class FakePublisher:
    def __init__(self) -> None:
        self.messages: list[tuple[str, dict[str, str]]] = []

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        self.messages.append((topic, payload))


def test_create_pairing_session_returns_qr_payload() -> None:
    repo = FakeSessionRepo()

    session = create_pairing_session(
        repo,
        TOKEN,
        PAIRING_CODE,
        "0.1.0",
        NOW,
    )

    assert (
        session.qr_payload
        == "farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913"
    )
    assert session.expires_at == NOW + timedelta(minutes=10)
    assert repo.created[0].pairing_code_hash != "482913"


def test_pair_iot_device_consumes_session_and_publishes_confirmation() -> None:
    links = FakeLinkRepo()
    sessions = FakeSessionRepo()
    publisher = FakePublisher()
    create_pairing_session(sessions, TOKEN, PAIRING_CODE, "0.1.0", NOW)

    link = pair_iot_device(
        links,
        sessions,
        publisher,
        "anon-1",
        TOKEN,
        PAIRING_CODE,
        NOW,
    )

    assert link.anonymous_id == "anon-1"
    assert sessions.consumed == [1]
    assert publisher.messages[0][0] == f"farol/{TOKEN}"
    assert publisher.messages[0][1]["type"] == "pairing_confirmed"


def test_pair_iot_device_rejects_invalid_pairing_code() -> None:
    with pytest.raises(InvalidPairingCodeError):
        pair_iot_device(
            FakeLinkRepo(),
            FakeSessionRepo(),
            FakePublisher(),
            "anon-1",
            TOKEN,
            PAIRING_CODE,
            NOW,
        )


def test_pair_iot_device_rejects_token_linked_to_another_user() -> None:
    links = FakeLinkRepo()
    links.set_link("anon-existing", TOKEN, NOW)
    sessions = FakeSessionRepo()
    create_pairing_session(sessions, TOKEN, PAIRING_CODE, "0.1.0", NOW)

    with pytest.raises(DeviceAlreadyLinkedError):
        pair_iot_device(
            links,
            sessions,
            FakePublisher(),
            "anon-1",
            TOKEN,
            PAIRING_CODE,
            NOW,
        )
