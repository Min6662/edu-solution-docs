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
      final schedule = await getTeacherSchedule(teacherId);
      final now = DateTime.now();

      // Filter schedule for today and the scanned class
      final todaySchedule = schedule.where((entry) {
        return entry.isValidToday() &&
            entry.classCode.toLowerCase() == classCode.toLowerCase();
      }).toList();

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
      // Check for duplicate attendance first
      final alreadyScanned = await hasAlreadyScannedToday(
        teacherId: teacherId,
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
        teacherId: teacherId,
        classCode: classCode,
        subjectId: scheduleEntry.subjectId,
        subjectName: scheduleEntry.subjectName,
        scannedTime: now,
        status: status,
        classStartTime: startTime,
        classEndTime: scheduleEntry.getEndDateTime(),
        period: scheduleEntry.period,
        dayOfWeek: scheduleEntry.dayOfWeek,
      );

      // Save to Parse Server
      final parseObject = ParseObject('TeacherAttendance');
      final data = attendanceRecord.toParseObject();
      data.forEach((key, value) {
        parseObject.set(key, value);
      });

      // Add teacher pointer
      parseObject.set('teacher', ParseObject('Teacher')..objectId = teacherId);

      final response = await parseObject.save();

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
}
