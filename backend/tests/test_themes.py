class TestListThemes:
    def test_returns_themes(self, client):
        r = client.get("/api/v1/themes")
        assert r.status_code == 200
        data = r.json()
        assert isinstance(data, list)
        assert len(data) > 0

    def test_has_required_fields(self, client):
        r = client.get("/api/v1/themes")
        for theme in r.json():
            assert "id" in theme
            assert "nome" in theme
            assert "total_teses_aprovadas" in theme

    def test_only_themes_with_min_3_theses(self, client):
        r = client.get("/api/v1/themes")
        for theme in r.json():
            assert theme["total_teses_aprovadas"] >= 3

    def test_ordered_by_total_desc(self, client):
        r = client.get("/api/v1/themes")
        totals = [t["total_teses_aprovadas"] for t in r.json()]
        assert totals == sorted(totals, reverse=True)

    def test_draft_theses_not_counted(self, client):
        r = client.get("/api/v1/themes")
        # theme "saude" has only 1 draft thesis — should not appear
        ids = [t["id"] for t in r.json()]
        assert "saude" not in ids
