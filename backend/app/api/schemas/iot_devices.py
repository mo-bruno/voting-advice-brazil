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
    def device_token_must_be_v4(cls, value: UUID) -> UUID:
        if value.version != 4:
            raise ValueError("device_token must be a UUID v4")
        return value


class IotDeviceOut(BaseModel):
    device_token: str
    status: str
    linked_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None
