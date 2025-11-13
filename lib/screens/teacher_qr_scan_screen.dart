import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'dart:io';

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

  Future<bool> _validateClassSchedule(String classId) async {
    try {
      // Get current time
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      final dayOfWeek = now.weekday; // 1=Monday, 7=Sunday

      // Get current teacher ID
      final currentUser = await ParseUser.currentUser() as ParseUser?;
      final teacherId = currentUser?.get<String>('objectId') ?? '';

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

      // Fetch teacher's schedule from Parse
      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('classId', classId)
        ..whereEqualTo('teacherId', teacherId);

      final response = await query.query();

      if (!response.success ||
          response.results == null ||
          response.results!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No schedule found for this class'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Check if current time matches any schedule entry
      for (final schedule in response.results!) {
        final scheduledDay = schedule.get<int>('dayOfWeek') ?? 0;
        final startTime = schedule.get<String>('startTime') ?? '';
        final endTime = schedule.get<String>('endTime') ?? '';

        // Parse start and end times (format: "HH:mm")
        if (startTime.isNotEmpty && endTime.isNotEmpty) {
          final startParts = startTime.split(':');
          final endParts = endTime.split(':');

          final startHour = int.tryParse(startParts[0]) ?? 0;
          final startMinuteVal = int.tryParse(startParts[1]) ?? 0;
          final endHour = int.tryParse(endParts[0]) ?? 0;
          final endMinuteVal = int.tryParse(endParts[1]) ?? 0;

          // Check if today matches scheduled day and current time is within class time
          if (dayOfWeek == scheduledDay) {
            final currentTimeInMinutes = currentHour * 60 + currentMinute;
            final startTimeInMinutes = startHour * 60 + startMinuteVal;
            final endTimeInMinutes = endHour * 60 + endMinuteVal;

            if (currentTimeInMinutes >= startTimeInMinutes &&
                currentTimeInMinutes <= endTimeInMinutes) {
              // Valid class time
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Class found! $startTime - $endTime'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              return true;
            }
          }
        }
      }

      // No matching schedule found
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ You do not have class at this time (Current: ${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')})'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
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

                  // Validate class schedule
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
