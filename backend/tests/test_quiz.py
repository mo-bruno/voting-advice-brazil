"""Testes de integração do router /quiz/*.

Testes da fórmula de scoring estão em tests/unit/test_scoring.py.
Aqui cobrimos: endpoints HTTP, conversão de entidades e contratos JSON.
"""


def _agree5() -> list[dict]:
    """Payload mínimo válido (5 respostas) — ajustar thesis_ids ao seed."""
    return [
        {"thesis_id": i, "answer": "agree", "weight": 1} for i in range(1, 6)
    ]


class TestEndpointQuestions:
    def test_returns_theses(self, client):
        r = client.get("/api/v1/quiz/questions")
        assert r.status_code == 200
        data = r.json()
        assert "theses" in data
        assert "total" in data
        assert len(data["theses"]) > 0

    def test_only_approved_theses(self, client):
        r = client.get("/api/v1/quiz/questions?limit=60")
        data = r.json()
        ids = [t["id"] for t in data["theses"]]
        assert 7 not in ids

    def test_filter_by_theme(self, client):
        r = client.get("/api/v1/quiz/questions?themes=seguranca")
        for t in r.json()["theses"]:
            assert t["theme_id"] == "seguranca"

    def test_limit_respected(self, client):
        r = client.get("/api/v1/quiz/questions?limit=2")
        assert len(r.json()["theses"]) <= 2

    def test_theses_have_coverage(self, client):
        r = client.get("/api/v1/quiz/questions")
        for t in r.json()["theses"]:
            assert 0 <= t["coverage"] <= 100


class TestEndpointSubmit:
    def test_returns_ranked_results(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": _agree5()})
        assert r.status_code == 200
        results = r.json()["results"]
        assert len(results) == 3

    def test_results_ordered_by_score_desc(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": _agree5()})
        scores = [res["score_percent"] for res in r.json()["results"]]
        assert scores == sorted(scores, reverse=True)

    def test_response_has_rank_field(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": _agree5()})
        ranks = [res["rank"] for res in r.json()["results"]]
        assert ranks[0] == 1
        assert all(isinstance(rk, int) and rk >= 1 for rk in ranks)

    def test_matches_present(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": _agree5()})
        for result in r.json()["results"]:
            assert len(result["matches"]) > 0

    def test_weight_2_accepted(self, client):
        payload = [{"thesis_id": i, "answer": "agree", "weight": 2}
                   for i in range(1, 6)]
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 200

    def test_below_minimum_returns_422(self, client):
        payload = [{"thesis_id": i, "answer": "agree", "weight": 1}
                   for i in range(1, 5)]
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 422
        detail = r.json()["detail"]
        assert detail["code"] == "insufficient_answers"
        assert detail["provided"] == 4
        assert detail["required"] == 5

    def test_skip_does_not_count_for_minimum(self, client):
        payload = [
            {"thesis_id": 1, "answer": "skip", "weight": 1},
            {"thesis_id": 2, "answer": "skip", "weight": 1},
            *[{"thesis_id": i, "answer": "agree", "weight": 1}
              for i in range(3, 7)],
        ]
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 422
        assert r.json()["detail"]["provided"] == 4

    def test_empty_answers_rejected_by_pydantic(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": []})
        assert r.status_code == 422

    def test_invalid_answer_value_rejected(self, client):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": 1, "answer": "sim"}]},
        )
        assert r.status_code == 422
