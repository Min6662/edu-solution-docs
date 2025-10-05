import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';

class ClassEnrolmentScreen extends StatefulWidget {
  final ParseObject classObj;
  const ClassEnrolmentScreen({super.key, required this.classObj});

  @override
  State<ClassEnrolmentScreen> createState() => _ClassEnrolmentScreenState();
}

class _ClassEnrolmentScreenState extends State<ClassEnrolmentScreen> {
  bool loading = true;
  String error = '';
  List<_EnrolledStudent> enrolledStudents = [];

  @override
  void initState() {
    super.initState();
    _loadEnrolmentsInstant();
  }

  void _loadEnrolmentsInstant() async {
    final box = await Hive.openBox('classEnrolments');
    final cached = box.get(widget.classObj.objectId);
    if (cached != null) {
      setState(() {
        enrolledStudents = List<Map<String, dynamic>>.from(cached)
            .map((e) => _EnrolledStudent(
                  name: e['name'],
                  studentId: e['studentId'],
                  enrolmentId: e['enrolmentId'],
                ))
            .toList();
        loading = false;
      });
    }
    _fetchEnrolments(); // Fetch fresh data in background
  }

  Future<void> _fetchEnrolments() async {
    setState(() {
      loading = true;
      error = '';
    });
    final enrolQuery = QueryBuilder<ParseObject>(ParseObject('Enrolment'))
      ..whereEqualTo(
          'class', ParseObject('Class')..objectId = widget.classObj.objectId);
    final enrolResponse = await enrolQuery.query();
    if (enrolResponse.success && enrolResponse.results != null) {
      List<_EnrolledStudent> students = [];
      List<String> studentIds = [];
      Map<String, String> enrolmentIdByStudentId = {};
      for (final enrol in enrolResponse.results!) {
        final studentPointer = enrol.get<ParseObject>('student');
        String? studentId = studentPointer?.objectId;
        String? enrolmentId = enrol.objectId;
        if (studentId != null && enrolmentId != null) {
          studentIds.add(studentId);
          enrolmentIdByStudentId[studentId] = enrolmentId;
        }
      }
      if (studentIds.isNotEmpty) {
        final studentQuery = QueryBuilder<ParseObject>(ParseObject('Student'))
          ..whereContainedIn('objectId', studentIds);
        final studentResponse = await studentQuery.query();
        if (studentResponse.success && studentResponse.results != null) {
          for (final studentObj in studentResponse.results!) {
            final name = studentObj.get<String>('name') ?? '';
            final studentId = studentObj.objectId;
            final enrolmentId = enrolmentIdByStudentId[studentId];
            if (name.isNotEmpty && studentId != null && enrolmentId != null) {
              students.add(_EnrolledStudent(
                name: name,
                studentId: studentId,
                enrolmentId: enrolmentId,
              ));
            }
          }
        }
      }
      setState(() {
        enrolledStudents = students;
        loading = false;
      });
      // Save to cache
      final box = await Hive.openBox('classEnrolments');
      await box.put(
          widget.classObj.objectId,
          students
              .map((e) => {
                    'name': e.name,
                    'studentId': e.studentId,
                    'enrolmentId': e.enrolmentId,
                  })
              .toList());
    } else {
      setState(() {
        error = 'Failed to fetch enrolments.';
        loading = false;
      });
    }
  }

  Future<void> _removeStudent(String enrolmentId) async {
    setState(() {
      loading = true;
    });
    final enrolment = ParseObject('Enrolment')..objectId = enrolmentId;
    final response = await enrolment.delete();
    if (response.success) {
      await _fetchEnrolments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student removed from class.')),
        );
      }
    } else {
      setState(() {
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove student: ' +
                  (response.error?.message ?? 'Unknown error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ClassEnrolmentScreen build called'); // Debug print
    final className = widget.classObj.get<String>('classname') ?? 'Class';
    return Scaffold(
      appBar: AppBar(
        title: Text(className),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            color: Colors.yellow, // Highlight background for debug
            child: IconButton(
              icon: const Icon(Icons.refresh,
                  color: Colors.red, size: 32), // Make icon larger and red
              tooltip: 'Refresh Enrolment List',
              onPressed: () async {
                final box = await Hive.openBox('classEnrolments');
                await box.delete(widget.classObj.objectId);
                _fetchEnrolments();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 40,
            color: Colors.purple,
            child: const Center(
              child: Text('DEBUG: ClassEnrolmentScreen',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                    ? Center(
                        child: Text(error,
                            style: const TextStyle(color: Colors.red)))
                    : enrolledStudents.isEmpty
                        ? const Center(child: Text('No students enrolled.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: enrolledStudents.length,
                            itemBuilder: (context, i) {
                              final student = enrolledStudents[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.person,
                                      color: Colors.blue),
                                  title: Text(student.name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    tooltip: 'Remove from class',
                                    onPressed: loading
                                        ? null
                                        : () =>
                                            _removeStudent(student.enrolmentId),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _EnrolledStudent {
  final String name;
  final String studentId;
  final String enrolmentId;
  _EnrolledStudent(
      {required this.name, required this.studentId, required this.enrolmentId});
}
