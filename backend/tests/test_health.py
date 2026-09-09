from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.database.session import get_db
from app.main import create_app


class TestHealth:
    def test_health_ok(self, client):
        r = client.get("/health")
        assert r.status_code == 200
        data = r.json()
        assert data["status"] == "ok"
        assert data["db_connected"] is True
        assert "version" in data
        assert data["uptime_seconds"] >= 0

    def test_health_not_rate_limited(self, client):
        for _ in range(10):
            r = client.get("/health")
            assert r.status_code == 200


def test_rate_limits_are_isolated_between_factory_instances(db_session):
    configured = Settings(_env_file=None, app_env="test")
    first_app = create_app(configured)
    second_app = create_app(configured)

    def override_get_db():
        yield db_session

    first_app.dependency_overrides[get_db] = override_get_db
    second_app.dependency_overrides[get_db] = override_get_db
    first_app.state.limiter.reset()

    with TestClient(first_app) as first_client, TestClient(second_app) as second_client:
        first_statuses = [
            first_client.get("/health").status_code for _ in range(60)
        ]
        second_status = second_client.get("/health").status_code

    assert first_statuses == [200] * 60
    assert second_status == 200
