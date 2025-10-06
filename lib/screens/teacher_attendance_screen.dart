import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  List<ParseObject> classes = [];
  List<ParseObject> students = [];
  ParseObject? selectedClass;
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  bool isSaving = false;

  // Map to store attendance status for each student
  Map<String, String> attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      isLoading = true;
    });

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          classes = response.results!.cast<ParseObject>();
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
      _showErrorSnackBar('Failed to load classes');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadStudents(ParseObject classObj) async {
    setState(() {
      isLoading = true;
      students = [];
      attendanceMap = {};
    });

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Student'));
      query.whereEqualTo('class', classObj);
      query.orderByAscending('fullName');

      final response = await query.query();

      if (response.success && response.results != null) {
        setState(() {
          students = response.results!.cast<ParseObject>();
          // Initialize attendance map with empty values
          for (var student in students) {
            attendanceMap[student.objectId!] = '';
          }
        });

        // Load existing attendance for the selected date
        await _loadExistingAttendance();
      }
    } catch (e) {
      print('Error loading students: $e');
      _showErrorSnackBar('Failed to load students');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadExistingAttendance() async {
    if (selectedClass == null) return;

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Attendance'));
      query.whereEqualTo('class', selectedClass);
      query.whereEqualTo('date', _formatDate(selectedDate));

      final response = await query.query();

      if (response.success && response.results != null) {
        for (var attendance in response.results!) {
          final studentId = attendance.get<ParseObject>('student')?.objectId;
          final status = attendance.get<String>('status') ?? '';

          if (studentId != null && attendanceMap.containsKey(studentId)) {
            setState(() {
              attendanceMap[studentId] = status;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading existing attendance: $e');
    }
  }

  Future<void> _saveAttendance() async {
    if (selectedClass == null || students.isEmpty) return;

    setState(() {
      isSaving = true;
    });

    try {
      for (var student in students) {
        final studentId = student.objectId!;
        final status = attendanceMap[studentId] ?? '';

        if (status.isNotEmpty) {
          // Check if attendance record already exists
          final query = QueryBuilder<ParseObject>(ParseObject('Attendance'));
          query.whereEqualTo('class', selectedClass);
          query.whereEqualTo('student', student);
          query.whereEqualTo('date', _formatDate(selectedDate));

          final response = await query.query();

          ParseObject attendanceRecord;
          if (response.success &&
              response.results != null &&
              response.results!.isNotEmpty) {
            // Update existing record
            attendanceRecord = response.results!.first;
          } else {
            // Create new record
            attendanceRecord = ParseObject('Attendance');
            attendanceRecord.set('class', selectedClass);
            attendanceRecord.set('student', student);
            attendanceRecord.set('date', _formatDate(selectedDate));
          }

          attendanceRecord.set('status', status);
          attendanceRecord.set('takenBy', ParseUser.currentUser);

          await attendanceRecord.save();
        }
      }

      _showSuccessSnackBar('Attendance saved successfully!');
    } catch (e) {
      print('Error saving attendance: $e');
      _showErrorSnackBar('Failed to save attendance');
    }

    setState(() {
      isSaving = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });

      if (selectedClass != null) {
        await _loadExistingAttendance();
      }
    }
  }

  Widget _buildAttendanceButton(String studentId, String status, String label) {
    final isSelected = attendanceMap[studentId] == status;

    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'P':
        backgroundColor =
            isSelected ? Colors.green : Colors.green.withOpacity(0.3);
        textColor = isSelected ? Colors.white : Colors.green;
        break;
      case 'A':
        backgroundColor = isSelected ? Colors.red : Colors.red.withOpacity(0.3);
        textColor = isSelected ? Colors.white : Colors.red;
        break;
      case 'L':
        backgroundColor =
            isSelected ? Colors.orange : Colors.orange.withOpacity(0.3);
        textColor = isSelected ? Colors.white : Colors.orange;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.3);
        textColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          attendanceMap[studentId] = isSelected ? '' : status;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? Colors.transparent : Colors.grey.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Attendance'),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        actions: [
          if (selectedClass != null && students.isNotEmpty)
            IconButton(
              onPressed: isSaving ? null : _saveAttendance,
              icon: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
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
            // Header Controls
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
                          const Text(
                            'Class: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: DropdownButton<ParseObject>(
                              value: selectedClass,
                              hint: const Text('Select Class'),
                              isExpanded: true,
                              items: classes.map((ParseObject classObj) {
                                final className =
                                    classObj.get<String>('classname') ??
                                        classObj.get<String>('name') ??
                                        'Unknown Class';
                                return DropdownMenuItem<ParseObject>(
                                  value: classObj,
                                  child: Text(className),
                                );
                              }).toList(),
                              onChanged: (ParseObject? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedClass = newValue;
                                  });
                                  _loadStudents(newValue);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date Picker
                      Row(
                        children: [
                          const Text(
                            'Date: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectDate,
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
                    ],
                  ),
                ),
              ),
            ),

            // Legend
            if (selectedClass != null && students.isNotEmpty)
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
                              child: const Center(
                                child: Text(
                                  'P',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('Present'),
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
                              child: const Center(
                                child: Text(
                                  'A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('Absent'),
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
                              child: const Center(
                                child: Text(
                                  'L',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('Late'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Students List
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : selectedClass == null
                      ? const Center(
                          child: Text(
                            'Please select a class to view students',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : students.isEmpty
                          ? const Center(
                              child: Text(
                                'No students found in this class',
                                style: TextStyle(
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
                                    // Header
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        color: Colors.grey,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          topRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              'No.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              'Student Name',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Attendance',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Students List
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: students.length,
                                        itemBuilder: (context, index) {
                                          final student = students[index];
                                          final studentId = student.objectId!;
                                          final studentName =
                                              student.get<String>('fullName') ??
                                                  student.get<String>('name') ??
                                                  'Unknown Student';

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: index % 2 == 0
                                                  ? Colors.grey.withOpacity(0.1)
                                                  : Colors.white,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 1,
                                                  child: Text(
                                                    '${index + 1}.',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    studentName,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      _buildAttendanceButton(
                                                          studentId, 'P', 'P'),
                                                      _buildAttendanceButton(
                                                          studentId, 'A', 'A'),
                                                      _buildAttendanceButton(
                                                          studentId, 'L', 'L'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
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
      ),
    );
  }
}
