# Publicação da edição presidencial de 2026

## Escopo e limites

Treze candidaturas e fotos oficiais do retrato de 20/09/2026; nove teses ativas. Revisão integral automatizada dos planos: 836 páginas e 117 decisões, sem células pendentes nesse núcleo. Há 37 posições categóricas, quatro condicionais e 76 casos sem manifestação suficiente. As outras 29 formulações ficam fora do quiz. Sem certificação editorial humana, recomendação de voto ou destaque de vencedor.

O detalhamento editorial e a matriz auditável ficam em `data/theses/2026/REVIEW.md` e `review-audit.json`. As entradas textuais originais necessárias à reconstrução são versionadas; PDFs e ZIPs grandes continuam preservados localmente, com hashes registrados.

## Condição externa

A proteção de `main` exige uma aprovação de outra pessoa. Não usar merge administrativo, force push ou publicação direta para contornar essa revisão. A autorização para preparar a publicação não remove essa regra do repositório.

## Ordem de publicação

1. Aprovar a proposta de alteração após CI e revisão do recorte editorial.
2. Migrar o banco de forma aditiva, preservando histórico e as migrações de comunidade/IoT já publicadas.
3. Publicar revisão intermediária com filtros e o ano anterior; mover 100% do tráfego para ela antes de adicionar 2026.
4. Carregar o snapshot 2026 transacionalmente; só depois ativar a edição 2026.
5. Publicar a interface após sucesso do backend, usando o mesmo commit.
6. Conferir saúde, somente 13 candidaturas de 2026, nove perguntas, fotos, cobertura e fontes. Não criar mensagens comunitárias de teste em produção.

## Recuperação

O processo registra `SAFE_BRIDGE_REVISION` nos logs depois de publicar a revisão intermediária. Se a carga ou ativação falhar, ela continua apta a servir a eleição anterior com filtros. Após carregar 2026, não restaurar imagem anterior a esses filtros: ela pode misturar eleições.

Para recuperação, transferir 100% do tráfego para a revisão intermediária registrada, na região `us-east4` e projeto `farol-politico-495210`. Não executar downgrade destrutivo de banco. Se apenas a interface falhar, restaurar a versão anterior do Firebase Hosting; o backend preserva contratos existentes.

Na inspeção anterior à entrega, a produção estava na revisão `farol-politico-api-00029-8kr`; esta não é um destino seguro de recuperação após carregar 2026. Moderação NVIDIA e `IOT_FEATURE_ENABLED=false` devem ser preservados.

## Privacidade

Não enviar respostas, teses identificáveis, seleção de partidos/candidatos ou afinidade individual aos serviços de métricas. Gravação de sessões desativada. Eventos genéricos, duração e contagens permanecem; isso não constitui anonimização completa. O serviço conserva a persistência funcional já existente das respostas, separada dessas métricas.
