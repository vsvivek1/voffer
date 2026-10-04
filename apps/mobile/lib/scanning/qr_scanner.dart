import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Shows a live camera view that reports QR codes. Swapped for a fake in
/// tests, where there is no camera.
abstract class QrScanner {
  const QrScanner();

  /// Whether this device can scan at all. When false, shops type codes.
  bool get available;

  /// A camera view that calls [onScanned] with each QR code's text.
  Widget buildView(ValueChanged<String> onScanned);
}

class DeviceQrScanner extends QrScanner {
  const DeviceQrScanner();

  @override
  bool get available => true;

  @override
  Widget buildView(ValueChanged<String> onScanned) => _CameraView(onScanned);
}

class NoQrScanner extends QrScanner {
  const NoQrScanner();

  @override
  bool get available => false;

  @override
  Widget buildView(ValueChanged<String> onScanned) => const SizedBox.shrink();
}

class _CameraView extends StatefulWidget {
  const _CameraView(this.onScanned);
  final ValueChanged<String> onScanned;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: (capture) {
      for (final code in capture.barcodes) {
        final text = code.rawValue;
        if (text != null && text.isNotEmpty) {
          widget.onScanned(text);
          return;
        }
      }
    },
    errorBuilder: (context, error) => ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? 'Allow camera access in Settings to scan, or type the code.'
                : 'Camera unavailable. Type the code instead.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}
