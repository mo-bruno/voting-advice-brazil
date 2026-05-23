from datetime import datetime, timedelta
from hashlib import sha256

from app.core.entities.iot_device import IotDeviceLink, IotPairingSession
from app.core.use_cases.interfaces import (
    IotDeviceLinkRepository,
    IotMqttPublisher,
    IotPairingSessionRepository,
)

PAIRING_TTL = timedelta(minutes=10)


class InvalidPairingCodeError(ValueError):
    pass


class DeviceAlreadyLinkedError(ValueError):
    pass


def _pairing_code_hash(device_token: str, pairing_code: str) -> str:
    return sha256(f"{device_token}:{pairing_code}".encode("utf-8")).hexdigest()


def _qr_payload(device_token: str, pairing_code: str) -> str:
    return f"farol://pair?device_token={device_token}&pairing_code={pairing_code}"


def create_pairing_session(
    repo: IotPairingSessionRepository,
    device_token: str,
    pairing_code: str,
    firmware_version: str | None,
    now: datetime,
) -> IotPairingSession:
    return repo.create_session(
        device_token=device_token,
        pairing_code_hash=_pairing_code_hash(device_token, pairing_code),
        qr_payload=_qr_payload(device_token, pairing_code),
        firmware_version=firmware_version,
        now=now,
        expires_at=now + PAIRING_TTL,
    )


def get_iot_device_link(
    repo: IotDeviceLinkRepository,
    anonymous_id: str,
) -> IotDeviceLink | None:
    return repo.get_by_anonymous_id(anonymous_id)


def pair_iot_device(
    link_repo: IotDeviceLinkRepository,
    session_repo: IotPairingSessionRepository,
    publisher: IotMqttPublisher,
    anonymous_id: str,
    device_token: str,
    pairing_code: str,
    now: datetime,
) -> IotDeviceLink:
    conflict = link_repo.get_conflicting_link(anonymous_id, device_token)
    if conflict is not None:
        raise DeviceAlreadyLinkedError("Gadget ja vinculado a outro app.")

    session = session_repo.get_active_session(
        device_token=device_token,
        pairing_code_hash=_pairing_code_hash(device_token, pairing_code),
        now=now,
    )
    if session is None:
        raise InvalidPairingCodeError("Codigo de pareamento invalido ou expirado.")

    try:
        link = link_repo.set_link(
            anonymous_id=anonymous_id,
            device_token=device_token,
            now=now,
        )
    except ValueError as exc:
        raise DeviceAlreadyLinkedError("Gadget ja vinculado a outro app.") from exc

    session_repo.consume_session(session.id, now)
    publisher.publish(
        f"farol/{device_token}",
        {
            "type": "pairing_confirmed",
            "color": "green",
            "deputy_name": "Farol Politico",
            "vote_summary": "Dispositivo conectado ao app com sucesso.",
            "timestamp_utc": now.isoformat().replace("+00:00", "Z"),
        },
    )
    return link


def unlink_iot_device(repo: IotDeviceLinkRepository, anonymous_id: str) -> bool:
    return repo.delete_by_anonymous_id(anonymous_id)
