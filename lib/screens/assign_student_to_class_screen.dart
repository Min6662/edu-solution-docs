import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AssignStudentToClassScreen extends StatefulWidget {
  const AssignStudentToClassScreen({super.key});

  @override
  State<AssignStudentToClassScreen> createState() =>
      _AssignStudentToClassScreenState();
}

class _AssignStudentToClassScreenState
    extends State<AssignStudentToClassScreen> {
  List<ParseObject> classes = [];
  List<ParseObject> students = [];
  List<String> selectedStudentIds = [];
  String? selectedClassId;
  bool loadingClasses = true;
  bool loadingStudents = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadClassesInstant();
  }

  Future<void> _loadClassesInstant() async {
    final box = await Hive.openBox('assignClassList');
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
      error = '';
    });
    final box = await Hive.openBox('assignClassList');
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
        error = 'Failed to fetch classes.';
        loadingClasses = false;
      });
    }
  }

  Future<void> _loadStudentsInstant() async {
    if (selectedClassId == null) return;
    final box = await Hive.openBox('assignClassStudents');
    final cached = box.get(selectedClassId);
    if (cached != null) {
      setState(() {
        students = List<Map<String, dynamic>>.from(cached).map((e) {
          final obj = ParseObject('Student')..objectId = e['objectId'];
          obj.set('name', e['name']);
          return obj;
        }).toList();
        loadingStudents = false;
      });
    }
    _fetchStudents(forceRefresh: false); // Fetch fresh data in background
  }

  Future<void> _fetchStudents({bool forceRefresh = false}) async {
    if (selectedClassId == null) return;
    setState(() {
      loadingStudents = true;
      error = '';
    });
    final box = await Hive.openBox('assignClassStudents');
    if (!forceRefresh) {
      final cached = box.get(selectedClassId);
      if (cached != null) {
        setState(() {
          students = List<Map<String, dynamic>>.from(cached).map((e) {
            final obj = ParseObject('Student')..objectId = e['objectId'];
            obj.set('name', e['name']);
            return obj;
          }).toList();
          loadingStudents = false;
        });
        // Continue to fetch fresh data in background
      }
    }
    final query = QueryBuilder<ParseObject>(ParseObject('Student'));
    final response = await query.query();
    if (response.success && response.results != null) {
      setState(() {
        students = response.results!.cast<ParseObject>();
        loadingStudents = false;
      });
      await box.put(
        selectedClassId,
        response.results!
            .map((student) => {
                  'objectId': student.objectId,
                  'name': student.get<String>('name') ?? '',
                })
            .toList(),
      );
    } else {
      setState(() {
        error = 'Failed to fetch students.';
        loadingStudents = false;
      });
    }
  }

  Future<void> _assignStudentsToClass() async {
    if (selectedClassId == null || selectedStudentIds.isEmpty) return;
    setState(() {
      loadingStudents = true;
    });
    for (final studentId in selectedStudentIds) {
      final studentObj = students.firstWhere(
        (s) => s.objectId == studentId,
        orElse: () => ParseObject('Student'),
      );
      final studentName = studentObj.get<String>('name') ?? '';
      final enrolment = ParseObject('Enrolment')
        ..set('student', ParseObject('Student')..objectId = studentId)
        ..set('class', ParseObject('Class')..objectId = selectedClassId)
        ..set('studentName', studentName);
      await enrolment.save();
    }
    setState(() {
      loadingStudents = false;
      selectedStudentIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Students assigned to class!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Student to Class'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: selectedClassId != null
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  tooltip: 'Refresh Student List',
                  onPressed: () async {
                    final box = await Hive.openBox('assignClassStudents');
                    await box.delete(selectedClassId);
                    _fetchStudents(forceRefresh: true);
                  },
                ),
              ]
            : null,
      ),
      body: loadingClasses
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error, style: const TextStyle(color: Colors.red)))
              : selectedClassId == null
                  ? _buildClassSelection()
                  : _buildStudentSelection(),
    );
  }

  Widget _buildClassSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a Class',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: classes.map((cls) {
                final className = cls.get<String>('classname') ?? '';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedClassId = cls.objectId;
                    });
                    _loadStudentsInstant();
                  },
                  child: Card(
                    color: Colors.blue[50],
                    child: Center(
                      child: Text(className,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSelection() {
    return loadingStudents
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          selectedClassId = null;
                          selectedStudentIds.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Select Students',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, i) {
                      final student = students[i];
                      final name = student.get<String>('name') ?? '';
                      final id = student.objectId!;
                      return CheckboxListTile(
                        title: Text(name),
                        value: selectedStudentIds.contains(id),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedStudentIds.add(id);
                            } else {
                              selectedStudentIds.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: selectedStudentIds.isEmpty
                        ? null
                        : _assignStudentsToClass,
                    child: const Text('Assign to Class',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
  }
}
