class AttendanceRecord {
  final String objectId;
  final String teacherId;
  final String classCode;
  final String subjectId;
  final String subjectName;
  final DateTime scannedTime;
  final String status; // 'On Time', 'Late'
  final DateTime classStartTime;
  final DateTime classEndTime;
  final String period;
  final String dayOfWeek;
  final DateTime? createdAt;

  AttendanceRecord({
    required this.objectId,
    required this.teacherId,
    required this.classCode,
    required this.subjectId,
    required this.subjectName,
    required this.scannedTime,
    required this.status,
    required this.classStartTime,
    required this.classEndTime,
    required this.period,
    required this.dayOfWeek,
    this.createdAt,
  });

  factory AttendanceRecord.fromParseObject(Map<String, dynamic> data) {
    // Parse dates safely
    DateTime parseDateTime(dynamic dateData) {
      if (dateData == null) return DateTime.now();
      if (dateData is DateTime) return dateData;
      if (dateData is String)
        return DateTime.tryParse(dateData) ?? DateTime.now();
      if (dateData is Map && dateData['iso'] != null) {
        return DateTime.tryParse(dateData['iso']) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return AttendanceRecord(
      objectId: data['objectId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      classCode: data['classCode'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      scannedTime: parseDateTime(data['scannedTime']),
      status: data['status'] ?? 'On Time',
      classStartTime: parseDateTime(data['classStartTime']),
      classEndTime: parseDateTime(data['classEndTime']),
      period: data['period'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? '',
      createdAt: parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toParseObject() {
    return {
      'teacherId': teacherId,
      'classCode': classCode,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'scannedTime': scannedTime, // Keep local time
      'status': status,
      'classStartTime': classStartTime, // Keep local time
      'classEndTime': classEndTime, // Keep local time
      'period': period,
      'dayOfWeek': dayOfWeek,
    };
  }
}

class ScheduleEntry {
  final String teacherId;
  final String classCode;
  final String className;
  final String subjectId;
  final String subjectName;
  final String dayOfWeek;
  final String startTime; // Format: "HH:MM"
  final String endTime; // Format: "HH:MM"
  final String period;

  ScheduleEntry({
    required this.teacherId,
    required this.classCode,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.period,
  });

  factory ScheduleEntry.fromParseObject(Map<String, dynamic> data) {
    final classObj = data['class'];
    final subjectObj = data['subject'];
    final teacherObj = data['teacher'];

    return ScheduleEntry(
      teacherId: teacherObj?['objectId'] ?? '',
      classCode: classObj?['classname'] ?? '',
      className: classObj?['classname'] ?? '',
      subjectId: subjectObj?['objectId'] ?? '',
      subjectName: subjectObj?['subjectName'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      period: data['period'] ?? '',
    );
  }

  DateTime getStartDateTime() {
    final now = DateTime.now();
    final timeParts = startTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime getEndDateTime() {
    final now = DateTime.now();
    final timeParts = endTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  bool isCurrentTime() {
    final now = DateTime.now();
    final start = getStartDateTime();
    final end = getEndDateTime();

    return now.isAfter(start) && now.isBefore(end);
  }

  bool isValidToday() {
    final today = DateTime.now();
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayName = weekdays[today.weekday - 1];
    final todayShort = shortWeekdays[today.weekday - 1];

    // Match both full and abbreviated day names
    return dayOfWeek.toLowerCase() == todayName.toLowerCase() ||
        dayOfWeek.toLowerCase() == todayShort.toLowerCase();
  }
}
