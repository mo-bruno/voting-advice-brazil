"""Testes de integração do router /quiz/*.

Testes da fórmula de scoring estão em tests/unit/test_scoring.py.
Aqui cobrimos: endpoints HTTP, conversão de entidades e contratos JSON.
"""

from app.infrastructure.database.models import DeviceModel, QuizResponseModel


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

    def test_submit_with_device_id_persists_answers(
        self, client, db_session, thesis_ids
    ):
        device_id = "550e8400-e29b-41d4-a716-446655440000"
        payload = _agree5(thesis_ids)

        r = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": payload},
        )

        assert r.status_code == 200
        device = db_session.get(DeviceModel, device_id)
        assert device is not None
        assert device.created_at is not None
        assert device.last_seen_at is not None

        rows = (
            db_session.query(QuizResponseModel)
            .filter_by(device_id=device_id)
            .order_by(QuizResponseModel.thesis_id)
            .all()
        )
        assert len(rows) == len(payload)
        assert [(row.thesis_id, row.answer, row.weight) for row in rows] == [
            (answer["thesis_id"], answer["answer"], answer["weight"])
            for answer in sorted(payload, key=lambda item: item["thesis_id"])
        ]
        assert {row.election_year for row in rows} == {2022}

    def test_submit_with_device_id_pushes_news_inline(
        self,
        client,
        monkeypatch,
        thesis_ids,
    ):
        from app.api.routers import quiz as quiz_router

        device_id = "550e8400-e29b-41d4-a716-446655440000"
        pushed_for: list[str] = []

        def fake_push_news(anonymous_id: str) -> None:
            pushed_for.append(anonymous_id)

        class NoopThread:
            def __init__(self, *args, **kwargs):
                pass

            def start(self) -> None:
                pass

        monkeypatch.setattr(
            quiz_router,
            "_push_news_for_quiz_submission",
            fake_push_news,
            raising=False,
        )
        monkeypatch.setattr(quiz_router, "Thread", NoopThread, raising=False)

        r = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": _agree5(thesis_ids)},
        )

        assert r.status_code == 200
        assert pushed_for == [device_id]

    def test_submit_with_uuidv1_device_id_rejected_without_persisting_device(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        device_id = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

        r = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": _agree5(thesis_ids)},
        )

        assert r.status_code == 422
        assert db_session.get(DeviceModel, device_id) is None

    def test_submit_with_same_device_id_updates_existing_answers(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        device_id = "550e8400-e29b-41d4-a716-446655440001"
        first_payload = _agree5(thesis_ids)
        updated_payload = [
            {
                "thesis_id": first_payload[0]["thesis_id"],
                "answer": "disagree",
                "weight": 2,
            },
            *first_payload[1:],
        ]

        first = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": first_payload},
        )
        second = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": updated_payload},
        )

        assert first.status_code == 200
        assert second.status_code == 200
        rows = (
            db_session.query(QuizResponseModel)
            .filter_by(device_id=device_id)
            .order_by(QuizResponseModel.thesis_id)
            .all()
        )
        assert len(rows) == len(first_payload)
        changed = next(
            row for row in rows if row.thesis_id == first_payload[0]["thesis_id"]
        )
        assert changed.answer == "disagree"
        assert changed.weight == 2

    def test_submit_persists_skip_answers_when_payload_is_valid(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        device_id = "550e8400-e29b-41d4-a716-446655440002"
        payload = [
            *_agree5(thesis_ids),
            {"thesis_id": thesis_ids["Tese 6"], "answer": "skip", "weight": 1},
        ]

        r = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": payload},
        )

        assert r.status_code == 200
        skipped = (
            db_session.query(QuizResponseModel)
            .filter_by(device_id=device_id, thesis_id=thesis_ids["Tese 6"])
            .one()
        )
        assert skipped.answer == "skip"
        assert skipped.weight == 1

    def test_submit_with_duplicate_thesis_ids_persists_latest_answer(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        device_id = "550e8400-e29b-41d4-a716-446655440003"
        thesis_id = thesis_ids["Tese 1"]
        payload = [
            {"thesis_id": thesis_id, "answer": "agree", "weight": 1},
            *[
                {
                    "thesis_id": thesis_ids[f"Tese {i}"],
                    "answer": "agree",
                    "weight": 1,
                }
                for i in range(2, 6)
            ],
            {"thesis_id": thesis_id, "answer": "neutral", "weight": 2},
        ]

        r = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": payload},
        )

        assert r.status_code == 200
        rows = (
            db_session.query(QuizResponseModel)
            .filter_by(device_id=device_id, thesis_id=thesis_id)
            .all()
        )
        assert len(rows) == 1
        assert rows[0].answer == "neutral"
        assert rows[0].weight == 2

    def test_submit_with_duplicate_thesis_ids_scores_and_persists_latest_answers(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        duplicate_device_id = "550e8400-e29b-41d4-a716-446655440004"
        canonical_device_id = "550e8400-e29b-41d4-a716-446655440005"
        thesis_1 = thesis_ids["Tese 1"]
        canonical_payload = [
            *[
                {
                    "thesis_id": thesis_ids[f"Tese {i}"],
                    "answer": "agree",
                    "weight": 1,
                }
                for i in range(2, 6)
            ],
            {"thesis_id": thesis_1, "answer": "disagree", "weight": 2},
        ]
        duplicate_payload = [
            {"thesis_id": thesis_1, "answer": "agree", "weight": 1},
            *canonical_payload[:2],
            {"thesis_id": thesis_1, "answer": "neutral", "weight": 1},
            *canonical_payload[2:4],
            canonical_payload[4],
        ]

        duplicate = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": duplicate_device_id, "answers": duplicate_payload},
        )
        canonical = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": canonical_device_id, "answers": canonical_payload},
        )

        assert duplicate.status_code == 200
        assert canonical.status_code == 200
        assert duplicate.json()["results"] == canonical.json()["results"]

        duplicate_rows = (
            db_session.query(QuizResponseModel)
            .filter_by(device_id=duplicate_device_id)
            .order_by(QuizResponseModel.thesis_id)
            .all()
        )
        assert [(row.thesis_id, row.answer, row.weight) for row in duplicate_rows] == [
            (answer["thesis_id"], answer["answer"], answer["weight"])
            for answer in sorted(canonical_payload, key=lambda item: item["thesis_id"])
        ]

    def test_submit_with_only_duplicate_non_skip_answers_returns_422(
        self,
        client,
        thesis_ids,
    ):
        thesis_id = thesis_ids["Tese 1"]
        payload = [
            {"thesis_id": thesis_id, "answer": "agree", "weight": 1},
            {"thesis_id": thesis_id, "answer": "neutral", "weight": 1},
            {"thesis_id": thesis_id, "answer": "disagree", "weight": 2},
            {"thesis_id": thesis_id, "answer": "agree", "weight": 2},
            {"thesis_id": thesis_id, "answer": "neutral", "weight": 2},
        ]

        r = client.post("/api/v1/quiz/submit", json={"answers": payload})

        assert r.status_code == 422
        assert r.json()["detail"]["provided"] == 1

    def test_submit_without_device_id_does_not_persist_answers(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        before = db_session.query(QuizResponseModel).count()

        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )

        assert r.status_code == 200
        after = db_session.query(QuizResponseModel).count()
        assert after == before

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

    def test_too_many_answers_rejected_by_pydantic(self, client, thesis_ids):
        tid = thesis_ids["Tese 1"]
        payload = [{"thesis_id": tid, "answer": "agree", "weight": 1}] * 61
        r = client.post("/api/v1/quiz/submit", json={"answers": payload})
        assert r.status_code == 422

    def test_invalid_answer_value_rejected(self, client, thesis_ids):
        tid = thesis_ids["Tese 1"]
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": tid, "answer": "sim"}]},
        )
        assert r.status_code == 422
