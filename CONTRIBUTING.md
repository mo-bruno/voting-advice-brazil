# Contribuição

## Fluxo

1. Crie uma branch curta: `feat/...`, `fix/...` ou `docs/...`.
2. Mantenha o PR focado em uma mudança.
3. Explique o que mudou e como foi verificado.
4. Não inclua segredos, bancos locais, builds ou arquivos de ambiente reais.

## Verificação

Backend:

```bash
cd backend
uv run pytest
uv run ruff check .
uv run mypy app/
```

Mobile:

```bash
cd mobile
flutter test
```

## Padrões

- Código e docs em português quando forem texto de produto.
- Commits pequenos e descritivos.
- Novas variáveis de ambiente devem entrar em `.env.example`.
- Mudanças de API devem manter `/docs` e testes atualizados.
