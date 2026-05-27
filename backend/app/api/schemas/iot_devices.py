from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


class CreatePairingSessionIn(BaseModel):
    pairing_code: str = Field(pattern=r"^[0-9]{6}$")
    firmware_version: str | None = Field(default=None, max_length=32)


class PairingSessionOut(BaseModel):
    device_token: str
    pairing_code: str
    qr_payload: str
    expires_at: datetime


class PairIotDeviceIn(BaseModel):
    device_token: UUID | None = None
    device_token_prefix: str | None = Field(
        default=None,
        min_length=8,
        max_length=8,
        pattern=r"^[0-9a-fA-F]{8}$",
    )
    pairing_code: str = Field(pattern=r"^[0-9]{6}$")

    @field_validator("device_token")
    @classmethod
    def device_token_must_be_v4(cls, value: UUID | None) -> UUID | None:
        if value is not None and value.version != 4:
            raise ValueError("device_token must be a UUID v4")
        return value

    @field_validator("device_token_prefix")
    @classmethod
    def normalize_device_token_prefix(cls, value: str | None) -> str | None:
        return value.lower() if value is not None else None

    @model_validator(mode="after")
    def exactly_one_token_identifier(self) -> "PairIotDeviceIn":
        has_device_token = self.device_token is not None
        has_device_token_prefix = self.device_token_prefix is not None
        if has_device_token == has_device_token_prefix:
            raise ValueError(
                "Informe exatamente um de device_token ou device_token_prefix."
            )
        return self


class IotDeviceOut(BaseModel):
    device_token: str
    status: str
    linked_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None


class PairingStatusOut(BaseModel):
    paired: bool
    status: str
