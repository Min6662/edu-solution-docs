import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../widgets/app_bottom_navigation.dart';

class TimeTableScreen extends StatefulWidget {
  final String userRole;
  final String? teacherId; // For teacher role, pass their teacher ID

  const TimeTableScreen({
    super.key,
    this.userRole = 'admin',
    this.teacherId,
  });

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> {
  // Dropdown selections
  String? selectedTeacher;
  String? selectedClass;

  // Data lists
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> classes = [];
  bool isLoadingData = true;

  // User role state
  String? currentUserRole;

  // Helper properties
  bool get isTeacher => currentUserRole == 'teacher';
  bool get isAdmin => currentUserRole == 'admin' || currentUserRole == 'owner';

  final List<String> timeSlots = [
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00'
  ];

  final List<String> afternoonTimeSlots = [
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00'
  ];

  final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  // Store schedule data - Map<timeSlot, Map<day, subject>>
  Map<String, Map<String, String>> scheduleData = {};
  Map<String, Map<String, String>> afternoonScheduleData = {};

  @override
  void initState() {
    super.initState();

    // Set user role from widget or get from Parse
    currentUserRole = widget.userRole;

    // Initialize empty morning schedule
    for (String time in timeSlots) {
      scheduleData[time] = {};
      for (String day in weekDays) {
        scheduleData[time]![day] = '';
      }
    }
    // Initialize empty afternoon schedule
    for (String time in afternoonTimeSlots) {
      afternoonScheduleData[time] = {};
      for (String day in weekDays) {
        afternoonScheduleData[time]![day] = '';
      }
    }

    // Auto-select teacher for teacher role
    if (isTeacher && widget.teacherId != null) {
      selectedTeacher = widget.teacherId;
    }

    _initializeUserRole();
    _loadData();
  }

  Future<void> _initializeUserRole() async {
    if (currentUserRole == null) {
      // Get user role from Parse if not provided
      final currentUser = await ParseUser.currentUser() as ParseUser?;
      if (currentUser != null) {
        setState(() {
          currentUserRole = currentUser.get<String>('role') ?? 'student';
        });
        print('DEBUG: Set currentUserRole to: $currentUserRole');
      }
    }

    // If user is a teacher, find their teacher ID
    if (isTeacher && widget.teacherId == null) {
      print('DEBUG: User is teacher, finding teacher ID...');
      await _findTeacherId();
    } else if (isTeacher && widget.teacherId != null) {
      print('DEBUG: Teacher ID already provided: ${widget.teacherId}');
      setState(() {
        selectedTeacher = widget.teacherId;
      });
      // Load schedule data for provided teacher ID
      await _loadScheduleData();
    }
  }

  Future<void> _findTeacherId() async {
    try {
      final currentUser = await ParseUser.currentUser() as ParseUser?;
      if (currentUser != null) {
        final username = currentUser.username;

        // Find teacher record by username
        final query = QueryBuilder<ParseObject>(ParseObject('Teacher'))
          ..whereEqualTo('username', username);

        final response = await query.query();
        if (response.success &&
            response.results != null &&
            response.results!.isNotEmpty) {
          setState(() {
            selectedTeacher = response.results!.first.objectId;
          });
          print(
              'DEBUG: Found teacher ID: $selectedTeacher for user: $username');

          // Load schedule data after finding teacher ID
          await _loadScheduleData();
        } else {
          print('DEBUG: No teacher record found for username: $username');
        }
      }
    } catch (e) {
      print('Error finding teacher ID: $e');
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTeachers(),
      _loadClasses(),
    ]);
    setState(() {
      isLoadingData = false;
    });

    // For teachers, load schedule data after all data is loaded
    if (isTeacher && selectedTeacher != null) {
      print('DEBUG: Loading schedule data for teacher after data load');
      await _loadScheduleData();
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          teachers = response.results!
              .map((teacher) => {
                    'id': teacher.objectId ?? '',
                    'name':
                        teacher.get<String>('fullName') ?? 'Unknown Teacher',
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> _loadClasses() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          classes = response.results!
              .map((classObj) => {
                    'id': classObj.objectId ?? '',
                    'name':
                        classObj.get<String>('classname') ?? 'Unknown Class',
                  })
              .toList();
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
    }
  }

  Future<void> _loadScheduleData() async {
    // Clear both schedules first
    setState(() {
      for (String time in timeSlots) {
        for (String day in weekDays) {
          scheduleData[time]![day] = '';
        }
      }
      for (String time in afternoonTimeSlots) {
        for (String day in weekDays) {
          afternoonScheduleData[time]![day] = '';
        }
      }
    });

    if (selectedTeacher == null && selectedClass == null) {
      // No selection, keep empty schedule
      print('DEBUG: No teacher or class selected, keeping empty schedule');
      return;
    }

    print(
        'DEBUG: _loadScheduleData called - isTeacher: $isTeacher, selectedTeacher: $selectedTeacher, selectedClass: $selectedClass');

    try {
      print(
          'Loading schedule data - Teacher: $selectedTeacher, Class: $selectedClass');

      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'));
      // Include teacher and class data in the query
      query.includeObject(['teacher', 'class']);

      // Priority logic: If class is selected, show ALL subjects for that class
      // If only teacher is selected, show subjects for that teacher
      if (selectedClass != null) {
        print(
            'Loading ALL schedules for class: $selectedClass (priority mode)');
        final classPointer = ParseObject('Class')..objectId = selectedClass;
        query.whereEqualTo('class', classPointer);

        // If teacher is also selected, we'll still show all class subjects
        // but can highlight the current teacher's subjects differently
      } else if (selectedTeacher != null) {
        print('Loading schedules for teacher only: $selectedTeacher');
        final teacherPointer = ParseObject('Teacher')
          ..objectId = selectedTeacher;
        query.whereEqualTo('teacher', teacherPointer);
      }

      final response = await query.query();
      print(
          'Query response - Success: ${response.success}, Results: ${response.results?.length ?? 0}');

      if (response.success && response.results != null) {
        // Load schedule from Parse
        for (var schedule in response.results!) {
          final day = schedule.get<String>('day') ?? '';
          final timeSlot = schedule.get<String>('timeSlot') ?? '';
          final subject = schedule.get<String>('subject') ?? '';

          // Get teacher and class information
          final teacherPointer = schedule.get<ParseObject>('teacher');
          final classPointer = schedule.get<ParseObject>('class');

          final teacherName =
              teacherPointer?.get<String>('fullName') ?? 'Unknown Teacher';
          final className =
              classPointer?.get<String>('classname') ?? 'Unknown Class';

          print(
              'Loading schedule entry: $day $timeSlot - $subject by $teacherName for $className');

          String displayText;

          // Format display text based on view mode and user role
          if (selectedClass != null && selectedTeacher != null) {
            // Both selected - show if this entry matches current teacher
            if (teacherPointer?.objectId == selectedTeacher) {
              displayText = subject; // Current teacher's subject
            } else {
              // Get first name only (split by space and take first part)
              String firstName = teacherName.split(' ').first.toLowerCase();
              displayText =
                  '$subject\n$firstName'; // Other teacher's subject with first name
            }
          } else if (selectedClass != null) {
            // Class selected - show all subjects with teacher names
            // Get first name only (split by space and take first part)
            String firstName = teacherName.split(' ').first.toLowerCase();
            displayText = '$subject\n$firstName';
          } else {
            // Teacher only selected
            if (isTeacher) {
              displayText = '$subject\n$className';
            } else {
              displayText = subject;
            }
          }

          // Check if it's a morning schedule
          if (scheduleData.containsKey(timeSlot) &&
              scheduleData[timeSlot]!.containsKey(day)) {
            setState(() {
              scheduleData[timeSlot]![day] = displayText;
            });
          }
          // Check if it's an afternoon schedule
          else if (afternoonScheduleData.containsKey(timeSlot) &&
              afternoonScheduleData[timeSlot]!.containsKey(day)) {
            setState(() {
              afternoonScheduleData[timeSlot]![day] = displayText;
            });
          }
        }
      } else {
        print('No schedule data found or query failed');
      }
    } catch (e) {
      print('Error loading schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading schedule data'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _checkForConflicts(
      String day, String timeSlot, String teacherId, String classId) async {
    try {
      // Check teacher conflict (exclude current teacher-class combination)
      final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
      final teacherQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('day', day)
        ..whereEqualTo('timeSlot', timeSlot)
        ..whereEqualTo('teacher', teacherPointer);

      // Exclude current class when checking teacher conflicts
      final classPointer = ParseObject('Class')..objectId = classId;
      teacherQuery.whereNotEqualTo('class', classPointer);

      // Check class conflict (exclude current teacher-class combination)
      final classQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('day', day)
        ..whereEqualTo('timeSlot', timeSlot)
        ..whereEqualTo('class', classPointer);

      // Exclude current teacher when checking class conflicts
      classQuery.whereNotEqualTo('teacher', teacherPointer);

      final teacherResponse = await teacherQuery.query();
      final classResponse = await classQuery.query();

      return (teacherResponse.success &&
              teacherResponse.results != null &&
              teacherResponse.results!.isNotEmpty) ||
          (classResponse.success &&
              classResponse.results != null &&
              classResponse.results!.isNotEmpty);
    } catch (e) {
      print('Error checking conflicts: $e');
      return false;
    }
  }

  Future<void> _saveScheduleEntry(
      String day, String timeSlot, String subject) async {
    if (selectedTeacher == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both teacher and class'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (subject.trim().isEmpty) {
      await _deleteScheduleEntry(day, timeSlot);
      return;
    }

    try {
      print('Saving schedule: day=$day, timeSlot=$timeSlot, subject=$subject');
      print('Teacher ID: $selectedTeacher, Class ID: $selectedClass');

      // Check for conflicts
      final hasConflict = await _checkForConflicts(
          day, timeSlot, selectedTeacher!, selectedClass!);

      if (hasConflict) {
        print('Conflict detected during save');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Conflict detected! Teacher or class already assigned at this time.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if entry already exists for this combination
      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'));
      final teacherPointer = ParseObject('Teacher')..objectId = selectedTeacher;
      final classPointer = ParseObject('Class')..objectId = selectedClass;

      query.whereEqualTo('teacher', teacherPointer);
      query.whereEqualTo('class', classPointer);
      query.whereEqualTo('day', day);
      query.whereEqualTo('timeSlot', timeSlot);

      final response = await query.query();
      print(
          'Existing entry check - Success: ${response.success}, Results: ${response.results?.length ?? 0}');

      ParseObject scheduleEntry;
      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        // Update existing entry
        print('Updating existing entry');
        scheduleEntry = response.results!.first;
        scheduleEntry.set('subject', subject);
      } else {
        // Create new entry
        print('Creating new entry');
        scheduleEntry = ParseObject('Schedule');
        scheduleEntry.set('teacher', teacherPointer);
        scheduleEntry.set('class', classPointer);
        scheduleEntry.set('day', day);
        scheduleEntry.set('timeSlot', timeSlot);
        scheduleEntry.set('subject', subject);
        // Note: Removed createdBy to avoid serialization issues
      }

      final saveResponse = await scheduleEntry.save();
      if (saveResponse.success) {
        setState(() {
          // Update the correct schedule based on time slot
          if (scheduleData.containsKey(timeSlot)) {
            scheduleData[timeSlot]![day] = subject;
          } else {
            afternoonScheduleData[timeSlot]![day] = subject;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Parse save error: ${saveResponse.error?.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Save failed: ${saveResponse.error?.message ?? "Unknown error"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error saving schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving schedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteScheduleEntry(String day, String timeSlot) async {
    if (selectedTeacher == null || selectedClass == null) return;

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'));
      final teacherPointer = ParseObject('Teacher')..objectId = selectedTeacher;
      final classPointer = ParseObject('Class')..objectId = selectedClass;

      query.whereEqualTo('teacher', teacherPointer);
      query.whereEqualTo('class', classPointer);
      query.whereEqualTo('day', day);
      query.whereEqualTo('timeSlot', timeSlot);

      final response = await query.query();

      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        final deleteResponse = await response.results!.first.delete();
        if (deleteResponse.success) {
          setState(() {
            // Clear the correct schedule based on time slot
            if (scheduleData.containsKey(timeSlot)) {
              scheduleData[timeSlot]![day] = '';
            } else {
              afternoonScheduleData[timeSlot]![day] = '';
            }
          });
        }
      }
    } catch (e) {
      print('Error deleting schedule entry: $e');
    }
  }

  Widget _buildScheduleText(String text, bool isEmpty,
      {bool isAfternoon = false}) {
    if (text.isEmpty) {
      return Text('');
    }

    // Choose colors based on morning/afternoon
    Color primaryColor = isAfternoon ? Colors.orange[900]! : Colors.blue[900]!;
    Color greyColor = Colors.grey[600]!;

    // Check if text contains a teacher name (has newline)
    if (text.contains('\n')) {
      final parts = text.split('\n');
      final subject = parts[0];
      final teacherName = parts.length > 1 ? parts[1] : '';

      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: subject,
              style: TextStyle(
                fontSize: 11,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (teacherName.isNotEmpty)
              TextSpan(
                text: '\n$teacherName',
                style: TextStyle(
                  fontSize: 8, // Smaller font for teacher name
                  color: greyColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      );
    } else {
      // Single line text (no teacher name)
      return Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: isEmpty ? greyColor : primaryColor,
          fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  void _showSubjectDialog(String day, String timeSlot) {
    // Determine which schedule this time slot belongs to
    String currentValue;
    if (scheduleData.containsKey(timeSlot)) {
      currentValue = scheduleData[timeSlot]![day] ?? '';
    } else {
      currentValue = afternoonScheduleData[timeSlot]![day] ?? '';
    }

    // Extract just the subject name for editing (remove teacher info)
    String subjectOnly = currentValue.split('\n').first;
    final controller = TextEditingController(text: subjectOnly);

    // Check if this slot has an entry by another teacher
    // If there's a newline with a teacher name, it's from another teacher
    bool hasOtherTeacherEntry = currentValue.contains('\n') &&
        currentValue.split('\n').length > 1 &&
        selectedTeacher != null &&
        selectedClass != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Text('$day - $timeSlot'),
            ),
            if (isTeacher) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VIEW ONLY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ] else if (hasOtherTeacherEntry) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'OTHER TEACHER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentValue.isNotEmpty && hasOtherTeacherEntry) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Assignment:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentValue,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Edit will overwrite the current assignment:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: selectedClass != null
                    ? 'Enter subject name for selected class'
                    : 'Enter subject name',
                border: const OutlineInputBorder(),
                helperText: selectedClass != null
                    ? 'This will be assigned to the selected class'
                    : null,
              ),
              enabled: isAdmin, // Only enabled for admin
              readOnly: isTeacher, // Read-only for teachers
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isTeacher ? 'Close' : 'Cancel'),
          ),
          if (isAdmin) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _saveScheduleEntry(day, timeSlot, controller.text.trim());
              },
              child: Text(hasOtherTeacherEntry ? 'Overwrite' : 'Save'),
            ),
            if (currentValue.isNotEmpty)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteScheduleEntry(day, timeSlot);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Class Schedule'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: const Text(
                  'CLASS SCHEDULE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Name and Class Row - Conditional for role
            if (isAdmin) ...[
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.grey[400]!, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TEACHER:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            isLoadingData
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    child: DropdownButtonFormField<String>(
                                      value: selectedTeacher,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Select teacher',
                                        hintStyle:
                                            TextStyle(color: Colors.grey),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      items: teachers.map((teacher) {
                                        return DropdownMenuItem<String>(
                                          value: teacher['id'],
                                          child: Text(
                                            teacher['name'],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? value) {
                                        setState(() {
                                          selectedTeacher = value;
                                        });
                                        _loadScheduleData();
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.grey[400]!, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CLASS:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            isLoadingData
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    child: DropdownButtonFormField<String>(
                                      value: selectedClass,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Select class',
                                        hintStyle:
                                            TextStyle(color: Colors.grey),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      items: classes.map((classItem) {
                                        return DropdownMenuItem<String>(
                                          value: classItem['id'],
                                          child: Text(
                                            classItem['name'],
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? value) {
                                        setState(() {
                                          selectedClass = value;
                                        });
                                        _loadScheduleData();
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Teacher View - Show selected teacher name only
            if (isTeacher) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEACHER SCHEDULE:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        teachers.isNotEmpty && selectedTeacher != null
                            ? teachers.firstWhere(
                                (t) => t['id'] == selectedTeacher,
                                orElse: () => {'name': 'Loading...'})['name']
                            : 'Loading teacher information...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'VIEW ONLY MODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Morning Schedule Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'MORNING SCHEDULE (7:00 AM - 12:00 PM)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // Schedule Table
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: Column(
                  children: [
                    // Header Row (Days)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Time column header
                          Container(
                            width: 70,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    color: Colors.grey[400]!, width: 1),
                                bottom: BorderSide(
                                    color: Colors.grey[400]!, width: 1),
                              ),
                            ),
                            child: const Text(
                              'TIME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Day headers
                          ...weekDays
                              .map((day) => Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: day != weekDays.last
                                              ? BorderSide(
                                                  color: Colors.grey[400]!,
                                                  width: 1)
                                              : BorderSide.none,
                                          bottom: BorderSide(
                                              color: Colors.grey[400]!,
                                              width: 1),
                                        ),
                                      ),
                                      child: Text(
                                        day,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),

                    // Time Slot Rows
                    ...timeSlots
                        .map((time) => Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: time != timeSlots.last
                                      ? BorderSide(
                                          color: Colors.grey[400]!, width: 1)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Time cell
                                  Container(
                                    width: 70,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      border: Border(
                                        right: BorderSide(
                                            color: Colors.grey[400]!, width: 1),
                                      ),
                                    ),
                                    child: Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  // Subject cells
                                  ...weekDays
                                      .map((day) => Expanded(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _showSubjectDialog(day, time),
                                              child: Container(
                                                height: 50,
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: day != weekDays.last
                                                        ? BorderSide(
                                                            color: Colors
                                                                .grey[400]!,
                                                            width: 1)
                                                        : BorderSide.none,
                                                  ),
                                                  color:
                                                      scheduleData[time]![day]!
                                                              .isNotEmpty
                                                          ? Colors.blue[50]
                                                          : Colors.transparent,
                                                ),
                                                child: Center(
                                                  child: _buildScheduleText(
                                                    scheduleData[time]![day] ??
                                                        '',
                                                    scheduleData[time]![day]!
                                                        .isEmpty,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Afternoon Schedule Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'AFTERNOON SCHEDULE (1:00 PM - 5:00 PM)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),

            // Afternoon Schedule Table
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 2),
                ),
                child: Column(
                  children: [
                    // Header Row (Days) - Afternoon
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Time column header
                          Container(
                            width: 70,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    color: Colors.grey[400]!, width: 1),
                                bottom: BorderSide(
                                    color: Colors.grey[400]!, width: 1),
                              ),
                            ),
                            child: const Text(
                              'TIME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Day headers
                          ...weekDays.map((day) => Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: day != weekDays.last
                                          ? BorderSide(
                                              color: Colors.grey[400]!,
                                              width: 1)
                                          : BorderSide.none,
                                      bottom: BorderSide(
                                          color: Colors.grey[400]!, width: 1),
                                    ),
                                  ),
                                  child: Text(
                                    day,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                    // Time slots rows - Afternoon
                    ...afternoonTimeSlots
                        .map((time) => Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: time != afternoonTimeSlots.last
                                      ? BorderSide(
                                          color: Colors.grey[400]!, width: 1)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Time cell
                                  Container(
                                    width: 70,
                                    height: 50,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      border: Border(
                                        right: BorderSide(
                                            color: Colors.grey[400]!, width: 1),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        time,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Day cells
                                  ...weekDays
                                      .map((day) => Expanded(
                                            child: GestureDetector(
                                              onTap: () =>
                                                  _showSubjectDialog(day, time),
                                              child: Container(
                                                height: 50,
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: day != weekDays.last
                                                        ? BorderSide(
                                                            color: Colors
                                                                .grey[400]!,
                                                            width: 1)
                                                        : BorderSide.none,
                                                  ),
                                                  color: afternoonScheduleData[
                                                              time]![day]!
                                                          .isNotEmpty
                                                      ? Colors.orange[50]
                                                      : Colors.transparent,
                                                ),
                                                child: Center(
                                                  child: _buildScheduleText(
                                                    afternoonScheduleData[
                                                            time]![day] ??
                                                        '',
                                                    afternoonScheduleData[
                                                            time]![day]!
                                                        .isEmpty,
                                                    isAfternoon: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons - Only for Admin
            if (isAdmin) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Clear Schedule',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save Schedule',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Teacher View Info
            if (isTeacher) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.visibility,
                      color: Colors.blue,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Schedule View Only',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This is your assigned teaching schedule.\nClick any cell to view details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: 1, // Schedule/Teachers tab
        userRole: currentUserRole,
      ),
    );
  }

  void _clearSchedule() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Schedule'),
        content:
            const Text('Are you sure you want to clear the entire schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                for (String time in timeSlots) {
                  for (String day in weekDays) {
                    scheduleData[time]![day] = '';
                  }
                }
                for (String time in afternoonTimeSlots) {
                  for (String day in weekDays) {
                    afternoonScheduleData[time]![day] = '';
                  }
                }
                selectedTeacher = null;
                selectedClass = null;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Schedule cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _saveSchedule() {
    // TODO: Implement save to database functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Schedule saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
