import json
from pathlib import Path

import pytest

from app.config import settings
from app.infrastructure.thesis_explanations import (
    _load_catalogue,
    get_thesis_explanation,
)

DATA_DIR = Path(__file__).resolve().parents[2] / "data"


@pytest.fixture
def catalogue(monkeypatch):
    monkeypatch.setattr(settings, "data_dir", str(DATA_DIR))
    _load_catalogue.cache_clear()
    yield
    _load_catalogue.cache_clear()


def lookup(**overrides):
    return get_thesis_explanation(**{
        "election_year": 2026,
        "editorial_id": "B01-Q01",
        "editorial_version": 1,
        "text": "O Brasil deve cobrar um imposto específico sobre grandes fortunas.",
        **overrides,
    })


def test_all_published_questions_have_exact_version_explanations(catalogue):
    snapshot = json.loads((DATA_DIR / "theses/2026/theses.json").read_text())
    approved = [thesis for thesis in snapshot["theses"] if thesis["status"] == "approved"]
    entries = _load_catalogue(DATA_DIR / "theses/2026/explanations.json", 2026)
    assert len(approved) == 20
    assert set(entries) == {thesis["id"] for thesis in approved}
    for thesis in approved:
        explanation = lookup(
            editorial_id=thesis["id"], editorial_version=thesis["version"], text=thesis["text"],
        )
        assert explanation is not None, thesis["id"]
        assert 2 <= len(explanation.paragraphs) <= 4
        assert all(source.url.startswith("https://") for source in explanation.sources)


@pytest.mark.parametrize("overrides", [
    {"election_year": 2022},
    {"editorial_id": "BR26-UNKNOWN"},
    {"editorial_id": None},
    {"editorial_version": None},
    {"editorial_version": 2},
    {"text": "Uma redação diferente, ainda que tenha o mesmo identificador."},
])
def test_never_attaches_an_explanation_to_another_question(catalogue, overrides):
    assert lookup() is not None
    assert lookup(**overrides) is None


def test_missing_catalogue_keeps_quiz_available(catalogue, monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "data_dir", str(tmp_path))
    assert lookup() is None


@pytest.mark.parametrize("change", ["invalid_json", "duplicate_id", "wrong_year", "unsafe_url", "empty_text"])
def test_invalid_catalogue_is_not_served(catalogue, monkeypatch, tmp_path, change):
    raw = json.loads((DATA_DIR / "theses/2026/explanations.json").read_text())
    if change == "duplicate_id":
        raw["explanations"].append(raw["explanations"][0])
    elif change == "wrong_year":
        raw["election_year"] = 2022
    elif change == "unsafe_url":
        raw["explanations"][0]["sources"][0]["url"] = "javascript:alert(1)"
    elif change == "empty_text":
        raw["explanations"][0]["paragraphs"] = ["   ", "Explicação"]
    path = tmp_path / "theses/2026/explanations.json"
    path.parent.mkdir(parents=True)
    path.write_text("{" if change == "invalid_json" else json.dumps(raw))
    monkeypatch.setattr(settings, "data_dir", str(tmp_path))
    assert lookup() is None
