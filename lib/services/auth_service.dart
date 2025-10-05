import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class AuthService {
  Future<ParseResponse> login(String email, String password) async {
    final user = ParseUser(email, password, email);
    return await user.login();
  }

  Future<ParseResponse> signup(
      String username, String email, String password, String role,
      {String? schoolId}) async {
    final user = ParseUser.createUser(username, password, email);
    user.set('role', role);
    if (schoolId != null) {
      user.set('school', ParseObject('School')..objectId = schoolId);
    }
    return await user.signUp();
  }

  Future<ParseUser?> getCurrentUser() async {
    return await ParseUser.currentUser();
  }

  Future<void> logout() async {
    final user = await ParseUser.currentUser();
    if (user != null) {
      await user.logout();
    }
  }
}
