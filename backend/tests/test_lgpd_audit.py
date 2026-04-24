from app.infrastructure.database.models import Base

FORBIDDEN_SUBSTRINGS = [
    "email",
    "e_mail",
    "phone",
    "telefone",
    "cpf",
    "rg",
    "address",
    "endereco",
    "ip_address",
    "latitude",
    "longitude",
    "geo",
    "push_token",
    "device_imei",
    "idfa",
    "android_id",
]


def test_schema_has_no_pii_fields() -> None:
    violations: list[str] = []
    for table in Base.metadata.tables.values():
        for col in table.columns:
            lower = col.name.lower()
            for substr in FORBIDDEN_SUBSTRINGS:
                if substr in lower:
                    violations.append(f"{table.name}.{col.name}")
                    break

    assert not violations, f"Campos PII encontrados: {violations}"


def test_user_facing_tables_dont_have_name_columns() -> None:
    user_tables = {"devices", "quiz_responses"}
    bad: list[str] = []
    for table in Base.metadata.tables.values():
        if table.name not in user_tables:
            continue
        for col in table.columns:
            if "name" in col.name.lower():
                bad.append(f"{table.name}.{col.name}")
    assert not bad, f"Tabelas anonimas tem colunas com 'name': {bad}"
