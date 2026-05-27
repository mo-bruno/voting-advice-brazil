from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, cast
from unicodedata import normalize as unicode_normalize

import httpx

from app.core.entities.political_actor import PoliticalActor

BASE_URL = "https://dadosabertos.camara.leg.br/api/v2"
QueryParamValue = str | int | float | bool | None


class CamaraSourceError(RuntimeError):
    pass


def _normalize_text(value: str) -> str:
    ascii_text = (
        unicode_normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
    )
    return " ".join(ascii_text.lower().split())


def _parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    if "T" not in normalized and len(normalized) == 10:
        normalized = f"{normalized}T00:00:00+00:00"
    parsed = datetime.fromisoformat(normalized)
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def _expires_at(fetched_at: datetime, evidence_type: str) -> datetime:
    if evidence_type == "expense":
        return fetched_at + timedelta(days=7)
    return fetched_at + timedelta(hours=24)


def _expense_source_id(
    payload: dict[str, Any],
    year: int,
    month: int,
    expense_type: str,
    value: Decimal,
) -> str:
    document_code = payload.get("codDocumento")
    if document_code:
        return f"expense:document:{document_code}"
    document_url = payload.get("urlDocumento")
    if document_url:
        return f"expense:url:{document_url}"
    document_number = payload.get("numDocumento")
    if document_number:
        return f"expense:{year}:{month}:{expense_type}:{value}:{document_number}"
    return f"expense:{year}:{month}:{expense_type}:{value}"


def normalize_deputy(
    payload: dict[str, Any],
    now: datetime,
) -> dict[str, object]:
    source_id = str(payload["id"])
    name = str(payload.get("nome") or "")
    return {
        "source": "camara",
        "source_id": source_id,
        "normalized_name": _normalize_text(name),
        "display_name": name,
        "party": payload.get("siglaPartido"),
        "state": payload.get("siglaUf"),
        "role": "federal_deputy",
        "status": "active",
        "photo_url": payload.get("urlFoto"),
        "source_url": payload.get("uri") or f"{BASE_URL}/deputados/{source_id}",
        "last_indexed_at": now,
    }


def normalize_proposition(
    actor_id: int,
    payload: dict[str, Any],
    fetched_at: datetime,
) -> dict[str, object]:
    source_id = str(payload["id"])
    sigla = payload.get("siglaTipo") or "Proposicao"
    numero = payload.get("numero")
    ano = payload.get("ano")
    label = f"{sigla} {numero}/{ano}" if numero and ano else str(sigla)
    summary = str(
        payload.get("ementa")
        or "Proposicao registrada na Camara dos Deputados."
    )
    return {
        "political_actor_id": actor_id,
        "source": "camara",
        "source_id": f"proposition:{source_id}",
        "evidence_type": "proposition",
        "title": f"Apresentou {label}",
        "summary": summary,
        "evidence_date": _parse_datetime(payload.get("dataApresentacao")),
        "source_url": payload.get("uri"),
        "normalized_payload": {
            "sigla_tipo": sigla,
            "numero": numero,
            "ano": ano,
        },
        "fetched_at": fetched_at,
        "expires_at": _expires_at(fetched_at, "proposition"),
    }


def normalize_expense(
    actor_id: int,
    payload: dict[str, Any],
    fetched_at: datetime,
) -> dict[str, object]:
    year = int(payload.get("ano") or fetched_at.year)
    month = int(payload.get("mes") or 1)
    value = Decimal(str(payload.get("valorLiquido") or "0"))
    value_text = (
        f"R$ {value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    )
    expense_type = str(payload.get("tipoDespesa") or "despesa parlamentar").lower()
    return {
        "political_actor_id": actor_id,
        "source": "camara",
        "source_id": _expense_source_id(
            payload,
            year,
            month,
            expense_type,
            value,
        ),
        "evidence_type": "expense",
        "title": f"Registrou {value_text} em despesa parlamentar",
        "summary": f"Despesa oficial de {expense_type}.",
        "evidence_date": datetime(year, month, 1, tzinfo=timezone.utc),
        "source_url": payload.get("urlDocumento"),
        "normalized_payload": {
            "year": year,
            "month": month,
            "expense_type": expense_type,
            "value": float(value),
            "document_code": payload.get("codDocumento"),
            "document_number": payload.get("numDocumento"),
        },
        "fetched_at": fetched_at,
        "expires_at": _expires_at(fetched_at, "expense"),
    }


def normalize_vote(
    actor_id: int,
    deputy_source_id: str,
    vote_payload: dict[str, Any],
    voting_payload: dict[str, Any],
    fetched_at: datetime,
) -> dict[str, object] | None:
    deputy = vote_payload.get("deputado_") or {}
    if not isinstance(deputy, dict) or str(deputy.get("id")) != deputy_source_id:
        return None
    vote = str(vote_payload.get("tipoVoto") or "Voto registrado")
    voting_id = str(voting_payload["id"])
    description = str(
        voting_payload.get("descricao")
        or "Votacao nominal na Camara dos Deputados."
    )
    return {
        "political_actor_id": actor_id,
        "source": "camara",
        "source_id": f"vote:{voting_id}:{deputy_source_id}",
        "evidence_type": "vote",
        "title": f"Votou {vote}",
        "summary": description,
        "evidence_date": _parse_datetime(
            vote_payload.get("dataRegistroVoto") or voting_payload.get("data")
        ),
        "source_url": voting_payload.get("uri"),
        "normalized_payload": {"vote": vote, "voting_id": voting_id},
        "fetched_at": fetched_at,
        "expires_at": _expires_at(fetched_at, "vote"),
    }


class CamaraClient:
    def __init__(
        self,
        base_url: str = BASE_URL,
        client: httpx.Client | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._client = client or httpx.Client(
            timeout=10.0,
            headers={"Accept": "application/json"},
        )

    def _get(
        self,
        path: str,
        params: dict[str, QueryParamValue] | None = None,
    ) -> list[dict[str, Any]]:
        try:
            response = self._client.get(f"{self._base_url}{path}", params=params)
        except httpx.RequestError as exc:
            raise CamaraSourceError("Camara request failed") from exc
        if response.status_code >= 400:
            raise CamaraSourceError(
                f"Camara request failed: {response.status_code}"
            )
        payload = response.json()
        if not isinstance(payload, dict):
            raise CamaraSourceError("Camara response was not a JSON object")
        rows = payload.get("dados")
        if not isinstance(rows, list):
            raise CamaraSourceError(
                "Camara response did not include list field 'dados'"
            )
        result: list[dict[str, Any]] = []
        for row in rows:
            if not isinstance(row, dict):
                raise CamaraSourceError("Camara response row was not an object")
            result.append(cast("dict[str, Any]", row))
        return result

    def list_current_deputies(self) -> list[dict[str, Any]]:
        page = 1
        rows: list[dict[str, Any]] = []
        while True:
            batch = self._get(
                "/deputados",
                {
                    "itens": 100,
                    "pagina": page,
                    "ordem": "ASC",
                    "ordenarPor": "nome",
                },
            )
            if not batch:
                break
            rows.extend(batch)
            if len(batch) < 100:
                break
            page += 1
        return rows

    def list_propositions(
        self,
        deputy_id: str,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        return self._get(
            "/proposicoes",
            {
                "idDeputadoAutor": deputy_id,
                "itens": limit,
                "ordem": "DESC",
                "ordenarPor": "id",
            },
        )

    def list_expenses(
        self,
        deputy_id: str,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        return self._get(
            f"/deputados/{deputy_id}/despesas",
            {"itens": limit, "ordem": "DESC", "ordenarPor": "ano"},
        )

    def list_recent_votings(self, scan_limit: int = 30) -> list[dict[str, Any]]:
        return self._get(
            "/votacoes",
            {
                "itens": scan_limit,
                "ordem": "DESC",
                "ordenarPor": "dataHoraRegistro",
            },
        )

    def list_votes_for_voting(self, voting_id: str) -> list[dict[str, Any]]:
        return self._get(f"/votacoes/{voting_id}/votos")


class CamaraDeputyIndexSource:
    def __init__(self, client: CamaraClient) -> None:
        self._client = client

    def list_current_deputies_for_index(
        self,
        now: datetime,
    ) -> list[dict[str, object]]:
        return [
            normalize_deputy(row, now=now)
            for row in self._client.list_current_deputies()
        ]


class CamaraEvidenceSource:
    def __init__(self, client: CamaraClient) -> None:
        self._client = client

    def _fetch_propositions(
        self,
        actor: PoliticalActor,
        fetched_at: datetime,
    ) -> list[dict[str, object]]:
        try:
            return [
                normalize_proposition(actor.id, row, fetched_at)
                for row in self._client.list_propositions(actor.source_id, limit=20)
            ][:20]
        except CamaraSourceError:
            return []

    def _fetch_expenses(
        self,
        actor: PoliticalActor,
        fetched_at: datetime,
    ) -> list[dict[str, object]]:
        try:
            return [
                normalize_expense(actor.id, row, fetched_at)
                for row in self._client.list_expenses(actor.source_id, limit=20)
            ][:20]
        except CamaraSourceError:
            return []

    def _fetch_votes(
        self,
        actor: PoliticalActor,
        fetched_at: datetime,
    ) -> list[dict[str, object]]:
        votes: list[dict[str, object]] = []
        try:
            votings = self._client.list_recent_votings(scan_limit=5)
        except CamaraSourceError:
            return votes
        for voting in votings:
            voting_id = str(voting.get("id"))
            try:
                vote_payloads = self._client.list_votes_for_voting(voting_id)
            except CamaraSourceError:
                continue
            for vote_payload in vote_payloads:
                normalized = normalize_vote(
                    actor.id,
                    actor.source_id,
                    vote_payload,
                    voting,
                    fetched_at,
                )
                if normalized is not None:
                    votes.append(normalized)
                    break
            if len(votes) >= 20:
                break
        return votes

    def fetch_votes_for_actor(
        self,
        actor: PoliticalActor,
    ) -> list[dict[str, object]]:
        return self._fetch_votes(actor, datetime.now(timezone.utc))

    def fetch_evidence_for_actor(
        self,
        actor: PoliticalActor,
    ) -> dict[str, list[dict[str, object]]]:
        fetched_at = datetime.now(timezone.utc)
        propositions = self._fetch_propositions(actor, fetched_at)
        expenses = self._fetch_expenses(actor, fetched_at)
        votes = self._fetch_votes(actor, fetched_at)
        return {"proposition": propositions, "expense": expenses, "vote": votes}
