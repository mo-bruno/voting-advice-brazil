from sqlalchemy.exc import IntegrityError

from app.core.use_cases.submit_quiz import QuizAnswer
from app.infrastructure.database.models import QuizResponseModel
from app.infrastructure.database.repositories import SqlQuizResponseRepository


def test_upsert_answers_retries_once_after_integrity_error(
    db_session,
    monkeypatch,
    thesis_ids,
):
    device_id = "550e8400-e29b-41d4-a716-446655440004"
    thesis_id = thesis_ids["Tese 1"]
    repo = SqlQuizResponseRepository(db_session)
    original_commit = db_session.commit
    original_rollback = db_session.rollback
    calls: list[str] = []

    def flaky_commit() -> None:
        calls.append("commit")
        if calls.count("commit") == 1:
            raise IntegrityError("insert quiz response", {}, Exception("unique race"))
        original_commit()

    def tracked_rollback() -> None:
        calls.append("rollback")
        original_rollback()

    monkeypatch.setattr(db_session, "commit", flaky_commit)
    monkeypatch.setattr(db_session, "rollback", tracked_rollback)

    repo.upsert_answers(
        device_id,
        [QuizAnswer(thesis_id=thesis_id, answer="disagree", weight=2)],
    )

    assert calls == ["commit", "rollback", "commit"]
    row = (
        db_session.query(QuizResponseModel)
        .filter_by(device_id=device_id, thesis_id=thesis_id)
        .one()
    )
    assert row.answer == "disagree"
    assert row.weight == 2
