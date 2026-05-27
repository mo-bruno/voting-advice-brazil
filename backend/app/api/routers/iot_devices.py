from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Response

from app.api.deps import (
    get_iot_device_event_repo,
    get_iot_device_link_repo,
    get_iot_mqtt_publisher,
    get_iot_pairing_session_repo,
)
from app.api.schemas.iot_devices import (
    CreatePairingSessionIn,
    IotDeviceOut,
    LastEventOut,
    PairingSessionOut,
    PairingStatusOut,
    PairIotDeviceIn,
    QuizPulseIn,
)
from app.core.entities.iot_device import IotDeviceLink
from app.core.use_cases.interfaces import IotMqttPublisher
from app.core.use_cases.pair_iot_device import (
    AmbiguousPairingCodeError,
    DeviceAlreadyLinkedError,
    InvalidPairingCodeError,
    create_pairing_session,
    get_iot_device_link,
    get_iot_device_link_by_token,
    pair_iot_device,
    resolve_pairing_device_token,
    unlink_iot_device,
)
from app.core.use_cases.quiz_pulse import publish_quiz_pulse
from app.infrastructure.database.iot_device_repositories import (
    SqlIotDeviceEventRepository,
    SqlIotDeviceLinkRepository,
    SqlIotPairingSessionRepository,
)

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
    status_code=201,
)
def create_session(
    device_token: UUID,
    body: CreatePairingSessionIn,
    repo: SqlIotPairingSessionRepository = Depends(get_iot_pairing_session_repo),
) -> PairingSessionOut:
    if device_token.version != 4:
        raise HTTPException(status_code=422, detail="device_token must be a UUID v4")

    session = create_pairing_session(
        repo,
        str(device_token),
        body.pairing_code,
        body.firmware_version,
        datetime.now(timezone.utc),
    )
    return PairingSessionOut(
        device_token=session.device_token,
        pairing_code=body.pairing_code,
        qr_payload=session.qr_payload,
        expires_at=session.expires_at,
    )


@router.get("/{device_token}/pairing-status", response_model=PairingStatusOut)
def get_pairing_status(
    device_token: UUID,
    repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
) -> PairingStatusOut:
    if device_token.version != 4:
        raise HTTPException(status_code=422, detail="device_token must be a UUID v4")

    link = get_iot_device_link_by_token(repo, str(device_token))
    if link is None:
        return PairingStatusOut(paired=False, status="unlinked")
    return PairingStatusOut(paired=True, status=link.status)


@me_router.get("/iot-device", response_model=IotDeviceOut)
def get_current_iot_device(
    x_farol_anonymous_id: AnonymousHeader,
    repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
) -> IotDeviceOut:
    link = get_iot_device_link(repo, x_farol_anonymous_id)
    if link is None:
        raise HTTPException(status_code=404, detail="Nenhum Farol conectado.")
    return _device_out(link)


@me_router.put("/iot-device", response_model=IotDeviceOut)
def pair_current_iot_device(
    body: PairIotDeviceIn,
    x_farol_anonymous_id: AnonymousHeader,
    link_repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
    session_repo: SqlIotPairingSessionRepository = Depends(
        get_iot_pairing_session_repo
    ),
    publisher: IotMqttPublisher = Depends(get_iot_mqtt_publisher),
) -> IotDeviceOut:
    now = datetime.now(timezone.utc)
    try:
        device_token = (
            str(body.device_token)
            if body.device_token is not None
            else resolve_pairing_device_token(
                session_repo,
                body.device_token_prefix or "",
                body.pairing_code,
                now,
            )
        )
        link = pair_iot_device(
            link_repo,
            session_repo,
            publisher,
            x_farol_anonymous_id,
            device_token,
            body.pairing_code,
            now,
        )
    except DeviceAlreadyLinkedError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except AmbiguousPairingCodeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except InvalidPairingCodeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _device_out(link)


@me_router.delete("/iot-device", status_code=204)
def delete_current_iot_device(
    x_farol_anonymous_id: AnonymousHeader,
    repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
) -> Response:
    unlink_iot_device(repo, x_farol_anonymous_id)
    return Response(status_code=204)


@me_router.post("/iot-device/quiz-pulse", status_code=204)
def quiz_pulse(
    body: QuizPulseIn,
    x_farol_anonymous_id: AnonymousHeader,
    link_repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
    publisher: IotMqttPublisher = Depends(get_iot_mqtt_publisher),
) -> Response:
    publish_quiz_pulse(
        anonymous_id=x_farol_anonymous_id,
        answer=body.answer,
        current=body.current,
        total=body.total,
        link_repo=link_repo,
        publisher=publisher,
    )
    return Response(status_code=204)


@me_router.get("/iot-device/last-event", response_model=LastEventOut)
def get_last_event(
    x_farol_anonymous_id: AnonymousHeader,
    link_repo: SqlIotDeviceLinkRepository = Depends(get_iot_device_link_repo),
    event_repo: SqlIotDeviceEventRepository = Depends(get_iot_device_event_repo),
) -> LastEventOut:
    link = get_iot_device_link(link_repo, x_farol_anonymous_id)
    if link is None:
        raise HTTPException(status_code=404, detail="Nenhum Farol conectado.")
    event = event_repo.get_latest(link.device_token, "vote_alert")
    if event is None:
        raise HTTPException(status_code=404, detail="Nenhum evento registrado.")
    p = event.payload
    return LastEventOut(
        deputy_name=str(p.get("deputy_name", "")),
        party=str(p.get("party", "")),
        state=str(p.get("state", "")),
        vote=str(p.get("vote", "")),
        alignment=str(p.get("alignment", "")),
        color=str(p.get("color", "")),
        description=str(p.get("description", "")),
        timestamp_utc=datetime.fromisoformat(str(p.get("timestamp_utc", ""))),
    )
