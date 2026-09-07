from datetime import date, datetime

from pydantic import BaseModel, Field


class NewsArticleOut(BaseModel):
    id: str = Field(description="SHA-1 do guid, estável entre requests")
    title: str
    summary: str
    image_url: str | None = Field(description="Nulo quando a matéria não traz imagem")
    theme_slug: str
    theme_label: str
    published_at: datetime
    reading_minutes: int
    url: str


class WeeklyNewsResponse(BaseModel):
    period_start: date
    period_end: date
    period_label: str = Field(examples=["30 DE AGO A 6 DE SET DE 2026"])
    total: int = Field(description="Quantidade de itens em articles; não há paginação")
    articles: list[NewsArticleOut]
