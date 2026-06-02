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

  late final MobileScannerController _scannerController =
      MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  final _manualCodeController = TextEditingController();
  final _manualShortIdController = TextEditingController();
  final _qrPayloadController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _scannerController.dispose();
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
                const SizedBox(height: 20),
                Text(
                  'Aponte a câmera para o QR Code exibido no Farol',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ClipRect(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
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
                        _ScanOverlay(scanning: !_submitting),
                      ],
                    ),
                  ),
                ),
                if (_submitting) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
                const SizedBox(height: 20),
                Text('CODIGO DO FAROL', style: textTheme.labelMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualCodeController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Codigo do Farol',
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
                    labelText: 'ID curto',
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
                    labelText: 'Link do QR',
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

class _ScanOverlay extends StatelessWidget {
  final bool scanning;

  const _ScanOverlay({required this.scanning});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: ShapeDecoration(
          shape: _ScanFrameBorder(
            borderColor: scanning ? Colors.white : Colors.grey,
            cornerLength: 24,
            cornerWidth: 3,
          ),
        ),
      ),
    );
  }
}

class _ScanFrameBorder extends ShapeBorder {
  final Color borderColor;
  final double cornerLength;
  final double cornerWidth;

  const _ScanFrameBorder({
    required this.borderColor,
    required this.cornerLength,
    required this.cornerWidth,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const inset = 32.0;
    final l = rect.left + inset;
    final t = rect.top + inset;
    final r = rect.right - inset;
    final b = rect.bottom - inset;
    final cl = cornerLength;

    // Top-left
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l, t + cl), paint);
    // Top-right
    canvas.drawLine(Offset(r - cl, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + cl), paint);
    // Bottom-left
    canvas.drawLine(Offset(l, b - cl), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + cl, b), paint);
    // Bottom-right
    canvas.drawLine(Offset(r, b - cl), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r - cl, b), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
