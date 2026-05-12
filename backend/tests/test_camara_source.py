from datetime import datetime, timezone

import httpx
import pytest

from app.core.entities.political_actor import PoliticalActor
from app.infrastructure.sources.camara import (
    CamaraClient,
    CamaraEvidenceSource,
    CamaraSourceError,
    normalize_deputy,
    normalize_expense,
    normalize_proposition,
    normalize_vote,
)


class _FakeResponse:
    def __init__(self, status_code: int, payload: dict[str, object]) -> None:
        self.status_code = status_code
        self._payload = payload

    def json(self) -> dict[str, object]:
        return self._payload


class _FakeHttpClient:
    def __init__(self, responses: list[_FakeResponse]) -> None:
        self._responses = responses
        self.requests: list[tuple[str, dict[str, object] | None]] = []

    def get(
        self,
        url: str,
        params: dict[str, object] | None = None,
    ) -> _FakeResponse:
        self.requests.append((url, params))
        return self._responses.pop(0)


class _TimeoutHttpClient:
    def get(
        self,
        url: str,
        params: dict[str, object] | None = None,
    ) -> _FakeResponse:
        raise httpx.ReadTimeout("timed out")


class _FakeCamaraClient:
    def list_propositions(
        self,
        deputy_id: str,
        limit: int = 20,
    ) -> list[dict[str, object]]:
        return [
            {
                "id": 9001,
                "siglaTipo": "PL",
                "numero": 123,
                "ano": 2026,
                "ementa": "Cria politica publica de saude.",
            }
        ]

    def list_expenses(
        self,
        deputy_id: str,
        limit: int = 20,
    ) -> list[dict[str, object]]:
        return []

    def list_recent_votings(self, scan_limit: int = 30) -> list[dict[str, object]]:
        return [{"id": "2468-1", "descricao": "Votacao nominal"}]

    def list_votes_for_voting(self, voting_id: str) -> list[dict[str, object]]:
        return [
            {
                "tipoVoto": "Sim",
                "deputado_": {"id": 101, "nome": "Maria Silva"},
            }
        ]


class _PartiallyFailingCamaraClient:
    def list_propositions(
        self,
        deputy_id: str,
        limit: int = 20,
    ) -> list[dict[str, object]]:
        raise CamaraSourceError("propositions unavailable")

    def list_expenses(
        self,
        deputy_id: str,
        limit: int = 20,
    ) -> list[dict[str, object]]:
        return [
            {
                "ano": 2026,
                "mes": 1,
                "tipoDespesa": "COMBUSTIVEIS",
                "valorLiquido": 119.72,
                "urlDocumento": "https://example.com/doc.pdf",
            }
        ]

    def list_recent_votings(self, scan_limit: int = 30) -> list[dict[str, object]]:
        raise CamaraSourceError("votings unavailable")

    def list_votes_for_voting(self, voting_id: str) -> list[dict[str, object]]:
        return []


def test_normalizes_deputy_index_payload():
    now = datetime(2026, 5, 6, tzinfo=timezone.utc)
    row = normalize_deputy(
        {
            "id": 101,
            "nome": "Maria Silva",
            "siglaPartido": "PT",
            "siglaUf": "SP",
            "urlFoto": "https://example.com/foto.jpg",
            "uri": "https://dadosabertos.camara.leg.br/api/v2/deputados/101",
        },
        now=now,
    )

    assert row["source"] == "camara"
    assert row["source_id"] == "101"
    assert row["normalized_name"] == "maria silva"
    assert row["display_name"] == "Maria Silva"
    assert row["party"] == "PT"
    assert row["state"] == "SP"
    assert row["role"] == "federal_deputy"


def test_normalizes_proposition_as_neutral_evidence():
    evidence = normalize_proposition(
        actor_id=1,
        payload={
            "id": 9001,
            "siglaTipo": "PL",
            "numero": 123,
            "ano": 2026,
            "ementa": "Cria politica publica de saude.",
            "dataApresentacao": "2026-04-10T12:00",
            "uri": "https://dadosabertos.camara.leg.br/api/v2/proposicoes/9001",
        },
        fetched_at=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )

    assert evidence["evidence_type"] == "proposition"
    assert evidence["source_id"] == "proposition:9001"
    assert evidence["title"] == "Apresentou PL 123/2026"
    assert "saude" in str(evidence["summary"])


def test_normalizes_expense_as_neutral_evidence():
    evidence = normalize_expense(
        actor_id=1,
        payload={
            "ano": 2026,
            "mes": 4,
            "tipoDespesa": "DIVULGACAO DA ATIVIDADE PARLAMENTAR",
            "valorLiquido": 2340.5,
            "urlDocumento": "https://example.com/doc.pdf",
        },
        fetched_at=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )

    assert evidence["evidence_type"] == "expense"
    assert evidence["title"] == "Registrou R$ 2.340,50 em despesa parlamentar"
    assert evidence["source_url"] == "https://example.com/doc.pdf"


def test_normalizes_vote_for_selected_deputy_only():
    evidence = normalize_vote(
        actor_id=1,
        deputy_source_id="101",
        vote_payload={
            "tipoVoto": "Sim",
            "dataRegistroVoto": "2026-04-12T18:30",
            "deputado_": {"id": 101, "nome": "Maria Silva"},
        },
        voting_payload={
            "id": "2468-1",
            "descricao": "Votacao nominal do PL 123/2026",
            "data": "2026-04-12",
            "uri": "https://dadosabertos.camara.leg.br/api/v2/votacoes/2468-1",
        },
        fetched_at=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )

    assert evidence is not None
    assert evidence["evidence_type"] == "vote"
    assert evidence["source_id"] == "vote:2468-1:101"
    assert evidence["title"] == "Votou Sim"


def test_vote_normalizer_ignores_other_deputies():
    evidence = normalize_vote(
        actor_id=1,
        deputy_source_id="101",
        vote_payload={"tipoVoto": "Nao", "deputado_": {"id": 999}},
        voting_payload={"id": "2468-1"},
        fetched_at=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )

    assert evidence is None


def test_camara_client_reads_dados_list():
    fake_client = _FakeHttpClient([
        _FakeResponse(200, {"dados": [{"id": 101}]})
    ])
    client = CamaraClient(base_url="https://camara.test", client=fake_client)

    rows = client.list_expenses("101", limit=1)

    assert rows == [{"id": 101}]
    assert fake_client.requests == [
        (
            "https://camara.test/deputados/101/despesas",
            {"itens": 1, "ordem": "DESC", "ordenarPor": "ano"},
        )
    ]


def test_camara_client_uses_valid_proposition_ordering():
    fake_client = _FakeHttpClient([
        _FakeResponse(200, {"dados": [{"id": 9001}]})
    ])
    client = CamaraClient(base_url="https://camara.test", client=fake_client)

    rows = client.list_propositions("101", limit=1)

    assert rows == [{"id": 9001}]
    assert fake_client.requests == [
        (
            "https://camara.test/proposicoes",
            {
                "idDeputadoAutor": "101",
                "itens": 1,
                "ordem": "DESC",
                "ordenarPor": "id",
            },
        )
    ]


def test_camara_client_raises_source_error_on_http_failure():
    fake_client = _FakeHttpClient([_FakeResponse(500, {"dados": []})])
    client = CamaraClient(base_url="https://camara.test", client=fake_client)

    with pytest.raises(CamaraSourceError):
        client.list_expenses("101")


def test_camara_client_wraps_timeout_as_source_error():
    client = CamaraClient(base_url="https://camara.test", client=_TimeoutHttpClient())

    with pytest.raises(CamaraSourceError):
        client.list_propositions("101")


def test_evidence_source_groups_normalized_evidence():
    actor = PoliticalActor(
        id=1,
        source="camara",
        source_id="101",
        normalized_name="maria silva",
        display_name="Maria Silva",
        party="PT",
        state="SP",
        role="federal_deputy",
        status="active",
        photo_url=None,
        source_url=None,
        last_indexed_at=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )
    source = CamaraEvidenceSource(_FakeCamaraClient())

    grouped = source.fetch_evidence_for_actor(actor)

    assert grouped["proposition"][0]["evidence_type"] == "proposition"
    assert grouped["vote"][0]["source_id"] == "vote:2468-1:101"
    assert grouped["expense"] == []


def test_evidence_source_returns_available_categories_when_one_fails():
    actor = PoliticalActor(
        id=1,
        source="camara",
        source_id="101",
        normalized_name="maria silva",
        display_name="Maria Silva",
        party="PT",
        state="SP",
        role="federal_deputy",
        status="active",
        photo_url=None,
        source_url=None,
        last_indexed_at=datetime(2026, 5, 6, tzinfo=timezone.utc),
    )
    source = CamaraEvidenceSource(_PartiallyFailingCamaraClient())

    grouped = source.fetch_evidence_for_actor(actor)

    assert grouped["proposition"] == []
    assert grouped["vote"] == []
    assert grouped["expense"][0]["evidence_type"] == "expense"
