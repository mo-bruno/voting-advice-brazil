# Compartilhamento direto dos banners

O usuário priorizou o site no celular, pediu worktree isolada e autorizou produção. Em 30/09/2026 esclareceu que quer o fluxo nos botões reais, não uma página de diagnóstico. O protótipo anterior foi guardado em stash e não foi publicado. Trabalhar a partir de main `91b73dd` para preservar as últimas mudanças de privacidade.

Instagram, X e WhatsApp devem enviar o banner preparado no primeiro toque, sem modal de instruções inicial. Enviar PNG pelo menu no Android. No iPhone usar JPEG `.igo` para Instagram Post e testar JPEG `.wai` para WhatsApp, quando o navegador aceitar o arquivo. Instagram Story mantém PNG para preservar a escolha Story/Post; o tipo exclusivo é documentado para Feed. Compartilhar arquivo sozinho no iOS, evitando incompatibilidade de arquivo+texto.

Gerar Blob/File/JPEG antes dos cliques. Manter o PNG pronto mesmo se a preparação de JPEG falhar. Cancelar não baixa nem abre apps. Recusa abre alternativas com novo gesto: PNG padrão, copiar PNG, abrir app/editor, baixar ou texto/link. X e WhatsApp recebem legenda no caminho não iOS. Não anunciar publicação ou prometer filtragem do menu em todos os dispositivos.

Documentar fontes e hipóteses técnicas fora do fluxo do usuário. Testar os contratos, dimensões dos banners, recusa e cancelamento. Publicar o build deste branch autorizado, preservando configurações atuais de Hosting, variáveis públicas e arquivos estáticos de produção. Verificar hashes remotos e manter referência de rollback. Não afirmar teste real em aparelhos indisponíveis.
