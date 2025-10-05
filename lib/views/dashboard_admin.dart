import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../screens/settings_screen.dart';

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  int studentCount = 0;
  int teacherCount = 0;
  int classCount = 0;
  int subjectCount = 0;
  bool loading = true;
  String error = '';
  String? userRole;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchUserRole();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final studentQuery = QueryBuilder<ParseObject>(ParseObject('Student'));
      final teacherQuery = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final classQuery = QueryBuilder<ParseObject>(ParseObject('Class'));
      final subjectQuery = QueryBuilder<ParseObject>(ParseObject('Subject'));
      final studentResp = await studentQuery.count();
      final teacherResp = await teacherQuery.count();
      final classResp = await classQuery.count();
      final subjectResp = await subjectQuery.count();
      setState(() {
        studentCount = studentResp.success ? studentResp.count : 0;
        teacherCount = teacherResp.success ? teacherResp.count : 0;
        classCount = classResp.success ? classResp.count : 0;
        subjectCount = subjectResp.success ? subjectResp.count : 0;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to fetch dashboard data.';
        loading = false;
      });
    }
  }

  Future<void> _fetchUserRole() async {
    final user = await ParseUser.currentUser();
    setState(() {
      userRole = user?.get<String>('role');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: userRole == null
          ? const Center(child: CircularProgressIndicator())
          : loading
              ? const Center(child: CircularProgressIndicator())
              : error.isNotEmpty
                  ? Center(
                      child: Text(error,
                          style: const TextStyle(color: Colors.red)))
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue[100],
                                  child: Icon(
                                    Icons.school,
                                    color: Colors.blue[900],
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Columbia University',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio:
                                  2.5, // Increased from 2.2 to give more height
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              children: [
                                _dashboardCard('Manage Students', Icons.people,
                                    Colors.blue, studentCount),
                                if (userRole != 'teacher')
                                  _dashboardCard('Manage Teachers',
                                      Icons.person, Colors.pink, teacherCount),
                                _dashboardCard('Manage Classes', Icons.class_,
                                    Colors.orange, classCount),
                                _dashboardCard('Manage Subjects', Icons.book,
                                    Colors.purple, subjectCount),
                              ],
                            ),
                            const SizedBox(height: 32),
                            const Text('Quick Actions',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _actionButton('Attendance', Icons.check_circle,
                                    Colors.green),
                                _actionButton(
                                    'Exams', Icons.assignment, Colors.amber),
                                _actionButton(
                                    'Grades', Icons.grade, Colors.red),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _dashboardCard(String title, IconData icon, Color color, int count) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        onTap: () {
          // Show a snackbar for now to indicate the tap is working
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title clicked!'),
              duration: const Duration(seconds: 1),
            ),
          );
          // TODO: Navigate to respective management screens
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Reduced padding
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color, size: 20), // Smaller icon
              ),
              const SizedBox(width: 8), // Reduced spacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13, // Smaller font
                      ),
                      maxLines: 2, // Allow text wrapping
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Count: $count',
                      style: const TextStyle(
                        fontSize: 11, // Smaller font
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // Show a snackbar for now to indicate the tap is working
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label clicked!'),
            duration: const Duration(seconds: 1),
          ),
        );
        // TODO: Navigate to respective action screens
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
