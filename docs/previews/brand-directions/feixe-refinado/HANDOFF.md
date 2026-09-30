# Handoff — banners de resultado com a identidade Feixe

## Estado real em 30/09/2026

O PR [#63](https://github.com/mo-bruno/voting-advice-brazil/pull/63) foi
mergeado em `main` no commit `32d96c0` e implantado. Ele já entregou:

- o símbolo Feixe no lugar do antigo horizonte;
- o feixe branco translúcido no fundo dos cards;
- um ângulo entre 10° e 70° sorteado uma vez por nova tela de
  compartilhamento e preservado durante personalização e exportação;
- a versão preta da marca nas paletas claras;
- favicon, ícones instaláveis e preview institucional;
- testes de PNG, estabilidade da composição, contraste e formatos.

O bundle publicado foi comparado com o build do PR e é idêntico. Portanto,
cards que ainda parecem próximos dos anteriores não indicam deploy antigo:
essa semelhança foi uma decisão explícita da aprovação anterior.

## Decisão anterior que explica a aparência atual

A orientação registrada em [NOTAS.md](NOTAS.md) foi:

> mudar somente o ícone e, opcionalmente, o pattern atrás; preservar cores,
> Barlow Condensed, conteúdo, hierarquia, formatos e controles.

A prancha [cards-cores-preservadas.png](cards-cores-preservadas.png) se chama
“Mesmos cards. Nova marca.” e documenta exatamente esse escopo. Os PNGs em
[implementado/](implementado/) são renderizações reais do Flutter depois da
implementação.

Se a próxima etapa pretende que os banners deixem de parecer os antigos, ela
é uma **nova revisão visual**, não uma correção do PR #63. O novo desenho deve
ser aprovado antes de alterar o Flutter. A identidade Feixe em si não deve ser
redesenhada.

## Materiais publicados nesta branch

- [index.html](index.html): sistema visual aprovado e aplicações.
- [angulos.html](angulos.html): estudo interativo da direção do feixe.
- [NOTAS.md](NOTAS.md): decisões, tokens, superfícies e prompts que originaram
  a direção.
- [cards-cores-preservadas.png](cards-cores-preservadas.png): prancha conceitual
  aprovada para os cards.
- [implementado/index.html](implementado/index.html): galeria das renderizações
  reais do componente Flutter.
- [implementado/azul-post.png](implementado/azul-post.png),
  [implementado/verde-ranking.png](implementado/verde-ranking.png),
  [implementado/preto-story.png](implementado/preto-story.png) e
  [implementado/branco-top10.png](implementado/branco-top10.png): formatos e
  paletas representativos.
- [implementado/limite-10.png](implementado/limite-10.png) e
  [implementado/limite-70.png](implementado/limite-70.png): limites aprovados
  para a direção do feixe.
- [marca-monocromatica.png](marca-monocromatica.png) e
  [feixe.svg](feixe.svg): referência da marca.

## Fontes de verdade no código

| Responsabilidade | Arquivo / símbolo |
|---|---|
| Geometria canônica | `mobile/branding/feixe.json` |
| Marca Flutter | `mobile/lib/core/branding/farol_mark.dart` |
| Assinatura Flutter | `mobile/lib/core/branding/farol_wordmark.dart` |
| Composição visual dos banners | `ResultShareCard` em `mobile/lib/features/results/sharing/result_share_card.dart` |
| Estado e sorteio do ângulo | `ResultSharePage` em `mobile/lib/features/results/sharing/result_share_page.dart` |
| Tokens das 12 paletas | `mobile/lib/features/results/sharing/result_share_palette.dart` |
| Dados, variantes e formatos | `mobile/lib/features/results/sharing/result_share_data.dart` |
| Renderização das referências | `mobile/tool/render_brand_previews.dart` |
| Testes principais | `mobile/test/result_share_page_test.dart` e `mobile/test/result_share_palette_test.dart` |

A geometria gerada em `feixe_geometry.dart` não deve ser editada à mão.
Alterações na marca partem de `feixe.json` e são regeneradas com:

```sh
python3 mobile/tool/generate_web_brand_assets.py
dart format mobile/lib/core/branding/feixe_geometry.dart
```

Para uma revisão apenas dos banners, não é necessário regenerar favicon,
ícones nativos ou `og-preview.png`.

## O que o próximo desenvolvedor deve fazer

1. Trabalhar a partir desta branch ou copiar estes documentos para sua branch
   baseada na `main`.
2. Abrir `index.html`, `angulos.html` e `implementado/index.html` para
   entender o ponto de partida.
3. Gerar novamente os cards atuais antes de editar:

   ```sh
   cd mobile
   flutter test tool/render_brand_previews.dart
   ```

4. Se a intenção continua sendo a atualização mínima aprovada, comparar os
   novos PNGs byte a byte/visualmente com `implementado/`. Nesse caso, o
   trabalho já está entregue e nenhuma mudança de produção é necessária.
5. Se a intenção é uma nova composição visual, produzir primeiro uma nova
   prancha de aprovação. Ela deve mostrar, no mínimo, Post 4:5, Story 9:16,
   Top 5 e Top 10, incluindo uma paleta clara. Registrar a decisão substituindo
   explicitamente a seção “Cards com cores preservadas” de `NOTAS.md`.
6. Depois da aprovação, restringir a implementação visual a
   `ResultShareCard` e, apenas se forem necessários novos tokens, a
   `ResultSharePalette`. Não alterar API de compartilhamento, dados,
   percentuais, formatos ou controles sem uma decisão de produto separada.
7. Atualizar `render_brand_previews.dart` com amostras que cubram a nova
   composição e regenerar todos os PNGs de `implementado/`.
8. Preservar as invariantes cobertas pelos testes:
   - o mesmo estado gera o mesmo PNG;
   - trocar paleta ou formato não muda o ângulo;
   - abrir uma nova tela sorteia 10°–70° e evita repetição próxima;
   - Post exporta 1080 × 1350 e Story exporta 1080 × 1920;
   - Top 5, Top 10, nomes longos e texto ampliado não estouram;
   - texto e marca mantêm contraste nas 12 paletas.
9. Executar a validação completa:

   ```sh
   cd mobile
   flutter test test/result_share_page_test.dart
   flutter test test/result_share_palette_test.dart
   flutter test
   flutter analyze
   flutter build web --release \
     --dart-define=IOT_ENABLED=false \
     --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
     --dart-define=PUBLIC_APP_URL=https://fpolitico.com.br
   ```

## Fora do escopo

- favicon, ícones Android/iOS e preview Open Graph, já publicados;
- cabeçalhos, gaveta e diálogo Sobre;
- mudança de dados, ranking, percentuais ou candidatos;
- mudança da lógica de compartilhamento/download;
- alteração das cores da marca Feixe;
- deploy, DNS ou Firebase Hosting.

## Definição de pronto para uma nova revisão

- direção visual aprovada e documentada;
- quatro formatos/variantes reais renderizados pelo Flutter;
- comportamento de exportação e ângulo preservado;
- testes direcionados, suíte completa, análise e build web aprovados;
- documentação e PNGs desta pasta atualizados no mesmo PR.
