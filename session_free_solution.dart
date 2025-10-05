import 'package:http/http.dart' as http;
import 'dart:convert';

// Session-Free Teacher Credential Creation
// This approach uses HTTP REST API calls directly to Parse
// No session conflicts, no automatic logins, admin stays logged in

Future<void> createTeacherCredentialsHTTP(
    String username, String password, String teacherId) async {
  const appId = 'EIbuzFd5v46RVy8iqf3vupM40l4PEcuS773XLUc5';
  const clientKey = 'o35E0eNihkhwtlOtwBoIASmO2htYsbAeL1BpnUdE';

  final headers = {
    'X-Parse-Application-Id': appId,
    'X-Parse-Client-Key': clientKey,
    'Content-Type': 'application/json',
  };

  // Step 1: Create User (doesn't affect current session)
  final userResponse = await http.post(
    Uri.parse('https://parseapi.back4app.com/users'),
    headers: headers,
    body: jsonEncode({
      'username': username,
      'password': password,
      'email': '$username@school.edu',
      'role': 'teacher',
    }),
  );

  if (userResponse.statusCode == 201) {
    final userData = jsonDecode(userResponse.body);
    final userId = userData['objectId'];

    // Step 2: Update Teacher record
    final teacherResponse = await http.put(
      Uri.parse('https://parseapi.back4app.com/classes/Teacher/$teacherId'),
      headers: headers,
      body: jsonEncode({
        'userId': {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': userId
        },
        'username': username,
        'plainPassword': password,
        'hasUserAccount': true,
      }),
    );

    if (teacherResponse.statusCode == 200) {
      print(
          '✅ SUCCESS: Teacher credentials created without session conflicts!');
      // Admin stays logged in, no session issues
    }
  }
}
