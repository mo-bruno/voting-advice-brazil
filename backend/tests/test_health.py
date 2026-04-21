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
