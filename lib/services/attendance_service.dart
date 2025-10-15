import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  // Legacy method for student attendance (keeping for backward compatibility)
  Future<List<ParseObject>> fetchStudentAttendance({
    String? classId,
    String? session,
    DateTime? date,
  }) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Attendance'));
    if (classId != null) {
      query.whereEqualTo('class', ParseObject('Class')..objectId = classId);
    }
    if (session != null && session.isNotEmpty) {
      query.whereEqualTo('session', session);
    }
    if (date != null) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      query.whereEqualTo(
          'date',
          DateTime.utc(
            normalizedDate.year,
            normalizedDate.month,
            normalizedDate.day,
          ));
    }
    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results as List<ParseObject>;
    }
    return [];
  }

  // NEW: Smart QR Attendance System Methods

  // Fetch teacher's current schedule for validation
  static Future<List<ScheduleEntry>> getTeacherSchedule(
      String teacherId) async {
    try {
      final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('teacher', teacherPointer)
        ..includeObject(['class', 'teacher']);

      final response = await query.query();

      if (response.success && response.results != null) {
        return (response.results as List<ParseObject>).map((obj) {
          final classObj = obj.get<ParseObject>('class');
          final timeSlot = obj.get<String>('timeSlot') ?? '08:00';

          // Calculate end time (assuming 1-hour classes)
          final startHour = int.parse(timeSlot.split(':')[0]);
          final endTime = '${(startHour + 1).toString().padLeft(2, '0')}:00';

          return ScheduleEntry.fromParseObject({
            'class': {
              'objectId': classObj?.objectId ?? '',
              'code':
                  classObj?.get('code') ?? classObj?.get('name') ?? 'Unknown',
            },
            'subject': {
              'objectId': obj.objectId ?? '',
              'name': obj.get<String>('subject') ?? 'Unknown Subject',
            },
            'teacher': obj.get<ParseObject>('teacher')?.toJson(),
            'dayOfWeek': obj.get<String>('day'),
            'startTime': timeSlot,
            'endTime': endTime,
            'period': timeSlot, // Use timeSlot as period identifier
          });
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching teacher schedule: $e');
      return [];
    }
  }

  // Check if teacher has a valid subject at current time for the scanned class
  static Future<ScheduleEntry?> validateAttendanceEligibility(
      String teacherId, String classCode) async {
    try {
      print('=== ATTENDANCE VALIDATION DEBUG ===');
      print('Original Teacher ID: $teacherId');
      print('Original Class Code: $classCode');

      // Map duplicate teacher IDs - temporary fix for duplicate records
      String mappedTeacherId = teacherId;
      if (teacherId == 'MpKBC2x5z6') {
        mappedTeacherId = '0VigufBHQT';
        print('MAPPED Teacher ID: $teacherId -> $mappedTeacherId');
      }

      // Map class codes if needed
      String mappedClassCode = classCode;
      if (classCode == 'wgSrRhbfud') {
        mappedClassCode = '1A';
        print('MAPPED Class Code: $classCode -> $mappedClassCode');
      }

      final schedule = await getTeacherSchedule(mappedTeacherId);
      final now = DateTime.now();

      print(
          'Current Time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      print('Current Day: ${_getDayName(now.weekday)}');
      print('Total Schedule Entries: ${schedule.length}');

      // Filter schedule for today and the scanned class
      final todaySchedule = schedule.where((entry) {
        final isToday = entry.isValidToday();
        final classMatches = entry.classCode.isEmpty ||
            entry.classCode.toLowerCase() == mappedClassCode.toLowerCase();

        print(
            'Entry check - Day: ${entry.dayOfWeek}, Class: "${entry.classCode}", IsToday: $isToday, ClassMatches: $classMatches');

        return isToday && classMatches;
      }).toList();

      print(
          'Today\'s Schedule for Class $mappedClassCode: ${todaySchedule.length} entries');

      // Debug: Show all schedule entries for this teacher
      print('=== ALL SCHEDULE ENTRIES FOR TEACHER $mappedTeacherId ===');
      for (var entry in schedule) {
        print(
            'Day: ${entry.dayOfWeek}, Time: ${entry.startTime}-${entry.endTime}, Class: ${entry.classCode}, Subject: ${entry.subjectName}');
      }

      // Debug: Show entries for today specifically
      final allTodayEntries =
          schedule.where((entry) => entry.isValidToday()).toList();
      print(
          '=== ALL ENTRIES FOR ${_getDayName(now.weekday).toUpperCase()} ===');
      for (var entry in allTodayEntries) {
        print(
            'Time: ${entry.startTime}-${entry.endTime}, Class: ${entry.classCode}, Subject: ${entry.subjectName}');
      }

      // Find current or recent class (within valid timeframe)
      for (final entry in todaySchedule) {
        final startTime = entry.getStartDateTime();
        final endTime = entry.getEndDateTime();

        // Check if we're in the valid attendance window
        // (from 5 minutes before start time to end time)
        if (now.isAfter(startTime.subtract(const Duration(minutes: 5))) &&
            now.isBefore(endTime)) {
          return entry;
        }
      }

      return null;
    } catch (e) {
      print('Error validating attendance eligibility: $e');
      return null;
    }
  }

  // Record attendance with automatic status determination
  static Future<Map<String, dynamic>> recordAttendance({
    required String teacherId,
    required String classCode,
    required ScheduleEntry scheduleEntry,
  }) async {
    try {
      // Map duplicate teacher IDs - use same mapping as validation
      String mappedTeacherId = teacherId;
      if (teacherId == 'MpKBC2x5z6') {
        mappedTeacherId = '0VigufBHQT';
        print(
            'MAPPED Teacher ID for attendance: $teacherId -> $mappedTeacherId');
      }

      // Check for duplicate attendance first
      final alreadyScanned = await hasAlreadyScannedToday(
        teacherId: mappedTeacherId, // Use mapped ID for checking duplicates
        classCode: classCode,
        subjectId: scheduleEntry.subjectId,
        period: scheduleEntry.period,
      );

      if (alreadyScanned) {
        return {
          'success': false,
          'message': 'Attendance already recorded for this class today!',
          'isDuplicate': true,
        };
      }

      final now = DateTime.now();
      final startTime = scheduleEntry.getStartDateTime();
      final minutesSinceStart = now.difference(startTime).inMinutes;

      // Determine status based on timing
      String status = 'On Time';
      if (minutesSinceStart > 20) {
        status = 'Late';
      }

      // Create attendance record
      final attendanceRecord = AttendanceRecord(
        objectId: '',
        teacherId: mappedTeacherId, // Use mapped teacher ID
        classCode: classCode,
        subjectId: scheduleEntry.subjectId.isEmpty
            ? 'unknown'
            : scheduleEntry.subjectId,
        subjectName: scheduleEntry.subjectName.isEmpty
            ? 'General Class'
            : scheduleEntry.subjectName,
        scannedTime: now,
        status: status,
        classStartTime: startTime,
        classEndTime: scheduleEntry.getEndDateTime(),
        period: scheduleEntry.period,
        dayOfWeek: scheduleEntry.dayOfWeek,
      );

      // Save to Parse Server
      print('=== SAVING ATTENDANCE RECORD ===');
      print('Teacher ID: $teacherId (original)');
      print('Mapped Teacher ID: $mappedTeacherId (for save)');
      print('Class Code: $classCode');
      print('Subject ID: ${scheduleEntry.subjectId}');
      print('Subject ID: ${scheduleEntry.subjectId}');
      print('Subject Name: ${scheduleEntry.subjectName}');
      print('Status: $status');
      print('Start Time (local): $startTime');
      print('Scanned Time (local): $now');

      final parseObject = ParseObject('TeacherAttendance');
      final data = attendanceRecord.toParseObject();

      print('Attendance data to save: $data');

      data.forEach((key, value) {
        parseObject.set(key, value);
      });

      // Add teacher pointer - use mapped teacher ID
      parseObject.set(
          'teacher', ParseObject('Teacher')..objectId = mappedTeacherId);

      print('About to save to Parse...');

      // First, let's try to create a simple test object to check permissions
      print('Testing Parse permissions with simple object...');
      final testObject = ParseObject('TeacherAttendance');
      testObject.set('test', 'test-value');
      final testResponse = await testObject.save();
      print('Test save - Success: ${testResponse.success}');
      if (testResponse.error != null) {
        print('Test save error: ${testResponse.error!.message}');
      }

      // Now try the actual save
      final response = await parseObject.save();
      print('Parse response - Success: ${response.success}');
      print('Parse response object: ${response.result}');
      print('Parse response results: ${response.results}');

      if (response.error != null) {
        print('Parse error: ${response.error!.message}');
        print('Parse error code: ${response.error!.code}');
        print('Parse error type: ${response.error!.type}');
      } else if (!response.success) {
        print('Parse failed but no error object - checking statusCode');
        print('Response count: ${response.count}');
        print('Response toString: ${response.toString()}');
      }

      if (response.success) {
        return {
          'success': true,
          'status': status,
          'message': 'Attendance recorded successfully!',
          'subjectName': scheduleEntry.subjectName,
          'className': classCode,
          'period': scheduleEntry.period,
          'scannedTime': now,
          'minutesSinceStart': minutesSinceStart,
        };
      } else {
        return {
          'success': false,
          'message':
              'Failed to save attendance: ${response.error?.message ?? "Unknown error"}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error recording attendance: $e',
      };
    }
  }

  // Get attendance history for a teacher
  static Future<List<AttendanceRecord>> getTeacherAttendanceHistory({
    required String teacherId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
      final query = QueryBuilder<ParseObject>(ParseObject('TeacherAttendance'))
        ..whereEqualTo('teacher', teacherPointer)
        ..orderByDescending('scannedTime');

      if (startDate != null) {
        query.whereGreaterThan('scannedTime', startDate);
      }
      if (endDate != null) {
        query.whereLessThan('scannedTime', endDate);
      }

      final response = await query.query();

      if (response.success && response.results != null) {
        return (response.results as List<ParseObject>).map((obj) {
          return AttendanceRecord.fromParseObject(obj.toJson());
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching attendance history: $e');
      return [];
    }
  }

  // Check for duplicate attendance (prevent multiple scans for same class/period)
  static Future<bool> hasAlreadyScannedToday({
    required String teacherId,
    required String classCode,
    required String subjectId,
    required String period,
  }) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
      final query = QueryBuilder<ParseObject>(ParseObject('TeacherAttendance'))
        ..whereEqualTo('teacher', teacherPointer)
        ..whereEqualTo('classCode', classCode)
        ..whereEqualTo('subjectId', subjectId)
        ..whereEqualTo('period', period)
        ..whereGreaterThan('scannedTime', startOfDay)
        ..whereLessThan('scannedTime', endOfDay);

      final response = await query.query();
      return response.success && (response.results?.isNotEmpty ?? false);
    } catch (e) {
      print('Error checking duplicate attendance: $e');
      return false;
    }
  }

  // Helper method to get day name from weekday number
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
}
