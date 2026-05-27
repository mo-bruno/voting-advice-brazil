import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/iot_device_session.dart';

class IotDevicePage extends StatefulWidget {
  final IotDeviceSession? session;

  const IotDevicePage({super.key, this.session});

  @override
  State<IotDevicePage> createState() => _IotDevicePageState();
}

class _IotDevicePageState extends State<IotDevicePage> {
  late final IotDeviceSession _session =
      widget.session ?? IotDeviceSession.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_session.loadStatus());
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
                  if (_session.loading) const LinearProgressIndicator(minHeight: 2),
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
                        : _LinkedState(shortToken: device.shortToken),
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

  const _LinkedState({required this.shortToken});

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
      ],
    );
  }
}
