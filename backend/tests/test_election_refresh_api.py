"""A live editorial refresh must be visible without restarting API instances."""

from app.api.cache import cache_delete_prefix
from app.infrastructure.database.models import (
    CandidateModel,
    CandidatePositionModel,
    ThesisModel,
)


def test_candidate_removal_reaches_warmed_list_and_profile(client, db_session, candidate_ids):
    candidate_id = candidate_ids["cand_a"]
    profile_url = f"/api/v1/candidates/{candidate_id}"
    assert client.get(profile_url).status_code == 200
    assert candidate_id in {item["id"] for item in client.get("/api/v1/candidates").json()["candidates"]}
    candidate = db_session.get(CandidateModel, candidate_id)
    try:
        candidate.is_active = False
        db_session.commit()
        assert client.get(profile_url).status_code == 404
        assert candidate_id not in {item["id"] for item in client.get("/api/v1/candidates").json()["candidates"]}
    finally:
        candidate.is_active = True
        db_session.commit()
        cache_delete_prefix("candidates:")


def test_archived_thesis_disappears_from_warmed_questions_and_themes(client, db_session, thesis_ids):
    question_url = "/api/v1/quiz/questions"
    before = client.get(question_url).json()["theses"]
    themes = client.get("/api/v1/themes").json()
    thesis = db_session.get(ThesisModel, thesis_ids["Tese 1"])
    old_count = next(item["total_teses_aprovadas"] for item in themes if item["id"] == thesis.theme_id)
    try:
        thesis.status = "archived"
        db_session.commit()
        after = client.get(question_url).json()["theses"]
        assert len(after) == len(before) - 1
        assert thesis.id not in {item["id"] for item in after}
        updated = client.get("/api/v1/themes").json()
        assert next(item["total_teses_aprovadas"] for item in updated if item["id"] == thesis.theme_id) == old_count - 1
    finally:
        thesis.status = "approved"
        db_session.commit()
        cache_delete_prefix("quiz:")
        cache_delete_prefix("themes:")


def test_corrected_evidence_reaches_warmed_positions_and_justifications(client, db_session, candidate_ids):
    candidate_id = candidate_ids["cand_a"]
    prefix = f"/api/v1/candidates/{candidate_id}"
    client.get(f"{prefix}/positions")
    client.get(f"{prefix}/justifications")
    position = db_session.query(CandidatePositionModel).filter_by(candidate_id=candidate_id).first()
    original = position.position, position.justification
    try:
        position.position = "discordo" if position.position != "discordo" else "concordo"
        position.justification = "Evidência corrigida na revisão editorial."
        db_session.commit()
        positions = client.get(f"{prefix}/positions").json()["positions"]
        assert next(item["position"] for item in positions if item["thesis_id"] == position.thesis_id) == position.position
        justifications = client.get(f"{prefix}/justifications").json()["justifications"]
        assert next(item["justification"] for item in justifications if item["thesis_id"] == position.thesis_id) == position.justification
    finally:
        position.position, position.justification = original
        db_session.commit()
        cache_delete_prefix("candidates:")
