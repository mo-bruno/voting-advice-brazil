from app.core.entities.candidate import CandidatePosition
from app.core.use_cases.submit_quiz import QuizAnswer, _match_type, _score_candidate


def _pos(thesis_id: int, theme_slug: str, position: str) -> CandidatePosition:
    return CandidatePosition(
        thesis_id=thesis_id,
        thesis_text="",
        theme_id=1,
        theme_slug=theme_slug,
        theme_name="",
        position=position,
        justification=None,
        quote=None,
    )


class TestMatchType:
    def test_perfect_match_agree(self):
        assert _match_type("concordo", "concordo") == "match"

    def test_perfect_match_disagree(self):
        assert _match_type("discordo", "discordo") == "match"

    def test_mismatch(self):
        assert _match_type("concordo", "discordo") == "mismatch"

    def test_partial_agree_neutral(self):
        assert _match_type("concordo", "neutro") == "partial"

    def test_skip_returns_skipped(self):
        assert _match_type("pulou", "concordo") == "skipped"

    def test_sem_posicao_returns_skipped(self):
        assert _match_type("concordo", "sem_posicao") == "skipped"


class TestScoreCandidate:
    def test_perfect_agreement(self):
        answers = [QuizAnswer(thesis_id=1, answer="concordo", weight=1)]
        positions = {1: _pos(1, "economia", "concordo")}
        score, by_theme = _score_candidate(answers, positions)
        assert score == 100.0

    def test_total_disagreement(self):
        answers = [QuizAnswer(thesis_id=1, answer="concordo", weight=1)]
        positions = {1: _pos(1, "economia", "discordo")}
        score, _ = _score_candidate(answers, positions)
        assert score == 0.0

    def test_neutral_gives_50_vs_agree(self):
        answers = [QuizAnswer(thesis_id=1, answer="concordo", weight=1)]
        positions = {1: _pos(1, "economia", "neutro")}
        score, _ = _score_candidate(answers, positions)
        assert score == 50.0

    def test_skip_excluded_from_calculation(self):
        answers = [
            QuizAnswer(thesis_id=1, answer="pulou", weight=1),
            QuizAnswer(thesis_id=2, answer="concordo", weight=1),
        ]
        positions = {
            1: _pos(1, "economia", "discordo"),
            2: _pos(2, "economia", "concordo"),
        }
        score, _ = _score_candidate(answers, positions)
        assert score == 100.0

    def test_sem_posicao_excluded_from_denominator(self):
        answers = [
            QuizAnswer(thesis_id=1, answer="concordo", weight=1),
            QuizAnswer(thesis_id=2, answer="concordo", weight=1),
        ]
        positions = {
            1: _pos(1, "economia", "concordo"),
            2: _pos(2, "economia", "sem_posicao"),
        }
        score, _ = _score_candidate(answers, positions)
        assert score == 100.0

    def test_weight_double_amplifies(self):
        answers = [QuizAnswer(thesis_id=1, answer="concordo", weight=2)]
        positions = {1: _pos(1, "economia", "discordo")}
        score, _ = _score_candidate(answers, positions)
        assert score == 0.0

    def test_score_by_theme(self):
        answers = [
            QuizAnswer(thesis_id=1, answer="concordo", weight=1),
            QuizAnswer(thesis_id=2, answer="discordo", weight=1),
        ]
        positions = {
            1: _pos(1, "economia", "concordo"),
            2: _pos(2, "seguranca", "discordo"),
        }
        score, by_theme = _score_candidate(answers, positions)
        assert score == 100.0
        assert by_theme["economia"] == 100.0
        assert by_theme["seguranca"] == 100.0

    def test_no_answerable_questions_returns_zero(self):
        answers = [QuizAnswer(thesis_id=1, answer="pulou", weight=1)]
        positions = {1: _pos(1, "economia", "concordo")}
        score, by_theme = _score_candidate(answers, positions)
        assert score == 0.0
        assert by_theme == {}


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
        data = r.json()
        assert len(data["theses"]) <= 2

    def test_theses_have_coverage(self, client):
        r = client.get("/api/v1/quiz/questions")
        for t in r.json()["theses"]:
            assert "coverage" in t
            assert 0 <= t["coverage"] <= 100


class TestEndpointSubmit:
    def test_returns_ranked_results(self, client, thesis_ids):
        t1 = thesis_ids["Tese 1"]
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": t1, "answer": "concordo", "weight": 1}]},
        )
        assert r.status_code == 200
        results = r.json()["results"]
        assert len(results) == 3

    def test_results_ordered_by_score_desc(self, client, thesis_ids):
        t1 = thesis_ids["Tese 1"]
        t2 = thesis_ids["Tese 2"]
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [
                {"thesis_id": t1, "answer": "concordo", "weight": 1},
                {"thesis_id": t2, "answer": "concordo", "weight": 1},
            ]},
        )
        scores = [res["score_percent"] for res in r.json()["results"]]
        assert scores == sorted(scores, reverse=True)

    def test_matches_present(self, client, thesis_ids):
        t1 = thesis_ids["Tese 1"]
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": t1, "answer": "concordo", "weight": 1}]},
        )
        for result in r.json()["results"]:
            assert len(result["matches"]) > 0

    def test_weight_2_accepted(self, client, thesis_ids):
        t1 = thesis_ids["Tese 1"]
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": t1, "answer": "concordo", "weight": 2}]},
        )
        assert r.status_code == 200

    def test_empty_answers_rejected(self, client):
        r = client.post("/api/v1/quiz/submit", json={"answers": []})
        assert r.status_code == 422

    def test_invalid_answer_value_rejected(self, client):
        r = client.post(
            "/api/v1/quiz/submit",
            json={"answers": [{"thesis_id": 1, "answer": "sim"}]},
        )
        assert r.status_code == 422
