import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class StudentService {
  Future<List<ParseObject>> fetchStudents(
      {String? searchQuery, String? schoolId}) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Student'));

    // TODO: Uncomment when multi-tenant system is fully implemented
    // if (schoolId != null) {
    //   query.whereEqualTo('school', ParseObject('School')..objectId = schoolId);
    // }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.whereContains('name', searchQuery);
    }
    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.cast<ParseObject>();
    }
    return [];
  }

  Future<ParseResponse> createStudent({
    required String name,
    required String grade,
    required String address,
    required String phoneNumber,
    required String studyStatus,
    DateTime? dateOfBirth,
    String? photoUrl,
    String gender = 'Male',
    String? schoolId,
  }) async {
    final student = ParseObject('Student')
      ..set('name', name)
      ..set('grade', grade)
      ..set('address', address)
      ..set('phoneNumber', phoneNumber)
      ..set('studyStatus', studyStatus)
      ..set('gender', gender);

    if (dateOfBirth != null) {
      student.set('dateOfBirth', dateOfBirth);
    }
    if (photoUrl != null) {
      student.set('photo', photoUrl);
    }
    if (schoolId != null) {
      student.set('school', ParseObject('School')..objectId = schoolId);
    }

    return await student.save();
  }

  Future<ParseObject?> getStudentById(String objectId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Student'))
      ..whereEqualTo('objectId', objectId);
    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      return response.results!.first as ParseObject;
    }
    return null;
  }
}
