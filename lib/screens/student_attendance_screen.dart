import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'student_attendance_history_screen.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  String? selectedClassId;
  DateTime selectedDate = DateTime.now();
  String selectedSession = 'Morning';
  List<ParseObject> classes = [];
  List<Map<String, dynamic>> students = [];
  bool loadingClasses = true;
  bool loadingStudents = false;

  final statusColors = {
    'present': Colors.green,
    'absent': Colors.red,
    'late': Colors.orange,
    'excuse': Colors.blue,
  };

  @override
  void initState() {
    super.initState();
    _loadClassesInstant();
  }

  Future<void> _loadClassesInstant() async {
    final box = await Hive.openBox('attendanceClassList');
    final cached = box.get('classList');
    if (cached != null) {
      setState(() {
        classes = (cached as List).map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final obj = ParseObject('Class')..objectId = map['objectId'];
          obj.set('classname', map['classname']);
          return obj;
        }).toList();
        loadingClasses = false;
      });
    }
    _fetchClasses(forceRefresh: false); // Fetch fresh data in background
  }

  Future<void> _fetchClasses({bool forceRefresh = false}) async {
    setState(() {
      loadingClasses = true;
    });
    final box = await Hive.openBox('attendanceClassList');
    if (!forceRefresh) {
      final cached = box.get('classList');
      if (cached != null) {
        setState(() {
          classes = (cached as List).map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final obj = ParseObject('Class')..objectId = map['objectId'];
            obj.set('classname', map['classname']);
            return obj;
          }).toList();
          loadingClasses = false;
        });
        // Continue to fetch fresh data in background
      }
    }
    final query = QueryBuilder<ParseObject>(ParseObject('Class'));
    final response = await query.query();
    if (response.success && response.results != null) {
      setState(() {
        classes = response.results!.cast<ParseObject>();
        loadingClasses = false;
      });
      await box.put(
        'classList',
        response.results!
            .map((cls) => {
                  'objectId': cls.objectId,
                  'classname': cls.get<String>('classname') ?? '',
                })
            .toList(),
      );
    } else {
      setState(() {
        loadingClasses = false;
      });
    }
  }

  Future<void> _loadStudentsInstant(String classId) async {
    final box = await Hive.openBox('attendanceStudents');
    final cached = box.get(classId);
    if (cached != null) {
      setState(() {
        students = (cached as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        loadingStudents = false;
      });
    }
    _fetchStudents(classId,
        forceRefresh: false); // Fetch fresh data in background
  }

  Future<void> _fetchStudents(String classId,
      {bool forceRefresh = false}) async {
    setState(() {
      loadingStudents = true;
    });
    final box = await Hive.openBox('attendanceStudents');
    if (!forceRefresh) {
      final cached = box.get(classId);
      if (cached != null) {
        setState(() {
          students = (cached as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          loadingStudents = false;
        });
        // Continue to fetch fresh data in background
      }
    }
    final classPointer = ParseObject('Class')..objectId = classId;
    final enrolQuery = QueryBuilder<ParseObject>(ParseObject('Enrolment'))
      ..whereEqualTo('class', classPointer);
    final enrolResponse = await enrolQuery.query();
    if (enrolResponse.success && enrolResponse.results != null) {
      final studentList = enrolResponse.results!
          .map((e) => {
                'id': e.get<ParseObject>('student')?.objectId ?? '',
                'name': e.get<String>('studentName') ?? '',
                'status': 'present',
              })
          .toList();
      setState(() {
        students = studentList;
        loadingStudents = false;
      });
      await box.put(classId, studentList);
    } else {
      setState(() {
        students = [];
        loadingStudents = false;
      });
    }
  }

  Future<void> _submitAttendance() async {
    final classObj = classes.firstWhere((c) => c.objectId == selectedClassId,
        orElse: () => ParseObject('Class'));
    final className = classObj.get<String>('classname') ?? '';
    int duplicateCount = 0;
    // Normalize date to midnight local, then convert to UTC
    final normalizedDateLocal =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final normalizedDateUtc = DateTime.utc(
      normalizedDateLocal.year,
      normalizedDateLocal.month,
      normalizedDateLocal.day,
    );
    for (var student in students) {
      if (student['status'] != 'absent') continue; // Only store absents
      // Check for existing attendance for this student/class/date/session
      final query = QueryBuilder<ParseObject>(ParseObject('Attendance'))
        ..whereEqualTo(
            'student', ParseObject('Student')..objectId = student['id'])
        ..whereEqualTo(
            'class', ParseObject('Class')..objectId = selectedClassId)
        ..whereEqualTo('date', normalizedDateUtc)
        ..whereEqualTo('session', selectedSession);
      final response = await query.query();
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        duplicateCount++;
        continue; // Skip duplicate
      }
      final attendance = ParseObject('Attendance')
        ..set('student', ParseObject('Student')..objectId = student['id'])
        ..set('class', ParseObject('Class')..objectId = selectedClassId)
        ..set('studentName', student['name'])
        ..set('classname', className)
        ..set(
            'classId',
            ParseObject('Class')
              ..objectId = selectedClassId) // <-- save as Pointer
        ..set('date', normalizedDateUtc)
        ..set('session', selectedSession)
        ..set('status', student['status']);
      await attendance.save();
    }
    String message = duplicateCount == 0
        ? 'Attendance submitted!'
        : 'Attendance submitted! ($duplicateCount duplicate(s) skipped)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Student Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            tooltip: 'Refresh Student List',
            onPressed: selectedClassId == null
                ? null
                : () async {
                    final box = await Hive.openBox('attendanceStudents');
                    await box.delete(selectedClassId);
                    _fetchStudents(selectedClassId!, forceRefresh: true);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              print('View History pressed, classId: ' +
                  (selectedClassId ?? 'null'));
              try {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentAttendanceHistoryScreen(
                      classId: selectedClassId,
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Navigation error: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Class:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            loadingClasses
                ? const Center(child: CircularProgressIndicator())
                : DropdownButton<String>(
                    value: selectedClassId,
                    hint: const Text('Choose class'),
                    items: classes
                        .map((c) => DropdownMenuItem(
                              value: c.objectId,
                              child: Text(c.get<String>('classname') ?? ''),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedClassId = val;
                      });
                      if (val != null) _loadStudentsInstant(val);
                    },
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Date:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text(
                  '${selectedDate.toLocal()}'.split(' ')[0],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Session:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedSession,
                  items: ['Morning', 'Afternoon']
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedSession = val!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Students:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            loadingStudents
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: students.isEmpty
                        ? const Center(child: Text('No students found.'))
                        : ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, i) {
                              final student = students[i];
                              return Card(
                                child: ListTile(
                                  title: Text(student['name']),
                                  trailing: DropdownButton<String>(
                                    value: student['status'],
                                    items: [
                                      'present',
                                      'absent',
                                      'late',
                                      'excuse'
                                    ]
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.circle,
                                                      color: statusColors[s],
                                                      size: 16),
                                                  const SizedBox(width: 6),
                                                  Text(s[0].toUpperCase() +
                                                      s.substring(1)),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      setState(
                                          () => students[i]['status'] = val);
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: students.isEmpty || selectedClassId == null
                    ? null
                    : _submitAttendance,
                child: const Text('Submit Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceHistoryView extends StatelessWidget {
  final String? classId;

  const AttendanceHistoryView({super.key, this.classId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(
            child: classId == null
                ? const Center(child: Text('No class selected.'))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future:
                        AttendanceHistoryView.fetchAttendanceHistory(classId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text('No attendance records.'));
                      } else {
                        final records = snapshot.data!;
                        return ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return Card(
                              child: ListTile(
                                title: Text(record['studentName']),
                                subtitle: Text(
                                    'Status: ${record['status']}, Date: ${record['date']}, Session: ${record['session']}'),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Static method so it can be reused elsewhere if needed
  static Future<List<Map<String, dynamic>>> fetchAttendanceHistory(
      String classId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Attendance'))
      ..whereEqualTo('class', ParseObject('Class')..objectId = classId)
      ..whereEqualTo('status', 'absent');
    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.map((e) {
        // Fetch classname for display
        String? classname = e.get<String>('classname');
        // If not present, try to get from class pointer
        if (classname == null || classname.isEmpty) {
          final classObj = e.get<ParseObject>('class');
          classname = classObj?.get<String>('classname') ?? '';
        }
        return {
          'studentName': e.get<String>('studentName') ?? '',
          'status': e.get<String>('status') ?? '',
          'date': e.get<DateTime>('date')?.toLocal().toString() ?? '',
          'session': e.get<String>('session') ?? '',
          'classname': classname ?? '',
        };
      }).toList();
    } else {
      return [];
    }
  }
}
