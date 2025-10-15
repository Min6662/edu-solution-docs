import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  Map<String, int> monthlyAbsentCounts =
      {}; // Store monthly absent counts for each student
  bool isAttendanceSubmitted =
      false; // Track if attendance for current date/session is already submitted

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

      // Load existing attendance for the current date and session
      await _loadExistingAttendance();

      // Load monthly absent counts for each student
      await _loadMonthlyAbsentCounts();
    } else {
      setState(() {
        students = [];
        loadingStudents = false;
      });
    }
  }

  Future<void> _loadMonthlyAbsentCounts() async {
    try {
      for (var student in students) {
        final studentId = student['id'] as String;
        if (studentId.isNotEmpty) {
          final count = await _getStudentMonthlyAbsentCount(studentId);
          monthlyAbsentCounts[studentId] = count;
        }
      }
      setState(() {}); // Refresh UI with new counts
    } catch (e) {
      print('Error loading monthly absent counts: $e');
    }
  }

  Future<bool> _checkIfAttendanceAlreadySubmitted() async {
    if (selectedClassId == null || students.isEmpty) return false;

    try {
      final normalizedDateLocal =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final normalizedDateUtc = DateTime.utc(
        normalizedDateLocal.year,
        normalizedDateLocal.month,
        normalizedDateLocal.day,
      );

      final query = QueryBuilder<ParseObject>(ParseObject('Attendance'))
        ..whereEqualTo(
            'class', ParseObject('Class')..objectId = selectedClassId)
        ..whereEqualTo('date', normalizedDateUtc)
        ..whereEqualTo('session', selectedSession);

      final response = await query.query();

      if (response.success && response.results != null) {
        // If we have attendance records for all students, consider it submitted
        return response.results!.length >= students.length;
      }
      return false;
    } catch (e) {
      print('Error checking attendance submission status: $e');
      return false;
    }
  }

  Future<void> _loadExistingAttendance() async {
    if (selectedClassId == null || students.isEmpty) return;

    try {
      // Normalize date to midnight local, then convert to UTC
      final normalizedDateLocal =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final normalizedDateUtc = DateTime.utc(
        normalizedDateLocal.year,
        normalizedDateLocal.month,
        normalizedDateLocal.day,
      );

      final query = QueryBuilder<ParseObject>(ParseObject('Attendance'))
        ..whereEqualTo(
            'class', ParseObject('Class')..objectId = selectedClassId)
        ..whereEqualTo('date', normalizedDateUtc)
        ..whereEqualTo('session', selectedSession);

      final response = await query.query();

      if (response.success && response.results != null) {
        print('Found ${response.results!.length} existing attendance records');

        // First reset all students to 'present' (default)
        for (int i = 0; i < students.length; i++) {
          students[i]['status'] = 'present';
        }

        // Update student statuses based on existing attendance records
        for (var attendanceRecord in response.results!) {
          final studentId =
              attendanceRecord.get<ParseObject>('student')?.objectId;
          final status = attendanceRecord.get<String>('status') ?? 'present';
          final studentName = attendanceRecord.get<String>('studentName') ?? '';

          print('Loading attendance: $studentName ($studentId) - $status');

          // Find the student in our current list and update their status
          for (int i = 0; i < students.length; i++) {
            if (students[i]['id'] == studentId) {
              print(
                  'Updating student ${students[i]['name']} to status: $status');
              students[i]['status'] = status;
              break;
            }
          }
        }

        // Check if attendance is already fully submitted
        isAttendanceSubmitted = response.results!.length >= students.length;
        print(
            'Attendance submission status: $isAttendanceSubmitted (${response.results!.length}/${students.length} records)');

        // Force UI update
        setState(() {});
      } else {
        print('No existing attendance records found or query failed');
        // Set all students to default 'present' status
        for (int i = 0; i < students.length; i++) {
          students[i]['status'] = 'present';
        }
        setState(() {});
      }
    } catch (e) {
      print('Error loading existing attendance: $e');
    }
  }

  Future<void> _submitAttendance() async {
    final localizations = AppLocalizations.of(context)!;

    if (selectedClassId == null || students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectClassToViewStudents),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if attendance for this date/session has already been submitted
    if (isAttendanceSubmitted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Attendance Already Submitted'),
            content: Text(
                'Attendance for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} (${selectedSession}) has already been submitted.\n\nDo you want to update the existing records?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _proceedWithSubmission(); // Proceed with update
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
      return;
    }

    _proceedWithSubmission();
  }

  Future<void> _proceedWithSubmission() async {
    final localizations = AppLocalizations.of(context)!;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(localizations.savingAttendance),
            ],
          ),
        );
      },
    );

    try {
      final classObj = classes.firstWhere((c) => c.objectId == selectedClassId,
          orElse: () => ParseObject('Class'));
      final className = classObj.get<String>('classname') ?? '';

      int savedCount = 0;
      int updatedCount = 0;
      int errorCount = 0;

      // Normalize date to midnight local, then convert to UTC
      final normalizedDateLocal =
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final normalizedDateUtc = DateTime.utc(
        normalizedDateLocal.year,
        normalizedDateLocal.month,
        normalizedDateLocal.day,
      );

      for (var student in students) {
        try {
          print(
              'Processing student: ${student['name']} with status: ${student['status']}');

          // Validate student data
          if (student['id'] == null || student['id'].isEmpty) {
            errorCount++;
            print('Error: Student ${student['name']} has no valid ID');
            continue;
          }

          // Check for existing attendance for this student/class/date/session
          final query = QueryBuilder<ParseObject>(ParseObject('Attendance'))
            ..whereEqualTo(
                'student', ParseObject('Student')..objectId = student['id'])
            ..whereEqualTo(
                'class', ParseObject('Class')..objectId = selectedClassId)
            ..whereEqualTo('date', normalizedDateUtc)
            ..whereEqualTo('session', selectedSession);

          final response = await query.query();

          if (!response.success) {
            errorCount++;
            print(
                'Error querying existing attendance for ${student['name']}: ${response.error}');
            continue;
          }

          ParseObject attendance;
          bool isUpdate = false;

          if (response.results != null && response.results!.isNotEmpty) {
            // Update existing record
            attendance = response.results!.first;
            isUpdate = true;
            print('Updating existing attendance for ${student['name']}');
          } else {
            // Create new record
            attendance = ParseObject('Attendance');
            print('Creating new attendance record for ${student['name']}');
          }

          // Set/update the attendance data
          attendance.set(
              'student', ParseObject('Student')..objectId = student['id']);
          attendance.set(
              'class', ParseObject('Class')..objectId = selectedClassId);
          attendance.set('studentName', student['name']);
          attendance.set('classname', className);
          attendance.set('date', normalizedDateUtc);
          attendance.set('session', selectedSession);
          attendance.set('status', student['status']);

          // Get the current user properly
          final currentUser = await ParseUser.currentUser();
          if (currentUser != null) {
            attendance.set('takenBy', currentUser);
          }

          attendance.set('updatedAt', DateTime.now());

          final saveResponse = await attendance.save();

          if (saveResponse.success) {
            if (isUpdate) {
              updatedCount++;
              print('Successfully updated attendance for ${student['name']}');
            } else {
              savedCount++;
              print('Successfully created attendance for ${student['name']}');
            }
          } else {
            errorCount++;
            print(
                'Error saving attendance for ${student['name']}: ${saveResponse.error?.message ?? 'Unknown error'}');
            print('Error code: ${saveResponse.error?.code}');
            print('Error details: ${saveResponse.error}');
          }
        } catch (e, stackTrace) {
          errorCount++;
          print('Exception saving attendance for ${student['name']}: $e');
          print('Stack trace: $stackTrace');
        }
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message with details
      String message;
      Color backgroundColor;

      if (errorCount == 0) {
        message = localizations.attendanceSavedSuccessfully;
        if (savedCount > 0)
          message += '\n$savedCount ${localizations.newRecordsCreated}';
        if (updatedCount > 0)
          message += '\n$updatedCount ${localizations.recordsUpdated}';
        backgroundColor = Colors.green;
      } else {
        message = localizations.attendanceSavedWithErrors;
        if (savedCount > 0) message += '\n$savedCount ${localizations.saved}';
        if (updatedCount > 0)
          message += '\n$updatedCount ${localizations.updated}';
        message +=
            '\n$errorCount ${localizations.errors}\n${localizations.checkConsoleForDetails}';
        backgroundColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
          action: errorCount > 0
              ? SnackBarAction(
                  label: localizations.details,
                  textColor: Colors.white,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(localizations.errorDetails),
                        content: Text(
                            '${localizations.errorsWhileSaving(errorCount)}\n\n'
                            '${localizations.errorReasons}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(localizations.ok),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : null,
        ),
      );

      // Set submission flag if no errors occurred
      if (errorCount == 0) {
        setState(() {
          isAttendanceSubmitted = true;
        });
      }

      // Reload existing attendance to show what was actually saved
      await _loadExistingAttendance();
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.errorSavingAttendance(e.toString())),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      print('Error in _submitAttendance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.attendanceTitle),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: localizations.refreshStudentList,
            onPressed: selectedClassId == null
                ? null
                : () async {
                    final box = await Hive.openBox('attendanceStudents');
                    await box.delete(selectedClassId);
                    _fetchStudents(selectedClassId!, forceRefresh: true);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: localizations.viewHistory,
            onPressed: () {
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
                  SnackBar(
                      content:
                          Text(localizations.navigationError(e.toString()))),
                );
              }
            },
          ),
          if (selectedClassId != null && students.isNotEmpty)
            IconButton(
              onPressed: _submitAttendance,
              icon: const Icon(Icons.save, color: Colors.white),
              tooltip: localizations.saveAttendance,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE91E63), Color(0xFFF8BBD9)],
          ),
        ),
        child: Column(
          children: [
            // Header Controls Card
            Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Class Dropdown
                      Row(
                        children: [
                          Text(
                            localizations.classLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: loadingClasses
                                ? const CircularProgressIndicator()
                                : DropdownButton<String>(
                                    value: selectedClassId,
                                    hint: Text(localizations.selectClass),
                                    isExpanded: true,
                                    items: classes.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c.objectId,
                                        child: Text(
                                            c.get<String>('classname') ??
                                                localizations.unknownClass),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        selectedClassId = val;
                                        isAttendanceSubmitted =
                                            false; // Reset submission flag when class changes
                                      });
                                      if (val != null)
                                        _loadStudentsInstant(val);
                                    },
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date Picker
                      Row(
                        children: [
                          Text(
                            localizations.dateColon,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (picked != null && picked != selectedDate) {
                                  setState(() {
                                    selectedDate = picked;
                                    isAttendanceSubmitted =
                                        false; // Reset submission flag when date changes
                                  });
                                  // Load existing attendance for the new date
                                  await _loadExistingAttendance();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const Icon(Icons.calendar_today),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Session Dropdown
                      Row(
                        children: [
                          Text(
                            localizations.sessionLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: DropdownButton<String>(
                              value: selectedSession,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'Morning',
                                  child: Text(localizations.morning),
                                ),
                                DropdownMenuItem(
                                  value: 'Afternoon',
                                  child: Text(localizations.afternoon),
                                ),
                              ],
                              onChanged: (val) async {
                                setState(() {
                                  selectedSession = val!;
                                  isAttendanceSubmitted =
                                      false; // Reset submission flag when session changes
                                });
                                // Load existing attendance for the new session
                                await _loadExistingAttendance();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Legend
            if (selectedClassId != null && students.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  localizations.presentShort,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(localizations.present),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  localizations.absentShort,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(localizations.absent),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  localizations.lateShort,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(localizations.late),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  localizations.excuseShort,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(localizations.excuse),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Students Grade Book Style Table
            Expanded(
              child: loadingStudents
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : selectedClassId == null
                      ? Center(
                          child: Text(
                            localizations.pleaseSelectClassToViewStudents,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : students.isEmpty
                          ? Center(
                              child: Text(
                                localizations.noStudentsFoundInClass,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.all(16),
                              child: Card(
                                child: Column(
                                  children: [
                                    // Table Header with proper grid style
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: Table(
                                        border: TableBorder.all(
                                          color: Colors.grey.shade400,
                                          width: 1,
                                        ),
                                        columnWidths: const {
                                          0: FixedColumnWidth(50),
                                          1: FlexColumnWidth(3),
                                          2: FixedColumnWidth(50),
                                          3: FixedColumnWidth(50),
                                          4: FixedColumnWidth(100),
                                        },
                                        children: [
                                          TableRow(
                                            decoration: const BoxDecoration(
                                              color: Colors.grey,
                                            ),
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Text(
                                                  localizations.numberShort,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Text(
                                                  localizations.studentName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Text(
                                                  localizations.presentShort,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Text(
                                                  localizations.absentShort,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Text(
                                                  localizations.totalAbsent,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Students Table Body
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Table(
                                          border: TableBorder.all(
                                            color: Colors.grey.shade300,
                                            width: 1,
                                          ),
                                          columnWidths: const {
                                            0: FixedColumnWidth(50),
                                            1: FlexColumnWidth(3),
                                            2: FixedColumnWidth(50),
                                            3: FixedColumnWidth(50),
                                            4: FixedColumnWidth(100),
                                          },
                                          children: students
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            final index = entry.key;
                                            final student = entry.value;

                                            return TableRow(
                                              decoration: BoxDecoration(
                                                color: index % 2 == 0
                                                    ? Colors.grey
                                                        .withOpacity(0.1)
                                                    : Colors.white,
                                              ),
                                              children: [
                                                // Number
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Text(
                                                    '${index + 1}.',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                // Student Name
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Text(
                                                    student['name'],
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                                // Present Button
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  child:
                                                      _buildTableAttendanceButton(
                                                          index,
                                                          'present',
                                                          'P',
                                                          Colors.green),
                                                ),
                                                // Absent Button
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  child:
                                                      _buildTableAttendanceButton(
                                                          index,
                                                          'absent',
                                                          'A',
                                                          Colors.red),
                                                ),
                                                // Total Absent Count (show for each student)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4,
                                                        horizontal: 8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                          color: Colors.red
                                                              .withOpacity(
                                                                  0.3)),
                                                    ),
                                                    child: Text(
                                                      '${monthlyAbsentCounts[students[index]['id']] ?? 0}',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.red,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceButton(
      int studentIndex, String status, String label, Color color) {
    final isSelected = students[studentIndex]['status'] == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          students[studentIndex]['status'] = status;
        });
      },
      child: Container(
        width: 35,
        height: 35,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.transparent : color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  int _getTotalAbsentCount() {
    return students.where((student) => student['status'] == 'absent').length;
  }

  Future<int> _getStudentMonthlyAbsentCount(String studentId) async {
    try {
      // Get the first and last day of the current month
      final firstDayOfMonth =
          DateTime(selectedDate.year, selectedDate.month, 1);
      final lastDayOfMonth =
          DateTime(selectedDate.year, selectedDate.month + 1, 0);

      // Convert dates to UTC for consistent querying
      final firstDayUtc = DateTime.utc(
        firstDayOfMonth.year,
        firstDayOfMonth.month,
        firstDayOfMonth.day,
      );
      final lastDayUtc = DateTime.utc(
        lastDayOfMonth.year,
        lastDayOfMonth.month,
        lastDayOfMonth.day,
        23,
        59,
        59,
      );

      final query = QueryBuilder<ParseObject>(ParseObject('Attendance'))
        ..whereEqualTo('student', ParseObject('Student')..objectId = studentId)
        ..whereEqualTo('status', 'absent')
        ..whereGreaterThan(
            'date', firstDayUtc.subtract(const Duration(milliseconds: 1)))
        ..whereLessThan(
            'date', lastDayUtc.add(const Duration(milliseconds: 1)));

      print(
          'Querying monthly absent count for student: $studentId from $firstDayUtc to $lastDayUtc');
      final response = await query.query();

      if (response.success && response.results != null) {
        print(
            'Found ${response.results!.length} absent records for student: $studentId');
        return response.results!.length;
      } else {
        print(
            'Error fetching monthly absent count: ${response.error?.message ?? 'No results found'}');
        return 0;
      }
    } catch (e) {
      print('Exception in _getStudentMonthlyAbsentCount: $e');
      return 0;
    }
  }

  Widget _buildTableAttendanceButton(
      int studentIndex, String status, String label, Color color) {
    final isSelected = students[studentIndex]['status'] == status;
    final localizations = AppLocalizations.of(context)!;

    // Use localized short labels
    String displayLabel = label;
    switch (status) {
      case 'present':
        displayLabel = localizations.presentShort;
        break;
      case 'absent':
        displayLabel = localizations.absentShort;
        break;
      case 'late':
        displayLabel = localizations.lateShort;
        break;
      case 'excuse':
        displayLabel = localizations.excuseShort;
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          students[studentIndex]['status'] = status;
        });
      },
      child: Container(
        width: double.infinity,
        height: 30,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            displayLabel,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
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
    final localizations = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.attendanceHistory,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(
            child: classId == null
                ? Center(child: Text(localizations.noClassSelected))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future:
                        AttendanceHistoryView.fetchAttendanceHistory(classId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                            child: Text(localizations.noAttendanceRecords));
                      } else {
                        final records = snapshot.data!;
                        return ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return Card(
                              child: ListTile(
                                title: Text(localizations
                                    .studentNameField(record['studentName'])),
                                subtitle: Text(localizations.statusDateSession(
                                    record['status'],
                                    record['date'],
                                    record['session'])),
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
            child: Text(localizations.close),
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
