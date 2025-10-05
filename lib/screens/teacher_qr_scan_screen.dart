import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';

class TeacherQRScanScreen extends StatefulWidget {
  const TeacherQRScanScreen({super.key});

  @override
  State<TeacherQRScanScreen> createState() => _TeacherQRScanScreenState();
}

class _TeacherQRScanScreenState extends State<TeacherQRScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? scanResult;
  bool isProcessing = false;
  String? teacherObjectId;
  String? lastProcessedCode;

  @override
  void initState() {
    super.initState();
    _fetchTeacherId();
  }

  Future<void> _fetchTeacherId() async {
    final user = await AuthService().getCurrentUser();
    setState(() {
      teacherObjectId = user?.objectId;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    ctrl.scannedDataStream.listen((scanData) async {
      final scannedCode = scanData.code;

      // Prevent processing the same code multiple times
      if (isProcessing || scannedCode == lastProcessedCode) return;

      setState(() {
        isProcessing = true;
        scanResult = scannedCode;
        lastProcessedCode = scannedCode;
      });

      await _processQRCode(scannedCode);

      // Reset processing after delay
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        isProcessing = false;
        lastProcessedCode = null;
      });
    });
  }

  Future<void> _processQRCode(String? classCode) async {
    if (classCode == null || teacherObjectId == null) {
      _showMessage('Invalid QR code or teacher information missing.',
          isError: true);
      return;
    }

    try {
      // Show processing indicator
      _showMessage('Validating attendance...', isLoading: true);

      // Step 1: Validate if teacher has subject at current time for this class
      final scheduleEntry =
          await AttendanceService.validateAttendanceEligibility(
        teacherObjectId!,
        classCode,
      );

      if (scheduleEntry == null) {
        _showMessage(
          'You don\'t have any subject scheduled right now for class $classCode.',
          isError: true,
        );
        return;
      }

      // Step 2: Record attendance with automatic status detection
      final result = await AttendanceService.recordAttendance(
        teacherId: teacherObjectId!,
        classCode: classCode,
        scheduleEntry: scheduleEntry,
      );

      if (result['success'] == true) {
        _showAttendanceSuccess(result);
      } else {
        _showMessage(result['message'] ?? 'Failed to record attendance',
            isError: true);
      }
    } catch (e) {
      _showMessage('Error processing QR code: $e', isError: true);
    }
  }

  void _showMessage(String message,
      {bool isError = false, bool isLoading = false}) {
    final color =
        isError ? Colors.red : (isLoading ? Colors.orange : Colors.green);
    final icon = isError
        ? Icons.error
        : (isLoading ? Icons.hourglass_empty : Icons.check_circle);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: isLoading ? 2 : 4),
      ),
    );
  }

  void _showAttendanceSuccess(Map<String, dynamic> result) {
    final status = result['status'] ?? 'On Time';
    final subjectName = result['subjectName'] ?? '';
    final className = result['className'] ?? '';
    final period = result['period'] ?? '';
    final minutesSinceStart = result['minutesSinceStart'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                status == 'Late' ? Icons.schedule : Icons.check_circle,
                color: status == 'Late' ? Colors.orange : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text('Attendance Recorded'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Subject:', subjectName),
              _buildInfoRow('Class:', className),
              _buildInfoRow('Period:', period),
              _buildInfoRow('Status:', status),
              _buildInfoRow('Time:', _formatCurrentTime()),
              if (minutesSinceStart > 0)
                _buildInfoRow('Minutes since start:', '$minutesSinceStart min'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: status == 'Late'
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: status == 'Late'
                        ? Colors.orange.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'Late' ? Icons.info : Icons.thumb_up,
                      color: status == 'Late' ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status == 'Late'
                            ? 'Marked as late (scanned more than 20 minutes after class start)'
                            : 'Perfect timing! Attendance recorded on time.',
                        style: TextStyle(
                          color: status == 'Late'
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance Scanner'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scan classroom QR code to record attendance',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'System will automatically check your schedule and mark you as "On Time" or "Late"',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // QR Scanner
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.blue,
                    borderRadius: 12,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 250,
                  ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Status area
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (scanResult == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Point camera at classroom QR code',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'Last scanned: $scanResult',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Processed at ${_formatCurrentTime()}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
