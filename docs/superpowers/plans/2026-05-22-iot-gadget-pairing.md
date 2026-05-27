# IoT Gadget Pairing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a complete first slice for pairing a physical Farol Politico gadget with the existing anonymous mobile app identity, with backend persistence, app status UI, and firmware scaffolds for ESP32 + Arduino Mega.

**Architecture:** Keep the current quiz and followed-politician flows intact. Add an `iot_devices` backend boundary with its own models, repositories, schemas, router, and MQTT publisher adapter; add a Flutter `iot` feature that reads a QR payload shown by the gadget; add PlatformIO firmware projects that preserve the existing ESP32-to-Mega UART display protocol and add a `Q|...` frame for pairing.

**Tech Stack:** Python 3.12/FastAPI/SQLAlchemy/Alembic/pytest, Flutter/Dart/http/shared_preferences/mobile_scanner, PlatformIO Arduino for ESP32 and Arduino Mega, PubSubClient, ArduinoJson, MCUFRIEND_kbv, QRCode.

---

## Scope

This plan implements Fatia 1 from the approved spec:

- Backend link/session storage, APIs, and testable MQTT confirmation publisher.
- Mobile "Meu Farol" status, QR/manual pairing UI, API client, and parser tests.
- Firmware ESP32 and Mega structures based on the existing Arduino sketches.
- CI build checks for firmware when PlatformIO projects change.

This plan does not implement the future Camara monitoring loop or vote-alignment rule. Those are Fatia 3 in the approved spec.

## File Structure

Backend:

- Create `backend/app/core/entities/iot_device.py`: dataclasses for IoT links, pairing sessions, and MQTT messages.
- Modify `backend/app/core/use_cases/interfaces.py`: repository and publisher protocols for IoT.
- Create `backend/app/core/use_cases/pair_iot_device.py`: pure-ish orchestration for creating sessions, pairing, fetching, and unlinking.
- Modify `backend/app/infrastructure/database/models.py`: SQLAlchemy models for `iot_device_links` and `iot_pairing_sessions`.
- Create `backend/alembic/versions/0003_iot_device_pairing.py`: migration for the two new tables.
- Create `backend/app/infrastructure/database/iot_device_repositories.py`: SQL persistence for links and pairing sessions.
- Create `backend/app/infrastructure/mqtt/publisher.py`: MQTT publisher interface implementation using `paho-mqtt`.
- Create `backend/app/api/schemas/iot_devices.py`: Pydantic request and response schemas.
- Create `backend/app/api/routers/iot_devices.py`: FastAPI routes.
- Modify `backend/app/api/deps.py`: dependency providers for IoT repos and publisher.
- Modify `backend/app/main.py`: include the IoT router.
- Modify `backend/pyproject.toml` and `backend/uv.lock`: add `paho-mqtt`.
- Create `backend/tests/test_iot_devices_api.py`: API coverage.
- Create `backend/tests/test_iot_device_repository.py`: repository coverage.
- Create `backend/tests/test_iot_pairing_use_case.py`: use-case coverage.

Mobile:

- Modify `mobile/pubspec.yaml` and `mobile/pubspec.lock`: add `mobile_scanner`.
- Modify `mobile/ios/Runner/Info.plist`: add camera permission description.
- Modify `mobile/android/app/src/main/AndroidManifest.xml`: add camera permission.
- Create `mobile/lib/shared/models/iot_device.dart`: model and QR payload parser.
- Create `mobile/lib/shared/iot_device_session.dart`: state/session class using `DeviceIdentityStore`.
- Modify `mobile/lib/core/api/api_client.dart`: IoT API methods.
- Create `mobile/lib/features/iot/iot_device_page.dart`: status page and entry point.
- Create `mobile/lib/features/iot/iot_pairing_page.dart`: QR scanner and manual code entry.
- Modify `mobile/lib/app.dart`: register `/iot-device` and `/iot-pairing`.
- Modify `mobile/lib/features/home/home_page.dart`: add `MEU FAROL` entry.
- Create `mobile/test/iot_device_model_test.dart`: QR parser tests.
- Create `mobile/test/iot_device_session_test.dart`: session tests.
- Create `mobile/test/api_client_iot_test.dart`: API request/response tests.
- Create `mobile/test/iot_device_page_test.dart`: status UI test.

Firmware:

- Create `firmware/esp32/platformio.ini`: ESP32 project config.
- Create `firmware/esp32/include/config.h`: pin, MQTT, UART, and API constants.
- Create `firmware/esp32/include/secrets.h.example`: WiFi/API secret template.
- Create `firmware/esp32/src/main.cpp`: setup/loop orchestration.
- Create `firmware/esp32/lib/DeviceToken/DeviceToken.h` and `.cpp`: UUID in NVS.
- Create `firmware/esp32/lib/WifiManager/WifiManager.h` and `.cpp`: WiFi connect.
- Create `firmware/esp32/lib/MqttClient/MqttClient.h` and `.cpp`: MQTT subscribe/reconnect.
- Create `firmware/esp32/lib/PayloadParser/PayloadParser.h` and `.cpp`: JSON event parser.
- Create `firmware/esp32/lib/LedStatus/LedStatus.h` and `.cpp`: LED state.
- Create `firmware/esp32/lib/DisplayUart/DisplayUart.h` and `.cpp`: `V|...` and `Q|...` frames.
- Create `firmware/esp32/lib/PairingClient/PairingClient.h` and `.cpp`: backend pairing-session HTTP call.
- Create `firmware/mega/platformio.ini`: Mega project config.
- Create `firmware/mega/src/main.cpp`: TFT display renderer for `V|...` and `Q|...`.
- Create `.github/workflows/firmware.yml`: PlatformIO build checks.

---

### Task 1: Backend Database and Repository

**Files:**
- Modify: `backend/app/infrastructure/database/models.py`
- Create: `backend/alembic/versions/0003_iot_device_pairing.py`
- Create: `backend/app/core/entities/iot_device.py`
- Modify: `backend/app/core/use_cases/interfaces.py`
- Create: `backend/app/infrastructure/database/iot_device_repositories.py`
- Create: `backend/tests/test_iot_device_repository.py`

- [ ] **Step 1: Write repository tests**

Create `backend/tests/test_iot_device_repository.py`:

```python
from datetime import datetime, timedelta, timezone

from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceLinkRepository,
    SqlIotPairingSessionRepository,
)
from app.infrastructure.database.models import (
    IotDeviceLinkModel,
    IotPairingSessionModel,
)


def _clean(db_session):
    db_session.query(IotPairingSessionModel).delete()
    db_session.query(IotDeviceLinkModel).delete()
    db_session.commit()


def test_upserts_one_iot_link_per_anonymous_id(db_session):
    _clean(db_session)
    repo = SqlIotDeviceLinkRepository(db_session)
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)

    first = repo.set_link("anon-1", "550e8400-e29b-41d4-a716-446655440000", now)
    second = repo.set_link("anon-1", "550e8400-e29b-41d4-a716-446655440001", now)

    assert first.device_token == "550e8400-e29b-41d4-a716-446655440000"
    assert second.device_token == "550e8400-e29b-41d4-a716-446655440001"
    assert repo.get_by_anonymous_id("anon-1").device_token == "550e8400-e29b-41d4-a716-446655440001"
    assert repo.get_by_token("550e8400-e29b-41d4-a716-446655440000") is None


def test_refuses_token_linked_to_other_anonymous_id(db_session):
    _clean(db_session)
    repo = SqlIotDeviceLinkRepository(db_session)
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)

    repo.set_link("anon-1", "550e8400-e29b-41d4-a716-446655440000", now)
    conflict = repo.get_conflicting_link("anon-2", "550e8400-e29b-41d4-a716-446655440000")

    assert conflict is not None
    assert conflict.anonymous_id == "anon-1"


def test_pairing_session_lifecycle(db_session):
    _clean(db_session)
    repo = SqlIotPairingSessionRepository(db_session)
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)
    expires_at = now + timedelta(minutes=10)

    created = repo.create_session(
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code_hash="hash-482913",
        qr_payload="farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913",
        firmware_version="0.1.0",
        now=now,
        expires_at=expires_at,
    )
    active = repo.get_active_session(
        "550e8400-e29b-41d4-a716-446655440000",
        "hash-482913",
        now,
    )
    repo.consume_session(created.id, now)
    consumed = repo.get_active_session(
        "550e8400-e29b-41d4-a716-446655440000",
        "hash-482913",
        now,
    )

    assert active is not None
    assert active.id == created.id
    assert consumed is None


def test_new_pairing_session_invalidates_previous_active_sessions(db_session):
    _clean(db_session)
    repo = SqlIotPairingSessionRepository(db_session)
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)

    repo.create_session(
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code_hash="hash-old",
        qr_payload="farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=111111",
        firmware_version="0.1.0",
        now=now,
        expires_at=now + timedelta(minutes=10),
    )
    repo.create_session(
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code_hash="hash-new",
        qr_payload="farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=222222",
        firmware_version="0.1.0",
        now=now,
        expires_at=now + timedelta(minutes=10),
    )

    assert repo.get_active_session(
        "550e8400-e29b-41d4-a716-446655440000",
        "hash-old",
        now,
    ) is None
    assert repo.get_active_session(
        "550e8400-e29b-41d4-a716-446655440000",
        "hash-new",
        now,
    ) is not None
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
cd backend
uv run pytest tests/test_iot_device_repository.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.infrastructure.database.iot_device_repositories'`.

- [ ] **Step 3: Add IoT dataclasses**

Create `backend/app/core/entities/iot_device.py`:

```python
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
```

- [ ] **Step 4: Add repository interfaces**

Modify `backend/app/core/use_cases/interfaces.py` by adding imports:

```python
from app.core.entities.iot_device import IotDeviceLink, IotPairingSession
```

Add these abstract classes at the end of the file:

```python
class IotDeviceLinkRepository(ABC):
    @abstractmethod
    def get_by_anonymous_id(self, anonymous_id: str) -> IotDeviceLink | None: ...

    @abstractmethod
    def get_by_token(self, device_token: str) -> IotDeviceLink | None: ...

    @abstractmethod
    def get_conflicting_link(
        self,
        anonymous_id: str,
        device_token: str,
    ) -> IotDeviceLink | None: ...

    @abstractmethod
    def set_link(
        self,
        anonymous_id: str,
        device_token: str,
        now: datetime,
    ) -> IotDeviceLink: ...

    @abstractmethod
    def delete_by_anonymous_id(self, anonymous_id: str) -> bool: ...


class IotPairingSessionRepository(ABC):
    @abstractmethod
    def create_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        qr_payload: str,
        firmware_version: str | None,
        now: datetime,
        expires_at: datetime,
    ) -> IotPairingSession: ...

    @abstractmethod
    def get_active_session(
        self,
        device_token: str,
        pairing_code_hash: str,
        now: datetime,
    ) -> IotPairingSession | None: ...

    @abstractmethod
    def consume_session(self, session_id: int, now: datetime) -> None: ...


class IotMqttPublisher(ABC):
    @abstractmethod
    def publish(self, topic: str, payload: dict[str, str]) -> None: ...
```

- [ ] **Step 5: Add SQLAlchemy models**

Modify `backend/app/infrastructure/database/models.py` after `FollowedActorModel`:

```python
class IotDeviceLinkModel(Base):
    __tablename__ = "iot_device_links"

    device_token: Mapped[str] = mapped_column(String(64), primary_key=True)
    anonymous_id: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="linked")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        Index("ix_iot_device_links_anonymous_id", "anonymous_id"),
        Index("ix_iot_device_links_updated_at", "updated_at"),
    )


class IotPairingSessionModel(Base):
    __tablename__ = "iot_pairing_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    device_token: Mapped[str] = mapped_column(String(64), nullable=False)
    pairing_code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    qr_payload: Mapped[str] = mapped_column(String(512), nullable=False)
    firmware_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        Index(
            "ix_iot_pairing_sessions_device_expires",
            "device_token",
            "expires_at",
        ),
    )
```

- [ ] **Step 6: Add Alembic migration**

Create `backend/alembic/versions/0003_iot_device_pairing.py`:

```python
"""iot_device_pairing

Revision ID: 0003_iot_device_pairing
Revises: 0002_public_actor_tracker
Create Date: 2026-05-22 21:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

revision: str = "0003_iot_device_pairing"
down_revision: Union[str, Sequence[str], None] = "0002_public_actor_tracker"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "iot_device_links",
        sa.Column("device_token", sa.String(length=64), nullable=False),
        sa.Column("anonymous_id", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("device_token"),
        sa.UniqueConstraint("anonymous_id", name="uq_iot_device_links_anonymous_id"),
    )
    with op.batch_alter_table("iot_device_links", schema=None) as batch_op:
        batch_op.create_index(
            "ix_iot_device_links_anonymous_id",
            ["anonymous_id"],
            unique=False,
        )
        batch_op.create_index(
            "ix_iot_device_links_updated_at",
            ["updated_at"],
            unique=False,
        )

    op.create_table(
        "iot_pairing_sessions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("device_token", sa.String(length=64), nullable=False),
        sa.Column("pairing_code_hash", sa.String(length=128), nullable=False),
        sa.Column("qr_payload", sa.String(length=512), nullable=False),
        sa.Column("firmware_version", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("iot_pairing_sessions", schema=None) as batch_op:
        batch_op.create_index(
            "ix_iot_pairing_sessions_device_expires",
            ["device_token", "expires_at"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("iot_pairing_sessions", schema=None) as batch_op:
        batch_op.drop_index("ix_iot_pairing_sessions_device_expires")
    op.drop_table("iot_pairing_sessions")

    with op.batch_alter_table("iot_device_links", schema=None) as batch_op:
        batch_op.drop_index("ix_iot_device_links_updated_at")
        batch_op.drop_index("ix_iot_device_links_anonymous_id")
    op.drop_table("iot_device_links")
```

- [ ] **Step 7: Add SQL repositories**

Create `backend/app/infrastructure/database/iot_device_repositories.py`:

```python
from __future__ import annotations

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
        existing_for_user = self._db.execute(
            select(IotDeviceLinkModel).where(
                IotDeviceLinkModel.anonymous_id == anonymous_id
            )
        ).scalar_one_or_none()
        if existing_for_user is not None and existing_for_user.device_token != device_token:
            self._db.delete(existing_for_user)
            self._db.flush()

        model = self._db.get(IotDeviceLinkModel, device_token)
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
        existing = self._db.execute(
            select(IotPairingSessionModel).where(
                IotPairingSessionModel.device_token == device_token,
                IotPairingSessionModel.consumed_at.is_(None),
                IotPairingSessionModel.expires_at > now,
            )
        ).scalars().all()
        for model in existing:
            model.consumed_at = now

        model = IotPairingSessionModel(
            device_token=device_token,
            pairing_code_hash=pairing_code_hash,
            qr_payload=qr_payload,
            firmware_version=firmware_version,
            created_at=now,
            expires_at=expires_at,
            consumed_at=None,
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
```

- [ ] **Step 8: Run repository tests**

Run:

```bash
cd backend
uv run pytest tests/test_iot_device_repository.py -v
```

Expected: PASS with 4 tests.

- [ ] **Step 9: Run migration tests**

Run:

```bash
cd backend
uv run pytest tests/test_migrations.py -v
```

Expected: PASS.

- [ ] **Step 10: Commit backend persistence**

Run:

```bash
git add backend/app/core/entities/iot_device.py backend/app/core/use_cases/interfaces.py backend/app/infrastructure/database/models.py backend/app/infrastructure/database/iot_device_repositories.py backend/alembic/versions/0003_iot_device_pairing.py backend/tests/test_iot_device_repository.py
git commit -m "feat(api): adicionar persistencia de pareamento iot"
```

---

### Task 2: Backend Use Cases, API, and MQTT Publisher

**Files:**
- Create: `backend/app/core/use_cases/pair_iot_device.py`
- Create: `backend/app/infrastructure/mqtt/__init__.py`
- Create: `backend/app/infrastructure/mqtt/publisher.py`
- Create: `backend/app/api/schemas/iot_devices.py`
- Create: `backend/app/api/routers/iot_devices.py`
- Modify: `backend/app/api/deps.py`
- Modify: `backend/app/main.py`
- Modify: `backend/pyproject.toml`
- Modify: `backend/uv.lock`
- Create: `backend/tests/test_iot_pairing_use_case.py`
- Create: `backend/tests/test_iot_devices_api.py`

- [ ] **Step 1: Add dependency**

Run:

```bash
cd backend
uv add "paho-mqtt>=2.1.0"
uv sync --extra dev
```

Expected: `pyproject.toml` includes `paho-mqtt>=2.1.0`, and `uv.lock` updates.

- [ ] **Step 2: Write use-case tests**

Create `backend/tests/test_iot_pairing_use_case.py`:

```python
from datetime import datetime, timedelta, timezone

import pytest

from app.core.entities.iot_device import IotDeviceLink, IotPairingSession
from app.core.use_cases.pair_iot_device import (
    DeviceAlreadyLinkedError,
    InvalidPairingCodeError,
    create_pairing_session,
    pair_iot_device,
)


class FakeLinkRepo:
    def __init__(self):
        self.by_token = {}
        self.by_anonymous = {}

    def get_by_anonymous_id(self, anonymous_id):
        return self.by_anonymous.get(anonymous_id)

    def get_by_token(self, device_token):
        return self.by_token.get(device_token)

    def get_conflicting_link(self, anonymous_id, device_token):
        link = self.by_token.get(device_token)
        if link is None or link.anonymous_id == anonymous_id:
            return None
        return link

    def set_link(self, anonymous_id, device_token, now):
        link = IotDeviceLink(
            device_token=device_token,
            anonymous_id=anonymous_id,
            status="linked",
            created_at=now,
            updated_at=now,
            last_seen_at=None,
        )
        previous = self.by_anonymous.get(anonymous_id)
        if previous is not None:
            self.by_token.pop(previous.device_token, None)
        self.by_anonymous[anonymous_id] = link
        self.by_token[device_token] = link
        return link

    def delete_by_anonymous_id(self, anonymous_id):
        link = self.by_anonymous.pop(anonymous_id, None)
        if link is None:
            return False
        self.by_token.pop(link.device_token, None)
        return True


class FakeSessionRepo:
    def __init__(self):
        self.created = []
        self.consumed = []

    def create_session(self, device_token, pairing_code_hash, qr_payload, firmware_version, now, expires_at):
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

    def get_active_session(self, device_token, pairing_code_hash, now):
        for session in self.created:
            if (
                session.device_token == device_token
                and session.pairing_code_hash == pairing_code_hash
                and session.consumed_at is None
                and session.expires_at > now
            ):
                return session
        return None

    def consume_session(self, session_id, now):
        self.consumed.append(session_id)


class FakePublisher:
    def __init__(self):
        self.messages = []

    def publish(self, topic, payload):
        self.messages.append((topic, payload))


def test_create_pairing_session_returns_qr_payload():
    repo = FakeSessionRepo()
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)

    session = create_pairing_session(
        repo,
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code="482913",
        firmware_version="0.1.0",
        now=now,
    )

    assert session.qr_payload == "farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913"
    assert session.expires_at == now + timedelta(minutes=10)
    assert repo.created[0].pairing_code_hash != "482913"


def test_pair_iot_device_consumes_session_and_publishes_confirmation():
    links = FakeLinkRepo()
    sessions = FakeSessionRepo()
    publisher = FakePublisher()
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)
    create_pairing_session(
        sessions,
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code="482913",
        firmware_version="0.1.0",
        now=now,
    )

    link = pair_iot_device(
        link_repo=links,
        session_repo=sessions,
        publisher=publisher,
        anonymous_id="anon-1",
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code="482913",
        now=now,
    )

    assert link.anonymous_id == "anon-1"
    assert sessions.consumed == [1]
    assert publisher.messages[0][0] == "farol/550e8400-e29b-41d4-a716-446655440000"
    assert publisher.messages[0][1]["type"] == "pairing_confirmed"


def test_pair_iot_device_rejects_invalid_pairing_code():
    with pytest.raises(InvalidPairingCodeError):
        pair_iot_device(
            link_repo=FakeLinkRepo(),
            session_repo=FakeSessionRepo(),
            publisher=FakePublisher(),
            anonymous_id="anon-1",
            device_token="550e8400-e29b-41d4-a716-446655440000",
            pairing_code="000000",
            now=datetime(2026, 5, 22, tzinfo=timezone.utc),
        )


def test_pair_iot_device_rejects_token_linked_to_another_user():
    links = FakeLinkRepo()
    sessions = FakeSessionRepo()
    publisher = FakePublisher()
    now = datetime(2026, 5, 22, tzinfo=timezone.utc)
    links.set_link("anon-existing", "550e8400-e29b-41d4-a716-446655440000", now)
    create_pairing_session(
        sessions,
        device_token="550e8400-e29b-41d4-a716-446655440000",
        pairing_code="482913",
        firmware_version="0.1.0",
        now=now,
    )

    with pytest.raises(DeviceAlreadyLinkedError):
        pair_iot_device(
            link_repo=links,
            session_repo=sessions,
            publisher=publisher,
            anonymous_id="anon-2",
            device_token="550e8400-e29b-41d4-a716-446655440000",
            pairing_code="482913",
            now=now,
        )
```

- [ ] **Step 3: Run use-case tests and verify they fail**

Run:

```bash
cd backend
uv run pytest tests/test_iot_pairing_use_case.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.core.use_cases.pair_iot_device'`.

- [ ] **Step 4: Implement use cases**

Create `backend/app/core/use_cases/pair_iot_device.py`:

```python
from __future__ import annotations

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
    conflicting = link_repo.get_conflicting_link(anonymous_id, device_token)
    if conflicting is not None:
        raise DeviceAlreadyLinkedError("Gadget ja vinculado a outro app.")

    session = session_repo.get_active_session(
        device_token,
        _pairing_code_hash(device_token, pairing_code),
        now,
    )
    if session is None:
        raise InvalidPairingCodeError("Codigo de pareamento invalido ou expirado.")

    link = link_repo.set_link(anonymous_id, device_token, now)
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


def unlink_iot_device(
    repo: IotDeviceLinkRepository,
    anonymous_id: str,
) -> bool:
    return repo.delete_by_anonymous_id(anonymous_id)
```

- [ ] **Step 5: Run use-case tests**

Run:

```bash
cd backend
uv run pytest tests/test_iot_pairing_use_case.py -v
```

Expected: PASS with 4 tests.

- [ ] **Step 6: Add MQTT publisher implementation**

Create `backend/app/infrastructure/mqtt/__init__.py`:

```python
"""MQTT infrastructure adapters."""
```

Create `backend/app/infrastructure/mqtt/publisher.py`:

```python
from __future__ import annotations

import json
from urllib.parse import urlparse

import paho.mqtt.client as mqtt

from app.core.config import settings
from app.core.use_cases.interfaces import IotMqttPublisher


class PahoIotMqttPublisher(IotMqttPublisher):
    def __init__(self, broker_url: str | None = None) -> None:
        self._broker_url = broker_url or settings.mqtt_broker_url

    def publish(self, topic: str, payload: dict[str, str]) -> None:
        parsed = urlparse(self._broker_url)
        host = parsed.hostname or "broker.hivemq.com"
        port = parsed.port or (8883 if parsed.scheme == "mqtts" else 1883)
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        if parsed.scheme == "mqtts":
            client.tls_set()
        client.connect(host, port, keepalive=30)
        client.loop_start()
        result = client.publish(topic, json.dumps(payload), qos=1)
        result.wait_for_publish()
        client.loop_stop()
        client.disconnect()
```

- [ ] **Step 7: Write API tests**

Create `backend/tests/test_iot_devices_api.py`:

```python
from datetime import datetime, timezone

import pytest

from app.api.deps import get_iot_mqtt_publisher
from app.infrastructure.database.models import (
    IotDeviceLinkModel,
    IotPairingSessionModel,
)
from app.main import app


@pytest.fixture(autouse=True)
def clean_iot_tables(db_session):
    db_session.query(IotPairingSessionModel).delete()
    db_session.query(IotDeviceLinkModel).delete()
    db_session.commit()
    yield
    db_session.query(IotPairingSessionModel).delete()
    db_session.query(IotDeviceLinkModel).delete()
    db_session.commit()


class FakePublisher:
    def __init__(self):
        self.messages = []

    def publish(self, topic, payload):
        self.messages.append((topic, payload))


def test_creates_pairing_session_for_gadget(client):
    response = client.post(
        "/api/v1/iot-devices/550e8400-e29b-41d4-a716-446655440000/pairing-session",
        json={"pairing_code": "482913", "firmware_version": "0.1.0"},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["device_token"] == "550e8400-e29b-41d4-a716-446655440000"
    assert data["pairing_code"] == "482913"
    assert data["qr_payload"] == "farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913"
    assert "expires_at" in data


def test_get_iot_device_returns_404_when_unlinked(client):
    response = client.get(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )

    assert response.status_code == 404


def test_pair_iot_device_links_app_and_publishes_confirmation(client):
    publisher = FakePublisher()
    app.dependency_overrides[get_iot_mqtt_publisher] = lambda: publisher
    client.post(
        "/api/v1/iot-devices/550e8400-e29b-41d4-a716-446655440000/pairing-session",
        json={"pairing_code": "482913", "firmware_version": "0.1.0"},
    )

    response = client.put(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
        json={
            "device_token": "550e8400-e29b-41d4-a716-446655440000",
            "pairing_code": "482913",
        },
    )
    fetched = client.get(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == "linked"
    assert fetched.status_code == 200
    assert fetched.json()["device_token"] == "550e8400-e29b-41d4-a716-446655440000"
    assert publisher.messages[0][0] == "farol/550e8400-e29b-41d4-a716-446655440000"
    assert publisher.messages[0][1]["type"] == "pairing_confirmed"


def test_pair_iot_device_rejects_consumed_pairing_session(client):
    app.dependency_overrides[get_iot_mqtt_publisher] = lambda: FakePublisher()
    client.post(
        "/api/v1/iot-devices/550e8400-e29b-41d4-a716-446655440000/pairing-session",
        json={"pairing_code": "482913", "firmware_version": "0.1.0"},
    )
    client.put(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
        json={
            "device_token": "550e8400-e29b-41d4-a716-446655440000",
            "pairing_code": "482913",
        },
    )

    response = client.put(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
        json={
            "device_token": "550e8400-e29b-41d4-a716-446655440000",
            "pairing_code": "482913",
        },
    )

    assert response.status_code == 422


def test_delete_iot_device_unlinks_current_app(client, db_session):
    db_session.add(
        IotDeviceLinkModel(
            device_token="550e8400-e29b-41d4-a716-446655440000",
            anonymous_id="anon-1",
            status="linked",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
    )
    db_session.commit()

    response = client.delete(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )
    fetched = client.get(
        "/api/v1/me/iot-device",
        headers={"X-Farol-Anonymous-Id": "anon-1"},
    )

    assert response.status_code == 204
    assert fetched.status_code == 404
```

- [ ] **Step 8: Run API tests and verify they fail**

Run:

```bash
cd backend
uv run pytest tests/test_iot_devices_api.py -v
```

Expected: FAIL because `app.api.deps.get_iot_mqtt_publisher` and the router do not exist.

- [ ] **Step 9: Add API schemas**

Create `backend/app/api/schemas/iot_devices.py`:

```python
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class CreatePairingSessionIn(BaseModel):
    pairing_code: str = Field(pattern=r"^[0-9]{6}$")
    firmware_version: str | None = Field(default=None, max_length=32)


class PairingSessionOut(BaseModel):
    device_token: str
    pairing_code: str
    qr_payload: str
    expires_at: datetime


class PairIotDeviceIn(BaseModel):
    device_token: UUID
    pairing_code: str = Field(pattern=r"^[0-9]{6}$")

    @field_validator("device_token")
    @classmethod
    def validate_device_token_uuidv4(cls, value: UUID) -> UUID:
        if value.version != 4:
            raise ValueError("device_token must be a UUID v4")
        return value


class IotDeviceOut(BaseModel):
    device_token: str
    status: str
    linked_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None
```

- [ ] **Step 10: Add API router**

Create `backend/app/api/routers/iot_devices.py`:

```python
from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Response, status

from app.api.deps import (
    get_iot_device_link_repo,
    get_iot_mqtt_publisher,
    get_iot_pairing_session_repo,
)
from app.api.schemas.iot_devices import (
    CreatePairingSessionIn,
    IotDeviceOut,
    PairingSessionOut,
    PairIotDeviceIn,
)
from app.core.entities.iot_device import IotDeviceLink
from app.core.use_cases.pair_iot_device import (
    DeviceAlreadyLinkedError,
    InvalidPairingCodeError,
    create_pairing_session,
    get_iot_device_link,
    pair_iot_device,
    unlink_iot_device,
)
from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceLinkRepository,
    SqlIotPairingSessionRepository,
)
from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher

router = APIRouter(prefix="/iot-devices", tags=["IoT"])
me_router = APIRouter(prefix="/me", tags=["IoT"])
AnonymousHeader = Annotated[str, Header(min_length=1, max_length=64)]


def _device_out(link: IotDeviceLink) -> IotDeviceOut:
    return IotDeviceOut(
        device_token=link.device_token,
        status=link.status,
        linked_at=link.created_at,
        updated_at=link.updated_at,
        last_seen_at=link.last_seen_at,
    )


@router.post(
    "/{device_token}/pairing-session",
    response_model=PairingSessionOut,
    status_code=status.HTTP_201_CREATED,
)
def create_session(
    device_token: UUID,
    body: CreatePairingSessionIn,
    repo: SqlIotPairingSessionRepository = Depends(get_iot_pairing_session_repo),
) -> PairingSessionOut:
    if device_token.version != 4:
        raise HTTPException(status_code=422, detail="device_token must be a UUID v4")
    session = create_pairing_session(
        repo=repo,
        device_token=str(device_token),
        pairing_code=body.pairing_code,
        firmware_version=body.firmware_version,
        now=datetime.now(timezone.utc),
    )
    return PairingSessionOut(
        device_token=str(device_token),
        pairing_code=body.pairing_code,
        qr_payload=session.qr_payload,
        expires_at=session.expires_at,
    )


@me_router.get("/iot-device", response_model=IotDeviceOut)
def get_linked_device(
    x_farol_anonymous_id: AnonymousHeader,
    repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
) -> IotDeviceOut:
    link = get_iot_device_link(repo, x_farol_anonymous_id)
    if link is None:
        raise HTTPException(status_code=404, detail="Nenhum Farol conectado.")
    return _device_out(link)


@me_router.put("/iot-device", response_model=IotDeviceOut)
def pair_device(
    body: PairIotDeviceIn,
    x_farol_anonymous_id: AnonymousHeader,
    link_repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
    session_repo: SqlIotPairingSessionRepository = Depends(get_iot_pairing_session_repo),
    publisher: PahoIotMqttPublisher = Depends(get_iot_mqtt_publisher),
) -> IotDeviceOut:
    try:
        link = pair_iot_device(
            link_repo=link_repo,
            session_repo=session_repo,
            publisher=publisher,
            anonymous_id=x_farol_anonymous_id,
            device_token=str(body.device_token),
            pairing_code=body.pairing_code,
            now=datetime.now(timezone.utc),
        )
    except DeviceAlreadyLinkedError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except InvalidPairingCodeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _device_out(link)


@me_router.delete("/iot-device", status_code=204)
def delete_linked_device(
    response: Response,
    x_farol_anonymous_id: AnonymousHeader,
    repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
) -> Response:
    unlink_iot_device(repo, x_farol_anonymous_id)
    response.status_code = 204
    return response
```

- [ ] **Step 11: Register dependencies and router**

Modify `backend/app/api/deps.py` imports:

```python
from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceLinkRepository,
    SqlIotPairingSessionRepository,
)
from app.infrastructure.mqtt.publisher import PahoIotMqttPublisher
```

Add functions after `get_followed_actor_repo`:

```python
def get_iot_device_link_repo(
    db: Session = Depends(get_db),
) -> SqlIotDeviceLinkRepository:
    return SqlIotDeviceLinkRepository(db)


def get_iot_pairing_session_repo(
    db: Session = Depends(get_db),
) -> SqlIotPairingSessionRepository:
    return SqlIotPairingSessionRepository(db)


def get_iot_mqtt_publisher() -> PahoIotMqttPublisher:
    return PahoIotMqttPublisher()
```

Modify `backend/app/main.py` import:

```python
from app.api.routers import candidates, health, iot_devices, political_actors, quiz, themes
```

Add routers after political actor routers:

```python
app.include_router(iot_devices.router, prefix=PREFIX)
app.include_router(iot_devices.me_router, prefix=PREFIX)
```

- [ ] **Step 12: Run API tests**

Run:

```bash
cd backend
uv run pytest tests/test_iot_pairing_use_case.py tests/test_iot_devices_api.py -v
```

Expected: PASS with 9 tests.

- [ ] **Step 13: Run full backend verification**

Run:

```bash
cd backend
uv run ruff check .
uv run mypy app/
uv run pytest
```

Expected: Ruff PASS, mypy PASS, pytest PASS.

- [ ] **Step 14: Commit backend API**

Run:

```bash
git add backend/pyproject.toml backend/uv.lock backend/app/core/use_cases/pair_iot_device.py backend/app/infrastructure/mqtt backend/app/api/schemas/iot_devices.py backend/app/api/routers/iot_devices.py backend/app/api/deps.py backend/app/main.py backend/tests/test_iot_pairing_use_case.py backend/tests/test_iot_devices_api.py
git commit -m "feat(api): adicionar pareamento de gadget iot"
```

---

### Task 3: Mobile Models, API Client, and Session

**Files:**
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/pubspec.lock`
- Create: `mobile/lib/shared/models/iot_device.dart`
- Create: `mobile/lib/shared/iot_device_session.dart`
- Modify: `mobile/lib/core/api/api_client.dart`
- Create: `mobile/test/iot_device_model_test.dart`
- Create: `mobile/test/iot_device_session_test.dart`
- Create: `mobile/test/api_client_iot_test.dart`

- [ ] **Step 1: Add scanner dependency**

Run:

```bash
cd mobile
flutter pub add mobile_scanner:^7.2.0
flutter pub get
```

Expected: `mobile/pubspec.yaml` includes `mobile_scanner: ^7.2.0`.

- [ ] **Step 2: Write QR parser tests**

Create `mobile/test/iot_device_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';

void main() {
  test('IotPairingPayload parses farol pair uri', () {
    final payload = IotPairingPayload.parse(
      'farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913',
    );

    expect(payload.deviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(payload.pairingCode, '482913');
  });

  test('IotPairingPayload rejects invalid scheme', () {
    expect(
      () => IotPairingPayload.parse('https://example.test/pair'),
      throwsA(isA<FormatException>()),
    );
  });

  test('IotDevice parses backend payload', () {
    final device = IotDevice.fromJson({
      'device_token': '550e8400-e29b-41d4-a716-446655440000',
      'status': 'linked',
      'linked_at': '2026-05-22T20:00:00Z',
      'updated_at': '2026-05-22T20:01:00Z',
      'last_seen_at': null,
    });

    expect(device.deviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(device.isLinked, isTrue);
  });
}
```

- [ ] **Step 3: Run parser tests and verify they fail**

Run:

```bash
cd mobile
flutter test test/iot_device_model_test.dart
```

Expected: FAIL with missing `shared/models/iot_device.dart`.

- [ ] **Step 4: Implement IoT models**

Create `mobile/lib/shared/models/iot_device.dart`:

```dart
class IotPairingPayload {
  final String deviceToken;
  final String pairingCode;

  const IotPairingPayload({
    required this.deviceToken,
    required this.pairingCode,
  });

  factory IotPairingPayload.parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'farol' || uri.host != 'pair') {
      throw const FormatException('QR Code do Farol invalido.');
    }
    final deviceToken = uri.queryParameters['device_token'];
    final pairingCode = uri.queryParameters['pairing_code'];
    final codePattern = RegExp(r'^[0-9]{6}$');
    if (deviceToken == null || deviceToken.isEmpty) {
      throw const FormatException('QR Code sem token do dispositivo.');
    }
    if (pairingCode == null || !codePattern.hasMatch(pairingCode)) {
      throw const FormatException('QR Code sem codigo de pareamento valido.');
    }
    return IotPairingPayload(
      deviceToken: deviceToken,
      pairingCode: pairingCode,
    );
  }
}

class IotDevice {
  final String deviceToken;
  final String status;
  final DateTime linkedAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;

  const IotDevice({
    required this.deviceToken,
    required this.status,
    required this.linkedAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  factory IotDevice.fromJson(Map<String, dynamic> json) {
    return IotDevice(
      deviceToken: json['device_token'] as String,
      status: json['status'] as String,
      linkedAt: DateTime.parse(json['linked_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
    );
  }

  String get shortToken {
    if (deviceToken.length <= 8) return deviceToken;
    return deviceToken.substring(0, 8).toUpperCase();
  }

  bool get isLinked => status == 'linked';
}
```

- [ ] **Step 5: Run parser tests**

Run:

```bash
cd mobile
flutter test test/iot_device_model_test.dart
```

Expected: PASS with 3 tests.

- [ ] **Step 6: Write API client tests**

Create `mobile/test/api_client_iot_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;

void main() {
  test('pairIotDevice sends anonymous header and pairing body', () async {
    final client = _CapturingClient({
      'device_token': '550e8400-e29b-41d4-a716-446655440000',
      'status': 'linked',
      'linked_at': '2026-05-22T20:00:00Z',
      'updated_at': '2026-05-22T20:00:00Z',
      'last_seen_at': null,
    });
    final api = ApiClient(baseUrl: 'https://example.test/api/v1', client: client);

    final device = await api.pairIotDevice(
      anonymousId: 'anon-1',
      deviceToken: '550e8400-e29b-41d4-a716-446655440000',
      pairingCode: '482913',
    );

    expect(device.deviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(client.lastMethod, 'PUT');
    expect(client.lastUri.toString(), 'https://example.test/api/v1/me/iot-device');
    expect(client.lastHeaders['X-Farol-Anonymous-Id'], 'anon-1');
    expect(client.lastBody, {
      'device_token': '550e8400-e29b-41d4-a716-446655440000',
      'pairing_code': '482913',
    });
  });

  test('fetchIotDevice returns null on 404', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: _StatusClient(404),
    );

    final device = await api.fetchIotDevice(anonymousId: 'anon-1');

    expect(device, isNull);
  });
}

class _CapturingClient extends http.BaseClient {
  final Map<String, dynamic> response;
  late Uri lastUri;
  late String lastMethod;
  late Map<String, String> lastHeaders;
  Map<String, dynamic>? lastBody;

  _CapturingClient(this.response);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    lastMethod = request.method;
    lastHeaders = request.headers;
    if (request is http.Request && request.body.isNotEmpty) {
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
    }
    final responseBytes = utf8.encode(jsonEncode(response));
    return http.StreamedResponse(
      Stream<List<int>>.value(responseBytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _StatusClient extends http.BaseClient {
  final int statusCode;

  _StatusClient(this.statusCode);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      statusCode,
    );
  }
}
```

- [ ] **Step 7: Add API client methods**

Modify `mobile/lib/core/api/api_client.dart` imports:

```dart
import '../../shared/models/iot_device.dart';
```

Add these methods before `_getJson`:

```dart
  Future<IotDevice?> fetchIotDevice({
    required String anonymousId,
  }) async {
    final uri = Uri.parse('$baseUrl/me/iot-device');
    final response = await _client.get(
      uri,
      headers: {'X-Farol-Anonymous-Id': anonymousId},
    );
    if (response.statusCode == 404) return null;
    final json = _decode(response) as Map<String, dynamic>;
    return IotDevice.fromJson(json);
  }

  Future<IotDevice> pairIotDevice({
    required String anonymousId,
    required String deviceToken,
    required String pairingCode,
  }) async {
    final uri = Uri.parse('$baseUrl/me/iot-device');
    final json = await _putJson(
      uri,
      {
        'device_token': deviceToken,
        'pairing_code': pairingCode,
      },
      headers: {'X-Farol-Anonymous-Id': anonymousId},
    ) as Map<String, dynamic>;
    return IotDevice.fromJson(json);
  }

  Future<void> deleteIotDevice({
    required String anonymousId,
  }) async {
    final uri = Uri.parse('$baseUrl/me/iot-device');
    final response = await _client.delete(
      uri,
      headers: {'X-Farol-Anonymous-Id': anonymousId},
    );
    _decode(response);
  }
```

- [ ] **Step 8: Run API client tests**

Run:

```bash
cd mobile
flutter test test/api_client_iot_test.dart
```

Expected: PASS with 2 tests.

- [ ] **Step 9: Write session tests**

Create `mobile/test/iot_device_session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';

class FakeApiClient extends ApiClient {
  String? fetchedAnonymousId;
  String? pairedAnonymousId;
  String? pairedDeviceToken;
  String? pairedCode;

  FakeApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<IotDevice?> fetchIotDevice({required String anonymousId}) async {
    fetchedAnonymousId = anonymousId;
    return null;
  }

  @override
  Future<IotDevice> pairIotDevice({
    required String anonymousId,
    required String deviceToken,
    required String pairingCode,
  }) async {
    pairedAnonymousId = anonymousId;
    pairedDeviceToken = deviceToken;
    pairedCode = pairingCode;
    return IotDevice(
      deviceToken: deviceToken,
      status: 'linked',
      linkedAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
      lastSeenAt: null,
    );
  }
}

class FakeDeviceIdentityStore extends DeviceIdentityStore {
  FakeDeviceIdentityStore() : super();

  @override
  Future<String> getOrCreateDeviceId() async => 'anon-1';
}

void main() {
  test('loadStatus uses persisted anonymous id', () async {
    final api = FakeApiClient();
    final session = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.loadStatus();

    expect(api.fetchedAnonymousId, 'anon-1');
    expect(session.device, isNull);
  });

  test('pairWithPayload stores linked device', () async {
    final api = FakeApiClient();
    final session = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.pairWithPayload(
      const IotPairingPayload(
        deviceToken: '550e8400-e29b-41d4-a716-446655440000',
        pairingCode: '482913',
      ),
    );

    expect(api.pairedAnonymousId, 'anon-1');
    expect(api.pairedDeviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(api.pairedCode, '482913');
    expect(session.device?.isLinked, isTrue);
  });
}
```

- [ ] **Step 10: Implement session**

Create `mobile/lib/shared/iot_device_session.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/device/device_identity_store.dart';
import 'models/iot_device.dart';

class IotDeviceSession extends ChangeNotifier {
  IotDeviceSession._({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  })  : api = api ?? ApiClient(),
        deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  @visibleForTesting
  factory IotDeviceSession.testOnly({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  }) =>
      IotDeviceSession._(
        api: api,
        deviceIdentityStore: deviceIdentityStore,
      );

  static final IotDeviceSession instance = IotDeviceSession._();

  final ApiClient api;
  final DeviceIdentityStore deviceIdentityStore;
  IotDevice? device;
  bool loading = false;
  String? error;

  Future<void> loadStatus() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      device = await api.fetchIotDevice(anonymousId: anonymousId);
    } catch (err) {
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> pairWithPayload(IotPairingPayload payload) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      device = await api.pairIotDevice(
        anonymousId: anonymousId,
        deviceToken: payload.deviceToken,
        pairingCode: payload.pairingCode,
      );
    } catch (err) {
      error = err.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 11: Run mobile model/API/session tests**

Run:

```bash
cd mobile
flutter test test/iot_device_model_test.dart test/api_client_iot_test.dart test/iot_device_session_test.dart
```

Expected: PASS.

- [ ] **Step 12: Commit mobile foundation**

Run:

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/shared/models/iot_device.dart mobile/lib/shared/iot_device_session.dart mobile/lib/core/api/api_client.dart mobile/test/iot_device_model_test.dart mobile/test/api_client_iot_test.dart mobile/test/iot_device_session_test.dart
git commit -m "feat(app): adicionar base de pareamento iot"
```

---

### Task 4: Mobile IoT UI and Routes

**Files:**
- Create: `mobile/lib/features/iot/iot_device_page.dart`
- Create: `mobile/lib/features/iot/iot_pairing_page.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/features/home/home_page.dart`
- Modify: `mobile/ios/Runner/Info.plist`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Create: `mobile/test/iot_device_page_test.dart`
- Modify: `mobile/test/widget_test.dart`

- [ ] **Step 1: Write UI tests**

Create `mobile/test/iot_device_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/features/iot/iot_device_page.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';

void main() {
  testWidgets('shows disconnected state and connect action', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final session = IotDeviceSession.testOnly();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/iot-pairing': (_) => const SizedBox()},
        home: IotDevicePage(session: session),
      ),
    );
    await tester.pump();

    expect(find.text('MEU FAROL'), findsOneWidget);
    expect(find.text('Nenhum Farol conectado.'), findsOneWidget);
    expect(find.text('CONECTAR FAROL'), findsOneWidget);
  });

  testWidgets('shows linked status', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final session = IotDeviceSession.testOnly()
      ..device = IotDevice(
        deviceToken: '550e8400-e29b-41d4-a716-446655440000',
        status: 'linked',
        linkedAt: DateTime(2026, 5, 22),
        updatedAt: DateTime(2026, 5, 22),
        lastSeenAt: null,
      );

    await tester.pumpWidget(
      MaterialApp(home: IotDevicePage(session: session)),
    );

    expect(find.text('Farol conectado'), findsOneWidget);
    expect(find.text('550E8400'), findsOneWidget);
  });
}
```

Modify `mobile/test/widget_test.dart` to also expect the Home entry:

```dart
expect(find.text('MEU FAROL'), findsOneWidget);
```

- [ ] **Step 2: Run UI tests and verify they fail**

Run:

```bash
cd mobile
flutter test test/iot_device_page_test.dart test/widget_test.dart
```

Expected: FAIL because `IotDevicePage` and the Home button do not exist.

- [ ] **Step 3: Implement IoT status page**

Create `mobile/lib/features/iot/iot_device_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/iot_device_session.dart';

class IotDevicePage extends StatefulWidget {
  final IotDeviceSession? session;

  const IotDevicePage({super.key, this.session});

  @override
  State<IotDevicePage> createState() => _IotDevicePageState();
}

class _IotDevicePageState extends State<IotDevicePage> {
  late final IotDeviceSession _session =
      widget.session ?? IotDeviceSession.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_session.loadStatus());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'FAROL POLITICO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      body: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          final device = _session.device;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(width: 4, height: 40, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Text('MEU\nFAROL', style: textTheme.headlineLarge),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_session.loading) const LinearProgressIndicator(minHeight: 2),
                  if (_session.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_session.error!, style: textTheme.bodySmall),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: device == null
                        ? _DisconnectedState(onConnect: _openPairing)
                        : _LinkedState(shortToken: device.shortToken),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPairing() async {
    await Navigator.pushNamed(context, '/iot-pairing');
    if (mounted) unawaited(_session.loadStatus());
  }
}

class _DisconnectedState extends StatelessWidget {
  final VoidCallback onConnect;

  const _DisconnectedState({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nenhum Farol conectado.', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Coloque o gadget em modo de pareamento e escaneie o QR exibido na tela.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onConnect,
            child: const Text('CONECTAR FAROL'),
          ),
        ),
      ],
    );
  }
}

class _LinkedState extends StatelessWidget {
  final String shortToken;

  const _LinkedState({required this.shortToken});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Farol conectado', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(shortToken, style: textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(
          'Este app esta vinculado ao gadget fisico.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement pairing page**

Create `mobile/lib/features/iot/iot_pairing_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/layout/app_scaffold.dart';
import '../../shared/iot_device_session.dart';
import '../../shared/models/iot_device.dart';

class IotPairingPage extends StatefulWidget {
  final IotDeviceSession? session;

  const IotPairingPage({super.key, this.session});

  @override
  State<IotPairingPage> createState() => _IotPairingPageState();
}

class _IotPairingPageState extends State<IotPairingPage> {
  late final IotDeviceSession _session =
      widget.session ?? IotDeviceSession.instance;
  final _manualController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _pairFromRaw(String raw) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = IotPairingPayload.parse(raw);
      await _session.pairWithPayload(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farol conectado.')),
      );
      Navigator.pop(context);
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'CONECTAR FAROL',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: ClipRect(
                child: MobileScanner(
                  onDetect: (capture) {
                    String? raw;
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        raw = barcode.rawValue;
                        break;
                      }
                    }
                    if (raw != null) _pairFromRaw(raw);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('CODIGO MANUAL', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _manualController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'farol://pair?...',
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () => _pairFromRaw(_manualController.text),
                child: Text(_submitting ? 'CONECTANDO' : 'CONECTAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Register routes and Home entry**

Modify `mobile/lib/app.dart` imports:

```dart
import 'features/iot/iot_device_page.dart';
import 'features/iot/iot_pairing_page.dart';
```

Add routes:

```dart
'/iot-device': (context) => const IotDevicePage(),
'/iot-pairing': (context) => const IotPairingPage(),
```

Modify `mobile/lib/features/home/home_page.dart` after the followed-politician button:

```dart
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/iot-device');
                              },
                              child: const Text('MEU FAROL'),
                            ),
                          ),
```

- [ ] **Step 6: Add camera permissions**

In `mobile/ios/Runner/Info.plist`, add inside `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>O app usa a camera para escanear o QR Code exibido no Farol fisico.</string>
```

In `mobile/android/app/src/main/AndroidManifest.xml`, add before `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 7: Run UI tests**

Run:

```bash
cd mobile
flutter test test/iot_device_page_test.dart test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 8: Run mobile verification**

Run:

```bash
cd mobile
flutter analyze
flutter test
```

Expected: analyze PASS and all tests PASS.

- [ ] **Step 9: Commit mobile UI**

Run:

```bash
git add mobile/lib/features/iot mobile/lib/app.dart mobile/lib/features/home/home_page.dart mobile/ios/Runner/Info.plist mobile/android/app/src/main/AndroidManifest.xml mobile/test/iot_device_page_test.dart mobile/test/widget_test.dart
git commit -m "feat(app): adicionar tela meu farol"
```

---

### Task 5: ESP32 Firmware Project

**Files:**
- Create: `firmware/esp32/platformio.ini`
- Create: `firmware/esp32/include/config.h`
- Create: `firmware/esp32/include/secrets.h.example`
- Create: `firmware/esp32/src/main.cpp`
- Create: `firmware/esp32/lib/DeviceToken/DeviceToken.h`
- Create: `firmware/esp32/lib/DeviceToken/DeviceToken.cpp`
- Create: `firmware/esp32/lib/WifiManager/WifiManager.h`
- Create: `firmware/esp32/lib/WifiManager/WifiManager.cpp`
- Create: `firmware/esp32/lib/MqttClient/MqttClient.h`
- Create: `firmware/esp32/lib/MqttClient/MqttClient.cpp`
- Create: `firmware/esp32/lib/PayloadParser/PayloadParser.h`
- Create: `firmware/esp32/lib/PayloadParser/PayloadParser.cpp`
- Create: `firmware/esp32/lib/LedStatus/LedStatus.h`
- Create: `firmware/esp32/lib/LedStatus/LedStatus.cpp`
- Create: `firmware/esp32/lib/DisplayUart/DisplayUart.h`
- Create: `firmware/esp32/lib/DisplayUart/DisplayUart.cpp`
- Create: `firmware/esp32/lib/PairingClient/PairingClient.h`
- Create: `firmware/esp32/lib/PairingClient/PairingClient.cpp`

- [ ] **Step 1: Create ESP32 PlatformIO config**

Create `firmware/esp32/platformio.ini`:

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps =
    knolleary/PubSubClient@^2.8
    bblanchon/ArduinoJson@^7.0
build_flags =
    -DCORE_DEBUG_LEVEL=0
```

- [ ] **Step 2: Create ESP32 config and secrets template**

Create `firmware/esp32/include/config.h`:

```cpp
#pragma once

#define API_BASE_URL      "https://farol-politico-api-ia6m2uvoba-uk.a.run.app/api/v1"
#define MQTT_BROKER       "broker.hivemq.com"
#define MQTT_PORT         8883
#define MQTT_TOPIC_PREFIX "farol/"

#define UART_BAUD         115200
#define UART_RX_PIN       16
#define UART_TX_PIN       17

#define LED_PIN_R         25
#define LED_PIN_G         26
#define LED_PIN_B         27
#define BUTTON_PIN        4

#define NVS_NAMESPACE     "farol"
#define NVS_TOKEN_KEY     "device_token"

#define PAIRING_CODE_MIN  100000
#define PAIRING_CODE_MAX  999999
#define PAIRING_DEBOUNCE_MS 50
#define PAIRING_HOLD_MS   1500
```

Create `firmware/esp32/include/secrets.h.example`:

```cpp
#pragma once

#define WIFI_SSID     "your-network-name"
#define WIFI_PASSWORD "your-network-password"
```

- [ ] **Step 3: Implement DeviceToken**

Create `firmware/esp32/lib/DeviceToken/DeviceToken.h`:

```cpp
#pragma once
#include <Arduino.h>

String getOrCreateDeviceToken();
```

Create `firmware/esp32/lib/DeviceToken/DeviceToken.cpp`:

```cpp
#include "DeviceToken.h"
#include <Preferences.h>
#include <esp_random.h>
#include "config.h"

static String generateUuidV4() {
    uint8_t raw[16];
    esp_fill_random(raw, sizeof(raw));
    raw[6] = (raw[6] & 0x0F) | 0x40;
    raw[8] = (raw[8] & 0x3F) | 0x80;

    char buf[37];
    snprintf(buf, sizeof(buf),
        "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
        raw[0], raw[1], raw[2], raw[3],
        raw[4], raw[5],
        raw[6], raw[7],
        raw[8], raw[9],
        raw[10], raw[11], raw[12], raw[13], raw[14], raw[15]);
    return String(buf);
}

String getOrCreateDeviceToken() {
    Preferences prefs;
    prefs.begin(NVS_NAMESPACE, false);
    String token = prefs.getString(NVS_TOKEN_KEY, "");
    if (token.isEmpty()) {
        token = generateUuidV4();
        prefs.putString(NVS_TOKEN_KEY, token);
        Serial.println("[DeviceToken] Novo token gerado: " + token);
    } else {
        Serial.println("[DeviceToken] Token recuperado: " + token);
    }
    prefs.end();
    return token;
}
```

- [ ] **Step 4: Implement WiFi manager**

Create `firmware/esp32/lib/WifiManager/WifiManager.h`:

```cpp
#pragma once
#include <Arduino.h>

bool connectWiFi(const char* ssid, const char* password, uint32_t timeoutMs = 20000);
```

Create `firmware/esp32/lib/WifiManager/WifiManager.cpp`:

```cpp
#include "WifiManager.h"
#include <WiFi.h>

bool connectWiFi(const char* ssid, const char* password, uint32_t timeoutMs) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    Serial.print("[WiFi] Conectando");
    const uint32_t start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
        delay(500);
        Serial.print(".");
    }
    Serial.println();
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WiFi] Falha na conexao.");
        return false;
    }
    Serial.println("[WiFi] Conectado. IP: " + WiFi.localIP().toString());
    return true;
}
```

- [ ] **Step 5: Implement LED status**

Create `firmware/esp32/lib/LedStatus/LedStatus.h`:

```cpp
#pragma once
#include <Arduino.h>
#include "config.h"

enum LedColor { GREEN, YELLOW, RED, BLUE };

void initLed();
void setLed(LedColor color);
void updateLed();
LedColor ledColorFromString(const String& color);
```

Create `firmware/esp32/lib/LedStatus/LedStatus.cpp`:

```cpp
#include "LedStatus.h"

static LedColor currentColor = BLUE;

void initLed() {
    pinMode(LED_PIN_R, OUTPUT);
    pinMode(LED_PIN_G, OUTPUT);
    pinMode(LED_PIN_B, OUTPUT);
    setLed(BLUE);
}

void setLed(LedColor color) {
    currentColor = color;
    switch (color) {
        case GREEN:
            analogWrite(LED_PIN_R, 0);
            analogWrite(LED_PIN_G, 255);
            analogWrite(LED_PIN_B, 0);
            break;
        case YELLOW:
            analogWrite(LED_PIN_R, 255);
            analogWrite(LED_PIN_G, 200);
            analogWrite(LED_PIN_B, 0);
            break;
        case RED:
            analogWrite(LED_PIN_R, 255);
            analogWrite(LED_PIN_G, 0);
            analogWrite(LED_PIN_B, 0);
            break;
        case BLUE:
            analogWrite(LED_PIN_R, 0);
            analogWrite(LED_PIN_G, 0);
            break;
    }
}

void updateLed() {
    if (currentColor != BLUE) return;
    uint32_t t = millis() % 1000;
    uint8_t b = (t < 500)
        ? static_cast<uint8_t>(t * 255 / 500)
        : static_cast<uint8_t>((1000 - t) * 255 / 500);
    analogWrite(LED_PIN_B, b);
}

LedColor ledColorFromString(const String& color) {
    if (color == "green") return GREEN;
    if (color == "yellow") return YELLOW;
    if (color == "red") return RED;
    return BLUE;
}
```

- [ ] **Step 6: Implement payload parser**

Create `firmware/esp32/lib/PayloadParser/PayloadParser.h`:

```cpp
#pragma once
#include <Arduino.h>

struct FarolEvent {
    String type;
    String color;
    String deputyName;
    String voteSummary;
    String timestampUtc;
};

bool parseFarolEvent(const char* json, FarolEvent& out);
```

Create `firmware/esp32/lib/PayloadParser/PayloadParser.cpp`:

```cpp
#include "PayloadParser.h"
#include <ArduinoJson.h>

bool parseFarolEvent(const char* json, FarolEvent& out) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, json);
    if (err) {
        Serial.print("[Parser] JSON invalido: ");
        Serial.println(err.c_str());
        return false;
    }

    if (!doc["color"].is<const char*>() ||
        !doc["deputy_name"].is<const char*>() ||
        !doc["vote_summary"].is<const char*>() ||
        !doc["timestamp_utc"].is<const char*>()) {
        Serial.println("[Parser] Campos obrigatorios ausentes.");
        return false;
    }

    out.type = doc["type"].is<const char*>() ? doc["type"].as<String>() : "vote_event";
    out.color = doc["color"].as<String>();
    out.deputyName = doc["deputy_name"].as<String>();
    out.voteSummary = doc["vote_summary"].as<String>();
    out.timestampUtc = doc["timestamp_utc"].as<String>();
    return true;
}
```

- [ ] **Step 7: Implement Display UART**

Create `firmware/esp32/lib/DisplayUart/DisplayUart.h`:

```cpp
#pragma once
#include <Arduino.h>
#include "PayloadParser.h"

void initDisplayUart();
void sendEventToDisplay(const FarolEvent& event);
void sendPairingToDisplay(const String& title, const String& qrPayload, const String& code);
void sendStatusToDisplay(const String& title, const String& line1, const String& line2);
```

Create `firmware/esp32/lib/DisplayUart/DisplayUart.cpp`:

```cpp
#include "DisplayUart.h"
#include "config.h"

static String sanitize(const String& value) {
    String out = value;
    out.replace("|", "/");
    return out;
}

static String utf8ToLatin1(const String& s) {
    String out;
    const uint8_t* p = reinterpret_cast<const uint8_t*>(s.c_str());
    while (*p) {
        if (*p < 0x80) {
            out += static_cast<char>(*p++);
        } else if (*p == 0xC2 && *(p + 1) >= 0x80 && *(p + 1) <= 0xBF) {
            out += static_cast<char>(*(p + 1));
            p += 2;
        } else if (*p == 0xC3 && *(p + 1) >= 0x80 && *(p + 1) <= 0xBF) {
            out += static_cast<char>(*(p + 1) + 0x40);
            p += 2;
        } else {
            out += '?';
            p++;
        }
    }
    return out;
}

static void wrapText(const String& text, String lines[3], int maxLen = 28) {
    String remaining = text;
    for (int i = 0; i < 3; i++) {
        if (remaining.length() == 0) {
            lines[i] = "";
        } else if (static_cast<int>(remaining.length()) <= maxLen) {
            lines[i] = remaining;
            remaining = "";
        } else {
            int cut = maxLen;
            while (cut > 0 && remaining.charAt(cut) != ' ') cut--;
            if (cut == 0) cut = maxLen;
            lines[i] = remaining.substring(0, cut);
            remaining = remaining.substring(cut);
            remaining.trim();
        }
    }
}

static String colorLabel(const String& color) {
    if (color == "green") return "CONECTADO";
    if (color == "yellow") return "ABSTENCAO";
    if (color == "red") return "DIVERGENTE";
    return "PENDENTE";
}

static String formatTimestamp(const String& ts) {
    if (ts.length() < 16) return ts;
    return ts.substring(8, 10) + "/" + ts.substring(5, 7) + " " +
           ts.substring(11, 13) + ":" + ts.substring(14, 16);
}

void initDisplayUart() {
    Serial2.begin(UART_BAUD, SERIAL_8N1, UART_RX_PIN, UART_TX_PIN);
}

void sendStatusToDisplay(const String& title, const String& line1, const String& line2) {
    String frame = "V|" + sanitize(title) + "|||INFO|" +
                   sanitize(line1) + "|" + sanitize(line2) + "||\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

void sendEventToDisplay(const FarolEvent& event) {
    String summary = sanitize(utf8ToLatin1(event.voteSummary));
    String lines[3];
    wrapText(summary, lines);
    String frame = "V|" + sanitize(utf8ToLatin1(event.deputyName)) + "|" +
                   colorLabel(event.color) + "|1/1|" + event.color + "|" +
                   lines[0] + "|" + lines[1] + "|" + lines[2] + "|" +
                   formatTimestamp(event.timestampUtc) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}

void sendPairingToDisplay(const String& title, const String& qrPayload, const String& code) {
    String frame = "Q|" + sanitize(title) + "|" + sanitize(qrPayload) + "|" +
                   sanitize(code) + "\n";
    Serial2.print(frame);
    Serial.print("[UART] " + frame);
}
```

- [ ] **Step 8: Implement MQTT client**

Create `firmware/esp32/lib/MqttClient/MqttClient.h`:

```cpp
#pragma once
#include <Arduino.h>
#include <PubSubClient.h>

using MqttMessageCallback = void (*)(char* topic, byte* payload, unsigned int length);

void mqttInit(const String& topic, MqttMessageCallback callback);
void mqttLoop();
```

Create `firmware/esp32/lib/MqttClient/MqttClient.cpp`:

```cpp
#include "MqttClient.h"
#include "config.h"
#include <WiFiClientSecure.h>
#include <esp_random.h>

static WiFiClientSecure wifiClient;
static PubSubClient client(wifiClient);
static String topic;
static MqttMessageCallback userCallback = nullptr;

static void dispatch(char* incomingTopic, byte* payload, unsigned int length) {
    if (userCallback) userCallback(incomingTopic, payload, length);
}

static void reconnect() {
    while (!client.connected()) {
        Serial.print("[MQTT] Conectando...");
        char clientId[24];
        snprintf(clientId, sizeof(clientId), "farol-%08lx", static_cast<unsigned long>(esp_random()));
        if (client.connect(clientId)) {
            client.subscribe(topic.c_str());
            Serial.println("[MQTT] Conectado em " + topic);
        } else {
            Serial.print("[MQTT] Falhou rc=");
            Serial.println(client.state());
            delay(5000);
        }
    }
}

void mqttInit(const String& subscribeTopic, MqttMessageCallback callback) {
    topic = subscribeTopic;
    userCallback = callback;
    wifiClient.setInsecure();
    client.setServer(MQTT_BROKER, MQTT_PORT);
    client.setCallback(dispatch);
    reconnect();
}

void mqttLoop() {
    if (!client.connected()) reconnect();
    client.loop();
}
```

- [ ] **Step 9: Implement pairing client**

Create `firmware/esp32/lib/PairingClient/PairingClient.h`:

```cpp
#pragma once
#include <Arduino.h>

struct PairingSessionResponse {
    bool ok;
    String qrPayload;
    String pairingCode;
};

String generatePairingCode();
PairingSessionResponse createPairingSession(const String& deviceToken, const String& pairingCode);
```

Create `firmware/esp32/lib/PairingClient/PairingClient.cpp`:

```cpp
#include "PairingClient.h"
#include "config.h"
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <esp_random.h>

String generatePairingCode() {
    uint32_t value = PAIRING_CODE_MIN + (esp_random() % (PAIRING_CODE_MAX - PAIRING_CODE_MIN + 1));
    char code[7];
    snprintf(code, sizeof(code), "%06lu", static_cast<unsigned long>(value));
    return String(code);
}

PairingSessionResponse createPairingSession(const String& deviceToken, const String& pairingCode) {
    WiFiClientSecure client;
    client.setInsecure();
    HTTPClient http;
    String url = String(API_BASE_URL) + "/iot-devices/" + deviceToken + "/pairing-session";
    http.begin(client, url);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Accept", "application/json");

    JsonDocument body;
    body["pairing_code"] = pairingCode;
    body["firmware_version"] = "0.1.0";
    String serialized;
    serializeJson(body, serialized);

    int code = http.POST(serialized);
    if (code != 201) {
        Serial.print("[Pairing] HTTP ");
        Serial.println(code);
        http.end();
        return {false, "", pairingCode};
    }

    String payload = http.getString();
    http.end();
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc["qr_payload"].is<const char*>()) {
        Serial.println("[Pairing] Resposta invalida.");
        return {false, "", pairingCode};
    }
    return {true, doc["qr_payload"].as<String>(), pairingCode};
}
```

- [ ] **Step 10: Implement main orchestration**

Create `firmware/esp32/src/main.cpp`:

```cpp
#include <Arduino.h>
#include "config.h"
#include "secrets.h"
#include "DeviceToken.h"
#include "WifiManager.h"
#include "MqttClient.h"
#include "PayloadParser.h"
#include "LedStatus.h"
#include "DisplayUart.h"
#include "PairingClient.h"

static String deviceToken;
static String mqttTopic;
static bool previousButtonState = HIGH;
static uint32_t buttonPressedAt = 0;

static void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    char buffer[length + 1];
    memcpy(buffer, payload, length);
    buffer[length] = '\0';

    FarolEvent event;
    if (!parseFarolEvent(buffer, event)) {
        return;
    }
    setLed(ledColorFromString(event.color));
    sendEventToDisplay(event);
}

static void startPairing() {
    setLed(BLUE);
    sendStatusToDisplay("Pareamento", "Registrando sessao", "Aguarde...");
    String code = generatePairingCode();
    PairingSessionResponse response = createPairingSession(deviceToken, code);
    if (!response.ok) {
        setLed(YELLOW);
        sendStatusToDisplay("Erro", "Falha ao parear", "Tente novamente");
        return;
    }
    sendPairingToDisplay("Conectar Farol", response.qrPayload, response.pairingCode);
}

static void handleButton() {
    bool current = digitalRead(BUTTON_PIN);
    if (previousButtonState == HIGH && current == LOW) {
        buttonPressedAt = millis();
    }
    if (previousButtonState == LOW && current == HIGH) {
        uint32_t duration = millis() - buttonPressedAt;
        if (duration >= PAIRING_HOLD_MS) {
            startPairing();
        }
    }
    previousButtonState = current;
}

void setup() {
    Serial.begin(UART_BAUD);
    initDisplayUart();
    initLed();
    pinMode(BUTTON_PIN, INPUT_PULLUP);

    deviceToken = getOrCreateDeviceToken();
    mqttTopic = String(MQTT_TOPIC_PREFIX) + deviceToken;
    Serial.println("[Farol] Device token: " + deviceToken);

    sendStatusToDisplay("Iniciando", "Conectando WiFi", WIFI_SSID);
    if (!connectWiFi(WIFI_SSID, WIFI_PASSWORD)) {
        setLed(YELLOW);
        sendStatusToDisplay("Falha WiFi", "Verifique rede", "Reinicie");
        return;
    }

    sendStatusToDisplay("WiFi OK", "Conectando MQTT", mqttTopic);
    mqttInit(mqttTopic, onMqttMessage);
    sendStatusToDisplay("Aguardando", "Segure o botao", "para parear");
}

void loop() {
    handleButton();
    mqttLoop();
    updateLed();
}
```

- [ ] **Step 11: Build ESP32 firmware**

Run:

```bash
pio run --project-dir firmware/esp32
```

Expected: Build succeeds for `esp32dev`.

- [ ] **Step 12: Commit ESP32 firmware**

Run:

```bash
git add firmware/esp32
git commit -m "feat(firmware): adicionar firmware esp32 do farol"
```

---

### Task 6: Arduino Mega Firmware Project

**Files:**
- Create: `firmware/mega/platformio.ini`
- Create: `firmware/mega/src/main.cpp`

- [ ] **Step 1: Create Mega PlatformIO config**

Create `firmware/mega/platformio.ini`:

```ini
[env:megaatmega2560]
platform = atmelavr
board = megaatmega2560
framework = arduino
monitor_speed = 115200
lib_deps =
    adafruit/Adafruit GFX Library@^1.12.4
    prenticedavid/MCUFRIEND_kbv@^3.0.0
    https://github.com/ricmoo/QRCode.git
```

- [ ] **Step 2: Create Mega renderer**

Create `firmware/mega/src/main.cpp`:

```cpp
#include <Adafruit_GFX.h>
#include <MCUFRIEND_kbv.h>
#include <qrcode.h>

MCUFRIEND_kbv tft;

#define BLACK   0x0000
#define WHITE   0xFFFF
#define BLUE    0x041F
#define YELLOW  0xFFE0
#define GRAY    0x4208
#define GREEN   0x07E0
#define RED     0xF800

static uint16_t statusColor(const String& status) {
    if (status == "green" || status == "CONECTADO") return GREEN;
    if (status == "red" || status == "DIVERGENTE") return RED;
    if (status == "yellow" || status == "ABSTENCAO") return YELLOW;
    return GRAY;
}

static void splitFields(const String& msg, String fields[], int maxFields, int start) {
    int index = 0;
    int begin = start;
    for (int i = start; i < static_cast<int>(msg.length()) && index < maxFields - 1; i++) {
        if (msg[i] == '|') {
            fields[index++] = msg.substring(begin, i);
            begin = i + 1;
        }
    }
    if (index < maxFields) {
        fields[index] = msg.substring(begin);
    }
}

static void showEventScreen(
    const String& header,
    const String& subtitle,
    const String& pageInfo,
    const String& status,
    const String& l1,
    const String& l2,
    const String& l3,
    const String& l4
) {
    tft.fillScreen(BLACK);
    tft.fillRect(0, 0, 480, 45, BLUE);
    tft.setTextColor(WHITE);
    tft.setTextSize(3);
    tft.setCursor(10, 12);
    tft.print(header);

    if (pageInfo.length() > 0) {
        tft.setTextSize(2);
        int x = 480 - (pageInfo.length() * 12) - 10;
        tft.setCursor(x, 17);
        tft.print(pageInfo);
    }

    if (subtitle.length() > 0) {
        tft.setTextColor(YELLOW);
        tft.setTextSize(2);
        tft.setCursor(10, 55);
        tft.print(subtitle);
    }

    if (status.length() > 0) {
        uint16_t color = statusColor(status);
        int width = status.length() * 14 + 16;
        tft.fillRoundRect(10, 82, width, 28, 4, color);
        tft.setTextColor((color == YELLOW || color == GREEN) ? BLACK : WHITE);
        tft.setTextSize(2);
        tft.setCursor(18, 89);
        tft.print(status);
    }

    tft.setTextColor(WHITE);
    tft.setTextSize(2);
    int y = 130;
    if (l1.length() > 0) { tft.setCursor(10, y); tft.print(l1); }
    y += 32;
    if (l2.length() > 0) { tft.setCursor(10, y); tft.print(l2); }
    y += 32;
    if (l3.length() > 0) { tft.setCursor(10, y); tft.print(l3); }
    y += 32;
    if (l4.length() > 0) { tft.setCursor(10, y); tft.print(l4); }
}

static void drawQr(const String& payload) {
    const uint8_t QR_VERSION = 10;
    QRCode qrcode;
    uint8_t qrcodeData[qrcode_getBufferSize(QR_VERSION)];
    qrcode_initText(&qrcode, qrcodeData, QR_VERSION, ECC_LOW, payload.c_str());

    int moduleSize = 4;
    int qrSize = qrcode.size * moduleSize;
    int startX = (480 - qrSize) / 2;
    int startY = 68;

    tft.fillRect(startX - 8, startY - 8, qrSize + 16, qrSize + 16, WHITE);
    for (uint8_t y = 0; y < qrcode.size; y++) {
        for (uint8_t x = 0; x < qrcode.size; x++) {
            uint16_t color = qrcode_getModule(&qrcode, x, y) ? BLACK : WHITE;
            tft.fillRect(startX + x * moduleSize, startY + y * moduleSize, moduleSize, moduleSize, color);
        }
    }
}

static void showPairingScreen(const String& title, const String& qrPayload, const String& code) {
    tft.fillScreen(BLACK);
    tft.fillRect(0, 0, 480, 45, BLUE);
    tft.setTextColor(WHITE);
    tft.setTextSize(3);
    tft.setCursor(10, 12);
    tft.print(title);

    drawQr(qrPayload);

    tft.setTextColor(YELLOW);
    tft.setTextSize(2);
    tft.setCursor(10, 290);
    tft.print("Codigo: ");
    tft.print(code);
}

void setup() {
    Serial.begin(115200);
    Serial1.begin(115200);

    tft.begin(0x9486);
    tft.setRotation(1);
    tft.fillScreen(BLACK);
    tft.setTextColor(WHITE);
    tft.setTextSize(3);
    tft.setCursor(10, 140);
    tft.print("Aguardando ESP32...");
    Serial.println("[Mega] pronto");
}

void loop() {
    if (!Serial1.available()) return;
    String msg = Serial1.readStringUntil('\n');
    msg.trim();
    Serial.print("[Mega] recebi: ");
    Serial.println(msg.substring(0, 80));

    if (msg.startsWith("V|")) {
        String fields[8];
        splitFields(msg, fields, 8, 2);
        showEventScreen(
            fields[0], fields[1], fields[2], fields[3],
            fields[4], fields[5], fields[6], fields[7]
        );
    } else if (msg.startsWith("Q|")) {
        String fields[3];
        splitFields(msg, fields, 3, 2);
        showPairingScreen(fields[0], fields[1], fields[2]);
    }
}
```

- [ ] **Step 3: Build Mega firmware**

Run:

```bash
pio run --project-dir firmware/mega
```

Expected: Build succeeds for `megaatmega2560`.

- [ ] **Step 4: Commit Mega firmware**

Run:

```bash
git add firmware/mega
git commit -m "feat(firmware): adicionar display mega do farol"
```

---

### Task 7: Firmware CI and Final Verification

**Files:**
- Create: `.github/workflows/firmware.yml`
- Modify: `README.md`

- [ ] **Step 1: Add firmware CI workflow**

Create `.github/workflows/firmware.yml`:

```yaml
name: Firmware

on:
  pull_request:
    branches: [main]
    paths:
      - 'firmware/**'
      - '.github/workflows/firmware.yml'

concurrency:
  group: firmware-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install PlatformIO
        run: pip install platformio

      - name: Build ESP32 firmware
        run: pio run --project-dir firmware/esp32

      - name: Build Mega firmware
        run: pio run --project-dir firmware/mega
```

- [ ] **Step 2: Update README firmware section**

Modify `README.md` after the Flutter run instructions:

````markdown
### Firmware

```bash
# ESP32
cp firmware/esp32/include/secrets.h.example firmware/esp32/include/secrets.h
# editar WIFI_SSID e WIFI_PASSWORD
pio run --project-dir firmware/esp32

# Arduino Mega
pio run --project-dir firmware/mega
```

O ESP32 gera um `device_token` persistente no primeiro boot, registra sessoes de pareamento no backend e assina `farol/{device_token}` via MQTT. O Mega recebe frames UART do ESP32 e renderiza telas `V|...` e QR de pareamento `Q|...`.
````

- [ ] **Step 3: Run full backend verification**

Run:

```bash
cd backend
uv run ruff check .
uv run mypy app/
uv run pytest
```

Expected: Ruff PASS, mypy PASS, pytest PASS with coverage above 80%.

- [ ] **Step 4: Run full mobile verification**

Run:

```bash
cd mobile
flutter analyze
flutter test
```

Expected: analyze PASS and all tests PASS.

- [ ] **Step 5: Run firmware builds**

Run:

```bash
pio run --project-dir firmware/esp32
pio run --project-dir firmware/mega
```

Expected: both builds PASS.

- [ ] **Step 6: Inspect final diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: only intended backend, mobile, firmware, CI, README files are changed.

- [ ] **Step 7: Commit CI and docs**

Run:

```bash
git add .github/workflows/firmware.yml README.md
git commit -m "ci(firmware): validar builds platformio"
```

---

## Self-Review Checklist

- Spec objective "QR on gadget display": covered by Task 5 `sendPairingToDisplay` and Task 6 `showPairingScreen`.
- Spec objective "mobile status and success": covered by Tasks 3 and 4.
- Spec objective "backend anonymous link": covered by Tasks 1 and 2.
- Spec objective "MQTT confirmation": covered by Task 2 `PahoIotMqttPublisher` and use-case tests.
- Spec objective "firmware based on sketches": covered by Tasks 5 and 6.
- Spec objective "no quiz/followed-politician changes": mobile/backend tasks add routes and Home entry only.
- Fatia 2 manual publish endpoint is not included in this plan; the approved spec made it a later slice.
- Fatia 3 Camara loop and alignment rule are not included in this plan; the approved spec made them later slices.
