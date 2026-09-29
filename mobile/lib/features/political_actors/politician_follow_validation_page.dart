import 'dart:async';

import 'package:flutter/material.dart';

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
    try {
      final registered = await _api
          .fetchPoliticianFollowInterest(
            anonymousId: await _identity(),
          )
          .timeout(_statusTimeout);
      if (!mounted) return;
      setState(() => _registered = registered);
      if (!registered) {
        _track(_analytics.followWaitlistPromptViewed());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusUnavailable = true);
      _track(_analytics.followWaitlistPromptViewed());
    } finally {
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
    try {
      final newlyRegistered = await _api.registerPoliticianFollowInterest(
        anonymousId: await _identity(),
      );
      if (newlyRegistered) {
        _track(_analytics.followWaitlistRegistered());
      }
      if (!mounted) return;
      setState(() {
        _registered = true;
        _statusUnavailable = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionFailed = true);
      _track(_analytics.followWaitlistFailed());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _withdraw() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _actionFailed = false;
    });
    try {
      await _api.deletePoliticianFollowInterest(
        anonymousId: await _identity(),
      );
      if (!mounted) return;
      setState(() => _registered = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionFailed = true);
    } finally {
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
            _RegisteredState(
              submitting: _submitting,
              failed: _actionFailed,
              onWithdraw: _withdraw,
            )
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
  const _RegisteredState({
    required this.submitting,
    required this.failed,
    required this.onWithdraw,
  });

  final bool submitting;
  final bool failed;
  final VoidCallback onWithdraw;

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
            'Obrigado. Esse registro anônimo entra na nossa medição de '
            'demanda.',
            style: textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          if (failed) ...[
            const SizedBox(height: 12),
            Text(
              'Não foi possível retirar seu interesse.',
              style: textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: submitting ? null : onWithdraw,
              child: const Text('RETIRAR INTERESSE'),
            ),
          ),
        ],
      ),
    );
  }
}
