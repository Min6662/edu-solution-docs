import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:io';
import '../services/attendance_service.dart';

class TeacherQRScanScreen extends StatefulWidget {
  const TeacherQRScanScreen({super.key});

  @override
  State<TeacherQRScanScreen> createState() => _TeacherQRScanScreenState();
}

class _TeacherQRScanScreenState extends State<TeacherQRScanScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickAndScanImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null || !mounted) return;

      // Show a dialog with the image and try to scan it
      _showImageScanDialog(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageScanDialog(XFile image) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan QR Code'),
        content: SizedBox(
          width: double.maxFinite,
          child: Image.file(File(image.path)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Process the image for QR code
              await _processImageForQR(image);
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  Future<void> _processImageForQR(XFile image) async {
    try {
      if (!mounted) return;

      setState(() {
        _isProcessing = true;
      });

      // Create a temporary scanner to detect QR in the image
      final tempController = MobileScannerController();

      // Use mobile_scanner's native detection on the image file
      final capture = await tempController.analyzeImage(image.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue != null) {
            // Validate class schedule before returning
            final classId = barcode.rawValue!;
            final isValidClass = await _validateClassSchedule(classId);

            if (isValidClass && mounted) {
              Navigator.pop(context, classId);
              return;
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR code detected in image'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _validateClassSchedule(String classCode) async {
    try {
      // Get current teacher ID - with proper error handling
      ParseUser? currentUser;
      try {
        currentUser = await ParseUser.currentUser();
      } catch (e) {
        print('Error getting current user: $e');
      }

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ User not authenticated - please log in'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      final teacherId = currentUser.get<String>('objectId') ?? '';
      print('Teacher ID: $teacherId');
      print('Class Code: $classCode');

      if (teacherId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Use the AttendanceService to validate eligibility
      print('Validating attendance eligibility for teacher: $teacherId, class: $classCode');
      final scheduleEntry =
          await AttendanceService.validateAttendanceEligibility(
        teacherId,
        classCode,
      );

      if (scheduleEntry == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No class scheduled at this time'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Valid class found - record attendance
      print('Valid class found! Recording attendance...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Class found! ${scheduleEntry.startTime} - ${scheduleEntry.endTime}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Record the attendance
      final result = await AttendanceService.recordAttendance(
        teacherId: teacherId,
        classCode: classCode,
        scheduleEntry: scheduleEntry,
      );

      print('Attendance record result: $result');

      if (result['success'] == true) {
        if (mounted) {
          _showAttendanceSuccessDialog(result);
        }
        return true;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(result['message'] ?? 'Failed to record attendance'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      print('Exception in _validateClassSchedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  void _showAttendanceSuccessDialog(Map<String, dynamic> result) {
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
              Text(AppLocalizations.of(context)!.attendanceRecorded),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(AppLocalizations.of(context)!.subject, subjectName),
              _buildInfoRow(AppLocalizations.of(context)!.className, className),
              _buildInfoRow(AppLocalizations.of(context)!.period, period),
              _buildInfoRow(AppLocalizations.of(context)!.status, status),
              _buildInfoRow(AppLocalizations.of(context)!.time,
                  _formatCurrentTime()),
              if (minutesSinceStart > 0)
                _buildInfoRow(
                    AppLocalizations.of(context)!.minutesSinceStart,
                    '$minutesSinceStart ${AppLocalizations.of(context)!.min}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.ok),
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.qrScannerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Load from Gallery',
            onPressed: _isProcessing ? null : _pickAndScanImage,
          ),
        ],
      ),
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
                if (code != null && mounted) {
                  setState(() {
                    _isProcessing = true;
                  });

                  // Stop the scanner before validating
                  controller.stop();

                  // Validate class schedule and record attendance
                  _validateClassSchedule(code).then((isValid) {
                    if (isValid && mounted) {
                      Navigator.pop(context, code);
                    } else {
                      // Re-enable scanning if validation failed
                      if (mounted) {
                        setState(() {
                          _isProcessing = false;
                        });
                        controller.start();
                      }
                    }
                  });
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
          // Gallery button at the bottom
          Positioned(
            bottom: 30,
            child: FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: _isProcessing ? null : _pickAndScanImage,
              child: const Icon(Icons.image),
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
