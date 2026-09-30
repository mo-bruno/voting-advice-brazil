"""Exercise the shipped snapshot through a migrated database and the HTTP API."""

import os
import subprocess
import sys
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.api.cache import cache_delete_prefix
from app.config import Settings, settings
from app.infrastructure.database.models import CandidateModel, ThesisModel
from app.infrastructure.database.seed import seed
from app.infrastructure.database.session import get_db
from app.main import create_app

BACKEND_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BACKEND_DIR.parent / "data"


def test_presidential_snapshot_survives_legacy_data_and_reaches_the_app(
    tmp_path, monkeypatch
):
    database_url = f"sqlite:///{tmp_path / 'election.db'}"
    migration = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=BACKEND_DIR,
        env={**os.environ, "DATABASE_URL": database_url},
        capture_output=True,
        text=True,
        check=False,
    )
    assert migration.returncode == 0, migration.stderr
    monkeypatch.setattr(settings, "data_dir", str(DATA_DIR))
    monkeypatch.setattr(settings, "active_election_office", "presidente")
    engine = create_engine(database_url, connect_args={"check_same_thread": False})
    with Session(engine) as db:
        monkeypatch.setattr(settings, "active_election_year", 2022)
        seed(db)
        legacy_id = db.scalar(
            select(CandidateModel.id).where(CandidateModel.election_year == 2022)
        )
        monkeypatch.setattr(settings, "active_election_year", 2026)
        seed(db)
        seed(db)
        approved_ids = set(
            db.scalars(
                select(ThesisModel.id).where(
                    ThesisModel.election_year == 2026,
                    ThesisModel.status == "approved",
                )
            )
        )
        assert db.get(CandidateModel, legacy_id) is not None

        application = create_app(
            Settings(_env_file=None, app_env="test", data_dir=str(DATA_DIR))
        )
        application.dependency_overrides[get_db] = lambda: db
        cache_delete_prefix("")
        try:
            with TestClient(application) as client:
                candidates = client.get("/api/v1/candidates?page_size=50").json()[
                    "candidates"
                ]
                assert len(candidates) == 13
                assert {candidate["election_year"] for candidate in candidates} == {
                    2026
                }
                assert client.get(f"/api/v1/candidates/{legacy_id}").status_code == 404
                questions = client.get("/api/v1/quiz/questions?limit=60").json()[
                    "theses"
                ]
                assert {question["id"] for question in questions} == approved_ids
                for question in questions:
                    explanation = question["explanation"]
                    assert len(explanation["paragraphs"]) >= 2
                    assert explanation["sources"]
                    assert all(source["url"].startswith("https://") for source in explanation["sources"])
                # The community composer uses this catalogue too: a small
                # presidential edition must not hide its one-question topics.
                themes = client.get("/api/v1/themes").json()
                assert {theme["slug"] for theme in themes} == {
                    "economia_desenvolvimento",
                    "estado_gestao",
                    "infraestrutura_territorio",
                    "meio_ambiente_clima",
                    "ciencia_tecnologia_inovacao",
                    "bem_estar_social",
                    "educacao_cultura_sociedade",
                    "cidadania_direitos",
                    "seguranca_publica",
                    "soberania_relacoes_internacionais",
                }
                assert sum(theme["total_teses_aprovadas"] for theme in themes) == 20
                answers = [
                    {"thesis_id": question["id"], "answer": "agree"}
                    for question in questions
                ]
                response = client.post("/api/v1/quiz/submit", json={"answers": answers})
                assert response.status_code == 200
                results = response.json()["results"]
                assert len(results) == len(candidates)
                assert sum(result["ranking_eligible"] for result in results) == 9
                assert {result["answered_theses"] for result in results} == {
                    len(questions)
                }
                for candidate in candidates:
                    photo = client.get(candidate["photo_url"])
                    assert photo.status_code == 200
                    assert photo.headers["content-type"] == "image/jpeg"
                    assert photo.content.startswith(b"\xff\xd8\xff")
                    items = client.get(
                        f"/api/v1/candidates/{candidate['id']}/justifications"
                    ).json()["justifications"]
                    categorical = [
                        item for item in items if item["position"] != "sem_posicao"
                    ]
                    assert all(
                        item["quote"] and item["source_ref"] and item["source_url"]
                        for item in categorical
                    )
                    result = next(
                        item
                        for item in results
                        if item["candidate_id"] == candidate["id"]
                    )
                    assert result["counted_theses"] == len(categorical)
                    assert result["documented_theses"] == len(categorical)
                    if not result["ranking_eligible"]:
                        assert result["rank"] == 0
                invalid = client.post(
                    "/api/v1/quiz/submit",
                    json={
                        "answers": [
                            *answers,
                            {"thesis_id": 999_999, "answer": "skip"},
                        ]
                    },
                )
                assert invalid.status_code == 422
                assert invalid.json()["detail"]["code"] == "invalid_thesis_ids"
        finally:
            cache_delete_prefix("")
            application.dependency_overrides.clear()
    engine.dispose()
