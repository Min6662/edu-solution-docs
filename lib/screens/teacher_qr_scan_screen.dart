import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TeacherQRScanScreen extends StatefulWidget {
  const TeacherQRScanScreen({super.key});

  @override
  State<TeacherQRScanScreen> createState() => _TeacherQRScanScreenState();
}

class _TeacherQRScanScreenState extends State<TeacherQRScanScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.qrScannerTitle)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  setState(() {
                    _isProcessing = true;
                  });
                  // Pop with the scanned data
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          // Add a scanner overlay (like a viewfinder)
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.green.withOpacity(0.7),
                width: 4,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
