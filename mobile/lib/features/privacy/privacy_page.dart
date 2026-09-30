import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_consent_controller.dart';
import '../../core/analytics/analytics_operational_config.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/link/link_opener.dart';
import 'privacy_config.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({
    super.key,
    required this.consentController,
    required this.config,
    this.openLink,
    this.analytics,
    this.analyticsEnabled = AnalyticsOperationalConfig.enabled,
  });

  final AnalyticsConsentController consentController;
  final PrivacyConfig config;
  final LinkOpener? openLink;
  final AnalyticsService? analytics;
  final bool analyticsEnabled;

  static final googlePartnerSitesUri = Uri.parse(
    'https://policies.google.com/technologies/partner-sites?hl=pt-BR',
  );

  Future<void> _open(
    BuildContext context,
    Uri uri,
    AnalyticsTarget target,
  ) async {
    var opened = false;
    try {
      opened = await (openLink ?? openExternalLink)(uri);
    } catch (_) {
      // A falha é comunicada sem fechar a página ou expor o conteúdo da URI.
    }
    unawaited(
      (analytics ?? AnalyticsService())
          .engagementAction(
            action: AnalyticsAction.outboundOpen,
            surface: AnalyticsSurface.privacy,
            target: target,
            outcome:
                opened ? AnalyticsOutcome.success : AnalyticsOutcome.failed,
          )
          .catchError((_) {}),
    );
    if (opened) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }

  Future<void> _choose(BuildContext context, {required bool granted}) async {
    final saved = granted
        ? await consentController.grant()
        : await consentController.deny();
    if (saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível salvar sua escolha.')),
    );
  }

  Widget _preferences(BuildContext context) {
    return ListenableBuilder(
      listenable: consentController,
      builder: (context, _) {
        final state = consentController.state;
        final status = switch (state) {
          AnalyticsConsent.pending => 'Métricas ainda não escolhidas',
          AnalyticsConsent.granted => 'Métricas aceitas',
          AnalyticsConsent.denied => 'Métricas rejeitadas',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suas preferências',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(status),
            if (consentController.denialPersistenceFailed) ...[
              const SizedBox(height: 8),
              const Text(
                'Métricas rejeitadas nesta sessão, mas não foi possível salvar a rejeição para a próxima visita.',
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (state == AnalyticsConsent.pending) ...[
                  OutlinedButton(
                    onPressed: () => _choose(context, granted: false),
                    child: const Text('REJEITAR MÉTRICAS'),
                  ),
                  OutlinedButton(
                    onPressed: () => _choose(context, granted: true),
                    child: const Text('ACEITAR MÉTRICAS'),
                  ),
                ],
                if (state == AnalyticsConsent.granted)
                  OutlinedButton(
                    onPressed: () => _choose(context, granted: false),
                    child: const Text('REVOGAR MÉTRICAS'),
                  ),
                if (state == AnalyticsConsent.denied) ...[
                  if (consentController.denialPersistenceFailed)
                    OutlinedButton(
                      onPressed: () => _choose(context, granted: false),
                      child: const Text('TENTAR SALVAR REJEIÇÃO'),
                    ),
                  OutlinedButton(
                    onPressed: () => _choose(context, granted: true),
                    child: const Text('ACEITAR MÉTRICAS'),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailUri = Uri(scheme: 'mailto', path: config.contactEmail);
    final analyticsRetention = analyticsEnabled
        ? 'Eventos e dados de usuário aceitos têm retenção configurada por 2 meses no GA4; relatórios agregados padrão podem seguir regras e prazos próprios. As tabelas históricas existentes podem não ter expiração; novas tabelas expiram em até 60 dias. A ativação em produção só ocorre se a configuração do GA4 e do BigQuery corresponder a este aviso.'
        : 'A coleta de métricas está pausada nesta versão. A ativação em produção só ocorre se a configuração do GA4 e do BigQuery corresponder a este aviso: retenção de eventos e dados de usuário em 2 meses no GA4; tabelas históricas existentes podem não ter expiração; e novas tabelas expiram em até 60 dias. Relatórios agregados padrão podem seguir regras e prazos próprios.';
    final sections = <(String, String)>[
      (
        'Quem decide e como falar conosco',
        'O controlador deste site é ${config.controllerName}. Pedidos sobre privacidade podem ser enviados para ${config.contactEmail}.',
      ),
      (
        'Finalidades e bases legais',
        'Métricas opcionais usam consentimento e podem ser recusadas ou revogadas. O processamento transitório das respostas políticas do quiz usa a manifestação específica e destacada em VER RESULTADOS. PUBLICAR, ENVIAR COMENTÁRIO e registrar interesse são ações deliberadas para as respectivas funções, precedidas de aviso específico. Interesse legítimo não fundamenta o conteúdo político: ele é usado apenas, quando aplicável e após avaliação, para segurança, limitação de abuso e proteção do serviço. Obrigação legal e exercício de direitos podem justificar conservação excepcional e limitada.',
      ),
      (
        'Métricas opcionais',
        'O consentimento é opcional e pode ser revogado sem perder funções do site. O Google Analytics só é ativado depois desse consentimento. Então, podemos enviar eventos sobre telas genéricas, uso de funcionalidades e resultados e durações de operações. O Google pode acrescentar página, referência, informações do navegador e dispositivo e identificadores pseudônimos, como o cookie `_ga` e um Firebase Installation ID. Google, Firebase Analytics, GA4 e BigQuery podem processar esses dados, inclusive fora do Brasil. Provedores também podem tratar endereço IP em trânsito e em registros técnicos e estimar localização aproximada. Nos eventos personalizados, não enviamos respostas do quiz, posições políticas, candidatos, partidos, ranking, afinidade, identificador funcional ou texto livre. Não usamos esses dados para publicidade. Você pode rejeitar ou revogar sem perder funções do site. Sua escolha sobre métricas é salva localmente no navegador para que o site possa lembrá-la. Revogar interrompe novos envios, mas não apaga automaticamente identificadores locais nem eventos já recebidos, que seguem os prazos abaixo e os direitos que você pode exercer pelo canal de privacidade.',
      ),
      (
        'Quiz e respostas políticas',
        'Suas respostas do quiz podem revelar opinião política. Quando você pede o cálculo, elas são enviadas à nossa API e processadas de forma transitória para comparar suas escolhas com posições documentadas. Na versão pública, com o recurso IoT desligado, não enviamos o UUID funcional local do navegador no quiz e não armazenamos essas respostas. A ação destacada VER RESULTADOS é sua manifestação positiva e específica para esse processamento; ela não aceita métricas.',
      ),
      (
        'Identidades funcionais e comunidade',
        'O navegador mantém um identificador aleatório local para funções como comunidade e acompanhamento. Ele não contém seu nome ou e-mail, mas é pseudônimo e não oferece recuperação de conta se for perdido. Posts e comentários podem revelar opinião política. Ao tocar em PUBLICAR ou ENVIAR COMENTÁRIO depois do aviso destacado, você concorda com o armazenamento, moderação via NVIDIA NIM e publicação do texto sob um alias pseudônimo estável; não inclua dados pessoais que não queira tornar públicos. O autor pode remover o conteúdo do próprio post, que vira uma lápide; os comentários permanecem para preservar a discussão. Para retirar um comentário ou exercer outros direitos, use o canal de privacidade. Identificadores e registros técnicos podem ser usados de forma limitada para votação, prevenção de abuso, segurança, cumprimento de obrigação legal e exercício de direitos.',
      ),
      (
        'Validação da área Acompanhar',
        'Ao registrar interesse na área Acompanhar, o navegador cria um identificador aleatório separado das outras atividades. O servidor guarda somente um hash contextualizado e a data do registro. É um registro sem nome ou contato, mas pseudônimo: o mesmo navegador pode consultá-lo enquanto conservar o identificador. A interface atual não oferece retirada direta; para solicitar a exclusão do registro, use ${config.contactEmail}. Ele é apagado quando a retirada é processada, no encerramento da validação ou em até 180 dias, o que ocorrer primeiro.',
      ),
      (
        'Compartilhamento do resultado',
        'O compartilhamento é voluntário. Quando você escolhe um destino, a imagem ou o texto selecionado é entregue ao aplicativo ou serviço indicado por você e fica sujeito também às regras desse serviço.',
      ),
      (
        'Fornecedores e transferências',
        'Usamos Google Cloud, Cloud Run e Cloud Logging para operar e proteger o site; Neon/PostgreSQL para dados funcionais; Google/Firebase/GA4/BigQuery apenas para métricas aceitas; NVIDIA NIM para moderar publicações; e ImprovMX e Google para encaminhar e receber mensagens enviadas ao canal de privacidade. Esses fornecedores podem processar dados em outros países com salvaguardas aplicáveis.',
      ),
      (
        'Retenção e segurança',
        'Respostas do quiz não são persistidas na versão pública atual. $analyticsRetention Logs operacionais do Cloud Run roteados ao bucket padrão do Cloud Logging são mantidos por 30 dias; registros de auditoria obrigatórios seguem política própria e mais longa. Dados funcionais permanecem somente enquanto necessários à função, segurança, obrigação legal ou exercício de direitos. Mensagens de privacidade permanecem durante o atendimento e, depois, somente enquanto necessárias para comprovar cumprimento legal ou exercer direitos, com revisão ao menos anual e eliminação quando essa necessidade terminar; a cópia entregue à caixa de e-mail é distinta dos registros mínimos de entrega que o ImprovMX mantém por 7 dias.',
      ),
      (
        'Seus direitos',
        'Você pode pedir confirmação e acesso, correção, anonimização, bloqueio ou eliminação quando cabível, portabilidade nos termos da regulamentação, informação sobre compartilhamentos, revogação do consentimento, revisão de decisões automatizadas e oposição a tratamento irregular. Use ${config.contactEmail}. Também é possível peticionar à Autoridade Nacional de Proteção de Dados.',
      ),
    ];

    return AppScaffold(
      title: 'PRIVACIDADE E DADOS',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _preferences(context),
                const SizedBox(height: 32),
                for (final section in sections) ...[
                  Text(section.$1,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(section.$2),
                  if (section.$1 == 'Quem decide e como falar conosco') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _open(
                        context,
                        emailUri,
                        AnalyticsTarget.privacyEmail,
                      ),
                      child: const Text('ENVIAR E-MAIL'),
                    ),
                  ],
                  if (section.$1 == 'Métricas opcionais') ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _open(
                        context,
                        googlePartnerSitesUri,
                        AnalyticsTarget.googlePrivacy,
                      ),
                      child: const Text('SAIBA COMO O GOOGLE USA DADOS'),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
