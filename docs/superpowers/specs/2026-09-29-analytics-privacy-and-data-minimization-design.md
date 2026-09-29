# Privacidade, consentimento de Analytics e minimização de dados — Design

**Data:** 2026-09-29

**Status:** desenho conversacional aprovado; aguardando revisão desta especificação

**Projeto:** Farol Político

**Base auditada:** `origin/main` em `95c22e12dfc428ca1660a113ba8c46423934d2c9`

## Objetivo

Manter métricas de produto úteis para o Farol Político sem iniciar o Google
Analytics antes de uma escolha positiva, sem enviar respostas ou preferências
políticas ao Analytics e sem persistir as respostas do quiz na implantação
pública em que o IoT está desligado.

A solução deve ser pequena, explícita e verificável. O quiz continua disponível
para quem rejeitar métricas. O projeto continua sendo um site Flutter Web; o
código compartilhado deve permanecer seguro em Android, mas esta entrega não
cria fluxos, permissões ou textos específicos de lojas iOS/Android.

## Fatos atuais que orientam o desenho

- O fluxo atual do Firebase Analytics é único; o PR #58 removeu o segundo envio
  por `gtag`.
- Os eventos customizados atuais não enviam tese, resposta, partido, candidato
  nem afinidade. Eles enviam apenas nomes genéricos e, em alguns casos,
  duração ou contagens.
- No Web, a primeira chamada efetiva ao Firebase Analytics inicializa o SDK,
  cria um Firebase Installation ID, carrega a tag e pode emitir `page_view`.
- O GA4 e o BigQuery ainda mantêm histórico anterior com campos políticos e
  identificadores pseudônimos.
- O cliente envia hoje um UUID junto às respostas do quiz. O backend grava as
  respostas mesmo quando `IOT_FEATURE_ENABLED=false`.
- O ranking é calculado diretamente a partir do corpo da requisição e não
  depende das respostas armazenadas. A única leitura funcional dessas
  respostas serve ao recurso IoT, que está desativado em produção.
- O mesmo UUID local continua necessário para seguir um ator político,
  autoria/ações na comunidade e um possível retorno do IoT. A mudança no quiz
  não pode apagar nem rotacionar essa identidade funcional.
- O PR #59 permite que a própria pessoa gere e compartilhe uma imagem e uma
  legenda com candidato e afinidade. Essa divulgação é voluntária e precisa
  ser descrita separadamente; ela não autoriza envio desses valores ao GA4.

## Decisões de escopo

Esta entrega inclui:

1. consentimento básico para métricas, negado enquanto não houver escolha;
2. inicialização preguiçosa do Firebase e do Firebase Analytics;
3. revogação e nova aceitação pelo próprio site;
4. aviso de privacidade completo e acessível;
5. ausência de persistência do quiz quando IoT estiver desligado;
6. retenção curta e limpeza do histórico analítico e das respostas antigas;
7. testes unitários, de widgets, backend, Web e validação em navegador real;
8. atualização da documentação pública e operacional.

Não inclui:

- uma CMP de terceiros;
- Consent Mode avançado ou pings sem cookies antes da escolha;
- publicidade, Google Signals, remarketing ou personalização de anúncios;
- criação de conta, login ou recuperação do UUID local;
- exclusão da comunidade, de follows ou do compartilhamento voluntário;
- remoção das tabelas de quiz do schema, pois elas continuam pertencendo ao
  modo IoT desativado;
- instrumentação de todas as lacunas de produto encontradas na auditoria de
  cobertura. Essa cobertura será estudada separadamente antes de ampliar o
  vocabulário de eventos.

## Identidade do controlador e canal público

O aviso deve mostrar a identidade real de quem decide as finalidades e os
meios de tratamento no Farol Político e um canal público funcional para
pedidos de titulares. “Farol Político” sozinho não substitui o nome civil ou a
razão social quando for apenas uma marca.

O build Web receberá duas variáveis públicas obrigatórias:

- `PRIVACY_CONTROLLER_NAME`: nome civil completo ou razão social do
  controlador;
- `PRIVACY_CONTACT_EMAIL`: caixa funcional monitorada para privacidade.

O workflow deve falhar antes do build quando qualquer valor estiver ausente,
vazio ou contiver valor de exemplo. Esses dados são públicos por natureza e
não pertencem a secrets. Os e-mails que receberam papel `Editor` no GCP não
serão reutilizados nem publicados sem instrução expressa.

O produto não chamará alguém de “encarregado” ou “DPO” sem uma indicação
formal. Antes da publicação, o responsável pelo projeto deve registrar uma
destas duas decisões fora do código:

- enquadramento documentado na dispensa aplicável a agente de pequeno porte,
  mantendo o canal público; ou
- indicação do encarregado, caso em que a identidade e o contato também serão
  publicados.

A falta da identidade real ou de um canal funcional bloqueia a publicação do
novo aviso; não será contornada com nome de marca, placeholder ou e-mail
inventado.

## Consentimento de Analytics

### Estados e persistência

Um controlador de consentimento terá três estados:

- `pending`: nenhuma escolha salva;
- `granted`: métricas aceitas;
- `denied`: métricas rejeitadas ou revogadas.

A escolha será persistida em `SharedPreferences` sob uma chave versionada. O
estado será hidratado antes de montar a árvore de widgets para evitar piscar o
banner ou inicializar serviços com uma decisão ainda desconhecida.

Eventos ocorridos em `pending` ou `denied` serão descartados. Eles não serão
enfileirados nem reproduzidos depois de uma aceitação.

### Inicialização preguiçosa

`main.dart` deixará de inicializar Firebase no startup. Hoje nenhum outro
produto Firebase é usado em runtime pelo cliente, portanto o Firebase só será
inicializado quando o primeiro evento futuro encontrar consentimento
`granted`.

O caminho padrão do `AnalyticsService` passará por um sink consciente de
consentimento. Esse sink:

1. consulta o estado atual sem criar o SDK;
2. descarta o evento quando o estado não for `granted`;
3. no primeiro evento autorizado, configura no Web o estado de consentimento
   antes de `Firebase.initializeApp`;
4. inicializa Firebase e Analytics uma única vez;
5. envia o evento pelo único pipeline Firebase já existente.

No Web, antes da inicialização, a ponte só emitirá o comando de consentimento.
Ela não carregará `gtag.js` nem chamará `js`, `config` ou `event`. O Firebase
continuará sendo o único carregador e emissor.

Os estados de publicidade permanecerão sempre negados:

- `ad_storage`;
- `ad_user_data`;
- `ad_personalization`.

Somente `analytics_storage` poderá ser concedido. Não haverá pings anônimos ou
sem cookies antes da aceitação.

O Android continuará fora do produto publicado, mas será deixado em estado
seguro: a coleta automática ficará desativada por metadata e só poderá ser
habilitada pelo mesmo controlador depois do aceite. O alvo iOS não inicializa
Firebase neste projeto. Como não há publicidade nem distribuição nativa nesta
entrega, não será solicitado ATT nem criada permissão móvel sem finalidade.

### Revogação e nova aceitação

Se Analytics ainda não tiver sido inicializado, rejeitar ou revogar apenas
fecha o gate. Se já tiver sido inicializado, a revogação primeiro fecha o gate
e depois aplica `analytics_storage=denied` e desativa a coleção para impedir
novos hits.

Uma nova aceitação reabilita a coleção, atualiza o estado de consentimento e
permite apenas eventos futuros. Falha ao inicializar ou atualizar o SDK não
impede o uso do site; o evento é perdido e o erro fica restrito a diagnóstico
sem payload político.

## Experiência no site

### Primeira visita

Enquanto o estado for `pending`, um banner responsivo e acessível explica em
linguagem curta que o Google Analytics mede uso e desempenho, pode receber um
identificador pseudônimo, página, navegador/dispositivo e eventos genéricos, e
não é usado para publicidade.

O banner terá ações com igual destaque visual e sem opção pré-marcada:

- `REJEITAR MÉTRICAS`;
- `ACEITAR MÉTRICAS`;
- `SAIBA MAIS`.

Fechar, continuar navegando ou iniciar o quiz não conta como aceitação. O
banner não bloqueia o conteúdo nem o quiz.

### Aviso e preferências permanentes

Uma rota pública e permanente de privacidade conterá:

- controlador e canal;
- finalidades, bases legais e categorias de dados por função;
- Google Analytics, Firebase Installation ID após aceite, Google/GA4 e
  BigQuery;
- processamento transitório das respostas do quiz e ausência de gravação no
  modo público sem IoT;
- UUID funcional de follow e comunidade;
- conteúdo de posts/comentários e moderação via NVIDIA NIM;
- compartilhamento voluntário do resultado pelo próprio usuário;
- localização aproximada, dispositivo, URL/referrer e logs técnicos;
- armazenamento no Neon/PostgreSQL e infraestrutura Google Cloud;
- transferências internacionais aplicáveis;
- prazos de retenção;
- direitos do art. 18 e como exercê-los;
- link para a explicação do Google sobre dados de sites parceiros.

O rodapé da gaveta continuará oferecendo `PRIVACIDADE`, agora abrindo essa
rota. A página exibirá o estado atual das métricas e permitirá aceitar,
rejeitar ou revogar com a mesma facilidade.

O texto atual que afirma que o identificador salva respostas do quiz será
substituído. A página não prometerá anonimato total, ausência de tratamento de
IP ou ausência geral de dados sensíveis.

### Transparência específica do quiz

A introdução do quiz informará, sem uma segunda caixa de consentimento, que as
respostas são enviadas à API para calcular o resultado e não são armazenadas
na versão pública com IoT desligado. O processamento necessário ao cálculo é
separado e independente da escolha sobre Analytics.

## Persistência das respostas do quiz

### Cliente

`QuizSession` receberá a flag de IoT, injetável em testes. Com IoT desligado,
`submitQuiz` omitirá `device_id`. Com IoT ligado, manterá o contrato atual para
as funções de hardware.

### Backend

O backend é a barreira de segurança definitiva para clientes antigos. Ele
continuará aceitando e validando `device_id`, mas só executará
`upsert_answers` e notificações quando
`request.app.state.settings.iot_feature_enabled` for verdadeiro.

Com a flag falsa:

- a API calcula e devolve o mesmo ranking;
- um UUID legado não cria nem atualiza `devices`;
- nenhuma linha de `quiz_responses` é criada ou alterada;
- nenhum push de notícia é iniciado.

Não haverá migration de schema. As tabelas e o repositório permanecem para um
eventual modo IoT explicitamente habilitado.

## Dados de Analytics permitidos

Os eventos atuais do quiz e comparação permanecem, sujeitos ao gate. As
assinaturas públicas podem continuar aceitando valores usados pela UI, mas o
sink nunca receberá:

- tese ou índice de tese;
- resposta, posição ou peso individual;
- partido ou candidato;
- colocação, score ou afinidade;
- conteúdo de post, comentário, busca ou compartilhamento;
- UUID funcional do Farol Político.

São permitidos apenas:

- nomes de evento genéricos;
- duração em milissegundos;
- totais de respostas, pulos, pesos e seleções;
- no futuro, parâmetros de enumeração fechada que não identifiquem conteúdo
  político, depois de revisão específica.

Eventos customizados nunca enviarão URL. A configuração de redação do stream
deve ocultar ao menos `fbclid`, `gclid`, `dclid`, `gbraid` e `wbraid` antes de
armazenar o `page_location` automático. Recursos de publicidade e Google
Signals ficarão desligados. A política continuará informando que o GA4 pode
receber a página e o referrer, sem prometer que toda URL é anônima.

## Retenção e acesso

### GA4

- retenção de eventos e usuários: 2 meses;
- redefinição da retenção em nova atividade: desligada;
- sem Google Signals, personalização de anúncios ou links publicitários;
- apenas o stream Web ativo para esta entrega.

Relatórios agregados padrão podem ter comportamento de retenção próprio do
GA4; o aviso não prometerá que toda contagem agregada desaparece em 60 dias.

### BigQuery

- expiração padrão de novas tabelas: 60 dias;
- exportação de dados pseudônimos por usuário: desligada;
- exportação limitada aos eventos necessários;
- os papéis de projeto concedidos anteriormente aos dois colaboradores serão
  preservados, conforme instrução expressa, sem ampliar novos acessos.

O prazo do BigQuery é independente do GA4. A política explicará essa diferença
sem apresentar identificadores pseudônimos como anônimos.

### Banco e logs

- respostas históricas do quiz e linhas da tabela funcional `devices` serão
  removidas no corte descrito abaixo;
- dados de follow e comunidade não fazem parte dessa exclusão;
- logs padrão do Cloud Run permanecem sujeitos à retenção configurada no
  Cloud Logging; o aviso usará o prazo efetivamente verificado na implantação,
  atualmente 30 dias para `_Default`;
- logs de auditoria obrigatórios têm finalidade e retenção próprias e não
  serão descritos como analytics de produto.

## Limpeza e corte de histórico

A limpeza ocorrerá somente depois de código implantado e verificações provarem
que novas respostas não são gravadas e que não existe tráfego Analytics antes
do aceite.

### Google Analytics

Uma solicitação comum de exclusão do GA4 não remove parâmetros numéricos nem
zera necessariamente as contagens históricas. Como o histórico contém IDs
numéricos de teses e eventos duplicados, o corte limpo será:

1. criar e configurar uma nova propriedade GA4 sem publicidade;
2. remover o link do Firebase com a propriedade antiga;
3. vincular o mesmo projeto Firebase à nova propriedade;
4. atualizar o `measurementId` do Web app no código gerado e validar o único
   pipeline;
5. recriar o vínculo do BigQuery com as configurações mínimas;
6. mover a propriedade antiga para a lixeira do Analytics.

A propriedade antiga fica recuperável pelo prazo da lixeira do Google e é
eliminada definitivamente depois desse prazo. O corte não reutiliza dados
históricos no novo ambiente.

### BigQuery

Antes da exclusão será registrado um inventário com projeto, dataset, nomes,
tipos e quantidade de tabelas. Depois do corte, todas as tabelas do dataset
Analytics antigo serão excluídas por nomes resolvidos explicitamente; o
dataset não será removido por um glob ou caminho amplo. A recuperação seguirá
a janela real de time travel/fail-safe do BigQuery, documentada no relatório
de execução.

### Neon/PostgreSQL

Antes da exclusão serão registrados apenas totais agregados. Dentro de uma
transação verificada:

1. excluir linhas de `quiz_responses`;
2. excluir linhas de `devices` que só serviam à persistência do quiz;
3. confirmar contagem zero nas duas tabelas;
4. confirmar que follow, posts, comentários, votos e relatórios não mudaram.

Credenciais e UUIDs individuais nunca serão impressos no relatório. A
possibilidade de recuperação dependerá dos backups e da retenção real do Neon
verificados imediatamente antes da operação.

## Ordem de implantação

1. publicar o backend com o gate de IoT;
2. provar em produção que submissões com e sem UUID não gravam quando IoT está
   desligado;
3. publicar o site com consentimento, aviso e omissão do UUID no quiz;
4. validar os três estados em navegador limpo;
5. configurar a nova propriedade GA4, o stream e a retenção;
6. configurar BigQuery e sua expiração;
7. observar um ciclo de exportação e confirmar os campos de consentimento;
8. executar a limpeza aprovada;
9. registrar inventários, horários, resultados e janelas de recuperação.

O workflow existente já publica backend antes do Web para o mesmo commit. Um
rollback não poderá apontar para uma revisão anterior ao gate do backend,
porque isso reativaria a persistência silenciosa para clientes antigos.

## Comportamento em falhas

- preferência local ilegível: tratar como `pending` e não coletar;
- Firebase indisponível: manter o site funcional e descartar o evento;
- tentativa concorrente de inicialização: compartilhar uma única `Future`;
- revogação durante inicialização: o gate fecha imediatamente e a conclusão
  aplica o estado negado antes de aceitar novo evento;
- falha ao salvar a escolha: manter o estado mais protetivo e informar que a
  preferência não pôde ser salva;
- falha no cálculo do quiz: preservar o tratamento atual e não persistir como
  fallback;
- variável pública de controlador/contato ausente: falhar o build de
  produção.

## Verificação e critérios de aceite

### Testes automatizados

- `pending` e `denied` não constroem nem acessam Firebase Analytics;
- eventos descartados não são reproduzidos após aceite;
- `granted` encaminha cada evento exatamente uma vez;
- revogar bloqueia imediatamente; aceitar novamente libera apenas eventos
  futuros;
- hidratação restaura cada escolha sem emissão prematura;
- todos os testes de minimização dos payloads continuam passando;
- o Web mantém um único pipeline, sem `gtag('event')` paralelo;
- banner tem aceitar/rejeitar equivalentes, não bloqueia o quiz e abre o aviso;
- preferências permanentes alteram e persistem o estado;
- política renderiza controlador e contato fornecidos pelo build;
- quiz com IoT falso omite UUID;
- backend com IoT falso e UUID legado devolve 200 sem criar ou atualizar
  `devices`/`quiz_responses` nem fazer push;
- backend com IoT verdadeiro preserva persistência e push;
- o fluxo de compartilhamento do PR #59 permanece funcional e continua sem
  enviar candidato/afinidade ao Analytics.

### Navegador real

Em perfil limpo, sem bloqueador e com `Preserve log`:

- antes da escolha e depois de rejeitar: zero chamadas a `g/collect`,
  `google-analytics.com`, `googletagmanager.com` e Firebase Installations;
- antes da escolha: nenhum cookie `_ga*` e nenhum FID no IndexedDB;
- depois de aceitar: um único carregamento/configuração e eventos únicos;
- depois de revogar: cessam novos hits;
- ao recarregar: a escolha é restaurada sem banner incorreto;
- o quiz completa normalmente nos três estados;
- o BigQuery novo mostra `analytics_storage=Yes` apenas para tráfego aceito e
  estados de publicidade negados.

### Suítes do repositório

```bash
cd backend
uv run pytest
uv run ruff check .
uv run mypy app/

cd ../mobile
flutter analyze
flutter test
flutter test --platform chrome test/analytics_default_pipeline_web_test.dart
flutter build web --release \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=PRIVACY_CONTROLLER_NAME="$PRIVACY_CONTROLLER_NAME" \
  --dart-define=PRIVACY_CONTACT_EMAIL="$PRIVACY_CONTACT_EMAIL"
```

As duas variáveis do comando são fornecidas pela implantação. O workflow
rejeita sua ausência antes de executar o build.

## Fontes normativas e técnicas usadas no desenho

- LGPD, especialmente arts. 5º, 6º, 9º, 11, 18 e 41;
- Resolução CD/ANPD nº 2/2022, especialmente arts. 3º, 7º e 11;
- Resolução CD/ANPD nº 18/2024 sobre atuação do encarregado;
- guias da ANPD sobre cookies, legítimo interesse e agentes de tratamento;
- Termos do Google Analytics para o Brasil;
- documentação do Google sobre Consent Mode, retenção e exclusão;
- documentação do Firebase sobre inicialização, Analytics e vínculos;
- documentação do BigQuery sobre expiração e time travel.

Esta especificação organiza requisitos técnicos e transparência; ela não
substitui uma avaliação jurídica individual do controlador.
