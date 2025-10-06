import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class ScheduleChecker {
  // Check if schedule data exists in your Schedule table
  static Future<Map<String, dynamic>> checkScheduleData() async {
    try {
      // Check total schedule entries
      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..includeObject(['teacher', 'class']);

      final response = await query.query();

      if (response.success && response.results != null) {
        final schedules = response.results as List<ParseObject>;

        // Group by teacher to see coverage
        Map<String, List<String>> teacherSchedules = {};
        Map<String, List<String>> classSchedules = {};
        Set<String> days = {};
        Set<String> timeSlots = {};

        for (final schedule in schedules) {
          final teacher = schedule.get<ParseObject>('teacher');
          final classObj = schedule.get<ParseObject>('class');
          final day = schedule.get<String>('day') ?? 'Unknown';
          final timeSlot = schedule.get<String>('timeSlot') ?? 'Unknown';
          final subject = schedule.get<String>('subject') ?? 'Unknown';

          days.add(day);
          timeSlots.add(timeSlot);

          final teacherName = teacher?.get<String>('fullName') ??
              teacher?.get<String>('name') ??
              'Unknown Teacher';
          final className = classObj?.get<String>('classname') ??
              classObj?.get<String>('name') ??
              classObj?.get<String>('code') ??
              'Unknown Class';

          final scheduleInfo = '$day $timeSlot - $subject ($className)';

          if (!teacherSchedules.containsKey(teacherName)) {
            teacherSchedules[teacherName] = [];
          }
          teacherSchedules[teacherName]!.add(scheduleInfo);

          if (!classSchedules.containsKey(className)) {
            classSchedules[className] = [];
          }
          classSchedules[className]!.add(scheduleInfo);
        }

        return {
          'hasData': schedules.isNotEmpty,
          'totalEntries': schedules.length,
          'teacherCount': teacherSchedules.length,
          'classCount': classSchedules.length,
          'days': days.toList()..sort(),
          'timeSlots': timeSlots.toList()..sort(),
          'teacherSchedules': teacherSchedules,
          'classSchedules': classSchedules,
          'sampleEntries': schedules.take(5).map((s) {
            final teacher = s.get<ParseObject>('teacher');
            final classObj = s.get<ParseObject>('class');
            return {
              'teacher': teacher?.get<String>('fullName') ??
                  teacher?.get<String>('name') ??
                  'Unknown',
              'class': classObj?.get<String>('classname') ??
                  classObj?.get<String>('name') ??
                  classObj?.get<String>('code') ??
                  'Unknown',
              'day': s.get<String>('day'),
              'timeSlot': s.get<String>('timeSlot'),
              'subject': s.get<String>('subject'),
            };
          }).toList(),
        };
      }

      return {
        'hasData': false,
        'totalEntries': 0,
        'message': 'No schedule data found',
      };
    } catch (e) {
      return {
        'hasData': false,
        'error': 'Error checking schedule data: $e',
      };
    }
  }

  // Sample method to add test schedule entries
  static Future<bool> addSampleScheduleEntries() async {
    try {
      // Get first available teacher and class
      final teacherQuery = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final teacherResponse = await teacherQuery.query();

      final classQuery = QueryBuilder<ParseObject>(ParseObject('Class'));
      final classResponse = await classQuery.query();

      if (teacherResponse.success &&
          teacherResponse.results != null &&
          classResponse.success &&
          classResponse.results != null &&
          teacherResponse.results!.isNotEmpty &&
          classResponse.results!.isNotEmpty) {
        final teacher = teacherResponse.results!.first;
        final classObj = classResponse.results!.first;

        // Sample schedule entries
        final sampleSchedules = [
          {'day': 'Monday', 'timeSlot': '08:00', 'subject': 'Mathematics'},
          {'day': 'Monday', 'timeSlot': '09:00', 'subject': 'English'},
          {'day': 'Tuesday', 'timeSlot': '08:00', 'subject': 'Science'},
          {'day': 'Wednesday', 'timeSlot': '10:00', 'subject': 'History'},
          {'day': 'Thursday', 'timeSlot': '09:00', 'subject': 'Physics'},
          {'day': 'Friday', 'timeSlot': '08:00', 'subject': 'Chemistry'},
        ];

        for (final scheduleData in sampleSchedules) {
          final schedule = ParseObject('Schedule');
          schedule.set('teacher', teacher);
          schedule.set('class', classObj);
          schedule.set('day', scheduleData['day']);
          schedule.set('timeSlot', scheduleData['timeSlot']);
          schedule.set('subject', scheduleData['subject']);

          await schedule.save();
        }

        return true;
      }

      return false;
    } catch (e) {
      print('Error adding sample schedule entries: $e');
      return false;
    }
  }

  // Method to get day name from current date
  static String getCurrentDayName() {
    final now = DateTime.now();
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return days[now.weekday % 7];
  }

  // Method to get current time slot (rounded to nearest hour)
  static String getCurrentTimeSlot() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:00';
  }
}
