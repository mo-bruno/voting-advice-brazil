from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class IotDeviceLink:
    device_token: str
    anonymous_id: str
    status: str
    created_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None


@dataclass(frozen=True)
class IotPairingSession:
    id: int
    device_token: str
    pairing_code_hash: str
    qr_payload: str
    firmware_version: str | None
    created_at: datetime
    expires_at: datetime
    consumed_at: datetime | None


@dataclass(frozen=True)
class IotMqttMessage:
    topic: str
    payload: dict[str, str]
