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


class AmbiguousPairingCodeError(ValueError):
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


def get_iot_device_link_by_token(
    repo: IotDeviceLinkRepository,
    device_token: str,
) -> IotDeviceLink | None:
    return repo.get_by_token(device_token)


def resolve_pairing_device_token(
    session_repo: IotPairingSessionRepository,
    device_token_prefix: str,
    pairing_code: str,
    now: datetime,
) -> str:
    sessions = session_repo.list_active_sessions_by_token_prefix(
        device_token_prefix=device_token_prefix,
        now=now,
    )
    matching_tokens = {
        session.device_token
        for session in sessions
        if session.pairing_code_hash
        == _pairing_code_hash(session.device_token, pairing_code)
    }
    if not matching_tokens:
        raise InvalidPairingCodeError("Codigo de pareamento invalido ou expirado.")
    if len(matching_tokens) > 1:
        raise AmbiguousPairingCodeError(
            "Prefixo do dispositivo corresponde a mais de uma sessao ativa."
        )
    return next(iter(matching_tokens))


def pair_iot_device(
    link_repo: IotDeviceLinkRepository,
    session_repo: IotPairingSessionRepository,
    publisher: IotMqttPublisher,
    anonymous_id: str,
    device_token: str,
    pairing_code: str,
    now: datetime,
) -> IotDeviceLink:
    session = session_repo.get_active_session(
        device_token=device_token,
        pairing_code_hash=_pairing_code_hash(device_token, pairing_code),
        now=now,
    )
    if session is None:
        raise InvalidPairingCodeError("Codigo de pareamento invalido ou expirado.")

    link = link_repo.set_link(
        anonymous_id=anonymous_id,
        device_token=device_token,
        now=now,
    )

    session_repo.consume_session(session.id, now)
    try:
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
    except Exception:
        # Pairing state is persisted; transient MQTT confirmation failure should
        # not roll it back. A future outbox/worker can retry this notification.
        pass
    return link


def unlink_iot_device(repo: IotDeviceLinkRepository, anonymous_id: str) -> bool:
    return repo.delete_by_anonymous_id(anonymous_id)
