# Feixe refinado — proposta de aplicação

Status em 30/09/2026: direção e variação do Feixe aprovadas. A identidade,
os assets e a atualização mínima dos cards foram entregues pelo PR
[#63](https://github.com/mo-bruno/voting-advice-brazil/pull/63), mergeado no
commit `32d96c0` e implantado. A prévia interativa está em `angulos.html`;
as imagens finais e os cards renderizados pelo Flutter estão em
`implementado/index.html`.

> Importante para a continuação: o escopo aprovado no PR #63 preservou
> propositalmente o desenho anterior dos cards. Foram trocados somente o
> símbolo e o pattern de fundo. Se a próxima etapa pretende redesenhar os
> banners de forma mais ampla, ela precisa de uma nova direção visual aprovada;
> não deve ser tratada como correção de deploy. Consulte `HANDOFF.md`.

## Refinamento: direção variável da luz

- O símbolo F não gira. Apenas o cone de luz no fundo muda de direção, a partir da ponta da barra do símbolo.
- Proposta de intervalo: 10° a 70° abaixo da horizontal, direcionado para dentro do card. Luz branca a 7,5%, com uma borda adicional a 3,5%; sem novas cores.
- Sortear uma vez ao abrir uma nova composição de compartilhamento e manter esse valor ao trocar paleta, formato, variante, reconstruir o widget ou exportar. Não introduzir aleatoriedade dentro de `paint`/`build`.
- A prévia compara três direções e permite novos sorteios, além de alternar entre as paletas atuais e carvão sem alterar os ângulos. Seus controles são demonstrativos, não novos controles do app.
- Favicon, ícones instaláveis e marca permanecem estáveis. O preview institucional é uma imagem estática com uma composição escolhida; não muda a cada acesso de um robô de compartilhamento.
- A implementação deve reutilizar o mesmo ângulo na prévia Flutter e no PNG exportado. Não remover paletas ou alterar conteúdo, percentuais, tipografia e estrutura dos cards.

## Direção incorporada

- A / Feixe escolhida pelo usuário.
- Símbolo institucional em branco com uma abertura branca translúcida, sem azul nem outros matizes.
- Fundo institucional #131313; texto #FFFFFF / #E2E2E2; conector em branco a 32%; feixe ao fundo em branco a 8–12%.
- Nos cards existentes, manter Barlow Condensed, cores, personalização, formatos, resultado e ranking. Substituir somente o ícone de horizonte pelo Feixe e ajustar o padrão de fundo.
- Em paletas claras dos cards, usar a versão preta do mesmo símbolo para preservar contraste. Ambos os símbolos são monocromáticos.
- No restante do app, atualizar somente a identidade do Farol; ícones funcionais e símbolos de partidos não são a marca do produto.

## Pontos de aplicação identificados

| Superfície | Local | Aplicação proposta |
|---|---|---|
| Preview do link | mobile/web/index.html e og-preview.png | Marca monocromática, composição institucional selecionada |
| Navegador e PWA | mobile/web/favicon.*, icons/* e manifest.json | SVG e PNG, Apple Touch e ícones adaptáveis |
| Cards compartilháveis | mobile/lib/features/results/sharing/result_share_card.dart | Feixe no lugar de wb_twilight_rounded, novo feixe sutil de fundo |
| Personalização dos cards | result_share_controls.dart / result_share_page.dart / result_share_palette.dart | Preservar controles e paletas; sem redesenho do conteúdo |
| Cabeçalho inicial | mobile/lib/features/home/home_page.dart | Assinatura compacta com Feixe |
| Menu lateral | mobile/lib/shared/widgets/drawer/farol_drawer_header.dart | Mesma assinatura e símbolo |
| Títulos institucionais | mobile/lib/core/layout/app_scaffold.dart | Símbolo compartilhado quando o título é a marca; títulos de ações permanecem textuais |
| Sobre | mobile/lib/shared/widgets/app_drawer.dart | Identidade do produto no diálogo |
| Android | mobile/android/app/src/main/res/mipmap-*/ic_launcher.png | Exportações do mesmo símbolo |
| iOS | mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset | Exportações do mesmo símbolo |

## Produção entregue no PR #63

Uma única geometria em `mobile/branding/feixe.json` é a fonte da marca. Ela
é reutilizada no Flutter e pelo exportador dos assets web/Android/iOS. A arte
final usa os arquivos Inter versionados, sem texto rasterizado por IA. O PR
validou redução, fundos claros/escuros, contraste, recorte adaptável,
Stories/Post e nomes longos/top 10. As pranchas de aprovação usam dados
fictícios e não são PNGs de usuários reais.

## Geração das pranchas

Ferramenta integrada image_gen, modo de edição com referências locais. A versão totalmente monocromática de todos os cards foi descartada após a orientação de preservar as cores.

### Marca — prompt final

Use case: logo-brand, precise identity refinement. EDIT the supplied Farol Político direction A artwork. User approved the F/Feixe identity, but explicitly requires NO BLUE and NO OTHER HUES: only black, white and translucent whites / neutral grays.
Keep the exact F silhouette, typography, composition, hierarchy, Portuguese text and wordmark from the input. Change all blue areas in the small F and large F to translucent white surfaces (visually neutral gray over charcoal): white 24–32% opacity for the small aperture, white 9–16% for the projected large beam. The solid parts of the F remain clear opaque white; the beam must feel airy and light, not a solid slab or dirty shadow. Keep background clean charcoal #131313. Remove any chromatic tint anywhere, including replacing red/yellow/green browser controls with NEUTRAL gray or white. R=G=B everywhere. Preserve exact Portuguese text, correctly accented: "farol político"; "Com quais propostas você se identifica?"; "Descubra sua afinidade com as propostas para a Presidência de 2026."; "fpolitico.com.br". Favicon tab title "Farol Político". Labels "Ícone" and "Favicon".
Refine the lower review strip to clean, quiet, flat neutral gray/white browser tab presentations with crisp edges and no giant bloom or glow; no colored dots. The SAME new achromatic F symbol in every application. Main preview stays flat dark with one translucent white geometric beam from the large F on the right. Luxury through proportion, restraint and typography. No illustration of a literal lighthouse, no extra symbols, no sun icon. Output a landscape review board at 1536x1024 with the main preview above and icon / tiny browser use below.

### Cards com cores preservadas — prompt final

Use case: brand-system application. Create a NEW FLAT comparison board demonstrating a MINIMAL BRAND UPDATE to the existing Farol Político social-result cards. The user's latest instruction is IMPORTANT: change ONLY the brand icon and optionally background beam pattern. KEEP the current colorful palettes, Barlow Condensed typography, card content/hierarchy, and customization options. Do not turn all cards monochrome. Do not switch card text to Inter.
Reference image 1 is the NEW approved F/Feixe mark: white F with translucent WHITE connector and translucent white projected beam. Copy this F silhouette accurately. It replaces the old sunrise/horizon icon.
Reference image 2 is the CURRENT cobalt post card. Preserve its Barlow Condensed ExtraBold/SemiBold typography, #2045D8 cobalt, #F5FAFF text, #C6F5EA mint accents and score hierarchy.
Reference image 3 is the CURRENT green ranking Story. Preserve its Barlow Condensed typography, #075D50 green, #F4FFF8 text, #E1F7B0 accents and ranking structure.
Canvas 1536x1024 review board with neutral #EDEDED background. Header at top in black: "Mesmos cards. Nova marca." Smaller note: "Cores e personalização preservadas".
Below header show THREE separate cards, top-aligned and with generous gutters: left cobalt POST card 4:5, middle green RANKING Story 9:16, right charcoal LEADER Story 9:16 from the existing black palette #181B24 / white / #D0DCF7 (its pale-gray accent can be subtly cool because this is an existing card palette; logo MUST use only WHITE). The cards should fit fully without clipping. No phone frames, shadows or perspective.
Update in every card:
- Existing top-left sunrise replaced by the same crisp white F logo, size roughly the old symbol; wordmark remains lowercase "farol político" in Barlow Condensed.
- Background pattern becomes 1–2 very quiet geometric translucent WHITE rays, strongest 8–12% opacity, opening diagonally from behind the top-left F toward the right. Keep score and names legible. Avoid outline circles and multiple noisy rays.
- Only the icon and pattern change visually; the rest matches the original.
For all examples use FICTIONAL generic candidate names clearly shown as examples, no real photos or real parties.
LEFT cobalt post copy:
"farol político"
"Fiz o quiz."
"87,5%"
"de afinidade com"
"Candidatura A"
"Exemplo fictício"
"Edição 2026"
"Entre os candidatos que comparei."
"fpolitico.com.br"
MIDDLE green ranking Story copy:
"farol político"
"Meus 5 alinhamentos."
"1" "Candidatura A" "87,5%"
"2" "Candidatura B" "81,5%"
"3" "Candidatura C" "75,5%"
"4" "Candidatura D" "72,5%"
"5" "Candidatura E" "68,5%"
"Edição 2026"
"Entre os candidatos que comparei."
"fpolitico.com.br"
RIGHT black Story copy:
"farol político"
"Fiz o quiz.\nMeu alinhamento."
"87,5%"
"de afinidade com"
"Candidatura A"
"Exemplo fictício"
"Edição 2026"
"Entre os candidatos que comparei."
"fpolitico.com.br"
Tiny board footer outside cards: "Prévia visual com dados fictícios". Accent marks accurate. No buttons or UI additions, no ranking changes, no new copy other than specified. This is a surgical brand replacement within an existing shared-result design, not a redesign.
