import os
import sqlite3
import subprocess
import sys
from pathlib import Path

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
    before = _alembic(["upgrade", "0006_community_integrity"], db_url)
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
