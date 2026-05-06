from sqlalchemy import text
from sqlalchemy.orm import Session


def _explain(db: Session, sql: str, **params: object) -> str:
    rows = db.execute(text(f"EXPLAIN QUERY PLAN {sql}"), params).all()
    return "\n".join(str(row) for row in rows).upper()


def test_political_actor_state_party_lookup_uses_index(
    db_session: Session,
) -> None:
    plan = _explain(
        db_session,
        "SELECT * FROM political_actors WHERE role = :role AND state = :state AND party = :party",
        role="federal_deputy",
        state="SP",
        party="PT",
    )
    assert "IX_POLITICAL_ACTORS_ROLE_STATE_PARTY" in plan or "USING INDEX" in plan


def test_followed_actor_lookup_uses_primary_key(db_session: Session) -> None:
    plan = _explain(
        db_session,
        "SELECT * FROM followed_actors WHERE anonymous_id = :anonymous_id",
        anonymous_id="anon-1",
    )
    assert "FOLLOWED_ACTORS" in plan and (
        "USING INDEX" in plan or "AUTO" in plan
    )
