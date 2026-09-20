from unittest.mock import patch

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


def test_production_startup_does_not_reapply_bundled_election_data():
    """An older Cloud Run revision must not overwrite a newer snapshot."""
    app = create_app(Settings(_env_file=None, app_env="prod"))
    with patch("app.infrastructure.database.seed.seed") as seed:
        with TestClient(app):
            pass
    seed.assert_not_called()
