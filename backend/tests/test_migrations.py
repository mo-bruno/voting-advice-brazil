import os
import sqlite3
import subprocess
import sys
from pathlib import Path

from sqlalchemy import create_engine, inspect, text

BACKEND_DIR = Path(__file__).parent.parent


def _alembic(args: list[str], db_url: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["DATABASE_URL"] = db_url
    return subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=BACKEND_DIR,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_migration_up_and_down(tmp_path: Path) -> None:
    db_file = tmp_path / "test.db"
    db_url = f"sqlite:///{db_file}"

    up = _alembic(["upgrade", "head"], db_url)
    assert up.returncode == 0, up.stderr

    metadata_check = _alembic(["check"], db_url)
    assert metadata_check.returncode == 0, metadata_check.stdout + metadata_check.stderr

    down = _alembic(["downgrade", "base"], db_url)
    assert down.returncode == 0, down.stderr

    reup = _alembic(["upgrade", "head"], db_url)
    assert reup.returncode == 0, reup.stderr


def test_election_refresh_migration_preserves_existing_answers(tmp_path, monkeypatch):
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session

    from app.config import settings
    from app.infrastructure.database.models import (
        CandidateModel,
        QuizResponseModel,
        ThesisModel,
    )
    from app.infrastructure.database.seed import seed

    db_file = tmp_path / "populated.db"
    db_url = f"sqlite:///{db_file}"
    before = _alembic(["upgrade", "0008_comment_admission_locks"], db_url)
    assert before.returncode == 0, before.stderr
    with sqlite3.connect(db_file) as connection:
        connection.executescript("""
            INSERT INTO parties (id, acronym, name, number, created_at)
                VALUES (1, 'PT', 'Partido legado', 13, '2026-09-01');
            INSERT INTO themes (id, slug, name, area, sort_order)
                VALUES (1, 'economia', 'Economia', 'economica', 1);
            INSERT INTO candidates (id, external_id, name, party_id, office, election_year, election_round, created_at)
                VALUES (1, '2026-a', 'Candidata legada', 1, 'presidente', 2026, 1, '2026-09-01');
            INSERT INTO theses (id, text, theme_id, status, election_year, created_at)
                VALUES (1, 'O imposto sobre grandes fortunas deve ser regulamentado.', 1, 'approved', 2026, '2026-09-01');
            INSERT INTO candidate_positions (id, candidate_id, thesis_id, position, created_at)
                VALUES (1, 1, 1, 'concordo', '2026-09-01');
            INSERT INTO devices (id, created_at, last_seen_at)
                VALUES ('historical-device', '2026-09-01', '2026-09-01');
            INSERT INTO quiz_responses (id, device_id, thesis_id, answer, weight, election_year, created_at, updated_at)
                VALUES (1, 'historical-device', 1, 'agree', 1, 2026, '2026-09-01', '2026-09-01');
        """)
    upgraded = _alembic(["upgrade", "head"], db_url)
    assert upgraded.returncode == 0, upgraded.stderr
    monkeypatch.setattr(settings, "active_election_year", 2026)
    monkeypatch.setattr(settings, "data_dir", str(BACKEND_DIR / "tests/fixtures/election_2026/data"))
    with Session(create_engine(db_url)) as db:
        assert db.get(CandidateModel, 1).is_active is True
        seed(db)
        assert db.query(ThesisModel).count() == 1
        assert db.get(ThesisModel, 1).editorial_id == "T2026-001"
        answer = db.query(QuizResponseModel).one()
        assert (answer.id, answer.thesis_id, answer.answer) == (1, 1, "agree")


def test_iot_deduplication_upgrade_preserves_existing_event(tmp_path: Path) -> None:
    db_url = f"sqlite:///{tmp_path / 'existing-iot.db'}"
    before = _alembic(["upgrade", "0006_community_integrity"], db_url)
    assert before.returncode == 0, before.stderr
    engine = create_engine(db_url)
    with engine.begin() as connection:
        connection.execute(text("""
            INSERT INTO iot_device_events (id, device_token, event_type, payload, published_at)
            VALUES (1, 'old-device', 'vote_alert', '{"vote":"Sim"}', '2026-01-01 00:00:00')
        """))
    tables_before = set(inspect(engine).get_table_names())
    upgraded = _alembic(["upgrade", "head"], db_url)
    assert upgraded.returncode == 0, upgraded.stderr
    assert set(inspect(engine).get_table_names()) == tables_before | {"comment_admission_locks"}
    constraints = inspect(engine).get_unique_constraints("iot_device_events")
    assert {"name": "uq_iot_events_delivery", "column_names": [
        "device_token", "event_type", "deduplication_key",
    ]} in constraints
    with engine.connect() as connection:
        row = connection.execute(text("""
            SELECT device_token, event_type, payload, deduplication_key
            FROM iot_device_events WHERE id = 1
        """)).one()
        assert tuple(row) == ("old-device", "vote_alert", '{"vote":"Sim"}', None)
        assert connection.scalar(text("SELECT version_num FROM alembic_version")) == (
            "0009_election_refresh"
        )
    engine.dispose()


def test_comment_admission_upgrade_preserves_comments(tmp_path: Path) -> None:
    db_url = f"sqlite:///{tmp_path / 'existing-comments.db'}"
    before = _alembic(["upgrade", "0007_iot_event_deduplication"], db_url)
    assert before.returncode == 0, before.stderr
    engine = create_engine(db_url)
    with engine.begin() as connection:
        connection.execute(text("""
            INSERT INTO posts (id, anonymous_id, content, score, created_at)
            VALUES ('old-post', 'old-author', 'Política', 3, '2026-09-09 12:00:00')
        """))
        connection.execute(text("""
            INSERT INTO comments (id, post_id, anonymous_id, content, created_at)
            VALUES ('old-comment', 'old-post', 'old-author', 'Concordo', '2026-09-09 12:01:00')
        """))
    tables_before = set(inspect(engine).get_table_names())
    upgraded = _alembic(["upgrade", "head"], db_url)
    assert upgraded.returncode == 0, upgraded.stderr
    assert set(inspect(engine).get_table_names()) == tables_before | {"comment_admission_locks"}
    assert inspect(engine).get_pk_constraint("comment_admission_locks")["constrained_columns"] == ["anonymous_id"]
    with engine.connect() as connection:
        assert tuple(connection.execute(text("SELECT * FROM comments")).one()) == (
            "old-comment", "old-post", "old-author", "Concordo", "2026-09-09 12:01:00",
        )
        assert connection.scalar(text("SELECT COUNT(*) FROM comment_admission_locks")) == 0
        assert connection.scalar(text("SELECT version_num FROM alembic_version")) == "0009_election_refresh"
    downgraded = _alembic(["downgrade", "0007_iot_event_deduplication"], db_url)
    assert downgraded.returncode == 0, downgraded.stderr
    assert set(inspect(engine).get_table_names()) == tables_before
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT content FROM comments")) == "Concordo"
        assert connection.scalar(text("SELECT score FROM posts")) == 3
    engine.dispose()
