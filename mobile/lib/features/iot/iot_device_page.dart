import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/iot_device_session.dart';
import '../../shared/political_actor_session.dart';
import '../../shared/models/political_actor.dart';

class IotDevicePage extends StatefulWidget {
  final IotDeviceSession? session;
  final PoliticalActorSession? actorSession;

  const IotDevicePage({super.key, this.session, this.actorSession});

  @override
  State<IotDevicePage> createState() => _IotDevicePageState();
}

class _IotDevicePageState extends State<IotDevicePage> {
  late final IotDeviceSession _session =
      widget.session ?? IotDeviceSession.instance;
  late final PoliticalActorSession _actorSession =
      widget.actorSession ?? PoliticalActorSession.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_session.loadStatus());
    unawaited(_actorSession.loadFollowedActor());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'FAROL POLÍTICO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_session, _actorSession]),
        builder: (context, _) {
          final device = _session.device;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(width: 4, height: 40, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Text('MEU FAROL', style: textTheme.headlineLarge),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_session.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_session.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_session.error!, style: textTheme.bodySmall),
                    ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainer,
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: device == null
                        ? _DisconnectedState(onConnect: _openPairing)
                        : _LinkedState(
                            shortToken: device.shortToken,
                            followedActor: _actorSession.followedActor,
                            onChooseDeputy: _openDeputySearch,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPairing() async {
    await Navigator.pushNamed(context, '/iot-pairing');
    if (mounted) unawaited(_session.loadStatus());
  }

  Future<void> _openDeputySearch() async {
    await Navigator.pushNamed(context, '/political-actors');
    if (mounted) unawaited(_actorSession.loadFollowedActor());
  }
}

class _DisconnectedState extends StatelessWidget {
  final VoidCallback onConnect;

  const _DisconnectedState({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nenhum Farol conectado.', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Coloque o gadget em modo de pareamento e escaneie o QR exibido na tela.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onConnect,
            child: const Text('CONECTAR FAROL'),
          ),
        ),
      ],
    );
  }
}

class _LinkedState extends StatelessWidget {
  final String shortToken;
  final PoliticalActor? followedActor;
  final VoidCallback onChooseDeputy;

  const _LinkedState({
    required this.shortToken,
    required this.followedActor,
    required this.onChooseDeputy,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Farol conectado', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(shortToken, style: textTheme.displayMedium),
        const SizedBox(height: 16),
        if (followedActor != null) ...[
          Text('MONITORANDO', style: textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(followedActor!.displayName, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'O Farol mudará de cor quando este deputado votar.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onChooseDeputy,
              child: const Text('TROCAR DEPUTADO'),
            ),
          ),
        ] else ...[
          Text(
            'Nenhum deputado selecionado.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onChooseDeputy,
              child: const Text('ESCOLHER DEPUTADO'),
            ),
          ),
        ],
      ],
    );
  }
}
