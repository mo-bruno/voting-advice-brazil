"""Validate visible app copy uses Brazilian Portuguese accents.

This intentionally scans only user-facing text sources. Internal slugs, enum
values, API field names, and route names remain ASCII because the app depends on
those stable identifiers.
"""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

MISSING_ACCENT_TERMS = {
    r"\bvoce\b": "você",
    r"\bnao\b": "não",
    r"\besta\b": "está",
    r"\bserie\b": "série",
    r"\bopiniao\b": "opinião",
    r"\bquestao\b": "questão",
    r"\bquestoes\b": "questões",
    r"\bcalculo\b": "cálculo",
    r"\bselecao\b": "seleção",
    r"\bcomparacao\b": "comparação",
    r"\beleicao\b": "eleição",
    r"\beleicoes\b": "eleições",
    r"\bposicao\b": "posição",
    r"\bposicoes\b": "posições",
    r"\bpolitica\b": "política",
    r"\bpoliticas\b": "políticas",
    r"\bpublica\b": "pública",
    r"\bpublicas\b": "públicas",
    r"\bpublico\b": "público",
    r"\bpublicos\b": "públicos",
    r"\bsaude\b": "saúde",
    r"\beducacao\b": "educação",
    r"\bseguranca\b": "segurança",
    r"\beconomico\b": "econômico",
    r"\beconomica\b": "econômica",
    r"\beconomicas\b": "econômicas",
    r"\beconomicos\b": "econômicos",
    r"\breducao\b": "redução",
    r"\bprivatizacao\b": "privatização",
    r"\bdesestatizacao\b": "desestatização",
    r"\bparticipacao\b": "participação",
    r"\bpresenca\b": "presença",
    r"\bsalario\b": "salário",
    r"\bminimo\b": "mínimo",
    r"\bmanutencao\b": "manutenção",
    r"\bconciliacao\b": "conciliação",
    r"\beficiencia\b": "eficiência",
    r"\bgestao\b": "gestão",
    r"\bintervencao\b": "intervenção",
    r"\borganizacao\b": "organização",
    r"\bestatizacao\b": "estatização",
    r"\bpopulacao\b": "população",
    r"\bprotecao\b": "proteção",
    r"\binclusao\b": "inclusão",
    r"\bcriacao\b": "criação",
    r"\bsimplificacao\b": "simplificação",
    r"\btributaria\b": "tributária",
    r"\bherancas\b": "heranças",
    r"\bpossivel\b": "possível",
    r"\bcontrario\b": "contrário",
    r"\bvalorizacao\b": "valorização",
    r"\bprivatizacoes\b": "privatizações",
    r"\bestatizacoes\b": "estatizações",
    r"\bcomunitaria\b": "comunitária",
    r"\bpolitico\b": "político",
    r"\be calculado\b": "é calculado",
    r"\bpoliticos\b": "políticos",
    r"\bsalarios\b": "salários",
    r"\brevogaveis\b": "revogáveis",
    r"\bimposicao\b": "imposição",
    r"\bnegociacao\b": "negociação",
    r"\bformalizacao\b": "formalização",
    r"\bmicrocredito\b": "microcrédito",
    r"\brevogacao\b": "revogação",
    r"\bprevidenciaria\b": "previdenciária",
    r"\bterceirizacao\b": "terceirização",
    r"\bpejotizacao\b": "pejotização",
    r"\bmunicoes\b": "munições",
    r"\bexpansao\b": "expansão",
    r"\bdesmilitarizacao\b": "desmilitarização",
    r"\bpolicia\b": "polícia",
    r"\bantidiscriminacao\b": "antidiscriminação",
    r"\buniao\b": "união",
    r"\bindigena\b": "indígena",
    r"\bsustentaveis\b": "sustentáveis",
    r"\boperacao\b": "operação",
    r"\bguardioes\b": "guardiões",
    r"\bincendios\b": "incêndios",
    r"\becologico\b": "ecológico",
    r"\bestrategia\b": "estratégia",
    r"\bfundiarios\b": "fundiários",
    r"\bresponsaveis\b": "responsáveis",
    r"\bpaises\b": "países",
    r"\bliquido\b": "líquido",
    r"\bcreditos\b": "créditos",
    r"\bnacoes\b": "nações",
    r"\bdemocraticas\b": "democráticas",
    r"\bclimaticos\b": "climáticos",
    r"\binflacao\b": "inflação",
    r"\bagraria\b": "agrária",
    r"\bocupacao\b": "ocupação",
    r"\bredistribuicao\b": "redistribuição",
    r"\bagricolas\b": "agrícolas",
    r"\bexportacao\b": "exportação",
    r"\bindustrializacao\b": "industrialização",
    r"\bflexivel\b": "flexível",
    r"\btecnologico\b": "tecnológico",
    r"\bjudiciario\b": "judiciário",
    r"\bjuizes\b": "juízes",
    r"\bprivilegios\b": "privilégios",
    r"\betica\b": "ética",
    r"\bcomunicacao\b": "comunicação",
    r"\bdesinformacao\b": "desinformação",
    r"\bmidia\b": "mídia",
    r"\binformacao\b": "informação",
    r"\bodio\b": "ódio",
    r"\brenegociacao\b": "renegociação",
    r"\bdividas\b": "dívidas",
    r"\bvulneraveis\b": "vulneráveis",
    r"\bpoupanca\b": "poupança",
    r"\bcarencia\b": "carência",
    r"\bindividuos\b": "indivíduos",
    r"\bmacroeconomica\b": "macroeconômica",
    r"\bcooperacao\b": "cooperação",
    r"\badesao\b": "adesão",
    r"\bforcas\b": "forças",
    r"\bareas\b": "áreas",
    r"\bpreocupacao\b": "preocupação",
    r"\binterferencia\b": "interferência",
    r"\bimplantacao\b": "implantação",
    r"\batuacao\b": "atuação",
    r"\breestruturacao\b": "reestruturação",
    r"\bpolicias\b": "polícias",
    r"\bconcentracao\b": "concentração",
    r"\bmunicipios\b": "municípios",
    r"\breorganizacao\b": "reorganização",
    r"\bcompeticao\b": "competição",
    r"\bmetricas\b": "métricas",
    r"\blimitacao\b": "limitação",
    r"\benergeticas\b": "energéticas",
    r"\brenovavel\b": "renovável",
    r"\babolicao\b": "abolição",
    r"\bacessiveis\b": "acessíveis",
    r"\banticorrupcao\b": "anticorrupção",
    r"\barticulacao\b": "articulação",
    r"\bautodeterminacao\b": "autodeterminação",
    r"\bautossuficiencia\b": "autossuficiência",
    r"\bbancaria\b": "bancária",
    r"\bbancario\b": "bancário",
    r"\bbancarios\b": "bancários",
    r"\bbeneficiarios\b": "beneficiários",
    r"\bbiocombustiveis\b": "biocombustíveis",
    r"\bcombustiveis\b": "combustíveis",
    r"\bcomunicacoes\b": "comunicações",
    r"\bconcepcao\b": "concepção",
    r"\bconotacoes\b": "conotações",
    r"\bconservacao\b": "conservação",
    r"\bconsolidacao\b": "consolidação",
    r"\bcontratacao\b": "contratação",
    r"\bconvencoes\b": "convenções",
    r"\bcorporacoes\b": "corporações",
    r"\bcotacao\b": "cotação",
    r"\bdemarcacao\b": "demarcação",
    r"\bdemocratizacao\b": "democratização",
    r"\bdependencia\b": "dependência",
    r"\bdesideologizacao\b": "desideologização",
    r"\bdesoneracao\b": "desoneração",
    r"\bdesregulamentacao\b": "desregulamentação",
    r"\bdestruicao\b": "destruição",
    r"\bdiarias\b": "diárias",
    r"\bdiscriminacao\b": "discriminação",
    r"\berario\b": "erário",
    r"\bevolucao\b": "evolução",
    r"\bexploracao\b": "exploração",
    r"\bexpropriacao\b": "expropriação",
    r"\bextincao\b": "extinção",
    r"\bextracao\b": "extração",
    r"\bfintechizacao\b": "fintechização",
    r"\bflexiveis\b": "flexíveis",
    r"\bformacao\b": "formação",
    r"\bfuncao\b": "função",
    r"\bfuncoes\b": "funções",
    r"\bfundiaria\b": "fundiária",
    r"\bgamificacao\b": "gamificação",
    r"\bgeracao\b": "geração",
    r"\bgraduacao\b": "graduação",
    r"\bimplementacao\b": "implementação",
    r"\bincompativel\b": "incompatível",
    r"\bincorporacao\b": "incorporação",
    r"\bindenizacao\b": "indenização",
    r"\bindependencia\b": "independência",
    r"\binformatizacao\b": "informatização",
    r"\binsercao\b": "inserção",
    r"\binsuportavel\b": "insuportável",
    r"\bisencoes\b": "isenções",
    r"\bmineracao\b": "mineração",
    r"\bnacionalizacao\b": "nacionalização",
    r"\bnegociacoes\b": "negociações",
    r"\bniveis\b": "níveis",
    r"\bnivel\b": "nível",
    r"\bobrigacao\b": "obrigação",
    r"\borcamentario\b": "orçamentário",
    r"\borientacao\b": "orientação",
    r"\boriginarios\b": "originários",
    r"\bprimario\b": "primário",
    r"\bprotecoes\b": "proteções",
    r"\bpunicao\b": "punição",
    r"\breestatizacao\b": "reestatização",
    r"\breferencia\b": "referência",
    r"\brelacao\b": "relação",
    r"\brenovacao\b": "renovação",
    r"\brenovaveis\b": "renováveis",
    r"\breparacao\b": "reparação",
    r"\bresponsavel\b": "responsável",
    r"\brevolucionaria\b": "revolucionária",
    r"\bsubstituicao\b": "substituição",
    r"\btelecomunicacoes\b": "telecomunicações",
    r"\btitulacao\b": "titulação",
    r"\btolerancia\b": "tolerância",
    r"\btransferencia\b": "transferência",
    r"\btransformacao\b": "transformação",
    r"\btransicao\b": "transição",
    r"\btributarias\b": "tributárias",
    r"\btributario\b": "tributário",
    r"\bunificacao\b": "unificação",
    r"\busuarios\b": "usuários",
    r"\blogica\b": "lógica",
    r"\borcamento\b": "orçamento",
    r"\bequilibrio\b": "equilíbrio",
    r"\bcodigo\b": "código",
}

TECHNICAL_TOKENS = (
    "sem_posicao",
    "theme_id",
    "party_acronym",
    "candidate_position",
    "API_BASE_URL",
    "PULAR ESTA QUESTÃO",
    "UNIAO",
)

MOBILE_COPY_FILES = (
    "mobile/lib/features/quiz/quiz_intro_page.dart",
    "mobile/lib/features/quiz/quiz_page.dart",
    "mobile/lib/features/weighting/weighting_page.dart",
    "mobile/lib/features/party_selection/party_selection_page.dart",
    "mobile/lib/features/results/results_page.dart",
    "mobile/lib/features/comparison/comparison_page.dart",
    "mobile/lib/shared/models/party.dart",
)


def without_technical_tokens(text: str) -> str:
    for token in TECHNICAL_TOKENS:
        text = text.replace(token, "")
    return text


def find_unaccented_terms(label: str, text: str) -> list[str]:
    normalized = without_technical_tokens(text).lower()
    findings = []
    for pattern, expected in MISSING_ACCENT_TERMS.items():
        if re.search(pattern, normalized):
            findings.append(f"{label}: {pattern} -> {expected}")
    return findings


def iter_seed_display_text() -> list[tuple[str, str]]:
    data = json.loads((ROOT / "data/theses/2022/theses.json").read_text(encoding="utf-8"))
    display_text = [("metadata.sources", data["metadata"]["sources"])]
    for thesis in data["theses"]:
        display_text.append((f"thesis {thesis['id']} text", thesis["text"]))
        for candidate_id, position in thesis["positions"].items():
            justification = position.get("justification")
            if justification:
                display_text.append(
                    (f"thesis {thesis['id']} {candidate_id} justification", justification)
                )
    return display_text


def main() -> int:
    findings: list[str] = []
    for label, text in iter_seed_display_text():
        findings.extend(find_unaccented_terms(label, text))

    for relative_path in MOBILE_COPY_FILES:
        path = ROOT / relative_path
        findings.extend(
            find_unaccented_terms(relative_path, path.read_text(encoding="utf-8"))
        )

    if findings:
        print("Found unaccented Brazilian Portuguese display copy:")
        for finding in findings[:80]:
            print(f"- {finding}")
        if len(findings) > 80:
            print(f"- ... {len(findings) - 80} more")
        return 1

    bad_phrasing = "PULAR ESTÁ QUESTÃO"
    quiz_page = (ROOT / "mobile/lib/features/quiz/quiz_page.dart").read_text(
        encoding="utf-8"
    )
    if bad_phrasing in quiz_page:
        print(f"Found incorrect Brazilian Portuguese phrasing: {bad_phrasing}")
        return 1

    print("Brazilian Portuguese display copy check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
