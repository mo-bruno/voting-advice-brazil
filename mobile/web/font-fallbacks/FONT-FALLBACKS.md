# Font fallbacks locais do Flutter Web

O `flutter_bootstrap.js` aponta `fontFallbackBaseUrl` para esta pasta para
impedir que texto exibido antes do consentimento gere requisições ao
`fonts.gstatic.com`.

Os 12 subconjuntos de Noto Color Emoji preservam os emojis aceitos nos campos da
comunidade. Noto Sans Symbols cobre o fallback de símbolos observado no Flutter
3.41.6. Os arquivos mantêm exatamente os caminhos esperados pelo runtime e só são
baixados pelo navegador quando um glifo correspondente é necessário.

`SOURCES.json` registra a versão e o código do Flutter usados para selecionar os
arquivos, além da URL, tamanho, SHA-256 e licença de cada WOFF2. Ao atualizar o
Flutter, confira `font_fallback_data.dart`, atualize esta árvore se os caminhos
mudarem e execute `flutter test test/web_font_fallback_assets_test.dart`.
