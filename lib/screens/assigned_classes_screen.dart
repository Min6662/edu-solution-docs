import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'teacher_schedule_screen.dart';

class AssignedClassesScreen extends StatefulWidget {
  const AssignedClassesScreen({super.key});

  @override
  State<AssignedClassesScreen> createState() => _AssignedClassesScreenState();
}

class _AssignedClassesScreenState extends State<AssignedClassesScreen> {
  bool loading = true;
  String error = '';
  List<Map<String, dynamic>> allClasses = [];
  String? selectedClassId;
  List<ParseObject> teacherList = [];
  bool loadingTeachers = true;

  // New: Store teacher-class assignments for display
  Map<String, List<Map<String, dynamic>>> teacherAssignments = {};

  // Store assignments fetched from ClassSubjectTeacher
  Map<String, List<Map<String, dynamic>>> teacherSchedules = {};

  // Helper: cache keys
  static const String _cacheTeachersKey = 'cache_teachers';
  static const String _cacheClassesKey = 'cache_classes';
  static const String _cacheAssignmentsKey = 'cache_teacher_assignments';
  static const String _cacheSchedulesKey = 'cache_teacher_schedules';

  // Helper: cache data
  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Cache teachers as JSON
    final teacherListJson = teacherList.map((t) => t.toJson()).toList();
    await prefs.setString(_cacheTeachersKey, jsonEncode(teacherListJson));
    // Cache classes as JSON
    await prefs.setString(_cacheClassesKey, jsonEncode(allClasses));
    // Cache assignments as JSON
    await prefs.setString(_cacheAssignmentsKey, jsonEncode(teacherAssignments));
    // Cache schedules as JSON
    await prefs.setString(_cacheSchedulesKey, jsonEncode(teacherSchedules));
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Teachers
    final teachersStr = prefs.getString(_cacheTeachersKey);
    if (teachersStr != null) {
      try {
        final List teachersJson = jsonDecode(teachersStr);
        teacherList = teachersJson
            .map((t) => ParseObject('Teacher')..fromJson(t))
            .toList()
            .cast<ParseObject>();
      } catch (_) {}
    }
    // Classes
    final classesStr = prefs.getString(_cacheClassesKey);
    if (classesStr != null) {
      try {
        final List classesJson = jsonDecode(classesStr);
        allClasses = classesJson.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    // Assignments
    final assignmentsStr = prefs.getString(_cacheAssignmentsKey);
    if (assignmentsStr != null) {
      try {
        final Map<String, dynamic> assignmentsJson = jsonDecode(assignmentsStr);
        teacherAssignments = assignmentsJson.map((k, v) => MapEntry(
            k, (v as List).map((e) => Map<String, dynamic>.from(e)).toList()));
      } catch (_) {}
    }
    // Schedules
    final schedulesStr = prefs.getString(_cacheSchedulesKey);
    if (schedulesStr != null) {
      try {
        final Map<String, dynamic> schedulesJson = jsonDecode(schedulesStr);
        teacherSchedules = schedulesJson.map((k, v) => MapEntry(
            k, (v as List).map((e) => Map<String, dynamic>.from(e)).toList()));
      } catch (_) {}
    }
    loadingTeachers = false;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadCache(); // Show cached data instantly
    // Do NOT fetch fresh data automatically; only fetch on refresh button
  }

  Future<List<ParseObject>> _fetchAllTeachers() async {
    setState(() {
      loadingTeachers = true;
    });
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final response = await query.query();
      if (response.success && response.results != null) {
        final teachers = List<ParseObject>.from(response.results!);
        setState(() {
          teacherList = teachers;
          loadingTeachers = false;
        });
        await _saveCache();
        return teachers;
      } else {
        setState(() {
          teacherList = [];
          loadingTeachers = false;
        });
        return [];
      }
    } catch (e) {
      setState(() {
        teacherList = [];
        loadingTeachers = false;
      });
      return [];
    }
  }

  Future<void> _loadAllData() async {
    final teachers = await _fetchAllTeachers();
    await _fetchAllClasses();
    // Only fetch assignments if teachers are present
    if (teachers.isNotEmpty) {
      await _fetchTeacherAssignments();
      await _fetchTeacherSchedules();
    } else {
      setState(() {
        teacherAssignments = {};
        teacherSchedules = {};
      });
    }
  }

  Future<void> _fetchAllClasses() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();
      if (response.success && response.results != null) {
        final fetched = List<ParseObject>.from(response.results!)
            .map((cls) => {
                  'objectId': cls.get<String>('objectId'),
                  'classname': cls.get<String>('classname') ?? 'Unnamed',
                })
            .toList();
        debugPrint('Fetched classes: ' + fetched.toString());
        setState(() {
          allClasses = fetched;
        });
        await _saveCache();
      } else {
        debugPrint('No classes found or query failed.');
        setState(() {
          allClasses = [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching classes: ' + e.toString());
      setState(() {
        allClasses = [];
      });
    }
  }

  Future<void> _assignClassesToTeacher(
      List<String> classIds, ParseObject teacher) async {
    try {
      for (final classId in classIds) {
        final query = QueryBuilder<ParseObject>(ParseObject('Class'))
          ..whereEqualTo('objectId', classId);
        final response = await query.query();
        if (response.success &&
            response.results != null &&
            response.results!.isNotEmpty) {
          final classObj = response.results!.first as ParseObject;
          // Use pointer array approach with pointer map
          final List<dynamic> teacherPointers =
              (classObj.get<List<dynamic>>('teacherPointers') ?? []).toList();
          final teacherPointer = {
            '__type': 'Pointer',
            'className': 'Teacher',
            'objectId': teacher.objectId,
          };
          final alreadyAssigned = teacherPointers.any((ptr) => (ptr is Map &&
              ptr['__type'] == 'Pointer' &&
              ptr['className'] == 'Teacher' &&
              ptr['objectId'] == teacher.objectId));
          if (!alreadyAssigned) {
            teacherPointers.add(teacherPointer);
            classObj.set('teacherPointers', teacherPointers);
            final saveResp = await classObj.save();
            if (!saveResp.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Failed to assign class: \n${saveResp.error?.message ?? 'Unknown error'}')),
              );
            }
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classes assigned successfully!')),
      );
      await _fetchTeacherAssignments();
      await _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \n$e')),
      );
    }
  }

  Future<void> _fetchTeacherAssignments() async {
    // Pointer array approach: build assignments by iterating all classes
    Map<String, List<Map<String, dynamic>>> assignments = {};
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();
      if (response.success && response.results != null) {
        final classes = List<ParseObject>.from(response.results!);
        for (final teacher in teacherList) {
          final teacherId = teacher.objectId;
          assignments[teacherId!] = [];
        }
        for (final classObj in classes) {
          final className = classObj.get<String>('classname') ?? 'Unnamed';
          final objectId = classObj.get<String>('objectId') ?? '';
          final teacherPointers =
              classObj.get<List<dynamic>>('teacherPointers') ?? [];
          for (final ptr in teacherPointers) {
            String? tId;
            if (ptr is ParseObject && ptr.parseClassName == 'Teacher') {
              tId = ptr.objectId;
            } else if (ptr is Map) {
              final isPointer =
                  ptr['__type'] == 'Pointer' && ptr['className'] == 'Teacher';
              final isOldStyle =
                  ptr['className'] == 'Teacher' && ptr['objectId'] != null;
              if (isPointer || isOldStyle) {
                tId = ptr['objectId'];
              }
            }
            if (tId != null && assignments.containsKey(tId)) {
              assignments[tId]!
                  .add({'classname': className, 'objectId': objectId});
            }
          }
        }
      }
      setState(() {
        teacherAssignments = assignments;
      });
      await _saveCache();
    } catch (e) {
      setState(() {
        teacherAssignments = assignments;
      });
    }
  }

  Future<void> _fetchTeacherSchedules() async {
    Map<String, List<Map<String, dynamic>>> schedules = {};
    try {
      for (final teacher in teacherList) {
        final teacherId = teacher.objectId;
        if (teacherId == null) continue;
        final query =
            QueryBuilder<ParseObject>(ParseObject('ClassSubjectTeacher'))
              ..whereEqualTo(
                  'teacher', ParseObject('Teacher')..objectId = teacherId)
              ..includeObject(['class', 'subject']);
        final response = await query.query();
        debugPrint('Schedule query for teacherId: '
            '${teacherId}, response.success: ${response.success}, results: ${response.results?.length}');
        if (response.success && response.results != null) {
          final assignments = List<ParseObject>.from(response.results!);
          schedules[teacherId] = assignments.map((a) {
            final classObj = a.get<ParseObject>('class');
            final subjectObj = a.get<ParseObject>('subject');
            debugPrint(
                'Assignment for teacherId=${teacherId}: class=${classObj?.get<String>('classname')}, subject=${subjectObj?.get<String>('subjectName')}, day=${a.get<String>('dayOfWeek')}');
            return {
              'className': classObj?.get<String>('classname') ?? '',
              'subjectName': subjectObj?.get<String>('subjectName') ?? '',
              'dayOfWeek': a.get<String>('dayOfWeek') ?? '',
              'startTime': a.get<String>('startTime') ?? '',
              'endTime': a.get<String>('endTime') ?? '',
              'period': a.get<String>('period') ?? '',
            };
          }).toList();
        } else {
          schedules[teacherId] = [];
        }
      }
      setState(() {
        teacherSchedules = schedules;
      });
    } catch (e) {
      setState(() {
        teacherSchedules = schedules;
      });
    }
  }

  void _showAssignClassAndSubjectDialog(ParseObject teacher) async {
    final subjectQuery = QueryBuilder<ParseObject>(ParseObject('Subject'));
    final subjectResponse = await subjectQuery.query();
    final subjectsList =
        subjectResponse.success && subjectResponse.results != null
            ? List<ParseObject>.from(subjectResponse.results!)
            : <ParseObject>[];
    List<String> selectedClasses = [];
    Map<String, ParseObject?> selectedSubjects = {};
    Map<String, List<String>> selectedDays = {};
    Map<String, TimeOfDay?> selectedStartTimes = {};
    Map<String, TimeOfDay?> selectedEndTimes = {};
    Map<String, String?> periods = {};
    final daysOfWeek = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                  'Assign Classes & Subjects to \\${teacher.get<String>('fullName') ?? 'Teacher'}'),
              content: SizedBox(
                width: 350,
                child: allClasses.isNotEmpty
                    ? ListView(
                        shrinkWrap: true,
                        children: allClasses.map((cls) {
                          final classId = cls['objectId'] as String?;
                          final className = cls['classname'] ?? '';
                          final isSelected = selectedClasses.contains(classId);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                value: isSelected,
                                title: Text(className),
                                onChanged: (checked) {
                                  if (classId == null) return;
                                  final id = classId;
                                  setStateDialog(() {
                                    if (checked == true) {
                                      selectedClasses.add(id);
                                      selectedSubjects[id] = null;
                                      selectedDays[id] = <String>[];
                                      selectedStartTimes[id] = null;
                                      selectedEndTimes[id] = null;
                                      periods[id] = null;
                                    } else if (checked == false) {
                                      selectedClasses.remove(id);
                                      selectedSubjects.remove(id);
                                      selectedDays.remove(id);
                                      selectedStartTimes.remove(id);
                                      selectedEndTimes.remove(id);
                                      periods.remove(id);
                                    }
                                  });
                                },
                              ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 24.0, bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<ParseObject>(
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Select Subject'),
                                        value: selectedSubjects[classId],
                                        items: subjectsList.map((subject) {
                                          final name = subject
                                                  .get<String>('subjectName') ??
                                              'Subject';
                                          return DropdownMenuItem(
                                            value: subject,
                                            child: Text(name),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (classId == null) return;
                                          final id = classId;
                                          setStateDialog(() =>
                                              selectedSubjects[id] = value);
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Select Days of Week',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        children: daysOfWeek
                                            .map((day) => FilterChip(
                                                  label: Text(day),
                                                  selected:
                                                      selectedDays[classId]
                                                              ?.contains(day) ??
                                                          false,
                                                  onSelected: (selected) {
                                                    setStateDialog(() {
                                                      if (selected) {
                                                        selectedDays[classId]
                                                            ?.add(day);
                                                      } else {
                                                        selectedDays[classId]
                                                            ?.remove(day);
                                                      }
                                                    });
                                                  },
                                                ))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 8),
                                      ListTile(
                                        title: Text(
                                            selectedStartTimes[classId] == null
                                                ? 'Select Start Time'
                                                : selectedStartTimes[classId]!
                                                    .format(context)),
                                        leading: const Icon(Icons.access_time),
                                        onTap: () async {
                                          if (classId == null) return;
                                          final id = classId;
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );
                                          if (picked != null)
                                            setStateDialog(() =>
                                                selectedStartTimes[id] =
                                                    picked);
                                        },
                                      ),
                                      ListTile(
                                        title: Text(
                                            selectedEndTimes[classId] == null
                                                ? 'Select End Time'
                                                : selectedEndTimes[classId]!
                                                    .format(context)),
                                        leading: const Icon(Icons.access_time),
                                        onTap: () async {
                                          if (classId == null) return;
                                          final id = classId;
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );
                                          if (picked != null)
                                            setStateDialog(() =>
                                                selectedEndTimes[id] = picked);
                                        },
                                      ),
                                      TextFormField(
                                        decoration: const InputDecoration(
                                            labelText: 'Period (optional)'),
                                        onChanged: (val) {
                                          if (classId == null) return;
                                          final id = classId;
                                          periods[id] = val;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        }).toList(),
                      )
                    : const Text('No classes found'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedClasses.isEmpty
                      ? null
                      : () async {
                          // Assign classes and create subject assignments
                          for (final classId in selectedClasses) {
                            // Assign class to teacher if not already
                            final query =
                                QueryBuilder<ParseObject>(ParseObject('Class'))
                                  ..whereEqualTo('objectId', classId);
                            final response = await query.query();
                            if (response.success &&
                                response.results != null &&
                                response.results!.isNotEmpty) {
                              final classObj =
                                  response.results!.first as ParseObject;
                              final List<dynamic> teacherPointers =
                                  (classObj.get<List<dynamic>>(
                                              'teacherPointers') ??
                                          [])
                                      .toList();
                              final teacherPointer = {
                                '__type': 'Pointer',
                                'className': 'Teacher',
                                'objectId': teacher.objectId,
                              };
                              final alreadyAssigned = teacherPointers.any(
                                  (ptr) => (ptr is Map &&
                                      ptr['__type'] == 'Pointer' &&
                                      ptr['className'] == 'Teacher' &&
                                      ptr['objectId'] == teacher.objectId));
                              if (!alreadyAssigned) {
                                teacherPointers.add(teacherPointer);
                                classObj.set(
                                    'teacherPointers', teacherPointers);
                                await classObj.save();
                              }
                              // Create subject assignments
                              final subject = selectedSubjects[classId];
                              final days = selectedDays[classId] ?? [];
                              final startTime = selectedStartTimes[classId];
                              final endTime = selectedEndTimes[classId];
                              final period = periods[classId];
                              if (subject != null &&
                                  days.isNotEmpty &&
                                  startTime != null &&
                                  endTime != null) {
                                for (final day in days) {
                                  final assignment = ParseObject(
                                      'ClassSubjectTeacher')
                                    ..set('teacher', teacher)
                                    ..set('class', classObj)
                                    ..set('subject', subject)
                                    ..set('dayOfWeek', day)
                                    ..set(
                                        'startTime', startTime.format(context))
                                    ..set('endTime', endTime.format(context));
                                  if (period != null && period.isNotEmpty) {
                                    assignment.set('period', period);
                                  }
                                  await assignment.save();
                                }
                              }
                            }
                          }
                          if (!mounted) return;
                          Navigator.pop(context);
                          await _fetchTeacherAssignments();
                          await _fetchTeacherSchedules();
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Classes'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await _loadAllData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear Cache',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_cacheTeachersKey);
              await prefs.remove(_cacheClassesKey);
              await prefs.remove(_cacheAssignmentsKey);
              await prefs.remove(_cacheSchedulesKey);
              setState(() {
                teacherList = [];
                allClasses = [];
                teacherAssignments = {};
                teacherSchedules = {};
                loadingTeachers = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared!')),
              );
            },
          ),
        ],
      ),
      body: loadingTeachers
          ? const Center(child: CircularProgressIndicator())
          : teacherList.isEmpty
              ? const Center(child: Text('No teachers found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: teacherList.length,
                  itemBuilder: (context, i) {
                    final teacher = teacherList[i];
                    final name = teacher.get<String>('fullName') ?? 'Unnamed';
                    final teacherId = teacher.objectId;
                    final schedule = teacherSchedules[teacherId] ?? [];
                    debugPrint(
                        'UI: teacherId=${teacherId}, schedule=${schedule}');
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeacherScheduleScreen(
                              teacherId: teacherId ?? '',
                              teacherName: name,
                              schedule: schedule,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Assign Classes',
                                    onPressed: () {
                                      _showAssignClassAndSubjectDialog(teacher);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Schedule display removed for cleaner look
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
