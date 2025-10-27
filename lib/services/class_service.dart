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
                'grade': stu.get<String>('grade'),
                'address': stu.get<String>('address'),
                'phoneNumber': stu.get<String>('phoneNumber'),
                'studyStatus': stu.get<String>('studyStatus'),
                'motherName': stu.get<String>('motherName'),
                'fatherName': stu.get<String>('fatherName'),
                'placeOfBirth': stu.get<String>('placeOfBirth'),
                'dateOfBirth': stu.get<String>('dateOfBirth'),
                'photo': stu.get<String>('photo'),
                'parentBusiness': stu.get<String>('parentBusiness'),
                'studyFeePeriod': stu.get<String>('studyFeePeriod'),
                'paidDate': stu.get<String>('paidDate'),
                'renewalDate': stu.get<String>('renewalDate'),
                'morningClassId': stu.get<String>('morningClassId'),
                'eveningClassId': stu.get<String>('eveningClassId'),
                'morningClassName': stu.get<String>('morningClassName'),
                'eveningClassName': stu.get<String>('eveningClassName'),
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
                'grade': stu.get<String>('grade'),
                'address': stu.get<String>('address'),
                'phoneNumber': stu.get<String>('phoneNumber'),
                'studyStatus': stu.get<String>('studyStatus'),
                'motherName': stu.get<String>('motherName'),
                'fatherName': stu.get<String>('fatherName'),
                'placeOfBirth': stu.get<String>('placeOfBirth'),
                'dateOfBirth': stu.get<String>('dateOfBirth'),
                'photo': stu.get<String>('photo'),
                'parentBusiness': stu.get<String>('parentBusiness'),
                'studyFeePeriod': stu.get<String>('studyFeePeriod'),
                'paidDate': stu.get<String>('paidDate'),
                'renewalDate': stu.get<String>('renewalDate'),
                'morningClassId': stu.get<String>('morningClassId'),
                'eveningClassId': stu.get<String>('eveningClassId'),
                'morningClassName': stu.get<String>('morningClassName'),
                'eveningClassName': stu.get<String>('eveningClassName'),
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
    print('DEBUG: ClassService.getTeacherList() called');

    final cached = CacheService.getTeacherList();
    if (cached != null && cached.isNotEmpty) {
      print(
          'DEBUG: Found cached data with ${cached.length} teachers, validating...');

      // Validate cached data - check if first teacher has essential fields
      final firstTeacher = cached.first;
      final hasValidData = firstTeacher['fullName'] != null &&
          firstTeacher['objectId'] != null &&
          firstTeacher['fullName'].toString().isNotEmpty;

      if (hasValidData) {
        print(
            'DEBUG: Cache validation passed, returning ${cached.length} teachers from cache');
        return cached;
      } else {
        print(
            'DEBUG: Cache validation failed - corrupted data detected, clearing cache and fetching fresh data');
        await CacheService.clearTeacherList();
      }
    }

    print('DEBUG: No cache found, fetching fresh teacher data from Parse...');
    final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
    final response = await query.query();

    if (response.success && response.results != null) {
      print(
          'DEBUG: Successfully fetched ${response.results!.length} teachers from Parse');

      final teacherList = response.results!.map((tch) {
        final teacherData = {
          'objectId': tch.objectId, // Fix: use objectId property directly
          'fullName': tch.get<String>('fullName') ?? '',
          'subject': tch.get<String>('subject') ?? '',
          'gender': tch.get<String>('gender') ?? '',
          'photo': tch.get<String>('photo') ?? '',
          'photoUrl': tch.get<String>('photoUrl') ?? '', // Add missing photoUrl
          'yearsOfExperience': tch.get<int>('yearsOfExperience') ?? 0,
          'rating': (tch.get<num>('rating') ?? 0.0).toDouble(),
          'ratingCount': tch.get<int>('ratingCount') ?? 0,
          'hourlyRate': (tch.get<num>('hourlyRate') ?? 0.0).toDouble(),
          'Address': tch.get<String>('Address') ?? '', // Add missing fields
          'address': tch.get<String>('address') ?? '',
          'createdAt': tch.createdAt?.toIso8601String(),
          'updatedAt': tch.updatedAt?.toIso8601String(),
        };

        print(
            'DEBUG: Processed teacher - Name: ${teacherData['fullName']}, Subject: ${teacherData['subject']}, Experience: ${teacherData['yearsOfExperience']} years');
        return teacherData;
      }).toList();

      await CacheService.saveTeacherList(teacherList);
      print('DEBUG: Saved ${teacherList.length} teachers to cache');
      return teacherList;
    }

    print('DEBUG: Failed to fetch teachers from Parse');
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
