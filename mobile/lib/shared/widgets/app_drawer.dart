// lib/shared/widgets/app_drawer.dart
//
// Menu lateral compartilhado por todas as telas. Os quatro destinos primarios
// (Inicio, Acompanhar, Quiz, Comunidade) vivem na barra inferior, entao a
// gaveta nao e uma lista de links: e um painel do que e SEU dentro do app — o
// Farol na sua mesa, o parlamentar que voce segue, o resultado do seu quiz.
//
// Ela nao busca nada. Le as tres sessions que ja estao em memoria e desenha o
// que houver; bloco sem dado vira convite, nunca some. Abrir a gaveta e um
// gesto de um toque, e um spinner dentro dela custaria mais do que informa.

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_dimensions.dart';
import '../../core/analytics/analytics_navigation.dart';
import '../../core/branding/farol_mark.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/features/feature_flags.dart';
import '../../core/shell/main_shell.dart';
import '../../core/theme/app_theme.dart';
import '../iot_device_session.dart';
import '../political_actor_session.dart';
import '../quiz_session.dart';
import 'drawer/drawer_footer.dart';
import 'drawer/farol_drawer_header.dart';
import 'drawer/farol_led_state.dart';
import 'drawer/farol_status_tile.dart';
import 'drawer/followed_actor_tile.dart';
import 'drawer/quiz_affinity_tile.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({
    super.key,
    this.deviceIdentityStore,
    this.iotEnabled,
    this.politicianFollowEnabled,
    this.navigationIntent,
  });

  /// Injetavel em teste. Em producao a gaveta usa o mesmo armazenamento local
  /// que o resto do app.
  final DeviceIdentityStore? deviceIdentityStore;

  /// Quando ausente, usa a flag de compilação da aplicação.
  final bool? iotEnabled;

  /// Quando ausente, usa a flag de compilação da aplicação.
  final bool? politicianFollowEnabled;

  final AnalyticsNavigationIntent? navigationIntent;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late final AnalyticsNavigationIntent _navigationIntent =
      widget.navigationIntent ?? AnalyticsNavigationIntent();

  /// Uma unica assinatura para as tres sessions: qualquer uma que mude
  /// redesenha a gaveta. Montada aqui e nao no `build` para nao criar um
  /// Listenable novo a cada frame.
  late final Listenable _sessions = Listenable.merge([
    if (widget.iotEnabled ?? FeatureFlags.environment.iotEnabled)
      IotDeviceSession.instance,
    if (widget.politicianFollowEnabled ??
        FeatureFlags.environment.politicianFollowEnabled)
      PoliticalActorSession.instance,
    QuizSession.instance,
  ]);

  String? _shortId;

  @override
  void initState() {
    super.initState();
    _loadShortId();
  }

  Future<void> _loadShortId() async {
    final store = widget.deviceIdentityStore ?? DeviceIdentityStore();
    final id = await store.getOrCreateDeviceId();
    if (!mounted) return;
    setState(() => _shortId = _shorten(id));
  }

  /// Os oito primeiros digitos, no mesmo formato do `shortToken` do gadget —
  /// curto o bastante para caber no rodape e longo o bastante para a pessoa
  /// reconhecer o proprio aparelho num suporte.
  static String _shorten(String id) {
    final compact = id.replaceAll('-', '');
    if (compact.length <= 8) return compact.toUpperCase();
    return compact.substring(0, 8).toUpperCase();
  }

  /// Fecha a gaveta antes de navegar. Sem isso ela fica aberta por baixo da
  /// tela nova e reaparece quando a pessoa volta.
  void _go(
    void Function(NavigatorState navigator) action, {
    bool tracked = false,
  }) {
    if (tracked) _navigationIntent.mark(AnalyticsSource.drawer);
    final navigator = Navigator.of(context);
    navigator.pop();
    action(navigator);
  }

  void _openTab(MainShellTab tab) {
    _go(
      (navigator) =>
          navigator.pushNamedAndRemoveUntil('/', (_) => false, arguments: tab),
      tracked: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final iotEnabled = widget.iotEnabled ?? FeatureFlags.environment.iotEnabled;
    final politicianFollowEnabled = widget.politicianFollowEnabled ??
        FeatureFlags.environment.politicianFollowEnabled;

    return Drawer(
      backgroundColor: AppTheme.surface,
      child: ListenableBuilder(
        listenable: _sessions,
        builder: (context, _) {
          final followed = politicianFollowEnabled
              ? PoliticalActorSession.instance.followedActor
              : null;
          final results = QuizSession.instance.visibleResults;
          final iot = iotEnabled ? IotDeviceSession.instance : null;

          return Column(
            children: [
              if (iotEnabled)
                FarolDrawerHeader(
                  state: farolLedStateFor(
                    device: iot!.device,
                    lastEvent: iot.lastEvent,
                    now: DateTime.now(),
                  ),
                )
              else
                const _BrandedDrawerHeader(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (iotEnabled) ...[
                      FarolStatusTile(
                        device: iot!.device,
                        lastEvent: iot.lastEvent,
                        onOpenDevice: () => _go(
                          (navigator) => navigator.pushNamed('/iot-device'),
                        ),
                        onPair: () => _go(
                          (navigator) => navigator.pushNamed('/iot-pairing'),
                        ),
                      ),
                      const _Rule(),
                    ],
                    FollowedActorTile(
                      actor: followed,
                      featureEnabled: politicianFollowEnabled,
                      onOpenProfile: () => _go(
                        (navigator) => navigator.pushNamed(
                          '/political-actor-profile',
                          arguments: followed,
                        ),
                      ),
                      onChoose: () => _openTab(MainShellTab.acompanhar),
                    ),
                    const _Rule(),
                    QuizAffinityTile(
                      hasResults: results.isNotEmpty,
                      onOpenResults: () => _go(
                        (navigator) => navigator.pushNamed('/results'),
                        tracked: true,
                      ),
                      onStartQuiz: () => _openTab(MainShellTab.quiz),
                    ),
                    // Sem regua depois do ultimo bloco: com a gaveta mais alta
                    // que o conteudo ela ficaria pendurada no meio do vazio, e
                    // a borda de cima do rodape ja fecha a lista.
                  ],
                ),
              ),
              DrawerFooter(
                shortId: _shortId,
                onAbout: () => _showAbout(
                  context,
                  politicianFollowEnabled: politicianFollowEnabled,
                ),
                onPrivacy: () => _go(
                  (navigator) => navigator.pushNamed('/privacidade'),
                  tracked: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandedDrawerHeader extends StatelessWidget {
  const _BrandedDrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 160 + MediaQuery.paddingOf(context).top,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16 + MediaQuery.paddingOf(context).top,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const FarolMark(size: 32),
          const SizedBox(height: 10),
          const Text(
            'FAROL\nPOLÍTICO',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              height: 1,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'BRASIL 2026',
            style: Theme.of(
              context,
            ).textTheme.bodySmall!.copyWith(letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.outlineVariant,
    );
  }
}

/// O aviso "Sobre" continua em diálogo; privacidade tem uma rota própria.
void _showAbout(
  BuildContext context, {
  required bool politicianFollowEnabled,
}) {
  final followDescription = politicianFollowEnabled
      ? 'A área Acompanhar apresenta deputados atuais e evidências oficiais '
          'da Câmara; esses votos são informativos e não alteram a comparação '
          'do quiz.'
      : 'A área Acompanhar ainda está em validação. Ela poderá reunir '
          'informações de fontes oficiais sobre a atuação de políticos; o '
          'registro de interesse sem nome ou contato ajuda a decidir se ela deve ser '
          'lançada.';
  _showNote(
    context,
    title: 'Sobre o Farol Político',
    showBrand: true,
    body: 'O quiz compara suas respostas com propostas publicadas por '
        'candidatos nas eleições de 2026. $followDescription\n\n'
        'As fontes incluem dados abertos do TSE e da Câmara. O projeto é '
        'acadêmico e não tem vínculo com nenhum partido ou candidato.',
  );
}

void _showNote(
  BuildContext context, {
  required String title,
  required String body,
  bool showBrand = false,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(),
      icon: showBrand ? const Center(child: FarolMark(size: 40)) : null,
      title: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      content: Text(body, style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('FECHAR'),
        ),
      ],
    ),
  );
}
