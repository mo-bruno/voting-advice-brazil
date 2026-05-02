"""Testes de integração do router /quiz/*.

Testes da fórmula de scoring estão em tests/unit/test_scoring.py.
Aqui cobrimos: endpoints HTTP, conversão de entidades e contratos JSON.
"""


def _agree5(thesis_ids: dict[str, int]) -> list[dict]:
    """Payload mínimo válido (5 respostas não-skip) a partir do seed de teste."""
    ids = [thesis_ids[f"Tese {i}"] for i in range(1, 6)]
    return [{"thesis_id": tid, "answer": "agree", "weight": 1} for tid in ids]


class TestEndpointQuestions:
    def test_returns_theses(self, client):
        r = client.get("/api/v1/quiz/questions")
        assert r.status_code == 200
        data = r.json()
        assert "theses" in data
        assert "total" in data
        assert len(data["theses"]) > 0

    def test_only_approved_theses(self, client, thesis_ids):
        r = client.get("/api/v1/quiz/questions?limit=60")
        data = r.json()
        ids = [t["id"] for t in data["theses"]]
        draft_id = thesis_ids["Tese 7 rascunho"]
        assert draft_id not in ids

    def test_filter_by_theme(self, client, db_session):
        from app.infrastructure.database.models import ThemeModel
        seguranca = db_session.query(ThemeModel).filter_by(slug="seguranca").one()
        r = client.get("/api/v1/quiz/questions?themes=seguranca")
        data = r.json()
        for t in data["theses"]:
            assert t["theme_id"] == seguranca.id

    def test_limit_respected(self, client):
        r = client.get("/api/v1/quiz/questions?limit=2")
        assert len(r.json()["theses"]) <= 2

    def test_theses_have_coverage(self, client):
        r = client.get("/api/v1/quiz/questions")
        for t in r.json()["theses"]:
            assert 0 <= t["coverage"] <= 100


class TestEndpointSubmit:
    def test_returns_ranked_results(self, client, thesis_ids):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )
        assert r.status_code == 200
        results = r.json()["results"]
        assert len(results) == 3

    def test_results_ordered_by_score_desc(self, client, thesis_ids):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )
        scores = [res["score_percent"] for res in r.json()["results"]]
        assert scores == sorted(scores, reverse=True)

    def test_response_has_rank_field(self, client, thesis_ids):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )
        ranks = [res["rank"] for res in r.json()["results"]]
        assert ranks[0] == 1
        assert all(isinstance(rk, int) and rk >= 1 for rk in ranks)

    def test_matches_present(self, client, thesis_ids):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )
        for result in r.json()["results"]:
            assert len(result["matches"]) > 0

    def test_weight_2_accepted(self, client, thesis_ids):
        payload = [
            {"thesis_id": tid, "answer": "agree", "weight": 2}
            for tid in (thesis_ids[f"Tese {i}"] for i in range(1, 6))
        ]
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 200

    def test_below_minimum_returns_422(self, client, thesis_ids):
        payload = [
            {"thesis_id": thesis_ids[f"Tese {i}"], "answer": "agree", "weight": 1}
            for i in range(1, 5)
        ]
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 422
        detail = r.json()["detail"]
        assert detail["code"] == "insufficient_answers"
        assert detail["provided"] == 4
        assert detail["required"] == 5

    def test_skip_does_not_count_for_minimum(self, client, thesis_ids):
        t = [thesis_ids[f"Tese {i}"] for i in range(1, 7)]
        payload = [
            {"thesis_id": t[0], "answer": "skip", "weight": 1},
            {"thesis_id": t[1], "answer": "skip", "weight": 1},
            *[{"thesis_id": tid, "answer": "agree", "weight": 1} for tid in t[2:6]],
        ]
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 422
        assert r.json()["detail"]["provided"] == 4

    def test_empty_answers_rejected_by_pydantic(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": []})
        assert r.status_code == 422

    def test_invalid_answer_value_rejected(self, client, thesis_ids):
        tid = thesis_ids["Tese 1"]
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": tid, "answer": "sim"}]},
        )
        assert r.status_code == 422
