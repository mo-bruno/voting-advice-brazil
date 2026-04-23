import os
import subprocess
from pathlib import Path

BACKEND_DIR = Path(__file__).parent.parent


def _alembic(args: list[str], db_url: str) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["DATABASE_URL"] = db_url
    return subprocess.run(
        ["uv", "run", "alembic", *args],
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
