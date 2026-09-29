# Feixe — Farol Político

Marca aprovada: F geométrico branco, abertura branca a 32% de opacidade,
fundo institucional `#131313`. Em superfícies claras, usar a versão preta.
Não usar as cores dos estados históricos do LED como cores da marca.

## Fonte única e exportação

`feixe.json` é a geometria canônica (viewBox 64 × 64). O exportador gera
o SVG transparente, o SVG do favicon, a geometria usada pelo `FarolMark`,
os PNGs web/Android/iOS e o preview institucional 1200 × 630:

```sh
python3 mobile/tool/generate_web_brand_assets.py
dart format mobile/lib/core/branding/feixe_geometry.dart
```

Requer Pillow. A arte do link usa os arquivos Inter já versionados em
`mobile/test/fixtures/fonts`, com proveniência e licença SIL OFL nesse diretório.
As fontes são usadas somente na exportação; não se adicionou dependência de
rede ou um segundo pacote de fontes ao app. Os PNGs finais são versionados.

## Compartilhamento de resultado

- Barlow Condensed, conteúdo, formatos e as 12 paletas originais são preservados.
- O F permanece fixo. O cone nasce na ponta da sua barra e abre para dentro do card.
- A página sorteia um ângulo entre 10° e 70° uma única vez. Duas aberturas
  consecutivas diferem em pelo menos 8°.
- Mudar paleta, formato, ranking ou exportar mantém o mesmo ângulo.
- A prévia e o PNG usam o mesmo `RepaintBoundary`, sem sorteios no painter.
- O feixe é branco com 7,5% de opacidade; a borda adiciona 3,5%, inclusive
  nas paletas claras (onde escurecer o fundo reduziria o contraste do texto).
- O preview institucional e os ícones são estáticos. A aleatoriedade pertence
  ao fundo dos resultados, não à identidade da marca ou ao cache dos links.

Ícones funcionais, logotipos dos partidos e as cores semânticas do módulo
histórico de IoT não fazem parte desta substituição de marca.
