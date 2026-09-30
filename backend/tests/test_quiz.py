"""Testes de integração do router /quiz/*.

Testes da fórmula de scoring estão em tests/unit/test_scoring.py.
Aqui cobrimos: endpoints HTTP, conversão de entidades e contratos JSON.
"""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import inspect

from app.config import Settings
from app.infrastructure.database.models import DeviceModel, QuizResponseModel
from app.infrastructure.database.repositories import SqlPositionRepository
from app.infrastructure.database.session import get_db
from app.main import create_app


@pytest.mark.parametrize("trigger", ["quiz", "scheduler"])
def test_news_themes_exclude_answers_from_other_elections(
    trigger,
    db_session,
    thesis_ids,
    monkeypatch,
):
    from contextlib import nullcontext
    from datetime import datetime, timezone

    from app.api.routers import quiz as quiz_router
    from app.core.use_cases import news_notifier
    from app.infrastructure import scheduler
    from app.infrastructure.database import session as session_module
    from app.infrastructure.database.models import ThemeModel, ThesisModel
    from app.infrastructure.database.political_actor_repositories import (
        SqlFollowedActorRepository,
    )

    anonymous_id = "550e8400-e29b-41d4-a716-446655440099"
    future_theme = ThemeModel(
        slug="future-only",
        name="Future",
        area="economica",
        sort_order=99,
    )
    db_session.add(future_theme)
    db_session.flush()
    future_thesis = ThesisModel(
        text="Other edition",
        theme_id=future_theme.id,
        status="approved",
        election_year=2026,
    )
    db_session.add_all([future_thesis, DeviceModel(id=anonymous_id)])
    db_session.flush()
    db_session.add_all(
        [
            QuizResponseModel(
                device_id=anonymous_id,
                thesis_id=thesis_id,
                answer="agree",
                weight=1,
                election_year=year,
            )
            for thesis_id, year in [
                (thesis_ids["Tese 1"], 2022),
                (future_thesis.id, 2026),
            ]
        ]
    )
    db_session.flush()
    captured = []

    def capture_themes(**kwargs):
        captured.extend(kwargs["fetch_themes"](anonymous_id))

    monkeypatch.setattr(news_notifier, "push_news_for_user", capture_themes)
    monkeypatch.setattr(session_module, "SessionLocal", lambda: nullcontext(db_session))
    monkeypatch.setattr(
        SqlFollowedActorRepository,
        "list_all_followed",
        lambda _: [(1, anonymous_id)],
    )
    try:
        if trigger == "quiz":
            quiz_router._push_news_for_quiz_submission(anonymous_id)
        else:
            scheduler._push_news_for_all_followers(
                db_session, datetime.now(timezone.utc)
            )
        assert captured == ["economia"]
    finally:
        db_session.rollback()


def _agree5(thesis_ids: dict[str, int]) -> list[dict]:
    """Payload mínimo válido (5 respostas não-skip) a partir do seed de teste."""
    ids = [thesis_ids[f"Tese {i}"] for i in range(1, 6)]
    return [{"thesis_id": tid, "answer": "agree", "weight": 1} for tid in ids]


def _mapped_column_snapshot(row: object) -> tuple:
    return tuple(
        getattr(row, column.key)
        for column in inspect(type(row)).mapper.column_attrs
    )


class TestEndpointQuestions:
    def test_default_limit_exposes_full_presidential_catalogue(self, client):
        with patch(
            "app.api.routers.quiz.get_quiz_questions", return_value=[]
        ) as mocked:
            r = client.get("/api/v1/quiz/questions")

        assert r.status_code == 200
        assert mocked.call_args.kwargs["limit"] == 60

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

    def test_excludes_theses_from_other_elections(self, client):
        r = client.get("/api/v1/quiz/questions?limit=60")
        assert r.status_code == 200
        assert all(
            not thesis["text"].startswith("Tese de 2026")
            for thesis in r.json()["theses"]
        )

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
    def test_results_report_comparable_and_answered_thesis_counts(
        self, client, thesis_ids
    ):
        response = client.post(
            "/api/v1/quiz/submit",
            json={
                "answers": [
                    *_agree5(thesis_ids),
                    {"thesis_id": thesis_ids["Tese 6"], "answer": "skip", "weight": 2},
                ]
            },
        )
        assert response.status_code == 200
        results = response.json()["results"]
        assert {item["answered_theses"] for item in results} == {5}
        by_name = {item["name"]: item for item in results}
        assert by_name["Candidato A"]["counted_theses"] == 5
        assert by_name["Candidato C"]["counted_theses"] == 4

    def test_unscored_candidates_are_unranked_and_follow_real_zero_scores(
        self,
        client,
        thesis_ids,
        candidate_ids,
        db_session,
    ):
        real_positions = SqlPositionRepository(db_session).get_by_candidates_and_theses(
            list(candidate_ids.values()),
            [answer["thesis_id"] for answer in _agree5(thesis_ids)],
        )
        # All documented positions disagree, while C has no comparable evidence.
        real_positions.pop(candidate_ids["cand_c"])
        for positions in real_positions.values():
            for position in positions.values():
                position.position = "discordo"
        with patch.object(
            SqlPositionRepository,
            "get_by_candidates_and_theses",
            return_value=real_positions,
        ):
            response = client.post(
                "/api/v1/quiz/submit",
                json={"answers": _agree5(thesis_ids)},
            )
        assert response.status_code == 200
        results = response.json()["results"]
        assert all(item["score_percent"] == 0 for item in results)
        assert [item["name"] for item in results] == [
            "Candidato A",
            "Candidato B",
            "Candidato C",
        ]
        assert [item["rank"] for item in results] == [1, 1, 0]
        assert [item["counted_theses"] for item in results] == [5, 5, 0]

    def test_returns_ranked_results(self, client, thesis_ids):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )
        assert r.status_code == 200
        results = r.json()["results"]
        assert len(results) == 3

    def test_submit_includes_candidate_photo_url(self, client, thesis_ids):
        response = client.post(
            "/api/v1/quiz/submit",
            json={"answers": _agree5(thesis_ids)},
        )

        assert response.status_code == 200
        results = response.json()["results"]
        assert all("photo_url" in item for item in results)
        candidate_a = next(item for item in results if item["name"] == "Candidato A")
        assert candidate_a["photo_url"] == "/data/fotos/2022/BR/cand_a.jpg"

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

    def test_submit_with_device_id_skips_news_push_when_iot_is_disabled(
        self,
        client,
        db_session,
        monkeypatch,
        thesis_ids,
    ):
        from app.api.routers import quiz as quiz_router

        def fail_if_called(anonymous_id: str) -> None:
            raise AssertionError(f"unexpected hardware push for {anonymous_id}")

        monkeypatch.setattr(quiz_router.settings, "iot_feature_enabled", True)
        monkeypatch.setattr(
            quiz_router,
            "_push_news_for_quiz_submission",
            fail_if_called,
        )

        device_id = "550e8400-e29b-41d4-a716-446655440006"
        configured_app = create_app(
            Settings(_env_file=None, app_env="test", iot_feature_enabled=False)
        )

        def override_get_db():
            yield db_session

        configured_app.dependency_overrides[get_db] = override_get_db
        answers = _agree5(thesis_ids)
        with TestClient(configured_app) as disabled_client:
            r = disabled_client.post(
                "/api/v1/quiz/submit",
                json={"device_id": device_id, "answers": answers},
            )
        control = client.post("/api/v1/quiz/submit", json={"answers": answers})

        assert r.status_code == 200
        assert control.status_code == 200
        assert r.json()["results"] == control.json()["results"]
        assert db_session.get(DeviceModel, device_id) is None
        assert (
            db_session.query(QuizResponseModel).filter_by(device_id=device_id).count()
            == 0
        )

    def test_submit_with_device_id_does_not_update_existing_data_when_iot_is_disabled(
        self, client, db_session, monkeypatch, thesis_ids
    ):
        from app.api.routers import quiz as quiz_router

        device_id = "550e8400-e29b-41d4-a716-446655440016"
        original = _agree5(thesis_ids)
        changed = [
            {
                "thesis_id": original[0]["thesis_id"],
                "answer": "disagree",
                "weight": 2,
            },
            *original[1:],
        ]
        pushed_for: list[str] = []
        monkeypatch.setattr(
            quiz_router, "_push_news_for_quiz_submission", pushed_for.append
        )
        created = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": original},
        )
        assert created.status_code == 200
        assert pushed_for == [device_id]
        pushed_for.clear()
        db_session.expire_all()
        before_device = db_session.get(DeviceModel, device_id)
        assert before_device is not None
        before_device_snapshot = _mapped_column_snapshot(before_device)
        before_rows = sorted(
            (
                _mapped_column_snapshot(row)
                for row in db_session.query(QuizResponseModel)
                .filter_by(device_id=device_id)
                .all()
            ),
            key=repr,
        )

        configured_app = create_app(
            Settings(_env_file=None, app_env="test", iot_feature_enabled=False)
        )

        def override_get_db():
            yield db_session

        configured_app.dependency_overrides[get_db] = override_get_db
        with TestClient(configured_app) as disabled_client:
            response = disabled_client.post(
                "/api/v1/quiz/submit",
                json={"device_id": device_id, "answers": changed},
            )
        control = client.post("/api/v1/quiz/submit", json={"answers": changed})

        assert response.status_code == 200
        assert control.status_code == 200
        assert response.json()["results"] == control.json()["results"]
        assert pushed_for == []
        db_session.expire_all()
        after_device = db_session.get(DeviceModel, device_id)
        assert after_device is not None
        assert _mapped_column_snapshot(after_device) == before_device_snapshot
        after_rows = sorted(
            (
                _mapped_column_snapshot(row)
                for row in db_session.query(QuizResponseModel)
                .filter_by(device_id=device_id)
                .all()
            ),
            key=repr,
        )
        assert after_rows == before_rows

    def test_factory_enabled_app_pushes_news_when_global_iot_is_disabled(
        self,
        db_session,
        monkeypatch,
        thesis_ids,
    ):
        from app.api.routers import quiz as quiz_router

        device_id = "550e8400-e29b-41d4-a716-446655440017"
        pushed_for: list[str] = []

        monkeypatch.setattr(quiz_router.settings, "iot_feature_enabled", False)
        monkeypatch.setattr(
            quiz_router,
            "_push_news_for_quiz_submission",
            pushed_for.append,
        )

        configured_app = create_app(
            Settings(_env_file=None, app_env="test", iot_feature_enabled=True)
        )

        def override_get_db():
            yield db_session

        configured_app.dependency_overrides[get_db] = override_get_db
        with TestClient(configured_app) as client:
            r = client.post(
                "/api/v1/quiz/submit",
                json={"device_id": device_id, "answers": _agree5(thesis_ids)},
            )

        assert r.status_code == 200
        assert pushed_for == [device_id]
        assert db_session.get(DeviceModel, device_id) is not None
        assert (
            db_session.query(QuizResponseModel).filter_by(device_id=device_id).count()
            == len(_agree5(thesis_ids))
        )

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

    def test_submit_rejects_unavailable_thesis_ids_without_persisting(
        self,
        client,
        db_session,
        thesis_ids,
    ):
        device_id = "550e8400-e29b-41d4-a716-446655440007"
        unavailable_ids = [
            thesis_ids["Tese 7 rascunho"],
            thesis_ids["Tese de 2026 A"],
            999_999,
        ]
        payload = [
            {
                "thesis_id": thesis_ids[f"Tese {i}"],
                "answer": "agree",
                "weight": 1,
            }
            for i in range(1, 5)
        ] + [
            {"thesis_id": thesis_id, "answer": "agree", "weight": 1}
            for thesis_id in unavailable_ids
        ]

        response = client.post(
            "/api/v1/quiz/submit",
            json={"device_id": device_id, "answers": payload},
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert detail["code"] == "invalid_thesis_ids"
        assert detail["thesis_ids"] == sorted(unavailable_ids)
        assert db_session.get(DeviceModel, device_id) is None
        assert (
            db_session.query(QuizResponseModel).filter_by(device_id=device_id).count()
            == 0
        )

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
