from pydantic import BaseModel, Field


class ThesisOut(BaseModel):
    id: int
    text: str
    theme_id: str
    theme_name: str
    coverage: float = Field(description="% candidatos com posição definida")

    model_config = {"from_attributes": True}


class QuestionsResponse(BaseModel):
    theses: list[ThesisOut]
    total: int


class AnswerIn(BaseModel):
    thesis_id: int
    answer: str = Field(pattern="^(agree|disagree|neutral|skip)$")
    weight: int = Field(default=1, ge=1, le=2)


class SubmitQuizIn(BaseModel):
    answers: list[AnswerIn] = Field(min_length=1)

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "answers": [
                        {"thesis_id": 1, "answer": "agree", "weight": 2},
                        {"thesis_id": 2, "answer": "disagree", "weight": 1},
                        {"thesis_id": 3, "answer": "neutral", "weight": 1},
                    ]
                }
            ]
        }
    }


class ThesisMatchOut(BaseModel):
    thesis_id: int
    thesis_text: str
    theme_id: str
    user_answer: str
    candidate_position: str
    match_type: str


class CandidateResultOut(BaseModel):
    candidate_id: str
    name: str
    party: str
    party_logo: str | None
    foto_url: str | None
    score_percent: float
    score_by_theme: dict[str, float]
    rank: int
    matches: list[ThesisMatchOut]


class SubmitQuizResponse(BaseModel):
    results: list[CandidateResultOut]
