from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.entities.iot_device import IotDeviceLink, IotPairingSession
from app.core.use_cases.interfaces import (
    IotDeviceLinkRepository,
    IotPairingSessionRepository,
)
from app.infrastructure.database.models import (
    IotDeviceLinkModel,
    IotPairingSessionModel,
)


def _to_link(model: IotDeviceLinkModel) -> IotDeviceLink:
    return IotDeviceLink(
        device_token=model.device_token,
        anonymous_id=model.anonymous_id,
        status=model.status,
        created_at=model.created_at,
        updated_at=model.updated_at,
        last_seen_at=model.last_seen_at,
    )


def _to_session(model: IotPairingSessionModel) -> IotPairingSession:
    return IotPairingSession(
        id=model.id,
        device_token=model.device_token,
        pairing_code_hash=model.pairing_code_hash,
        qr_payload=model.qr_payload,
        firmware_version=model.firmware_version,
        created_at=model.created_at,
        expires_at=model.expires_at,
        consumed_at=model.consumed_at,
    )


class SqlIotDeviceLinkRepository(IotDeviceLinkRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None:
        model = self._db.execute(
            select(IotDeviceLinkModel).where(
                IotDeviceLinkModel.anonymous_id == anonymous_id
            )
        ).scalar_one_or_none()
        return _to_link(model) if model else None

    def get_by_token(self, device_token: str) -> IotDeviceLink | None:
        model = self._db.get(IotDeviceLinkModel, device_token)
        return _to_link(model) if model else None

    def get_conflicting_link(
        self,
        anonymous_id: str,
        device_token: str,
    ) -> IotDeviceLink | None:
        model = self._db.get(IotDeviceLinkModel, device_token)
        if model is None or model.anonymous_id == anonymous_id:
            return None
        return _to_link(model)

    def set_link(
        self,
        anonymous_id: str,
        device_token: str,
        now: datetime,
    ) -> IotDeviceLink:
        model = self._db.get(IotDeviceLinkModel, device_token)
        if model is not None and model.anonymous_id != anonymous_id:
            raise ValueError("device token already linked")

        existing_for_anonymous = self._db.execute(
            select(IotDeviceLinkModel).where(
                IotDeviceLinkModel.anonymous_id == anonymous_id
            )
        ).scalar_one_or_none()
        if (
            existing_for_anonymous is not None
            and existing_for_anonymous.device_token != device_token
        ):
            self._db.delete(existing_for_anonymous)
            self._db.flush()

        if model is None:
            model = IotDeviceLinkModel(
                device_token=device_token,
                anonymous_id=anonymous_id,
                status="linked",
                created_at=now,
                updated_at=now,
            )
            self._db.add(model)
        else:
            model.anonymous_id = anonymous_id
            model.status = "linked"
            model.updated_at = now
        self._db.commit()
        self._db.refresh(model)
        return _to_link(model)

    def delete_by_anonymous_id(self, anonymous_id: str) -> bool:
        model = self._db.execute(
            select(IotDeviceLinkModel).where(
                IotDeviceLinkModel.anonymous_id == anonymous_id
            )
        ).scalar_one_or_none()
        if model is None:
            return False
        self._db.delete(model)
        self._db.commit()
        return True


class SqlIotPairingSessionRepository(IotPairingSessionRepository):
    def __init__(self, db: Session) -> None:
        self._db = db

    def create_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        qr_payload: str,
        firmware_version: str | None,
        now: datetime,
        expires_at: datetime,
    ) -> IotPairingSession:
        existing_sessions = self._db.execute(
            select(IotPairingSessionModel).where(
                IotPairingSessionModel.device_token == device_token,
                IotPairingSessionModel.consumed_at.is_(None),
                IotPairingSessionModel.expires_at > now,
            )
        ).scalars()
        for existing_session in existing_sessions:
            existing_session.consumed_at = now

        model = IotPairingSessionModel(
            device_token=device_token,
            pairing_code_hash=pairing_code_hash,
            qr_payload=qr_payload,
            firmware_version=firmware_version,
            created_at=now,
            expires_at=expires_at,
        )
        self._db.add(model)
        self._db.commit()
        self._db.refresh(model)
        return _to_session(model)

    def get_active_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        now: datetime,
    ) -> IotPairingSession | None:
        model = self._db.execute(
            select(IotPairingSessionModel).where(
                IotPairingSessionModel.device_token == device_token,
                IotPairingSessionModel.pairing_code_hash == pairing_code_hash,
                IotPairingSessionModel.consumed_at.is_(None),
                IotPairingSessionModel.expires_at > now,
            )
        ).scalar_one_or_none()
        return _to_session(model) if model else None

    def consume_session(self, session_id: int, now: datetime) -> None:
        model = self._db.get(IotPairingSessionModel, session_id)
        if model is None:
            return
        model.consumed_at = now
        self._db.commit()
