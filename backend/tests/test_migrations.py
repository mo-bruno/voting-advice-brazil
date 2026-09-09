import os
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

    down = _alembic(["downgrade", "base"], db_url)
    assert down.returncode == 0, down.stderr

    reup = _alembic(["upgrade", "head"], db_url)
    assert reup.returncode == 0, reup.stderr


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
            "0008_comment_admission_locks"
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
        assert connection.scalar(text("SELECT version_num FROM alembic_version")) == "0008_comment_admission_locks"
    downgraded = _alembic(["downgrade", "0007_iot_event_deduplication"], db_url)
    assert downgraded.returncode == 0, downgraded.stderr
    assert set(inspect(engine).get_table_names()) == tables_before
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT content FROM comments")) == "Concordo"
        assert connection.scalar(text("SELECT score FROM posts")) == 3
    engine.dispose()
