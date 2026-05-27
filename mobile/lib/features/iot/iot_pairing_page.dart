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
  final _manualCodeController = TextEditingController();
  final _manualShortIdController = TextEditingController();
  final _qrPayloadController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _manualCodeController.dispose();
    _manualShortIdController.dispose();
    _qrPayloadController.dispose();
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

  Future<void> _pairFromManualCode() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _session.pairWithManualCode(
        IotManualPairingInput(
          pairingCode: _manualCodeController.text,
          shortId: _manualShortIdController.text,
        ),
      );
      if (!mounted) return;
      if (_session.error != null) {
        setState(() => _error = _session.error);
        return;
      }
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
        child: ListView(
          children: [
            Column(
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
                        if (raw != null && mounted) _pairFromRaw(raw);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('CODIGO DO FAROL', style: textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualCodeController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '482 913',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Text('ID CURTO', style: textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualShortIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '2D90 AE25',
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null) Text(_error!, style: textTheme.bodySmall),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _pairFromManualCode,
                    child: Text(_submitting ? 'CONECTANDO' : 'CONECTAR'),
                  ),
                ),
                const SizedBox(height: 20),
                Text('LINK DO QR', style: textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _qrPayloadController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'farol://pair?...',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _pairFromRaw(_qrPayloadController.text),
                    child:
                        Text(_submitting ? 'CONECTANDO' : 'CONECTAR PELO QR'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
