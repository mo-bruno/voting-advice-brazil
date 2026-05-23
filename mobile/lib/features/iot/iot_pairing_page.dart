import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/layout/app_scaffold.dart';
import '../../shared/iot_device_session.dart';
import '../../shared/models/iot_device.dart';

class IotPairingPage extends StatefulWidget {
  final IotDeviceSession? session;

  const IotPairingPage({super.key, this.session});

  @override
  State<IotPairingPage> createState() => _IotPairingPageState();
}

class _IotPairingPageState extends State<IotPairingPage> {
  late final IotDeviceSession _session =
      widget.session ?? IotDeviceSession.instance;
  final _manualController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _pairFromRaw(String raw) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = IotPairingPayload.parse(raw);
      await _session.pairWithPayload(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farol conectado.')),
      );
      Navigator.pop(context);
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'CONECTAR FAROL',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: ClipRect(
                child: MobileScanner(
                  onDetect: (capture) {
                    String? raw;
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        raw = barcode.rawValue;
                        break;
                      }
                    }
                    if (raw != null) _pairFromRaw(raw);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('CODIGO MANUAL', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _manualController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'farol://pair?...',
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () => _pairFromRaw(_manualController.text),
                child: Text(_submitting ? 'CONECTANDO' : 'CONECTAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
