# Publicação da edição presidencial de 2026

## Escopo e limites

Treze candidaturas e fotos oficiais do retrato de 20/09/2026; 30 teses ativas. A revisão integral automatizada dos planos classificou as 910 combinações de 70 formulações, sem células pendentes. O quiz contém 116 posições categóricas, 20 condicionais ou mistas e 254 casos sem manifestação suficiente. As outras 40 formulações permanecem documentadas, mas ficam fora da pontuação por falta de contraste, redundância ou inadequação de escopo. Sem certificação editorial humana, recomendação de voto ou destaque de vencedor.

O detalhamento editorial e a matriz auditável ficam em `data/theses/2026/REVIEW.md` e `review-audit.json`. As entradas textuais originais necessárias à reconstrução são versionadas; PDFs e ZIPs grandes continuam preservados localmente, com hashes registrados.

## Condição externa

A proteção de `main` exige uma aprovação de outra pessoa. Não usar merge administrativo, force push ou publicação direta para contornar essa revisão. A autorização para preparar a publicação não remove essa regra do repositório.

## Ordem de publicação

1. Aprovar a proposta de alteração após CI e revisão do recorte editorial.
2. Migrar o banco de forma aditiva, preservando histórico e as migrações de comunidade/IoT já publicadas.
3. Publicar revisão intermediária com filtros e o ano anterior; mover 100% do tráfego para ela antes de adicionar 2026.
4. Carregar o snapshot 2026 transacionalmente; só depois ativar a edição 2026.
5. Publicar a interface após sucesso do backend, usando o mesmo commit.
6. Conferir saúde, somente 13 candidaturas de 2026, 30 perguntas, fotos, cobertura e fontes. Não criar mensagens comunitárias de teste em produção.

Republicações manuais devem iniciar o workflow `Deploy Backend` em `main`; a interface não tem disparo manual independente. O workflow web recebe o commit exato do backend concluído com sucesso.

## Recuperação

O processo registra `SAFE_BRIDGE_REVISION` nos logs depois de publicar a revisão intermediária. Se a carga ou ativação falhar, ela continua apta a servir a eleição anterior com filtros. Após carregar 2026, não restaurar imagem anterior a esses filtros: ela pode misturar eleições.

Para recuperação, transferir 100% do tráfego para a revisão intermediária registrada, na região `us-east4` e projeto `farol-politico-495210`. Não executar downgrade destrutivo de banco. Se apenas a interface falhar, restaurar a versão anterior do Firebase Hosting; o backend preserva contratos existentes.

Na inspeção anterior à entrega, a produção estava na revisão `farol-politico-api-00029-8kr`; esta não é um destino seguro de recuperação após carregar 2026. Moderação NVIDIA e `IOT_FEATURE_ENABLED=false` devem ser preservados.

## Privacidade

Não enviar respostas, teses identificáveis, seleção de partidos/candidatos ou afinidade individual aos serviços de métricas. Gravação de sessões desativada. Eventos genéricos, duração e contagens permanecem; isso não constitui anonimização completa. O serviço conserva a persistência funcional já existente das respostas, separada dessas métricas.

## Verificação da entrega

- A expansão preserva a base de implantação segura já integrada à `main`, além da moderação NVIDIA, identidade privada e limites de publicação da comunidade.
- Backend: 583 testes aprovados, cobertura de 93,66%, Ruff sem problemas nos arquivos alterados e Mypy aprovado em 81 arquivos.
- Flutter: 234 testes aprovados, análise sem problemas e build web release concluído. Aviso não bloqueante de fonte CupertinoIcons ausente.
- Banco PostgreSQL 16: migração até `0009_election_refresh`, carga histórica de 2022 seguida de 2026 e repetição idempotente verificadas; nenhum desvio de schema detectado.
- Revisão independente de engenharia sem bloqueadores P1/P2 pendentes no escopo analisado. Isso não substitui a aprovação de outra pessoa nem transforma a revisão documental automatizada em validação humana.

Essas evidências são locais. O CI da proposta de alteração e a aprovação precisam ser confirmados antes da integração; os checks de produção da etapa 6 continuam obrigatórios após a publicação.

## Falha da primeira publicação e retomada

A execução de 20/09/2026 após integrar o PR #52 parou na preparação da ponte. O Cloud Build `c63ed2aa-e3c9-4b7e-b33f-2672aa00d984` concluiu imagem e migração, mas a checagem do script rejeitou o retorno agregado do serviço: `latestCreatedRevisionName` apontava para `00030-8c9`, enquanto `latestReadyRevisionName` ainda apontava para `00029-8kr`. A consulta da revisão nova confirmou `Ready=True`, `Active=False` e geração reconciliada. Carga e ativação de 2026 não executaram; 100% do tráfego permaneceu na revisão anterior, com 12 candidaturas de 2022 e saúde normal.

A correção consulta a revisão exata retornada pelo deploy, exige nome correspondente, geração reconciliada e uma única condição `Ready=True` antes de transferir tráfego. Ausência, erro de leitura ou prontidão não confirmada interrompem a publicação. Não exige `Active=True` em uma revisão criada sem tráfego. O contrato de reconciliação está na [documentação de revisões do Cloud Run](https://docs.cloud.google.com/run/docs/reference/rest/v1/namespaces.revisions).

Integrar a correção dispara uma nova publicação a partir do commit corrigido. Não basta repetir a execução antiga: ela reutiliza o script com defeito. A migração já aplicada é idempotente; não reverter schema nem alterar permissões IAM para contornar essa falha. O aviso de IAM observado no log não foi a exceção que encerrou a execução, e o acesso público anterior permaneceu funcionando.
