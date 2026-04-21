class TestListCandidates:
    def test_returns_all(self, client):
        r = client.get("/api/v1/candidates")
        assert r.status_code == 200
        data = r.json()
        assert data["total_count"] == 3
        assert len(data["candidates"]) == 3

    def test_has_next_false_when_all_fit(self, client):
        r = client.get("/api/v1/candidates?page_size=50")
        assert r.json()["has_next"] is False

    def test_has_next_true_when_paginated(self, client):
        r = client.get("/api/v1/candidates?page_size=1")
        assert r.json()["has_next"] is True

    def test_filter_by_partido(self, client):
        r = client.get("/api/v1/candidates?partido=PT")
        data = r.json()
        assert data["total_count"] == 1
        assert data["candidates"][0]["party"] == "PT"

    def test_filter_by_search(self, client):
        r = client.get("/api/v1/candidates?search=Candidato+A")
        data = r.json()
        assert data["total_count"] == 1
        assert "Candidato A" in data["candidates"][0]["name"]

    def test_page_size_max_50(self, client):
        r = client.get("/api/v1/candidates?page_size=100")
        assert r.status_code == 422

    def test_ordered_alphabetically(self, client):
        r = client.get("/api/v1/candidates")
        names = [c["name"] for c in r.json()["candidates"]]
        assert names == sorted(names)


class TestGetCandidate:
    def test_returns_profile(self, client):
        r = client.get("/api/v1/candidates/cand_a")
        assert r.status_code == 200
        data = r.json()
        assert data["id"] == "cand_a"
        assert data["party"] == "PT"

    def test_404_for_unknown(self, client):
        r = client.get("/api/v1/candidates/nao_existe")
        assert r.status_code == 404
        assert "não encontrado" in r.json()["detail"]


class TestCandidatePositions:
    def test_returns_positions(self, client):
        r = client.get("/api/v1/candidates/cand_a/positions")
        assert r.status_code == 200
        data = r.json()
        assert data["candidate_id"] == "cand_a"
        assert len(data["positions"]) > 0

    def test_only_approved_theses(self, client):
        r = client.get("/api/v1/candidates/cand_a/positions")
        thesis_ids = [p["thesis_id"] for p in r.json()["positions"]]
        assert 7 not in thesis_ids

    def test_ordered_by_theme(self, client):
        r = client.get("/api/v1/candidates/cand_a/positions")
        theme_ids = [p["theme_id"] for p in r.json()["positions"]]
        assert theme_ids == sorted(theme_ids)

    def test_404_for_unknown_candidate(self, client):
        r = client.get("/api/v1/candidates/nao_existe/positions")
        assert r.status_code == 404


class TestCandidateJustifications:
    def test_returns_justifications(self, client):
        r = client.get("/api/v1/candidates/cand_a/justifications")
        assert r.status_code == 200
        data = r.json()
        assert "justifications" in data
        assert "summary" in data

    def test_summary_counts(self, client):
        r = client.get("/api/v1/candidates/cand_a/justifications")
        summary = r.json()["summary"]
        total = (
            summary["agree_count"]
            + summary["disagree_count"]
            + summary["neutral_count"]
            + summary["no_position_count"]
        )
        assert total == len(r.json()["justifications"])

    def test_group_by_theme(self, client):
        r = client.get("/api/v1/candidates/cand_a/justifications?group_by=theme")
        data = r.json()
        assert data["grouped"] is not None
        for theme, items in data["grouped"].items():
            for item in items:
                assert item["theme"] == theme

    def test_no_group_by_returns_null_grouped(self, client):
        r = client.get("/api/v1/candidates/cand_a/justifications")
        assert r.json()["grouped"] is None

    def test_404_for_unknown_candidate(self, client):
        r = client.get("/api/v1/candidates/nao_existe/justifications")
        assert r.status_code == 404
