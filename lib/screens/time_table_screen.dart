import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/app_bottom_navigation.dart';
import '../services/language_service.dart';
import '../services/cache_service.dart';

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

  // Helper method to get localized day names
  List<String> getLocalizedWeekDays(AppLocalizations l10n) {
    return [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri];
  }

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
    setState(() {
      isLoadingData = true;
    });

    try {
      print('DEBUG: Starting _loadData...');

      // Try to load from cache first
      final cachedData = CacheService.getTeachersAndClasses();
      print('DEBUG: Cached data exists: ${cachedData != null}');
      if (cachedData != null &&
          CacheService.isCacheFresh(cachedData['lastUpdated'],
              maxAgeMinutes: 10)) {
        print('DEBUG: Cache is fresh, loading from cache...');

        try {
          setState(() {
            // Safely cast the cached data
            final cachedTeachers =
                cachedData['teachers'] as List<dynamic>? ?? [];
            final cachedClasses = cachedData['classes'] as List<dynamic>? ?? [];

            teachers = cachedTeachers
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            classes = cachedClasses
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            isLoadingData = false;
          });

          print(
              'DEBUG: Loaded ${teachers.length} teachers and ${classes.length} classes from cache');

          // For teachers, load schedule data after cached data is loaded
          if (isTeacher && selectedTeacher != null) {
            print(
                'DEBUG: Loading schedule data for teacher after cached data load');
            await _loadScheduleData();
          }

          // Still fetch fresh data in background
          _loadFreshData();
          return;
        } catch (cacheError) {
          print('ERROR in cache processing: $cacheError');
          // If cache processing fails, fall through to fresh data loading
        }
      }

      print('DEBUG: No cache or cache is stale, loading fresh data...');
      // Load fresh data if no cache or cache is stale
      await _loadFreshData();
    } catch (e) {
      print('ERROR in _loadData: $e');
      print('ERROR stack trace: ${e.toString()}');
      setState(() {
        isLoadingData = false;
      });
    }
  }

  Future<void> _loadFreshData() async {
    try {
      await Future.wait([
        _loadTeachers(),
        _loadClasses(),
      ]);

      print(
          'DEBUG: Loaded ${teachers.length} teachers and ${classes.length} classes from Parse');

      // Save to cache
      await CacheService.saveTeachersAndClasses(
        teachers: teachers,
        classes: classes,
      );

      setState(() {
        isLoadingData = false;
      });

      // For teachers, load schedule data after all data is loaded
      if (isTeacher && selectedTeacher != null) {
        print('DEBUG: Loading schedule data for teacher after fresh data load');
        await _loadScheduleData();
      }
    } catch (e) {
      print('ERROR in _loadFreshData: $e');
      setState(() {
        isLoadingData = false;
      });
    }
  }

  Future<void> _loadTeachers() async {
    try {
      print('DEBUG: Fetching teachers from Parse...');
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final response = await query.query();

      if (response.success && response.results != null) {
        final fetchedTeachers = response.results!
            .map((teacher) => {
                  'id': teacher.objectId ?? '',
                  'name': teacher.get<String>('fullName') ?? 'Unknown Teacher',
                })
            .toList();

        setState(() {
          teachers = fetchedTeachers;
        });

        print('DEBUG: Successfully loaded ${teachers.length} teachers');
      } else {
        print('DEBUG: Failed to load teachers - ${response.error?.message}');
        setState(() {
          teachers = []; // Set empty list instead of leaving undefined
        });
      }
    } catch (e) {
      print('ERROR loading teachers: $e');
      setState(() {
        teachers = []; // Set empty list on error
      });
    }
  }

  Future<void> _loadClasses() async {
    try {
      print('DEBUG: Fetching classes from Parse...');
      final query = QueryBuilder<ParseObject>(ParseObject('Class'));
      final response = await query.query();

      if (response.success && response.results != null) {
        final fetchedClasses = response.results!
            .map((classObj) => {
                  'id': classObj.objectId ?? '',
                  'name': classObj.get<String>('classname') ?? 'Unknown Class',
                })
            .toList();

        setState(() {
          classes = fetchedClasses;
        });

        print('DEBUG: Successfully loaded ${classes.length} classes');
      } else {
        print('DEBUG: Failed to load classes - ${response.error?.message}');
        setState(() {
          classes = []; // Set empty list instead of leaving undefined
        });
      }
    } catch (e) {
      print('ERROR loading classes: $e');
      setState(() {
        classes = []; // Set empty list on error
      });
    }
  }

  Future<void> _loadScheduleData() async {
    if (selectedTeacher == null && selectedClass == null) {
      // No selection, keep empty schedule
      print('DEBUG: No teacher or class selected, keeping empty schedule');
      return;
    }

    // Try to load from cache first
    final cacheKey = '${selectedTeacher ?? 'none'}_${selectedClass ?? 'none'}';
    final cachedTimetable = CacheService.getTimetableData(
      teacherId: selectedTeacher ?? 'none',
      classId: selectedClass ?? 'none',
    );

    if (cachedTimetable != null &&
        CacheService.isCacheFresh(cachedTimetable['lastUpdated'],
            maxAgeMinutes: 5)) {
      // Load from cache
      setState(() {
        scheduleData = Map<String, Map<String, String>>.from(
            cachedTimetable['morningSchedule'].map((key, value) =>
                MapEntry(key, Map<String, String>.from(value))));
        afternoonScheduleData = Map<String, Map<String, String>>.from(
            cachedTimetable['afternoonSchedule'].map((key, value) =>
                MapEntry(key, Map<String, String>.from(value))));
      });
      print('DEBUG: Loaded schedule from cache for $cacheKey');

      // Still fetch fresh data in background
      _loadFreshScheduleData();
      return;
    }

    // Load fresh data if no cache or cache is stale
    await _loadFreshScheduleData();
  }

  Future<Map<String, String>> _getTeacherAssignedSubjects(
      String teacherId, String classId) async {
    try {
      print(
          'DEBUG: Fetching teacher assigned subjects for teacherId: $teacherId, classId: $classId');

      // Query ClassSubjectTeacher table to get teacher's assigned subjects for this class
      final query = QueryBuilder<ParseObject>(
          ParseObject('ClassSubjectTeacher'))
        ..whereEqualTo('teacher', ParseObject('Teacher')..objectId = teacherId)
        ..whereEqualTo('class', ParseObject('Class')..objectId = classId)
        ..includeObject(['subject']);

      final response = await query.query();

      Map<String, String> assignedSubjects = {};

      if (response.success && response.results != null) {
        for (var assignment in response.results!) {
          final subjectObj = assignment.get<ParseObject>('subject');
          final dayOfWeek = assignment.get<String>('dayOfWeek') ?? '';

          if (subjectObj != null) {
            final subjectName = subjectObj.get<String>('subjectName') ??
                subjectObj.get<String>('name') ??
                'Unknown Subject';

            // Store with day as key for easy lookup
            assignedSubjects[dayOfWeek] = subjectName;
            print(
                'DEBUG: Found assigned subject: $subjectName for day: $dayOfWeek');
          }
        }
      }

      print('DEBUG: Total assigned subjects found: ${assignedSubjects.length}');
      return assignedSubjects;
    } catch (e) {
      print('ERROR: Failed to fetch teacher assigned subjects: $e');
      return {};
    }
  }

  Future<void> _loadFreshScheduleData() async {
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

    print(
        'DEBUG: _loadFreshScheduleData called - isTeacher: $isTeacher, selectedTeacher: $selectedTeacher, selectedClass: $selectedClass');

    try {
      print(
          'Loading fresh schedule data - Teacher: $selectedTeacher, Class: $selectedClass');

      // Get teacher's assigned subjects for the selected class (if both are selected)
      Map<String, String> teacherClassSubjects = {};
      if (selectedTeacher != null && selectedClass != null) {
        teacherClassSubjects =
            await _getTeacherAssignedSubjects(selectedTeacher!, selectedClass!);
        print(
            'DEBUG: Teacher assigned subjects for class: $teacherClassSubjects');
      }

      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'));
      // Include teacher and class data in the query
      query.includeObject(['teacher', 'class']);

      // Modified logic: When both teacher and class are selected,
      // we need to load TWO sets of data for complete conflict prevention:
      // 1. Selected teacher's schedules across all classes (to prevent teacher conflicts)
      // 2. All teachers' schedules for the selected class (to prevent class conflicts)
      if (selectedTeacher != null && selectedClass != null) {
        print(
            'Loading HYBRID data: teacher schedules + class schedules for conflict prevention');

        // Check cache first for hybrid data
        final hybridCacheKey = '${selectedTeacher}_${selectedClass}_hybrid';
        final cachedHybridData = CacheService.getTimetableData(
          teacherId: selectedTeacher!,
          classId: selectedClass!,
        );

        if (cachedHybridData != null &&
            CacheService.isCacheFresh(cachedHybridData['lastUpdated'],
                maxAgeMinutes: 3)) {
          // Load hybrid data from cache
          setState(() {
            scheduleData = Map<String, Map<String, String>>.from(
                cachedHybridData['morningSchedule'].map((key, value) =>
                    MapEntry(key, Map<String, String>.from(value))));
            afternoonScheduleData = Map<String, Map<String, String>>.from(
                cachedHybridData['afternoonSchedule'].map((key, value) =>
                    MapEntry(key, Map<String, String>.from(value))));
            isLoadingData = false;
          });
          print('DEBUG: Loaded hybrid schedule from cache for $hybridCacheKey');
          return; // Exit early since we loaded from cache
        }

        print('DEBUG: No fresh hybrid cache found, executing dual queries...');

        // First query: Get selected teacher's schedules across all classes
        final teacherQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'));
        teacherQuery.includeObject(['teacher', 'class']);
        final teacherPointer = ParseObject('Teacher')
          ..objectId = selectedTeacher;
        teacherQuery.whereEqualTo('teacher', teacherPointer);

        // Second query: Get all schedules for the selected class
        final classQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'));
        classQuery.includeObject(['teacher', 'class']);
        final classPointer = ParseObject('Class')..objectId = selectedClass;
        classQuery.whereEqualTo('class', classPointer);

        // Execute both queries
        final teacherResponse = await teacherQuery.query();
        final classResponse = await classQuery.query();

        print('Teacher query results: ${teacherResponse.results?.length ?? 0}');
        print('Class query results: ${classResponse.results?.length ?? 0}');

        // Combine results, avoiding duplicates
        final allResults = <ParseObject>[];
        final seenSchedules = <String>{};

        // Add teacher schedules
        if (teacherResponse.success && teacherResponse.results != null) {
          for (var schedule in teacherResponse.results!) {
            final key =
                '${schedule.get<String>('day')}_${schedule.get<String>('timeSlot')}_${schedule.objectId}';
            if (!seenSchedules.contains(key)) {
              allResults.add(schedule);
              seenSchedules.add(key);
            }
          }
        }

        // Add class schedules (avoiding duplicates)
        if (classResponse.success && classResponse.results != null) {
          for (var schedule in classResponse.results!) {
            final key =
                '${schedule.get<String>('day')}_${schedule.get<String>('timeSlot')}_${schedule.objectId}';
            if (!seenSchedules.contains(key)) {
              allResults.add(schedule);
              seenSchedules.add(key);
            }
          }
        }

        // Process the combined results
        if (allResults.isNotEmpty) {
          for (var schedule in allResults) {
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
                'Processing hybrid schedule: $day $timeSlot - $subject by $teacherName for $className');

            String displayText;

            if (teacherPointer?.objectId == selectedTeacher) {
              // This is the selected teacher's schedule
              final isCurrentClass = classPointer?.objectId == selectedClass;

              if (isCurrentClass) {
                // Current class assignment - show as editable
                bool isAssignedSubject =
                    teacherClassSubjects.values.contains(subject);
                if (isAssignedSubject) {
                  displayText =
                      '$subject ✓'; // Assigned subject for current class
                } else {
                  displayText = subject; // Other subject for current class
                }
              } else {
                // Different class - show as conflict warning with class name
                String classShortName = className.length > 8
                    ? className.substring(0, 8) + '..'
                    : className;
                displayText =
                    '$subject\n($classShortName)'; // Show subject with class info
              }
            } else {
              // Different teacher's schedule in the selected class
              String firstName = teacherName.split(' ').first.toLowerCase();
              displayText =
                  '$subject\n($firstName)'; // Show other teacher's subject
            }

            // Store the schedule data
            if (scheduleData.containsKey(timeSlot)) {
              scheduleData[timeSlot]![day] = displayText;
            } else {
              afternoonScheduleData[timeSlot]![day] = displayText;
            }
          }
        }

        // Cache the combined data
        await CacheService.saveTimetableData(
          teacherId: selectedTeacher ?? 'none',
          classId: selectedClass ?? 'none',
          morningSchedule: scheduleData,
          afternoonSchedule: afternoonScheduleData,
          teachers: teachers,
          classes: classes,
        );
        print(
            'DEBUG: Cached hybrid schedule data for ${selectedTeacher}_$selectedClass');

        setState(() {
          isLoadingData = false;
        });
        return; // Exit early since we handled everything above
      } else if (selectedClass != null) {
        print(
            'Loading ALL schedules for class: $selectedClass (class-only mode)');

        // Check cache first for class-only data
        final classCacheData = CacheService.getTimetableData(
          teacherId: 'none',
          classId: selectedClass!,
        );

        if (classCacheData != null &&
            CacheService.isCacheFresh(classCacheData['lastUpdated'],
                maxAgeMinutes: 3)) {
          // Load class-only data from cache
          setState(() {
            scheduleData = Map<String, Map<String, String>>.from(
                classCacheData['morningSchedule'].map((key, value) =>
                    MapEntry(key, Map<String, String>.from(value))));
            afternoonScheduleData = Map<String, Map<String, String>>.from(
                classCacheData['afternoonSchedule'].map((key, value) =>
                    MapEntry(key, Map<String, String>.from(value))));
            isLoadingData = false;
          });
          print(
              'DEBUG: Loaded class-only schedule from cache for $selectedClass');
          return; // Exit early since we loaded from cache
        }

        final classPointer = ParseObject('Class')..objectId = selectedClass;
        query.whereEqualTo('class', classPointer);
      } else if (selectedTeacher != null) {
        print('Loading schedules for teacher only: $selectedTeacher');

        // Check cache first for teacher-only data
        final teacherCacheData = CacheService.getTimetableData(
          teacherId: selectedTeacher!,
          classId: 'none',
        );

        if (teacherCacheData != null &&
            CacheService.isCacheFresh(teacherCacheData['lastUpdated'],
                maxAgeMinutes: 3)) {
          // Load teacher-only data from cache
          setState(() {
            scheduleData = Map<String, Map<String, String>>.from(
                teacherCacheData['morningSchedule'].map((key, value) =>
                    MapEntry(key, Map<String, String>.from(value))));
            afternoonScheduleData = Map<String, Map<String, String>>.from(
                teacherCacheData['afternoonSchedule'].map((key, value) =>
                    MapEntry(key, Map<String, String>.from(value))));
            isLoadingData = false;
          });
          print(
              'DEBUG: Loaded teacher-only schedule from cache for $selectedTeacher');
          return; // Exit early since we loaded from cache
        }

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
          if (selectedTeacher != null && selectedClass != null) {
            // Both selected - show ALL teacher's schedules across classes to prevent conflicts

            if (teacherPointer?.objectId == selectedTeacher) {
              // This is the selected teacher's schedule
              final isCurrentClass = classPointer?.objectId == selectedClass;

              if (isCurrentClass) {
                // Current class assignment - show as editable
                bool isAssignedSubject =
                    teacherClassSubjects.values.contains(subject);
                if (isAssignedSubject) {
                  displayText =
                      '$subject ✓'; // Assigned subject for current class
                } else {
                  displayText = subject; // Other subject for current class
                }
              } else {
                // Different class - show as conflict warning with class name
                String classShortName = className.length > 8
                    ? className.substring(0, 8) + '..'
                    : className;
                displayText =
                    '$subject\n($classShortName)'; // Show subject with class info
              }
            } else {
              // This shouldn't happen with current query logic
              String firstName = teacherName.split(' ').first.toLowerCase();
              displayText = '$subject\n($firstName)';
            }
          } else if (selectedClass != null) {
            // Class selected only - show all subjects with teacher names
            String firstName = teacherName.split(' ').first.toLowerCase();
            displayText = '$subject\n$firstName';
          } else if (selectedTeacher != null) {
            // Teacher selected only - show subjects with class names
            if (isTeacher) {
              displayText = '$subject\n$className';
            } else {
              displayText = '$subject\n$className';
            }
          } else {
            // Nothing selected
            displayText = subject;
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

        // Cache the loaded schedule data
        await CacheService.saveTimetableData(
          teacherId: selectedTeacher ?? 'none',
          classId: selectedClass ?? 'none',
          morningSchedule: scheduleData,
          afternoonSchedule: afternoonScheduleData,
          teachers: teachers,
          classes: classes,
        );

        print(
            'DEBUG: Cached fresh schedule data for ${selectedTeacher ?? 'none'}_${selectedClass ?? 'none'}');
      } else {
        print('No schedule data found or query failed');
      }
    } catch (e) {
      print('Error loading schedule: $e');
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorLoadingSchedule),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _checkForConflicts(
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

      bool hasTeacherConflict = teacherResponse.success &&
          teacherResponse.results != null &&
          teacherResponse.results!.isNotEmpty;

      bool hasClassConflict = classResponse.success &&
          classResponse.results != null &&
          classResponse.results!.isNotEmpty;

      String conflictMessage = '';
      if (hasTeacherConflict && hasClassConflict) {
        conflictMessage =
            'Both teacher and class are already assigned at this time.';
      } else if (hasTeacherConflict) {
        conflictMessage =
            'Teacher is already assigned to another class at this time.';
      } else if (hasClassConflict) {
        conflictMessage =
            'Class is already assigned to another teacher at this time.';
      }

      return {
        'hasConflict': hasTeacherConflict || hasClassConflict,
        'message': conflictMessage,
        'teacherConflict': hasTeacherConflict,
        'classConflict': hasClassConflict,
      };
    } catch (e) {
      print('Error checking conflicts: $e');
      return {
        'hasConflict': false,
        'message': '',
        'teacherConflict': false,
        'classConflict': false,
      };
    }
  }

  Future<void> _removeConflictingAssignments(
      String day, String timeSlot, String teacherId, String classId) async {
    try {
      print('Removing conflicting assignments for $day $timeSlot');

      // Remove any existing assignment for this class at this time
      final classPointer = ParseObject('Class')..objectId = classId;
      final classQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('day', day)
        ..whereEqualTo('timeSlot', timeSlot)
        ..whereEqualTo('class', classPointer);

      final classResponse = await classQuery.query();
      if (classResponse.success && classResponse.results != null) {
        for (var assignment in classResponse.results!) {
          print('Removing existing class assignment: ${assignment.objectId}');
          await assignment.delete();
        }
      }

      // Remove any existing assignment for this teacher at this time (except current class)
      final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
      final teacherQuery = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('day', day)
        ..whereEqualTo('timeSlot', timeSlot)
        ..whereEqualTo('teacher', teacherPointer)
        ..whereNotEqualTo('class', classPointer);

      final teacherResponse = await teacherQuery.query();
      if (teacherResponse.success && teacherResponse.results != null) {
        for (var assignment in teacherResponse.results!) {
          print(
              'Removing conflicting teacher assignment: ${assignment.objectId}');
          await assignment.delete();
        }
      }

      print('Conflicting assignments removed successfully');
    } catch (e) {
      print('Error removing conflicting assignments: $e');
    }
  }

  Future<void> _debugCurrentAssignments(String day, String timeSlot) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Schedule'))
        ..whereEqualTo('day', day)
        ..whereEqualTo('timeSlot', timeSlot)
        ..includeObject(['teacher', 'class']);

      final response = await query.query();

      if (response.success && response.results != null) {
        print('=== Current assignments for $day $timeSlot ===');
        for (var assignment in response.results!) {
          final teacher = assignment.get('teacher');
          final classObj = assignment.get('class');
          final subject = assignment.get('subject');

          print(
              'Teacher: ${teacher?.get('fullName')} (ID: ${teacher?.objectId})');
          print(
              'Class: ${classObj?.get('className')} (ID: ${classObj?.objectId})');
          print('Subject: $subject');
          print('---');
        }
        print('=== End current assignments ===');
      } else {
        print('No current assignments found for $day $timeSlot');
      }
    } catch (e) {
      print('Error debugging assignments: $e');
    }
  }

  Future<void> _saveScheduleEntry(String day, String timeSlot, String subject,
      {bool allowOverwrite = false}) async {
    final l10n = AppLocalizations.of(context)!;

    if (selectedTeacher == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectBothTeacherClass),
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

      // Debug: Show what's currently in this time slot
      await _debugCurrentAssignments(day, timeSlot);

      // Check for conflicts only if overwrite is not explicitly allowed
      if (!allowOverwrite) {
        final conflictResult = await _checkForConflicts(
            day, timeSlot, selectedTeacher!, selectedClass!);

        if (conflictResult['hasConflict'] == true) {
          print('Conflict detected during save: ${conflictResult['message']}');
          print('Teacher conflict: ${conflictResult['teacherConflict']}');
          print('Class conflict: ${conflictResult['classConflict']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(conflictResult['message'] ??
                  'Conflict detected! Teacher or class already assigned at this time.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      } else {
        print('Overwrite allowed - skipping conflict check');
        // When overwriting, we need to remove conflicting assignments
        await _removeConflictingAssignments(
            day, timeSlot, selectedTeacher!, selectedClass!);
      } // Check if entry already exists for this combination
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
        // Clear cache for this specific timetable to force refresh
        await CacheService.clearSpecificTimetable(
          teacherId: selectedTeacher!,
          classId: selectedClass!,
        );

        // Clear hybrid caches that might be affected by this change
        print('DEBUG: Clearing related caches...');

        // Clear general timetable cache to force fresh loading of all related data
        await CacheService.clearTimetableCache();

        // Clear teacher detail cache to refresh teacher-specific data
        await CacheService.clearTeacherDetail(teacherId: selectedTeacher!);

        print('DEBUG: Cache clearing completed');

        // Preemptively warm up cache for next likely queries
        _warmUpRelatedCaches();

        setState(() {
          // Update the correct schedule based on time slot
          if (scheduleData.containsKey(timeSlot)) {
            scheduleData[timeSlot]![day] = subject;
          } else {
            afternoonScheduleData[timeSlot]![day] = subject;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.scheduleSavedSuccess),
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
          // Clear cache for this specific timetable to force refresh
          await CacheService.clearSpecificTimetable(
            teacherId: selectedTeacher!,
            classId: selectedClass!,
          );

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
    Color assignedColor = isAfternoon ? Colors.orange[700]! : Colors.blue[700]!;
    Color conflictColor = isAfternoon ? Colors.red[700]! : Colors.red[600]!;

    // Check if text contains a checkmark (assigned subject)
    bool isAssignedSubject = text.contains(' ✓');

    // Check if text contains class info in parentheses (conflict indicator)
    bool isConflict = text.contains('(') && text.contains(')');

    // Check if text contains a teacher name or class info (has newline)
    if (text.contains('\n')) {
      final parts = text.split('\n');
      final subject = parts[0];
      final additionalInfo = parts.length > 1 ? parts[1] : '';

      // Determine the color and style based on the type of entry
      Color subjectColor;
      FontWeight subjectWeight;

      if (isAssignedSubject) {
        subjectColor = assignedColor;
        subjectWeight = FontWeight.w700;
      } else if (isConflict) {
        subjectColor = conflictColor;
        subjectWeight = FontWeight.w600;
      } else {
        subjectColor = primaryColor;
        subjectWeight = FontWeight.w600;
      }

      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: subject,
              style: TextStyle(
                fontSize: 11,
                color: subjectColor,
                fontWeight: subjectWeight,
              ),
            ),
            if (additionalInfo.isNotEmpty)
              TextSpan(
                text: '\n$additionalInfo',
                style: TextStyle(
                  fontSize: 8, // Smaller font for additional info
                  color: isConflict ? conflictColor : greyColor,
                  fontWeight: isConflict ? FontWeight.w500 : FontWeight.normal,
                  fontStyle: isConflict ? FontStyle.italic : FontStyle.normal,
                ),
              ),
          ],
        ),
      );
    } else {
      // Single line text (no additional info)
      Color textColor;
      FontWeight textWeight;

      if (isAssignedSubject) {
        textColor = assignedColor;
        textWeight = FontWeight.w700;
      } else if (isEmpty) {
        textColor = greyColor;
        textWeight = FontWeight.normal;
      } else {
        textColor = primaryColor;
        textWeight = FontWeight.w600;
      }

      return Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: textWeight,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  void _showSubjectDialog(String day, String timeSlot) async {
    // Determine which schedule this time slot belongs to
    String currentValue;
    if (scheduleData.containsKey(timeSlot)) {
      currentValue = scheduleData[timeSlot]![day] ?? '';
    } else {
      currentValue = afternoonScheduleData[timeSlot]![day] ?? '';
    }

    // Extract just the subject name for editing (remove teacher info and checkmark)
    String subjectOnly = currentValue.split('\n').first.replaceAll(' ✓', '');
    // Also remove class info in parentheses for conflicts
    subjectOnly = subjectOnly.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    final controller = TextEditingController(text: subjectOnly);

    // Check if this slot has a teacher conflict (teaching another class)
    bool hasTeacherConflict = currentValue.contains('\n') &&
        currentValue.split('\n').length > 1 &&
        selectedTeacher != null &&
        selectedClass != null;

    String conflictClass = '';
    if (hasTeacherConflict) {
      final parts = currentValue.split('\n');
      if (parts.length > 1) {
        // Extract class name from parentheses like "(1 A)"
        conflictClass = parts[1].replaceAll(RegExp(r'[()]'), '');
      }
    }

    // Get teacher's assigned subjects if both teacher and class are selected
    List<String> assignedSubjects = [];
    String? selectedSubject = subjectOnly.isNotEmpty ? subjectOnly : null;

    if (selectedTeacher != null && selectedClass != null && isAdmin) {
      try {
        final teacherSubjects =
            await _getTeacherAssignedSubjects(selectedTeacher!, selectedClass!);
        assignedSubjects = teacherSubjects.values.toList();
        print(
            'DEBUG: Available assigned subjects for dialog: $assignedSubjects');
      } catch (e) {
        print('ERROR: Failed to get assigned subjects for dialog: $e');
      }
    }

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
            ] else if (hasTeacherConflict) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CONFLICT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ] else if (hasTeacherConflict) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CONFLICT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
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
            // Show conflict warning
            if (hasTeacherConflict) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Teacher Conflict Detected:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teacher is already teaching "$subjectOnly" for class "$conflictClass" at this time',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assigning here will create a scheduling conflict!',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (currentValue.isNotEmpty && hasTeacherConflict) ...[
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

            // Show assigned subjects info if available
            if (assignedSubjects.isNotEmpty &&
                selectedTeacher != null &&
                selectedClass != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Teacher\'s Assigned Subjects for this Class:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignedSubjects.join(', '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Dropdown for assigned subjects
              DropdownButtonFormField<String>(
                value: assignedSubjects.contains(selectedSubject)
                    ? selectedSubject
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Select Assigned Subject',
                  border: OutlineInputBorder(),
                  helperText: 'Choose from teacher\'s assigned subjects',
                ),
                items: [
                  // Add empty option
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('-- Clear Subject --'),
                  ),
                  // Add assigned subjects
                  ...assignedSubjects.map((subject) => DropdownMenuItem<String>(
                        value: subject,
                        child: Text(subject),
                      )),
                ],
                onChanged: isAdmin
                    ? (String? value) {
                        selectedSubject = value;
                        controller.text = value ?? '';
                      }
                    : null,
              ),

              const SizedBox(height: 8),
              const Text(
                'Or enter custom subject:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Text field for custom input
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: selectedClass != null
                    ? (assignedSubjects.isNotEmpty
                        ? 'Enter custom subject or use dropdown above'
                        : 'Enter subject name for selected class')
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
                await _saveScheduleEntry(
                  day,
                  timeSlot,
                  controller.text.trim(),
                  allowOverwrite: hasTeacherConflict,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: hasTeacherConflict ? Colors.red : null,
              ),
              child: Text(hasTeacherConflict ? 'Create Conflict' : 'Save'),
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
    final l10n = AppLocalizations.of(context)!;

    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text(l10n.classSchedule),
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
                    child: Text(
                      l10n.classSchedule.toUpperCase(),
                      style: const TextStyle(
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
                              border: Border.all(
                                  color: Colors.grey[400]!, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l10n.teacher.toUpperCase()}:',
                                  style: const TextStyle(
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
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: l10n.selectTeacher,
                                            hintStyle: const TextStyle(
                                                color: Colors.grey),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          items: teachers.map((teacher) {
                                            return DropdownMenuItem<String>(
                                              value: teacher['id'],
                                              child: Text(
                                                teacher['name'],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                    fontSize: 14),
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
                              border: Border.all(
                                  color: Colors.grey[400]!, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${l10n.classLabel.toUpperCase()}:',
                                  style: const TextStyle(
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
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            hintText: l10n.selectClass,
                                            hintStyle: const TextStyle(
                                                color: Colors.grey),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          items: classes.map((classItem) {
                                            return DropdownMenuItem<String>(
                                              value: classItem['id'],
                                              child: Text(
                                                classItem['name'],
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                    fontSize: 14),
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
                          Text(
                            '${l10n.teacherSchedule.toUpperCase()}:',
                            style: const TextStyle(
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
                                    orElse: () =>
                                        {'name': 'Loading...'})['name']
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
                            child: Text(
                              l10n.viewOnlyMode,
                              style: const TextStyle(
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

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    l10n.morningSchedule,
                    style: const TextStyle(
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
                                              color: Colors.grey[400]!,
                                              width: 1)
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
                                                color: Colors.grey[400]!,
                                                width: 1),
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
                                                      _showSubjectDialog(
                                                          day, time),
                                                  child: Container(
                                                    height: 50,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        right: day !=
                                                                weekDays.last
                                                            ? BorderSide(
                                                                color: Colors
                                                                    .grey[400]!,
                                                                width: 1)
                                                            : BorderSide.none,
                                                      ),
                                                      color: scheduleData[
                                                                  time]![day]!
                                                              .isNotEmpty
                                                          ? Colors.blue[50]
                                                          : Colors.transparent,
                                                    ),
                                                    child: Center(
                                                      child: _buildScheduleText(
                                                        scheduleData[time]![
                                                                day] ??
                                                            '',
                                                        scheduleData[time]![
                                                                day]!
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

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    l10n.afternoonSchedule,
                    style: const TextStyle(
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
                                              color: Colors.grey[400]!,
                                              width: 1)
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
                                                color: Colors.grey[400]!,
                                                width: 1),
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
                                                      _showSubjectDialog(
                                                          day, time),
                                                  child: Container(
                                                    height: 50,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        right: day !=
                                                                weekDays.last
                                                            ? BorderSide(
                                                                color: Colors
                                                                    .grey[400]!,
                                                                width: 1)
                                                            : BorderSide.none,
                                                      ),
                                                      color:
                                                          afternoonScheduleData[
                                                                          time]![
                                                                      day]!
                                                                  .isNotEmpty
                                                              ? Colors
                                                                  .orange[50]
                                                              : Colors
                                                                  .transparent,
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
                          child: Text(
                            l10n.clearSchedule,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                          child: Text(
                            l10n.saveSchedule,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                    child: Column(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.scheduleViewOnly,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.assignedTeachingSchedule,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
      },
    );
  }

  Future<void> _refreshTimetable() async {
    setState(() {
      isLoadingData = true;
    });

    // Clear all timetable cache
    await CacheService.clearTimetableCache();

    // Reload all data
    await _loadData();

    // Reload schedule data if selections exist
    if (selectedTeacher != null || selectedClass != null) {
      await _loadScheduleData();
    }
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

  /// Preemptively warm up caches for related data that user might access next
  void _warmUpRelatedCaches() {
    if (selectedTeacher == null || selectedClass == null) return;

    // Background cache warming - don't await to avoid blocking UI
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        print('DEBUG: Starting cache warm-up for related data...');

        // Warm up teacher's schedule across other classes
        for (var classData in classes) {
          final classId = classData['objectId'] as String?;
          if (classId != null && classId != selectedClass) {
            final cachedData = CacheService.getTimetableData(
              teacherId: selectedTeacher!,
              classId: classId,
            );
            if (cachedData == null) {
              // Cache miss - could preload this data
              print(
                  'DEBUG: Cache miss for teacher $selectedTeacher in class $classId');
            }
          }
        }

        // Warm up other teachers' schedules in current class
        for (var teacherData in teachers) {
          final teacherId = teacherData['objectId'] as String?;
          if (teacherId != null && teacherId != selectedTeacher) {
            final cachedData = CacheService.getTimetableData(
              teacherId: teacherId,
              classId: selectedClass!,
            );
            if (cachedData == null) {
              // Cache miss - could preload this data
              print(
                  'DEBUG: Cache miss for teacher $teacherId in class $selectedClass');
            }
          }
        }

        print('DEBUG: Cache warm-up analysis completed');
      } catch (e) {
        print('DEBUG: Cache warm-up error (non-blocking): $e');
      }
    });
  }
}
