from pydantic import BaseModel


class ThemeOut(BaseModel):
    id: int
    slug: str
    nome: str
    area: str
    descricao: str | None
    icone_slug: str | None
    total_teses_aprovadas: int

    model_config = {"from_attributes": True}
