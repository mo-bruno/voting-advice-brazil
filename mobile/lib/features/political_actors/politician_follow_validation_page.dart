import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_failure_classifier.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';

class PoliticianFollowValidationPage extends StatefulWidget {
  const PoliticianFollowValidationPage({
    super.key,
    this.apiClient,
    this.interestIdentityStore,
    this.analytics,
  });

  @visibleForTesting
  final ApiClient? apiClient;

  @visibleForTesting
  final PoliticianFollowInterestIdentityStore? interestIdentityStore;

  @visibleForTesting
  final AnalyticsService? analytics;

  @override
  State<PoliticianFollowValidationPage> createState() =>
      _PoliticianFollowValidationPageState();
}

class _PoliticianFollowValidationPageState
    extends State<PoliticianFollowValidationPage> {
  static const _statusTimeout = Duration(seconds: 5);

  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final PoliticianFollowInterestIdentityStore _identityStore =
      widget.interestIdentityStore ?? PoliticianFollowInterestIdentityStore();
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();

  bool _loading = true;
  bool _submitting = false;
  bool _registered = false;
  bool _statusUnavailable = false;
  bool _actionFailed = false;
  String? _anonymousId;

  @override
  void initState() {
    super.initState();
    _track(_analytics.followWaitlistViewed());
    unawaited(_loadStatus());
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  Future<String> _identity() async {
    return _anonymousId ??= await _identityStore.getOrCreateInterestId();
  }

  Future<void> _loadStatus() async {
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.success;
    AnalyticsFailureType? failureType;
    try {
      final registered = await _api
          .fetchPoliticianFollowInterest(
            anonymousId: await _identity(),
          )
          .timeout(_statusTimeout);
      if (mounted) {
        setState(() => _registered = registered);
      }
      if (!registered && mounted) {
        _track(_analytics.followWaitlistPromptViewed());
      }
    } catch (error) {
      outcome = AnalyticsOutcome.failed;
      failureType = classifyAnalyticsFailure(error);
      if (mounted) {
        setState(() => _statusUnavailable = true);
        _track(_analytics.followWaitlistPromptViewed());
      }
    } finally {
      stopwatch.stop();
      _track(_analytics.operationResult(
        operation: AnalyticsOperation.followStatusLoad,
        outcome: outcome,
        trigger: AnalyticsTrigger.initial,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
      ));
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _actionFailed = false;
    });
    _track(_analytics.followWaitlistCtaClicked());
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.success;
    AnalyticsFailureType? failureType;
    try {
      final newlyRegistered = await _api.registerPoliticianFollowInterest(
        anonymousId: await _identity(),
      );
      if (newlyRegistered) {
        _track(_analytics.followWaitlistRegistered());
      }
      if (mounted) {
        setState(() {
          _registered = true;
          _statusUnavailable = false;
        });
      }
    } catch (error) {
      outcome = AnalyticsOutcome.failed;
      failureType = classifyAnalyticsFailure(error);
      if (mounted) {
        setState(() => _actionFailed = true);
        _track(_analytics.followWaitlistFailed());
      }
    } finally {
      stopwatch.stop();
      _track(_analytics.operationResult(
        operation: AnalyticsOperation.followRegister,
        outcome: outcome,
        trigger: AnalyticsTrigger.submit,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
      ));
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'ACOMPANHAR POLÍTICOS',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          Text(
            'Esta funcionalidade ainda está em validação.',
            style: textTheme.headlineLarge?.copyWith(height: 1.15),
          ),
          const SizedBox(height: 16),
          Text(
            'Queremos criar uma área para acompanhar a atuação de políticos '
            'com informações de fontes oficiais. Antes de avançar, precisamos '
            'saber se isso é útil para você.',
            style: textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UM SINAL DE INTERESSE', style: textTheme.labelMedium),
                const SizedBox(height: 12),
                Text(
                  'Seu registro ajuda a medir a demanda e decidir se a '
                  'funcionalidade deve ser lançada.',
                  style: textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Não pedimos nome, e-mail ou telefone. Você não receberá '
                  'uma mensagem; quando a área for lançada, ela aparecerá '
                  'aqui.',
                  style: textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_registered)
            const _RegisteredState()
          else
            _InterestAction(
              submitting: _submitting,
              failed: _actionFailed,
              statusUnavailable: _statusUnavailable,
              onRegister: _register,
            ),
        ],
      ),
    );
  }
}

class _InterestAction extends StatelessWidget {
  const _InterestAction({
    required this.submitting,
    required this.failed,
    required this.statusUnavailable,
    required this.onRegister,
  });

  final bool submitting;
  final bool failed;
  final bool statusUnavailable;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failed) ...[
          Text(
            'Não foi possível registrar seu interesse.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
        ] else if (statusUnavailable) ...[
          Text(
            'Não foi possível verificar um registro anterior. Você ainda '
            'pode tentar registrar seu interesse.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: submitting ? null : onRegister,
            child: Text(failed ? 'TENTAR NOVAMENTE' : 'TENHO INTERESSE'),
          ),
        ),
      ],
    );
  }
}

class _RegisteredState extends StatelessWidget {
  const _RegisteredState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppTheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text('INTERESSE REGISTRADO', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Obrigado. Esse registro sem nome ou contato, separado das outras atividades, entra na nossa medição de '
            'demanda.',
            style: textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
