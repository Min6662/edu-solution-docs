import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
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

  Future<bool> _validateClassSchedule(String classCode) async {
    try {
      // Get current teacher ID
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

      // Get current day of week
      final now = DateTime.now();
      final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final currentDay = days[now.weekday % 7]; // weekday: 1=Monday, 7=Sunday
      final currentHour = now.hour;
      final currentMinute = now.minute;

      print(
          'Current Day: $currentDay, Time: $currentHour:${currentMinute.toString().padLeft(2, '0')}');

      // The classCode is actually the classId (from QR code pointer)
      // So we query directly using it as the class ID
      final classId = classCode;
      print('Class ID from QR: $classId');

      // Query the Class table to verify the class exists
      // Try two approaches: first by objectId, then query all and match
      ParseObject? classObj;
      
      final classQuery = QueryBuilder<ParseObject>(ParseObject('Class'))
        ..whereEqualTo('objectId', classId);

      final classResponse = await classQuery.query();

      if (classResponse.success &&
          classResponse.results != null &&
          classResponse.results!.isNotEmpty) {
        classObj = classResponse.results!.first as ParseObject;
      } else {
        print('⚠️ Class not found by objectId, trying alternative approach...');
        // If not found by objectId, we'll proceed anyway since we have the ID
        // The Schedule table will verify it exists
      }

      final className = classObj?.get<String>('name') ?? classId;
      print('✅ Using Class: $className (ID: $classId)');

      // Query the Schedule table for this teacher and class on this day
      final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
      final classPointer = ParseObject('Class')..objectId = classId;

      print('=== SCHEDULE QUERY DEBUG ===');
      print('Teacher Pointer ID: $teacherId');
      print('Class Pointer ID: $classId');
      print('Current Day: $currentDay');

      final scheduleQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('teacher', teacherPointer)
        ..whereEqualTo('class', classPointer)
        ..whereEqualTo('day', currentDay);

      final scheduleResponse = await scheduleQuery.query();

      print('Schedule query success: ${scheduleResponse.success}');
      print('Schedule query results count: ${scheduleResponse.results?.length ?? 0}');
      
      // Debug: Print all results
      if (scheduleResponse.results != null) {
        for (int i = 0; i < scheduleResponse.results!.length; i++) {
          final sched = scheduleResponse.results![i];
          print('Schedule #$i:');
          print('  - Teacher: ${sched.get<ParseObject>('teacher')?.objectId}');
          print('  - Class: ${sched.get<ParseObject>('class')?.objectId}');
          print('  - Day: ${sched.get<String>('day')}');
          print('  - TimeSlot: ${sched.get<String>('timeSlot')}');
          print('  - Subject: ${sched.get<String>('subject')}');
        }
      }

      if (!scheduleResponse.success ||
          scheduleResponse.results == null ||
          scheduleResponse.results!.isEmpty) {
        print(
            '❌ No schedule found for teacher $teacherId, class $classId on $currentDay');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '❌ No schedule found\nTeacher: $teacherId\nClass: $classId\nDay: $currentDay'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // Check if current time matches the scheduled time slot
      for (final schedule in scheduleResponse.results!) {
        final timeSlot = schedule.get<String>('timeSlot') ?? '';
        final subject = schedule.get<String>('subject') ?? 'Unknown';
        
        print('=== TIME SLOT MATCHING ===');
        print('Checking time slot: $timeSlot for subject: $subject');

        if (timeSlot.isNotEmpty) {
          final timeParts = timeSlot.split(':');
          if (timeParts.length < 2) {
            print('❌ Invalid timeSlot format: $timeSlot');
            continue;
          }
          
          final scheduledHour = int.tryParse(timeParts[0]) ?? 0;
          final scheduledMinute = int.tryParse(timeParts[1]) ?? 0;

          // Check if current time is within 1 hour of the scheduled time
          // (allowing 5 minutes before to 55 minutes after the start time)
          final scheduleTimeInMinutes = scheduledHour * 60 + scheduledMinute;
          final currentTimeInMinutes = currentHour * 60 + currentMinute;
          final timeDifference = currentTimeInMinutes - scheduleTimeInMinutes;

          print(
              'Scheduled time: $scheduledHour:${scheduledMinute.toString().padLeft(2, '0')} = $scheduleTimeInMinutes min');
          print(
              'Current time: $currentHour:${currentMinute.toString().padLeft(2, '0')} = $currentTimeInMinutes min');
          print('Time difference: $timeDifference minutes');
          print('Checking range: -5 to 55 (5 min before to 55 min after)');

          // Accept if time is between 5 minutes before class starts and 55 minutes after
          if (timeDifference >= -5 && timeDifference <= 55) {
            print('✅ MATCH! Valid class time for $subject!');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('✅ Class found: $className - $subject at $timeSlot'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            return true;
          } else {
            print('❌ Time outside valid window. Difference: $timeDifference (need -5 to 55)');
          }
        } else {
          print('❌ Empty timeSlot');
        }
      }

      // If we get here, time doesn't match
      print('❌ Current time does not match any scheduled class time');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ No class at this time\nCurrent: $currentHour:${currentMinute.toString().padLeft(2, '0')} on $currentDay'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return false;
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
