import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../services/attendance_service.dart';

class AttendanceHistoryView extends StatefulWidget {
  final String? classId;
  const AttendanceHistoryView({Key? key, this.classId}) : super(key: key);

  @override
  State<AttendanceHistoryView> createState() => _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends State<AttendanceHistoryView> {
  List<ParseObject> _attendanceRecords = [];
  bool _loading = false;
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _fetchAttendance();
    }
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _loading = true;
    });
    final records = await _attendanceService.fetchStudentAttendance(
      classId: widget.classId,
    );
    setState(() {
      _attendanceRecords = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : (_attendanceRecords.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No attendance history found.',
                    style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _attendanceRecords.length,
                itemBuilder: (context, i) {
                  final record = _attendanceRecords[i];
                  final status = record.get<String>('status') ?? '';
                  final date = record.get<DateTime>('date');
                  final studentName =
                      record.get<String>('studentName') ?? 'Unknown';
                  final className =
                      record.get<String>('classname') ?? 'Unknown';
                  String dateStr = date != null
                      ? date.toLocal().toString().substring(0, 19)
                      : 'Unknown';
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      leading: Icon(
                        status == 'present'
                            ? Icons.check_circle
                            : status == 'absent'
                                ? Icons.cancel
                                : Icons.info,
                        size: 28,
                        color: status == 'present'
                            ? Colors.green
                            : status == 'absent'
                                ? Colors.red
                                : Colors.orange,
                      ),
                      title: Text('Student: $studentName',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                          'Class: $className\nDate: $dateStr\nStatus: $status',
                          style: const TextStyle(fontSize: 14)),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // You can implement navigation to a detailed history screen or show a dialog here
                          // For now, just show a snackbar as a placeholder
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('View history for $studentName')),
                          );
                        },
                        child: const Text('View History'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  );
                },
              ));
  }
}
