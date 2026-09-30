# Feixe Share Cards Verification and Continuation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Verificar os banners compartilháveis contra a direção Feixe aprovada, corrigir apenas divergências demonstráveis e preparar uma nova rodada visual caso o produto queira abandonar o princípio “mesmos cards, nova marca”.

**Architecture:** `ResultShareCard` continua sendo a única composição usada na prévia e no PNG exportado. `ResultSharePage` possui o estado do ângulo; `ResultSharePalette` fornece cores, marca e overlays; a geometria institucional vem de `mobile/branding/feixe.json`. A primeira tarefa é um gate: se os renders atuais coincidirem com as referências e os testes passarem, a direção aprovada já está implementada e não há correção de código a fazer.

**Tech Stack:** Flutter 3.41.6, Dart, `flutter_test`, `CustomPainter`, PNGs gerados pelo próprio `RenderRepaintBoundary`.

**Spec:** `docs/previews/brand-directions/feixe-refinado/HANDOFF.md`

## Global Constraints

- O símbolo Feixe não gira; somente o cone de luz muda de 10° a 70°.
- A marca usa branco/transparência neutra; em fundos claros, usa preto.
- O ângulo é sorteado uma vez por nova tela e não muda com paleta, formato, variante ou exportação.
- Barlow Condensed, as 12 paletas, conteúdo, hierarquia, Post, Story, Top 5, Top 10 e controles permanecem até que uma nova prancha seja explicitamente aprovada.
- Post exporta 1080 × 1350; Story exporta 1080 × 1920.
- Dados das pranchas e testes permanecem fictícios.
- Favicon, preview Open Graph, ícones nativos, DNS e deploy estão fora deste plano.

## Review Focus

- Paleta branca: símbolo preto e texto com contraste mínimo de 4,5:1 sobre feixe branco translúcido.
- Ângulos 10° e 70°: cone permanece dentro da composição e nasce na ponta da barra do F.
- Top 10 em Post: dez linhas cabem sem posições vazias ou corte.
- Nome longo com escala de texto ampliada: tela de personalização não produz overflow.
- Rebuild, troca de paleta/formato e exportação: bytes retornam à mesma composição quando o estado visual volta às mesmas opções.

---

### Task 1: Reproduzir e classificar o estado atual

**Files:**
- Read: `docs/previews/brand-directions/feixe-refinado/HANDOFF.md`
- Read: `docs/previews/brand-directions/feixe-refinado/NOTAS.md`
- Read: `docs/previews/brand-directions/feixe-refinado/cards-cores-preservadas.png`
- Generate: `docs/previews/brand-directions/feixe-refinado/implementado/*.png`

**Interfaces:**
- Consumes: `ResultShareCard(data, format, palette, beamAngle)`.
- Produces: seis PNGs reais nos nomes definidos por `mobile/tool/render_brand_previews.dart`.

- [ ] **Step 1: Ler a decisão anterior**

Confirmar em `HANDOFF.md` e `NOTAS.md` que o alvo atual é uma troca cirúrgica de símbolo/pattern, não um redesenho completo.

- [ ] **Step 2: Gerar o baseline real**

Run:

```sh
cd mobile
flutter test tool/render_brand_previews.dart
```

Expected: PASS em `exporta as aplicações reais da marca para revisão` e geração de:

```text
azul-post.png
verde-ranking.png
preto-story.png
branco-top10.png
limite-10.png
limite-70.png
```

- [ ] **Step 3: Comparar as superfícies obrigatórias**

Abrir `implementado/index.html` e conferir lado a lado:

```text
azul-post.png       -> Post, paleta escura, 14°
verde-ranking.png   -> Top 5, Story, 38°
preto-story.png     -> líder, Story, 64°
branco-top10.png    -> Top 10, Post, marca inversa
limite-10.png       -> menor ângulo
limite-70.png       -> maior ângulo
```

Expected: símbolo Feixe no topo esquerdo, cone partindo da abertura, conteúdo e paletas preservados.

- [ ] **Step 4: Aplicar o gate**

Se os seis renders coincidirem com as referências e a intenção continuar sendo “mesmos cards, nova marca”, não editar código: registrar que o PR #63 já entregou o alvo. Se o produto quer uma composição mais diferente, encerrar esta execução e aprovar uma nova prancha antes da Task 2.

### Task 2: Fixar uma divergência aprovada por teste

**Files:**
- Modify: `mobile/test/result_share_page_test.dart`
- Modify: `mobile/test/result_share_palette_test.dart`
- Test: os mesmos dois arquivos

**Interfaces:**
- Consumes: `ResultShareCard`, `ResultSharePage`, `ResultSharePalette.values`.
- Produces: um teste de regressão que falha antes da correção e passa depois.

- [ ] **Step 1: Executar os contratos existentes**

Run:

```sh
cd mobile
flutter test test/result_share_page_test.dart
flutter test test/result_share_palette_test.dart
```

Expected: PASS. Uma falha aqui é regressão funcional e deve ser corrigida antes de qualquer refinamento visual.

- [ ] **Step 2: Escrever o menor teste que descreve a divergência aprovada**

Usar o padrão já presente no arquivo: renderizar o `RepaintBoundary` real, ler o PNG e afirmar a propriedade visual, sem testar detalhes internos do painter. Exemplos válidos de propriedade são origem do cone no símbolo, presença da marca monocromática ou ausência de overflow em uma variante concreta.

Não adicionar golden de plataforma sem usar as fontes versionadas carregadas por `ResultShareCard.loadFonts`.

Nomear o teste `exporta a direção visual aprovada para o card`. Esse nome
é usado pelo comando isolado no próximo passo.

- [ ] **Step 3: Confirmar que o novo teste falha**

Run:

```sh
cd mobile
flutter test test/result_share_page_test.dart \
  --plain-name "exporta a direção visual aprovada para o card"
```

Expected: FAIL pela divergência visual descrita, não por fonte ausente, overflow não relacionado ou erro de fixture.

- [ ] **Step 4: Commit do teste**

```sh
git add mobile/test/result_share_page_test.dart mobile/test/result_share_palette_test.dart
git commit -m "test: fixa direção aprovada dos cards Feixe"
```

### Task 3: Implementar somente a diferença aprovada

**Files:**
- Modify: `mobile/lib/features/results/sharing/result_share_card.dart`
- Modify only if tokens change: `mobile/lib/features/results/sharing/result_share_palette.dart`
- Do not modify: `mobile/lib/features/results/sharing/result_share_page.dart`
- Do not modify: `mobile/lib/features/results/sharing/result_share_data.dart`

**Interfaces:**
- Consumes: `feixeBeamOrigin`, `feixeViewBox`, `FarolMark`, `beamAngle`, `palette.mark`, `palette.beamOverlay`, `palette.beamEdgeOverlay`.
- Produces: a mesma assinatura pública de `ResultShareCard` e os mesmos tamanhos lógicos 360 × 450/640.

- [ ] **Step 1: Fazer a menor alteração no card**

Manter a chamada pública:

```dart
ResultShareCard(
  data: data,
  format: format,
  palette: palette,
  beamAngle: beamAngle,
)
```

Concentrar a mudança na árvore visual de `ResultShareCard.build` ou em `_SharePatternPainter.paint`. Não sortear valores em `build` ou `paint`.

- [ ] **Step 2: Rodar o teste novo e os contratos do card**

Run:

```sh
cd mobile
flutter test test/result_share_page_test.dart
flutter test test/result_share_palette_test.dart
```

Expected: PASS.

- [ ] **Step 3: Regenerar as seis referências**

Run:

```sh
cd mobile
flutter test tool/render_brand_previews.dart
```

Expected: PASS e seis PNGs atualizados. Revisar visualmente todos, não apenas a paleta usada no teste.

- [ ] **Step 4: Commit da implementação e dos renders**

```sh
git add mobile/lib/features/results/sharing/result_share_card.dart \
  mobile/lib/features/results/sharing/result_share_palette.dart \
  docs/previews/brand-directions/feixe-refinado/implementado
git commit -m "feat: refina banners de resultado na identidade Feixe"
```

### Task 4: Verificação de integração

**Files:**
- Verify: todos os arquivos alterados nas Tasks 2 e 3
- Update: `docs/previews/brand-directions/feixe-refinado/NOTAS.md`
- Update: `docs/previews/brand-directions/feixe-refinado/implementado/index.html`

**Interfaces:**
- Consumes: implementação e renders finais.
- Produces: branch pronta para revisão, sem deploy.

- [ ] **Step 1: Atualizar a decisão visual**

Registrar em `NOTAS.md` exatamente a diferença aprovada e ajustar legendas de `implementado/index.html` se ângulos, formatos ou amostras mudarem.

- [ ] **Step 2: Rodar a suíte completa**

Run:

```sh
cd mobile
flutter test
flutter analyze
```

Expected: todos os testes PASS e `No issues found!`.

- [ ] **Step 3: Rodar o build de produção**

Run:

```sh
cd mobile
flutter build web --release \
  --dart-define=IOT_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=PUBLIC_APP_URL=https://fpolitico.com.br
```

Expected: `Built build/web`.

- [ ] **Step 4: Conferir escopo e whitespace**

Run:

```sh
git diff --check
git diff --stat origin/main...HEAD
```

Expected: sem alterações em backend, DNS, Firebase, favicon, ícones nativos ou metadados sociais.

- [ ] **Step 5: Commit da documentação**

```sh
git add docs/previews/brand-directions/feixe-refinado
git commit -m "docs: atualiza referências dos banners Feixe"
```
