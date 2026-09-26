# Proveniência da Inter usada nos testes de layout

As três fontes são cópias não modificadas das variantes usadas por
`google_fonts` 6.3.3 em `AppTheme`: regular (400), semibold (600) e extrabold (800).
São fixtures de teste, não novos assets do aplicativo.

O teste de descoberta da ajuda em 320 px precisa das métricas reais da Inter.
A fonte Ahem do Flutter é monoespaçada e muito mais larga, acionando corretamente
o modo de respostas empilhadas que exige rolagem para texto grande.
As fixtures tornam a verificação reproduzível e independente de rede.

Origem: `https://fonts.gstatic.com/s/a/<sha256>.ttf`, hashes fixados pelo pacote:

- Inter-Regular.ttf: `ecdb53099b1a68cd24c6900ea5beeafec81bd3c8cb9d0f3c51b9986583ba3982`
- Inter-SemiBold.ttf: `d7ba633bab7f40576e539a7e934a1301d7618dceea59c743de477c2c493462fc`
- Inter-ExtraBold.ttf: `06fb8b97ad04af6b7fa9f2fb17d3763d28f6694f777f33dcf147e84c55a4e81a`

Licença: SIL Open Font License 1.1, em `OFL.txt`.
