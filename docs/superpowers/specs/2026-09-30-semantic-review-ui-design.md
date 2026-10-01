# Interface local de revisão semântica

## Objetivo

Criar uma interface local para a revisão humana das 260 combinações entre 20 teses e 13 candidaturas. A ferramenta deve preservar todo o conteúdo analítico do caderno de revisão semântica e permitir que o revisor abra cada referência diretamente na página correspondente do plano oficial.

A interface apoia uma decisão editorial humana. Ela não altera a matriz, o aplicativo, o cálculo de afinidade nem as classificações de produção.

## Escopo e restrições

- Uso individual e local, em navegador desktop.
- Execução vinculada apenas a `127.0.0.1`, sem autenticação, telemetria ou envio de dados.
- Corpus de 13 candidaturas; Pablo Marçal permanece excluído.
- Fonte analítica: os relatórios JSON em `docs/research/2026-09-30-semantic-manual-review/candidates/`.
- Fonte documental: os PDFs oficiais registrados no manifesto da auditoria integral.
- Estado da revisão salvo localmente e exportável em JSON.
- Nenhuma dependência de serviços de produção ou do backend do aplicativo.
- Nenhuma inferência nova no navegador: a UI apresenta os dados auditados e registra a decisão humana.

## Conteúdo obrigatório de cada ficha

A ficha ativa deve apresentar integralmente os mesmos elementos do caderno consolidado:

1. número, texto e categoria da tese;
2. objeto da decisão, dimensões semânticas e limites de interpretação;
3. candidatura e partido;
4. classificação atual;
5. justificativa atual;
6. evidências diretas usadas pela matriz, com página, trecho e interpretação;
7. resumo da vizinhança semântica do plano;
8. trechos semanticamente relacionados, com página, relação, origem e relevância;
9. justificativa de ausência quando não houver contexto adicional;
10. avaliação semântica;
11. razões para manter a classificação;
12. razões para reconsiderar;
13. recomendação documental preliminar e nível de confiança;
14. pergunta dirigida ao revisor humano;
15. decisão humana e justificativa escrita.

A classificação atual, a recomendação preliminar e a decisão humana terão tratamentos visuais distintos. A interface não pode sugerir que a recomendação já tenha substituído a posição vigente.

## Experiência de revisão

### Estrutura principal

Em telas largas, a aplicação usa três áreas:

- **Navegação:** progresso, filtros e lista de teses ou candidaturas.
- **Ficha analítica:** todo o conteúdo semântico da combinação ativa.
- **Plano oficial:** visualizador do PDF na página selecionada.

Em telas menores, o plano abre em um painel sobreposto ou em nova aba, preservando a posição da ficha.

### Navegação e filtros

O revisor pode:

- começar pelos 13 casos da fila prioritária;
- alternar entre todas as fichas, somente pendentes, concluídas ou marcadas para retorno;
- filtrar por tese, categoria, candidatura, classificação atual e recomendação preliminar;
- percorrer as fichas anterior e seguinte sem perder alterações;
- ver uma comparação resumida das 13 candidaturas dentro de cada tese;
- pesquisar nomes e texto das teses.

O cabeçalho mostra quantas fichas foram decididas, quantas permanecem pendentes e quantas divergem da classificação vigente.

### Evidências e plano oficial

Cada evidência direta e cada trecho de contexto semântico é um controle clicável. Ao clicar:

1. a evidência fica destacada na ficha;
2. o visualizador carrega o PDF da candidatura ativa;
3. o PDF abre na página indicada pela citação;
4. o painel mostra o número da página e oferece “abrir em nova aba”.

O trecho citado permanece visível ao lado do PDF para facilitar sua localização visual. O navegador usa seu visualizador nativo; a primeira versão não tenta destacar coordenadas dentro da página, pois a auditoria registra página e texto, mas não caixas geométricas.

### Decisão humana

O rodapé fixo da ficha oferece:

- Concorda;
- Discorda;
- Condicional ou mista;
- Sem posição documental suficiente;
- campo de justificativa;
- marcação “revisitar depois”.

A decisão é salva automaticamente. Quando ela altera a classificação atual, a justificativa é obrigatória para considerar a ficha concluída. Manter a classificação permite justificativa opcional.

Atalhos de teclado podem selecionar as quatro posições, avançar e voltar, desde que os mesmos controles continuem disponíveis por clique e com rótulos acessíveis.

## Arquitetura

A ferramenta ficará em `docs/research/2026-09-30-semantic-manual-review/review-ui/` e usará apenas a biblioteca padrão do Python no servidor e HTML, CSS e JavaScript sem framework no navegador.

### Servidor local

`server.py` terá responsabilidades limitadas:

- iniciar um `ThreadingHTTPServer` em `127.0.0.1` numa porta configurável;
- servir os arquivos estáticos da interface;
- expor o conjunto de dados consolidado;
- ler e gravar decisões humanas;
- servir os PDFs com suporte a requisições HTTP Range;
- abrir o navegador quando solicitado.

O servidor não interpretará decisões nem mudará classificações.

O fluxo normal terá um único comando:

```bash
python3 docs/research/2026-09-30-semantic-manual-review/review-ui/server.py --prepare-plans --open
```

`--prepare-plans` reutiliza os arquivos válidos do cache e prepara somente os documentos ausentes.

### Montagem dos dados

`dataset.py` carregará:

- `FINAL_MATRIX.json`;
- `question-lenses.json`;
- os 13 relatórios semânticos por candidatura;
- `source-manifest.json` da leitura integral dos planos.

Ele produzirá uma representação única para a UI, preservando textos, páginas, relações e identificadores originais. A inicialização falhará com mensagem clara se houver candidato, tese ou campo obrigatório ausente. O validador existente será executado antes de servir os dados.

### Resolução dos planos oficiais

`prepare_plans.py` montará um cache local ignorado pelo Git em `review-ui/.local/plans/`.

Para cada candidatura, o preparador:

1. procura o PDF oficial num caminho fornecido por `--plans-dir`, no corpus do repositório e nos worktrees irmãos do mesmo repositório;
2. copia o arquivo para o cache da ferramenta;
3. confere o SHA-256 registrado no manifesto;
4. se o arquivo estiver ausente, baixa o ZIP oficial registrado no manifesto e extrai somente o membro necessário;
5. recusa arquivos cujo hash não corresponda ao documento auditado.

Doze PDFs já foram localizados no corpus da máquina. O PDF de Leonardo Avalanche não está presente nos caminhos locais pesquisados e será extraído do arquivo oficial do TSE durante a preparação. A ferramenta não inclui Pablo Marçal no cache nem na interface.

Depois da preparação, a revisão funciona sem internet.

O painel do documento exibirá nome da candidatura, partido, nome do arquivo oficial, total de páginas e uma forma abreviada do SHA-256. Assim o revisor consegue confirmar visualmente qual documento está consultando.

### Persistência

`decision_store.py` gravará `review-ui/.local/human-review-decisions.json` de forma atômica, usando arquivo temporário e renomeação. O estado terá versão de esquema e será indexado por `candidate_id` e `question_id`.

Cada registro conterá:

- decisão humana;
- justificativa;
- marcação para revisitar;
- data da última alteração;
- classificação atual observada;
- recomendação preliminar observada.

A UI permitirá baixar uma exportação consolidada. O arquivo exportado também registrará o commit da pesquisa, a versão do esquema e os totais da revisão. Exportar não aplica mudanças à matriz.

### Interface

Os arquivos `index.html`, `styles.css` e módulos JavaScript terão limites claros:

- `api.js`: comunicação com o servidor e tratamento de falhas;
- `state.js`: filtros, seleção e progresso;
- `review.js`: ficha analítica e decisões;
- `pdf-panel.js`: abertura de documento e página;
- `app.js`: composição da aplicação e navegação.

Todo texto vindo dos relatórios será inserido com APIs seguras de texto, sem interpolação como HTML.

## Fluxo de dados

1. O comando de execução prepara somente os planos ausentes, valida os relatórios e inicia o servidor.
3. O navegador solicita o conjunto de dados e o estado humano já salvo.
4. O revisor seleciona uma tese e uma candidatura.
5. A ficha apresenta todos os campos do caderno.
6. Um clique numa citação atualiza o PDF para `/plans/<candidate_id>.pdf#page=<n>`.
7. Uma decisão ou nota é enviada ao servidor e gravada atomicamente.
8. A exportação gera um JSON completo sem tocar nos dados de produção.

## Tratamento de erros

- Relatório inválido: o servidor não inicia e aponta o candidato e o campo problemático.
- PDF ausente: a ficha continua disponível, o painel informa o arquivo faltante e apresenta o comando de preparação.
- Hash divergente: o PDF não é servido; a interface informa que o arquivo não corresponde ao plano auditado.
- Estado humano corrompido: o arquivo é preservado com sufixo de backup e a UI inicia com estado vazio, exibindo o aviso.
- Falha ao salvar: a decisão permanece visível como não sincronizada e o avanço automático é bloqueado.
- Página fora do intervalo: a citação é exibida, mas o visualizador informa a inconsistência documental.

## Verificação

Testes Python com `unittest` cobrirão:

- montagem das 260 fichas e presença dos campos do caderno;
- correspondência entre candidatos, teses e manifesto;
- validação de páginas e hashes;
- resolução local e extração seletiva do ZIP;
- leitura, gravação atômica e recuperação do estado humano;
- respostas completas e parciais de PDF por HTTP Range;
- exportação consolidada.

A verificação de navegador cobrirá:

- carregamento da fila prioritária;
- exibição integral de uma ficha;
- clique em evidência abrindo candidato e página corretos;
- decisão persistindo após recarregar;
- filtros e contadores de progresso;
- exportação do resultado;
- funcionamento em largura desktop e compacta.

## Critérios de aceite

- As 260 fichas estão acessíveis e correspondem aos relatórios validados.
- Todos os elementos obrigatórios do caderno aparecem na interface.
- Toda evidência com página pode abrir o plano oficial da candidatura naquela página.
- Os 13 PDFs servidos correspondem aos hashes do manifesto oficial.
- A fila prioritária contém os mesmos 13 casos do caderno.
- As decisões sobrevivem ao fechamento do navegador e podem ser exportadas.
- A ferramenta funciona localmente depois da preparação inicial.
- Nenhum arquivo de produção, classificação vigente ou cálculo de afinidade é alterado.
