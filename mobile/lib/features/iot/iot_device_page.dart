import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/iot_device_session.dart';
import '../../shared/models/iot_device.dart';

class IotDevicePage extends StatefulWidget {
  final IotDeviceSession? session;

  const IotDevicePage({super.key, this.session});

  @override
  State<IotDevicePage> createState() => _IotDevicePageState();
}

class _IotDevicePageState extends State<IotDevicePage> {
  late final IotDeviceSession _session =
      widget.session ?? IotDeviceSession.instance;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_session.loadStatus().then((_) {
      unawaited(_session.loadLastEvent());
    }));
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_session.loadLastEvent());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
        animation: _session,
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
                            onUnlink: _confirmUnlink,
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

  Future<void> _confirmUnlink() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Farol?'),
        content: const Text(
          'O gadget sera desvinculado deste app e parara de receber atualizacoes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DESVINCULAR'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _session.unlink();
    }
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
  final VoidCallback onUnlink;

  const _LinkedState({required this.shortToken, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Farol conectado', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(shortToken, style: textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(
          'Este app esta vinculado ao gadget fisico.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onUnlink,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DESVINCULAR FAROL'),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: IotDeviceSession.instance,
          builder: (context, _) {
            final ev = IotDeviceSession.instance.lastEvent;
            if (ev == null) return const SizedBox.shrink();
            return _LastEventCard(event: ev);
          },
        ),
      ],
    );
  }
}

class _LastEventCard extends StatelessWidget {
  final IotLastEvent event;
  const _LastEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('ÚLTIMO EVENTO', style: textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          Text(event.deputyName, style: textTheme.titleLarge),
          Text('${event.party} • ${event.state}', style: textTheme.bodySmall),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: event.alignmentColor,
            child: Text(
              event.alignmentLabel,
              style: textTheme.labelLarge!.copyWith(
                color: event.alignment == 'divergent'
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Votou ${event.vote}', style: textTheme.bodyMedium),
          if (event.description.isNotEmpty)
            Text(event.description, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
