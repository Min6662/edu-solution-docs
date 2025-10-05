import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/school.dart';

class SchoolService {
  /// Create a new school
  static Future<ParseResponse> createSchool({
    required String schoolName,
    required String schoolCode,
    String? logo,
    String? address,
    String? phone,
    String? email,
    String? website,
    String subscriptionPlan = 'basic',
    int maxUsers = 50,
    String? ownerId,
  }) async {
    final school = ParseObject('School')
      ..set('schoolName', schoolName)
      ..set('schoolCode', schoolCode)
      ..set('subscriptionPlan', subscriptionPlan)
      ..set('maxUsers', maxUsers)
      ..set('currentUserCount', 0)
      ..set('isActive', true);

    if (logo != null) school.set('logo', logo);
    if (address != null) school.set('address', address);
    if (phone != null) school.set('phone', phone);
    if (email != null) school.set('email', email);
    if (website != null) school.set('website', website);
    if (ownerId != null) {
      school.set('owner', ParseObject('_User')..objectId = ownerId);
    }

    return await school.save();
  }

  /// Get school by ID
  static Future<School?> getSchoolById(String schoolId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('School'))
      ..whereEqualTo('objectId', schoolId);

    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final schoolData = response.results!.first.toJson();
      return School.fromParseObject(schoolData);
    }
    return null;
  }

  /// Get school by code
  static Future<School?> getSchoolByCode(String schoolCode) async {
    final query = QueryBuilder<ParseObject>(ParseObject('School'))
      ..whereEqualTo('schoolCode', schoolCode);

    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final schoolData = response.results!.first.toJson();
      return School.fromParseObject(schoolData);
    }
    return null;
  }

  /// Update school information
  static Future<ParseResponse> updateSchool({
    required String schoolId,
    String? schoolName,
    String? logo,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? subscriptionPlan,
    int? maxUsers,
    bool? isActive,
  }) async {
    final school = ParseObject('School')..objectId = schoolId;

    if (schoolName != null) school.set('schoolName', schoolName);
    if (logo != null) school.set('logo', logo);
    if (address != null) school.set('address', address);
    if (phone != null) school.set('phone', phone);
    if (email != null) school.set('email', email);
    if (website != null) school.set('website', website);
    if (subscriptionPlan != null)
      school.set('subscriptionPlan', subscriptionPlan);
    if (maxUsers != null) school.set('maxUsers', maxUsers);
    if (isActive != null) school.set('isActive', isActive);

    return await school.save();
  }

  /// Get all schools (for admin purposes)
  static Future<List<School>> getAllSchools() async {
    final query = QueryBuilder<ParseObject>(ParseObject('School'));
    final response = await query.query();

    if (response.success && response.results != null) {
      return response.results!
          .map((school) => School.fromParseObject(school.toJson()))
          .toList();
    }
    return [];
  }

  /// Increment user count for a school
  static Future<ParseResponse> incrementUserCount(String schoolId) async {
    final school = ParseObject('School')..objectId = schoolId;
    // Get current count and increment it
    final currentSchool = await getSchoolById(schoolId);
    if (currentSchool != null) {
      school.set('currentUserCount', currentSchool.currentUserCount + 1);
    }
    return await school.save();
  }

  /// Decrement user count for a school
  static Future<ParseResponse> decrementUserCount(String schoolId) async {
    final school = ParseObject('School')..objectId = schoolId;
    // Get current count and decrement it
    final currentSchool = await getSchoolById(schoolId);
    if (currentSchool != null) {
      final newCount = (currentSchool.currentUserCount - 1)
          .clamp(0, double.infinity)
          .toInt();
      school.set('currentUserCount', newCount);
    }
    return await school.save();
  }

  /// Check if school can add more users
  static Future<bool> canAddUser(String schoolId) async {
    final school = await getSchoolById(schoolId);
    if (school == null) return false;
    return school.currentUserCount < school.maxUsers;
  }

  /// Check if school code is unique
  static Future<bool> isSchoolCodeUnique(String schoolCode) async {
    final query = QueryBuilder<ParseObject>(ParseObject('School'))
      ..whereEqualTo('schoolCode', schoolCode);

    final response = await query.count();
    return response.success && response.count == 0;
  }
}
