import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/analytics/analytics_consent_controller.dart';
import 'core/analytics/analytics_dependencies.dart';
import 'core/analytics/analytics_navigation.dart';
import 'core/analytics/analytics_service.dart';
import 'core/features/feature_flags.dart';
import 'core/layout/responsive_layout.dart';
import 'core/shell/main_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/community/community_feed_page.dart';
import 'features/comparison/comparison_page.dart';
import 'features/party_selection/party_selection_page.dart';
import 'features/political_actors/political_actor_profile_page.dart';
import 'features/political_actors/political_actor_search_page.dart';
import 'features/political_actors/politician_follow_validation_page.dart';
import 'features/quiz/quiz_page.dart';
import 'features/quiz/quiz_controller.dart';
import 'features/results/results_page.dart';
import 'features/iot/iot_device_page.dart';
import 'features/iot/iot_pairing_page.dart';
import 'features/privacy/privacy_config.dart';
import 'features/privacy/analytics_consent_banner.dart';
import 'features/privacy/privacy_page.dart';
import 'features/weighting/weighting_page.dart';

/// Largura máxima do conteúdo. Em telas largas (web/tablet) a interface é
/// centralizada e limitada a esta largura — o equivalente em Flutter da
/// "caixa limitada" do CSS (`max-width` + `margin: 0 auto`). Em celulares,
/// onde a tela é mais estreita, usa-se a largura total disponível.
const double kMaxContentWidth = 600;

/// Configuração global da aplicação: tema, rotas nomeadas e a camada de layout
/// aplicada a todas as telas (ver `builder`). Mantém a configuração separada do
/// ponto de entrada (main.dart).
class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.featureFlags = FeatureFlags.environment,
    this.analyticsConsent,
    this.analytics,
    this.privacyConfig = PrivacyConfig.environment,
    this.pageBuilders,
    this.initialUri,
  });

  final FeatureFlags featureFlags;
  final AnalyticsConsentController? analyticsConsent;
  final AnalyticsService? analytics;
  final PrivacyConfig privacyConfig;

  @visibleForTesting
  final List<Widget Function(VoidCallback onStartQuiz)>? pageBuilders;

  @visibleForTesting
  final Uri? initialUri;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final AnalyticsService _analytics;
  late final AnalyticsNavigationIntent _navigationIntent;
  late final AnalyticsNavigationObserver _navigationObserver;
  late final Uri? _initialUri;

  @override
  void initState() {
    super.initState();
    _analytics = widget.analytics ?? AnalyticsService();
    _navigationIntent = AnalyticsNavigationIntent();
    _navigationObserver = AnalyticsNavigationObserver(
      analytics: _analytics,
      intent: _navigationIntent,
      politicianFollowEnabled: widget.featureFlags.politicianFollowEnabled,
    );
    _initialUri = widget.initialUri ?? (kIsWeb ? Uri.base : null);
    if (MainShell.tabFromArguments(_initialUri) == MainShellTab.quiz) {
      _navigationIntent.mark(AnalyticsSource.deepLink);
    }
  }

  Widget _buildResponsiveContent(BuildContext context, Widget? child) {
    if (ResponsiveLayout.isDesktop(context)) {
      return child ?? const SizedBox.shrink();
    }
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width > kMaxContentWidth ? kMaxContentWidth : width;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  void _showConsentSaveError(Future<bool> Function() retry) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Não foi possível salvar sua escolha.'),
        action: SnackBarAction(
          label: 'TENTAR NOVAMENTE',
          onPressed: () async {
            if (!await retry() && mounted) {
              _showConsentSaveError(retry);
            }
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final featureFlags = widget.featureFlags;
    final resolvedConsent =
        widget.analyticsConsent ?? AnalyticsDependencies.instance.controller;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_navigationObserver],
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title:
          kIsWeb ? 'Farol Político | Quiz presidencial 2026' : 'Farol Político',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // O `builder` intercepta a construção de TODAS as telas e aplica uma
      // camada de layout global: área segura (SafeArea) + limite de largura
      // responsivo. Centralizar isso aqui evita repetir a mesma lógica em cada
      // página (princípio DRY) e garante consistência visual em todo o app.
      builder: (context, child) => ColoredBox(
        color: AppTheme.background,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => ListenableBuilder(
              listenable: resolvedConsent,
              builder: (context, _) => Column(
                children: [
                  Expanded(
                    child: _buildResponsiveContent(context, child),
                  ),
                  if (resolvedConsent.state == AnalyticsConsent.pending)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * .55,
                      ),
                      child: AnalyticsConsentBanner(
                        controller: resolvedConsent,
                        onLearnMore: () => _navigatorKey.currentState!
                            .pushNamed('/privacidade'),
                        onGrantPersistenceFailure: () =>
                            _showConsentSaveError(resolvedConsent.grant),
                        onDenialPersistenceFailure: () =>
                            _showConsentSaveError(resolvedConsent.deny),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        // O shell le a aba de abertura dos arguments da rota, o que permite a
        // telas como a de resultados voltarem direto para a aba do quiz.
        '/': (context) => MainShell(
              iotEnabled: featureFlags.iotEnabled,
              politicianFollowEnabled: featureFlags.politicianFollowEnabled,
              analytics: _analytics,
              navigationIntent: _navigationIntent,
              routeObserver: _navigationObserver,
              pageBuilders: widget.pageBuilders,
              initialTab: MainShell.tabFromArguments(
                ModalRoute.of(context)?.settings.arguments ?? _initialUri,
              ),
            ),
        '/quiz': (context) => QuizPage(
              iotEnabled: featureFlags.iotEnabled,
              controller: QuizController(analytics: _analytics),
            ),
        '/weighting': (context) => WeightingPage(analytics: _analytics),
        '/party-selection': (context) =>
            PartySelectionPage(analytics: _analytics),
        '/results': (context) => ResultsPage(analytics: _analytics),
        '/comparison': (context) => ComparisonPage(analytics: _analytics),
        '/political-actors': (context) => featureFlags.politicianFollowEnabled
            ? const PoliticalActorSearchPage()
            : PoliticianFollowValidationPage(analytics: _analytics),
        if (featureFlags.politicianFollowEnabled)
          '/political-actor-profile': (context) =>
              const PoliticalActorProfilePage(),
        if (featureFlags.iotEnabled) ...{
          '/iot-device': (context) => const IotDevicePage(),
          '/iot-pairing': (context) => const IotPairingPage(),
        },
        '/comunidade': (context) => CommunityFeedPage(analytics: _analytics),
        '/privacidade': (_) => PrivacyPage(
              consentController: resolvedConsent,
              config: widget.privacyConfig,
              analytics: _analytics,
            ),
      },
    );
  }
}
