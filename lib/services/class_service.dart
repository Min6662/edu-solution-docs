import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class ClassService {
  Future<List<ParseObject>> fetchClasses({String? schoolId}) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Class'));

    // TODO: Uncomment when multi-tenant system is fully implemented
    // if (schoolId != null) {
    //   query.whereEqualTo('school', ParseObject('School')..objectId = schoolId);
    // }

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.cast<ParseObject>();
    }
    return [];
  }

  Future<ParseResponse> createClass(String className,
      {String? schoolId}) async {
    final newClass = ParseObject('Class')..set('classname', className);
    if (schoolId != null) {
      newClass.set('school', ParseObject('School')..objectId = schoolId);
    }
    return await newClass.save();
  }

  Future<ParseObject?> getClassById(String objectId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Class'))
      ..whereEqualTo('objectId', objectId);
    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return response.results!.first as ParseObject;
    }
    return null;
  }

  // Fetch class list, using cache if available
  static Future<List<Map<String, dynamic>>> getClassList(
      {String? schoolId}) async {
    // Try to load from cache first
    final cached = CacheService.getClassList();
    if (cached != null && cached.isNotEmpty) {
      // TODO: Filter cached classes by school when multi-tenant is implemented
      return cached;
    }
    // If cache is empty, fetch from Parse
    final query = QueryBuilder<ParseObject>(ParseObject('Class'));

    // TODO: Uncomment when multi-tenant system is fully implemented
    // if (schoolId != null) {
    //   query.whereEqualTo('school', ParseObject('School')..objectId = schoolId);
    // }

    final response = await query.query();
    if (response.success && response.results != null) {
      final classList = response.results!
          .map((cls) => {
                'objectId': cls.get<String>('objectId'),
                'classname': cls.get<String>('classname'),
                // add other fields as needed
              })
          .toList();
      await CacheService.saveClassList(classList);
      return classList;
    }
    // If fetch fails, return empty list
    return [];
  }

  // Fetch student list, using cache if available, and cache images in background
  static Future<List<Map<String, dynamic>>> getStudentList(
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService.getStudentList();
      if (cached != null && cached.isNotEmpty) {
        // Start background update from Parse
        _updateStudentCacheInBackground();
        return cached;
      }
    }
    // Fetch from Parse
    final query = QueryBuilder<ParseObject>(ParseObject('Student'));
    final response = await query.query();
    if (response.success && response.results != null) {
      final studentList = response.results!
          .map((stu) => {
                'objectId': stu.get<String>('objectId'),
                'name': stu.get<String>('name'),
                'photo': stu.get<String>('photo'),
                'yearsOfExperience': stu.get<int>('yearsOfExperience') ?? 0,
                'rating': stu.get<double>('rating') ?? 4.5,
                'ratingCount': stu.get<int>('ratingCount') ?? 100,
                'hourlyRate': stu.get<String>('hourlyRate') ?? '20/hr',
                // add other fields as needed
              })
          .toList();
      await CacheService.saveStudentList(studentList);
      // Start background image caching
      _cacheStudentImages(studentList);
      return studentList;
    }
    return [];
  }

  // Background update for cache
  static Future<void> _updateStudentCacheInBackground() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Student'));
    final response = await query.query();
    if (response.success && response.results != null) {
      final studentList = response.results!
          .map((stu) => {
                'objectId': stu.get<String>('objectId'),
                'name': stu.get<String>('name'),
                'photo': stu.get<String>('photo'),
                'yearsOfExperience': stu.get<int>('yearsOfExperience') ?? 0,
                'rating': stu.get<double>('rating') ?? 4.5,
                'ratingCount': stu.get<int>('ratingCount') ?? 100,
                'hourlyRate': stu.get<String>('hourlyRate') ?? '20/hr',
              })
          .toList();
      await CacheService.saveStudentList(studentList);
      _cacheStudentImages(studentList);
    }
  }

  // Cache images in background
  static Future<void> _cacheStudentImages(
      List<Map<String, dynamic>> students) async {
    final box = await Hive.openBox('studentImages');
    for (final student in students) {
      final id = student['objectId'] ?? '';
      final url = student['photo'] ?? '';
      if (id.isNotEmpty &&
          url.isNotEmpty &&
          url.startsWith('http') &&
          box.get(id) == null) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            await box.put(id, response.bodyBytes);
          }
        } catch (_) {}
      }
    }
  }

  // Fetch teacher list, using cache if available
  static Future<List<Map<String, dynamic>>> getTeacherList() async {
    final cached = CacheService.getTeacherList();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
    final response = await query.query();
    if (response.success && response.results != null) {
      final teacherList = response.results!
          .map((tch) => {
                'objectId': tch.get<String>('objectId'),
                'fullName': tch.get<String>('fullName'),
                'subject': tch.get<String>('subject'),
                'gender': tch.get<String>('gender'),
                'photo': tch.get<String>('photo'),
                'yearsOfExperience': tch.get<int>('yearsOfExperience') ?? 0,
                'rating': (tch.get<num>('rating') ?? 0.0).toDouble(),
                'ratingCount': tch.get<int>('ratingCount') ?? 0,
                'hourlyRate': (tch.get<num>('hourlyRate') ?? 0.0).toDouble(),
              })
          .toList();
      await CacheService.saveTeacherList(teacherList);
      return teacherList;
    }
    return [];
  }

  // Fetch attendance history, using cache if available
  static Future<List<Map<String, dynamic>>> getAttendanceHistory() async {
    final cached = CacheService.getAttendanceHistory();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final query = QueryBuilder<ParseObject>(ParseObject('Attendance'));
    final response = await query.query();
    if (response.success && response.results != null) {
      final attendanceList = response.results!
          .map((att) => {
                'objectId': att.get<String>('objectId'),
                'studentId': att.get<String>('studentId'),
                'teacherID': att.get<String>('teacherID'),
                'date': att.get<DateTime>('date')?.toIso8601String(),
                // add other fields as needed
              })
          .toList();
      await CacheService.saveAttendanceHistory(attendanceList);
      return attendanceList;
    }
    return [];
  }

  // Fetch app settings, using cache if available
  static Future<Map<String, dynamic>?> getSettings() async {
    final cached = CacheService.getSettings();
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    // Example: fetch settings from Parse (replace with your actual settings logic)
    final query = QueryBuilder<ParseObject>(ParseObject('Settings'));
    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final settings = {
        'role': response.results!.first.get<String>('role'),
        // add other fields as needed
      };
      await CacheService.saveSettings(settings);
      return settings;
    }
    return null;
  }
}
