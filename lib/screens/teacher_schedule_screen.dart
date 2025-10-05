import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<Map<String, dynamic>> schedule;
  final Future<void> Function()? onRefresh;

  const TeacherScheduleScreen({
    Key? key,
    required this.teacherId,
    required this.teacherName,
    required this.schedule,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  bool isLoading = false;
  List<Map<String, dynamic>> schedule = [];

  @override
  void initState() {
    super.initState();
    schedule = List<Map<String, dynamic>>.from(widget.schedule);
  }

  Future<List<Map<String, dynamic>>> fetchTeacherSchedule(
      String teacherId) async {
    final teacherPointer = ParseObject('Teacher')..objectId = teacherId;
    final query = QueryBuilder<ParseObject>(ParseObject('ClassSubjectTeacher'))
      ..whereEqualTo('teacher', teacherPointer)
      ..includeObject(['class', 'subject']); // include pointers for names
    final response = await query.query();

    if (response.success && response.results != null) {
      return (response.results as List<ParseObject>).map((obj) {
        final classObj = obj.get<ParseObject>('class');
        final subjectObj = obj.get<ParseObject>('subject');
        return {
          'subjectName': subjectObj?.get<String>('subjectName') ?? '',
          'className': classObj?.get<String>('classname') ?? '',
          'dayOfWeek': obj.get<String>('dayOfWeek') ?? '',
          'startTime': obj.get<String>('startTime') ?? '',
          'endTime': obj.get<String>('endTime') ?? '',
          'period': obj.get<String>('period') ?? '',
        };
      }).toList();
    } else {
      return [];
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => isLoading = true);
    try {
      List<Map<String, dynamic>> newSchedule;
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
        // Optionally, you can update schedule here if onRefresh returns data
        newSchedule = await fetchTeacherSchedule(widget.teacherId);
      } else {
        newSchedule = await fetchTeacherSchedule(widget.teacherId);
      }
      if (!mounted) return;
      setState(() {
        schedule = newSchedule;
      });
    } catch (e) {
      // Optionally show error
      debugPrint('Failed to refresh: $e');
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule for ${widget.teacherName}'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: schedule.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text('No schedule assigned')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...schedule.map((sch) => Card(
                              color: Colors.blue[50],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${sch['subjectName']} (${sch['className']})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${sch['dayOfWeek']}  ${sch['startTime']} - ${sch['endTime']}',
                                    ),
                                    if ((sch['period'] ?? '').isNotEmpty)
                                      Text('Period: ${sch['period']}'),
                                  ],
                                ),
                              ),
                            ))
                      ],
                    ),
            ),
    );
  }
}
