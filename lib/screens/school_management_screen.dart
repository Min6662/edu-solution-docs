import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'school_registration_screen.dart';
import 'teacher_registration_screen.dart';
import 'admin_teacher_management_screen.dart';
import '../main.dart'; // Import to access RoleBasedHome

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  List<ParseObject> schools = [];
  bool loading = true;
  String error = '';
  String? userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchSchools();
  }

  Future<void> _fetchUserRole() async {
    final user = await ParseUser.currentUser();
    setState(() {
      userRole = user?.get<String>('role')?.toLowerCase();
    });
  }

  bool get isAdmin => userRole == 'admin' || userRole == 'owner';
  bool get isTeacher => userRole == 'teacher';

  Future<void> _fetchSchools() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('School'));
      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          schools = response.results as List<ParseObject>;
          loading = false;
        });
      } else {
        setState(() {
          error =
              'Failed to fetch schools: ${response.error?.message ?? 'Unknown error'}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final user = await ParseUser.currentUser();
      if (user != null) {
        await user.logout();
      }
      if (mounted) {
        // Navigate to the main app entry point, clearing all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleBasedHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String roleText = isAdmin
        ? 'Admin'
        : isTeacher
            ? 'Teacher'
            : 'User';

    return Scaffold(
      appBar: AppBar(
        title: Text('School Management ($roleText)'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView.builder(
                  itemCount: schools.length,
                  itemBuilder: (context, index) {
                    final school = schools[index];
                    return ListTile(
                      title: Text(school.get<String>('name') ?? 'No Name'),
                      subtitle:
                          Text(school.get<String>('address') ?? 'No Address'),
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Admin-only: Create Teacher Account
          if (isAdmin) ...[
            FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminTeacherManagementScreen(),
                  ),
                );
                if (result == true) {
                  _fetchSchools(); // Refresh the list if needed
                }
              },
              backgroundColor: Colors.green,
              child: const Icon(Icons.person_add),
              tooltip: 'Create Teacher Account',
            ),
            const SizedBox(height: 16),
          ],

          // Available to both Admin and Teacher: Manage Teachers
          FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeacherRegistrationScreen(),
                ),
              );
              if (result == true) {
                _fetchSchools(); // Refresh the list if needed
              }
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.person),
            tooltip: isTeacher ? 'View Teachers' : 'Manage Teachers',
          ),

          // Admin-only: Register School
          if (isAdmin) ...[
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SchoolRegistrationScreen(),
                  ),
                );
                if (result == true) {
                  _fetchSchools(); // Refresh the list after registration
                }
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.add),
              tooltip: 'Register School',
            ),
          ],
        ],
      ),
    );
  }
}
