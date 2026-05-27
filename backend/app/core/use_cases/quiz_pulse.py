from app.core.use_cases.interfaces import IotDeviceLinkRepository, IotMqttPublisher


def publish_quiz_pulse(
    anonymous_id: str,
    answer: str,
    current: int,
    total: int,
    link_repo: IotDeviceLinkRepository,
    publisher: IotMqttPublisher,
) -> None:
    link = link_repo.get_by_anonymous_id(anonymous_id)
    if link is None:
        return
    publisher.publish(
        topic=f"farol/{link.device_token}",
        payload={
            "type": "quiz_answer",
            "answer": answer,
            "current": str(current),
            "total": str(total),
        },
    )
