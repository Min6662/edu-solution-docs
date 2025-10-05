import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../models/attendance_model.dart';
import '../services/auth_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> attendanceHistory = [];
  bool isLoading = true;
  String? teacherId;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    final user = await AuthService().getCurrentUser();
    if (user != null) {
      teacherId = user.objectId;
      await _fetchAttendanceHistory();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchAttendanceHistory() async {
    if (teacherId == null) return;

    setState(() => isLoading = true);

    try {
      final history = await AttendanceService.getTeacherAttendanceHistory(
        teacherId: teacherId!,
        startDate:
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        endDate: DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day + 1),
      );

      setState(() {
        attendanceHistory = history;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance history: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
      await _fetchAttendanceHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Date',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDate(selectedDate),
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Change Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Attendance list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : attendanceHistory.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchAttendanceHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: attendanceHistory.length,
                          itemBuilder: (context, index) {
                            final record = attendanceHistory[index];
                            return _buildAttendanceCard(record);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${_formatDate(selectedDate)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Select Different Date'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final isLate = record.status == 'Late';
    final statusColor = isLate ? Colors.orange : Colors.green;
    final statusIcon = isLate ? Icons.schedule : Icons.check_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with subject and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.subjectName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Class ${record.classCode} • ${record.period}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        record.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildTimeRow(
                    'Class Time:',
                    '${_formatTime(record.classStartTime)} - ${_formatTime(record.classEndTime)}',
                    Icons.schedule,
                  ),
                  const SizedBox(height: 8),
                  _buildTimeRow(
                    'Scanned At:',
                    _formatTime(record.scannedTime),
                    Icons.qr_code_scanner,
                  ),
                  if (isLate) ...[
                    const SizedBox(height: 8),
                    _buildTimeRow(
                      'Delay:',
                      '${record.scannedTime.difference(record.classStartTime).inMinutes} minutes late',
                      Icons.warning,
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow(String label, String value, IconData icon,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color ?? Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color ?? Colors.grey.shade800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
