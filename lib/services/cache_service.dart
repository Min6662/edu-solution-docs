import 'package:hive/hive.dart';

class CacheService {
  static const String classBoxName = 'classBox';
  static const String studentBoxName = 'studentBox';
  static const String teacherBoxName = 'teacherBox';
  static const String attendanceBoxName = 'attendanceBox';
  static const String userBoxName = 'userBox';
  static const String settingsBoxName = 'settingsBox';
  static const String enrollmentBoxName = 'enrollmentBox';
  static const String schoolBoxName = 'schoolBox'; // Add school cache box
  static const String dashboardBoxName =
      'dashboardBox'; // Add dashboard stats cache box
  static const String timetableBoxName =
      'timetableBox'; // Add timetable cache box

  // Call once at app startup
  static Future<void> init() async {
    await Hive.openBox(classBoxName);
    await Hive.openBox(studentBoxName);
    await Hive.openBox(teacherBoxName);
    await Hive.openBox(attendanceBoxName);
    await Hive.openBox(userBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(enrollmentBoxName);
    await Hive.openBox(schoolBoxName); // Add school box
    await Hive.openBox(dashboardBoxName); // Add dashboard box
    await Hive.openBox(timetableBoxName); // Add timetable box
  }

  // Class List
  static Future<void> saveClassList(
      List<Map<String, dynamic>> classList) async {
    final box = Hive.box(classBoxName);
    await box.put('classList', classList);
  }

  static List<Map<String, dynamic>>? getClassList() {
    final box = Hive.box(classBoxName);
    final data = box.get('classList');
    if (data != null) {
      return List<Map<String, dynamic>>.from(
          (data as List).map((e) => Map<String, dynamic>.from(e)));
    }
    return null;
  }

  static Future<void> clearClassList() async {
    final box = Hive.box(classBoxName);
    await box.delete('classList');
  }

  // Student List
  static Future<void> saveStudentList(
      List<Map<String, dynamic>> studentList) async {
    final box = Hive.box(studentBoxName);
    await box.put('studentList', studentList);
  }

  static List<Map<String, dynamic>>? getStudentList() {
    final box = Hive.box(studentBoxName);
    final data = box.get('studentList');
    if (data != null) {
      return List<Map<String, dynamic>>.from(
          (data as List).map((e) => Map<String, dynamic>.from(e)));
    }
    return null;
  }

  static Future<void> clearStudentList() async {
    final box = Hive.box(studentBoxName);
    await box.delete('studentList');
  }

  // Teacher List
  static Future<void> saveTeacherList(
      List<Map<String, dynamic>> teacherList) async {
    final box = Hive.box(teacherBoxName);

    // Save teacher data with timestamp for freshness validation
    final cacheData = {
      'teacherList': teacherList,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    await box.put('teacherData', cacheData);
  }

  static List<Map<String, dynamic>>? getTeacherList() {
    final box = Hive.box(teacherBoxName);
    final cacheData = box.get('teacherData');

    if (cacheData != null && cacheData is Map) {
      // Check cache freshness (5 minutes)
      final lastUpdatedStr = cacheData['lastUpdated'] as String?;
      if (lastUpdatedStr != null) {
        final lastUpdated = DateTime.parse(lastUpdatedStr);
        final now = DateTime.now();
        final difference = now.difference(lastUpdated).inMinutes;

        if (difference > 5) {
          print(
              'DEBUG: Teacher cache is stale (${difference} minutes old), clearing...');
          return null; // Return null to force fresh data fetch
        }
      }

      final teacherList = cacheData['teacherList'];
      if (teacherList != null) {
        return List<Map<String, dynamic>>.from(
            (teacherList as List).map((e) => Map<String, dynamic>.from(e)));
      }
    }

    // Fallback: check old cache format for backward compatibility
    final oldData = box.get('teacherList');
    if (oldData != null) {
      print('DEBUG: Found old cache format, will refresh...');
      return null; // Force refresh for old format
    }

    return null;
  }

  static Future<void> clearTeacherList() async {
    final box = Hive.box(teacherBoxName);
    await box.delete('teacherData');
    await box.delete('teacherList'); // Also clear old format
  }

  // Attendance History
  static Future<void> saveAttendanceHistory(
      List<Map<String, dynamic>> attendanceList) async {
    final box = Hive.box(attendanceBoxName);
    await box.put('attendanceList', attendanceList);
  }

  static List<Map<String, dynamic>>? getAttendanceHistory() {
    final box = Hive.box(attendanceBoxName);
    final data = box.get('attendanceList');
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return null;
  }

  static Future<void> clearAttendanceHistory() async {
    final box = Hive.box(attendanceBoxName);
    await box.delete('attendanceList');
  }

  // User Profile
  static Future<void> saveUserProfile(Map<String, dynamic> userProfile) async {
    final box = Hive.box(userBoxName);
    await box.put('userProfile', userProfile);
  }

  static Map<String, dynamic>? getUserProfile() {
    final box = Hive.box(userBoxName);
    final data = box.get('userProfile');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> clearUserProfile() async {
    final box = Hive.box(userBoxName);
    await box.delete('userProfile');
  }

  // App Settings or Role Info
  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final box = Hive.box(settingsBoxName);
    await box.put('settings', settings);
  }

  static Map<String, dynamic>? getSettings() {
    final box = Hive.box(settingsBoxName);
    final data = box.get('settings');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> clearSettings() async {
    final box = Hive.box(settingsBoxName);
    await box.delete('settings');
  }

  // Images (base64 or file path)
  static Future<void> saveImage(
      String boxName, String key, String imageData) async {
    final box = Hive.box(boxName);
    await box.put(key, imageData);
  }

  static String? getImage(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  static Future<void> clearImage(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  // Student Count
  static Future<void> saveStudentCount(int count) async {
    final box = Hive.box(studentBoxName);
    await box.put('studentCount', count);
  }

  static int? getStudentCount() {
    final box = Hive.box(studentBoxName);
    return box.get('studentCount');
  }

  // Class Count
  static Future<void> saveClassCount(int count) async {
    final box = Hive.box(classBoxName);
    await box.put('classCount', count);
  }

  static int? getClassCount() {
    final box = Hive.box(classBoxName);
    return box.get('classCount');
  }

  // Enrolled Students (per class)
  static Future<void> saveEnrolledStudents(
      String classId, List<Map<String, dynamic>> students) async {
    final box = Hive.box(enrollmentBoxName);
    await box.put('class_$classId', {
      'students': students,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static List<Map<String, dynamic>>? getEnrolledStudents(String classId) {
    final box = Hive.box(enrollmentBoxName);
    final data = box.get('class_$classId');
    if (data != null && data is Map) {
      final students = data['students'];
      if (students != null) {
        return List<Map<String, dynamic>>.from(
          (students as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    }
    return null;
  }

  static Future<void> clearEnrolledStudents(String classId) async {
    final box = Hive.box(enrollmentBoxName);
    await box.delete('class_$classId');
  }

  static Future<void> clearAllEnrollments() async {
    final box = Hive.box(enrollmentBoxName);
    await box.clear();
  }

  // Check if enrolled students data is fresh (within specified duration)
  static bool isEnrollmentDataFresh(String classId, Duration maxAge) {
    try {
      final box = Hive.box(enrollmentBoxName);
      final timestamp = box.get('${classId}_timestamp');
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) < maxAge;
    } catch (e) {
      return false; // If there's any error, assume data is not fresh
    }
  }

  // Initialize cache boxes if needed
  static Future<void> initializeCacheBoxes() async {
    try {
      if (!Hive.isBoxOpen(classBoxName)) {
        await Hive.openBox(classBoxName);
      }
      if (!Hive.isBoxOpen(studentBoxName)) {
        await Hive.openBox(studentBoxName);
      }
      if (!Hive.isBoxOpen(teacherBoxName)) {
        await Hive.openBox(teacherBoxName);
      }
      if (!Hive.isBoxOpen(attendanceBoxName)) {
        await Hive.openBox(attendanceBoxName);
      }
      if (!Hive.isBoxOpen(userBoxName)) {
        await Hive.openBox(userBoxName);
      }
      if (!Hive.isBoxOpen(settingsBoxName)) {
        await Hive.openBox(settingsBoxName);
      }
      if (!Hive.isBoxOpen(enrollmentBoxName)) {
        await Hive.openBox(enrollmentBoxName);
      }
      if (!Hive.isBoxOpen(schoolBoxName)) {
        await Hive.openBox(schoolBoxName);
      }
      if (!Hive.isBoxOpen(dashboardBoxName)) {
        await Hive.openBox(dashboardBoxName);
      }
    } catch (e) {
      print('Error initializing cache boxes: $e');
    }
  }

  // Clear all cache data (useful for logout or data reset)
  static Future<void> clearAllCache() async {
    try {
      await Hive.box(classBoxName).clear();
      await Hive.box(studentBoxName).clear();
      await Hive.box(teacherBoxName).clear();
      await Hive.box(attendanceBoxName).clear();
      await Hive.box(userBoxName).clear();
      await Hive.box(settingsBoxName).clear();
      await Hive.box(enrollmentBoxName).clear();
      await Hive.box(schoolBoxName).clear();
      await Hive.box(dashboardBoxName).clear();
      await Hive.box(timetableBoxName).clear();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Generic list cache methods
  Future<void> saveList(String key, List<Map<String, dynamic>> list) async {
    // Use attendanceBox for attendance history, otherwise default to classBox
    final box = Hive.box(CacheService.attendanceBoxName);
    await box.put(key, list);
  }

  List<Map<String, dynamic>>? getList(String key) {
    final box = Hive.box(CacheService.attendanceBoxName);
    final data = box.get(key);
    if (data != null) {
      return List<Map<String, dynamic>>.from(
        (data as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return null;
  }

  Future<void> clear(String key) async {
    final box = Hive.box(CacheService.attendanceBoxName);
    await box.delete(key);
  }

  // School Information Cache
  static Future<void> saveSchoolInfo({
    required String name,
    String? logoUrl,
    String? address,
    String? phone,
    String? email,
  }) async {
    final box = Hive.box(schoolBoxName);
    final schoolData = {
      'name': name,
      'logoUrl': logoUrl,
      'address': address,
      'phone': phone,
      'email': email,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put('schoolInfo', schoolData);
  }

  static Map<String, dynamic>? getSchoolInfo() {
    final box = Hive.box(schoolBoxName);
    final data = box.get('schoolInfo');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> clearSchoolInfo() async {
    final box = Hive.box(schoolBoxName);
    await box.delete('schoolInfo');
  }

  // Dashboard Statistics Cache
  static Future<void> saveDashboardStats({
    required int studentCount,
    required int teacherCount,
    required int classCount,
  }) async {
    final box = Hive.box(dashboardBoxName);
    final statsData = {
      'studentCount': studentCount,
      'teacherCount': teacherCount,
      'classCount': classCount,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put('dashboardStats', statsData);
  }

  static Map<String, dynamic>? getDashboardStats() {
    final box = Hive.box(dashboardBoxName);
    final data = box.get('dashboardStats');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> clearDashboardStats() async {
    final box = Hive.box(dashboardBoxName);
    await box.delete('dashboardStats');
  }

  // Timetable Cache Methods
  static Future<void> saveTimetableData({
    required String teacherId,
    required String classId,
    required Map<String, Map<String, String>> morningSchedule,
    required Map<String, Map<String, String>> afternoonSchedule,
    required List<Map<String, dynamic>> teachers,
    required List<Map<String, dynamic>> classes,
  }) async {
    final box = Hive.box(timetableBoxName);
    final cacheKey = '${teacherId}_$classId';

    final timetableData = {
      'teacherId': teacherId,
      'classId': classId,
      'morningSchedule': morningSchedule,
      'afternoonSchedule': afternoonSchedule,
      'teachers': teachers,
      'classes': classes,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    await box.put(cacheKey, timetableData);
  }

  static Map<String, dynamic>? getTimetableData({
    required String teacherId,
    required String classId,
  }) {
    final box = Hive.box(timetableBoxName);
    final cacheKey = '${teacherId}_$classId';
    final data = box.get(cacheKey);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> saveTeachersAndClasses({
    required List<Map<String, dynamic>> teachers,
    required List<Map<String, dynamic>> classes,
  }) async {
    final box = Hive.box(timetableBoxName);
    final data = {
      'teachers': teachers,
      'classes': classes,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };
    await box.put('teachers_classes', data);
  }

  static Map<String, dynamic>? getTeachersAndClasses() {
    final box = Hive.box(timetableBoxName);
    final data = box.get('teachers_classes');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> clearTimetableCache() async {
    final box = Hive.box(timetableBoxName);
    await box.clear();
  }

  static Future<void> clearSpecificTimetable({
    required String teacherId,
    required String classId,
  }) async {
    final box = Hive.box(timetableBoxName);
    final cacheKey = '${teacherId}_$classId';
    await box.delete(cacheKey);
  }

  // Teacher Detail Cache Methods
  static Future<void> saveTeacherDetail({
    required String teacherId,
    required Map<String, dynamic> teacherData,
    required Map<String, dynamic> credentialsData,
  }) async {
    final box = Hive.box(teacherBoxName);
    final cacheKey = 'detail_$teacherId';

    final detailData = {
      'teacherData': teacherData,
      'credentialsData': credentialsData,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    await box.put(cacheKey, detailData);
  }

  static Map<String, dynamic>? getTeacherDetail({required String teacherId}) {
    final box = Hive.box(teacherBoxName);
    final cacheKey = 'detail_$teacherId';
    final data = box.get(cacheKey);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> saveTeacherCredentials({
    required String teacherId,
    required String? username,
    required String? password,
    required bool hasUserAccount,
  }) async {
    final box = Hive.box(teacherBoxName);
    final cacheKey = 'credentials_$teacherId';

    final credentialsData = {
      'username': username,
      'password': password,
      'hasUserAccount': hasUserAccount,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    await box.put(cacheKey, credentialsData);
  }

  static Map<String, dynamic>? getTeacherCredentials(
      {required String teacherId}) {
    final box = Hive.box(teacherBoxName);
    final cacheKey = 'credentials_$teacherId';
    final data = box.get(cacheKey);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> clearTeacherDetail({required String teacherId}) async {
    final box = Hive.box(teacherBoxName);
    await box.delete('detail_$teacherId');
    await box.delete('credentials_$teacherId');
  }

  // Check if cached data is fresh (less than 5 minutes old)
  static bool isCacheFresh(int? lastUpdated, {int maxAgeMinutes = 5}) {
    if (lastUpdated == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ageMinutes = (now - lastUpdated) / (1000 * 60);
    return ageMinutes < maxAgeMinutes;
  }
}
