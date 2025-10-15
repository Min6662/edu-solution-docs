import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/attendance_service.dart';
import '../models/attendance_model.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class AdminAttendanceOverviewScreen extends StatefulWidget {
  const AdminAttendanceOverviewScreen({super.key});

  @override
  State<AdminAttendanceOverviewScreen> createState() =>
      _AdminAttendanceOverviewScreenState();
}

class _AdminAttendanceOverviewScreenState
    extends State<AdminAttendanceOverviewScreen> {
  List<AttendanceRecord> allAttendanceRecords = [];
  List<Map<String, dynamic>> teachers = [];
  Map<String, String> teacherNames = {};
  bool isLoading = true;
  String? selectedTeacherId;
  DateTime selectedDate = DateTime.now();
  String filterPeriod = 'today'; // today, week, month, all

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  Future<void> _initializeAndFetch() async {
    await _loadTeachers();
    await _fetchAllAttendanceRecords();
  }

  Future<void> _loadTeachers() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Teacher'));
      final response = await query.query();

      if (response.success && response.results != null) {
        final teacherList = response.results!.map((teacher) {
          final id = teacher.objectId ?? '';
          final name = teacher.get<String>('fullName') ?? 'Unknown Teacher';
          teacherNames[id] = name;
          return {
            'id': id,
            'name': name,
          };
        }).toList();

        setState(() {
          teachers = teacherList;
        });
      }
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> _fetchAllAttendanceRecords() async {
    setState(() => isLoading = true);

    try {
      DateTime? startDate;
      DateTime? endDate;

      // Set date range based on filter
      final now = DateTime.now();
      switch (filterPeriod) {
        case 'today':
          startDate =
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          endDate = now;
          break;
        case 'month':
          startDate = now.subtract(const Duration(days: 30));
          endDate = now;
          break;
        case 'all':
          // No date filter for all records
          break;
      }

      // Fetch records
      List<AttendanceRecord> records = [];

      if (selectedTeacherId != null) {
        // Fetch for specific teacher
        records = await AttendanceService.getTeacherAttendanceHistory(
          teacherId: selectedTeacherId!,
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        // Fetch for all teachers
        records = await _fetchAllTeachersAttendance(startDate, endDate);
      }

      setState(() {
        allAttendanceRecords = records;
        isLoading = false;
      });

      print(
          'Fetched ${records.length} attendance records for filter: $filterPeriod');
    } catch (e) {
      print('Error fetching attendance records: $e');
      setState(() => isLoading = false);
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  localizations.errorLoadingAttendanceRecords(e.toString()))),
        );
      }
    }
  }

  Future<List<AttendanceRecord>> _fetchAllTeachersAttendance(
      DateTime? startDate, DateTime? endDate) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('TeacherAttendance'))
        ..includeObject(['teacher'])
        ..orderByDescending('scannedTime');

      if (startDate != null) {
        query.whereGreaterThan('scannedTime', startDate);
      }
      if (endDate != null) {
        query.whereLessThan('scannedTime', endDate);
      }

      final response = await query.query();

      if (response.success && response.results != null) {
        return (response.results as List<ParseObject>).map((obj) {
          return AttendanceRecord.fromParseObject(obj.toJson());
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching all teachers attendance: $e');
      return [];
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
        filterPeriod = 'today'; // Reset to today filter when date is selected
      });
      await _fetchAllAttendanceRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final onTimeCount =
        allAttendanceRecords.where((r) => r.status == 'On Time').length;
    final lateCount =
        allAttendanceRecords.where((r) => r.status == 'Late').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.adminAllQRAttendance),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllAttendanceRecords,
            tooltip: localizations.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters and Stats Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(localizations.totalScans,
                        '${allAttendanceRecords.length}', Colors.blue),
                    _buildStatCard(
                        localizations.onTime, '$onTimeCount', Colors.green),
                    _buildStatCard(
                        localizations.late, '$lateCount', Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),

                // Filters Row - Wrapped in container to prevent overflow
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    children: [
                      // First row: Teacher and Period filters
                      Row(
                        children: [
                          // Teacher Filter
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String?>(
                              value: selectedTeacherId,
                              decoration: InputDecoration(
                                labelText: localizations.filterByTeacher,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              isExpanded: true,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(localizations.allTeachers,
                                      style: const TextStyle(fontSize: 14)),
                                ),
                                ...teachers
                                    .map((teacher) => DropdownMenuItem<String?>(
                                          value: teacher['id'],
                                          child: Text(teacher['name'],
                                              style:
                                                  const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.ellipsis),
                                        )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedTeacherId = value;
                                });
                                _fetchAllAttendanceRecords();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Period Filter
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: filterPeriod,
                              decoration: InputDecoration(
                                labelText: localizations.period,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                    value: 'today',
                                    child: Text(localizations.today,
                                        style: const TextStyle(fontSize: 14))),
                                DropdownMenuItem(
                                    value: 'week',
                                    child: Text(localizations.week,
                                        style: const TextStyle(fontSize: 14))),
                                DropdownMenuItem(
                                    value: 'month',
                                    child: Text(localizations.month,
                                        style: const TextStyle(fontSize: 14))),
                                DropdownMenuItem(
                                    value: 'all',
                                    child: Text(localizations.all,
                                        style: const TextStyle(fontSize: 14))),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  filterPeriod = value!;
                                });
                                _fetchAllAttendanceRecords();
                              },
                            ),
                          ),
                        ],
                      ),

                      // Second row: Date selector (only for today filter)
                      if (filterPeriod == 'today') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(localizations
                                .dateLabel(_formatDate(selectedDate))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Attendance Records List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : allAttendanceRecords.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchAllAttendanceRecords,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: allAttendanceRecords.length,
                          itemBuilder: (context, index) {
                            final record = allAttendanceRecords[index];
                            return _buildAttendanceCard(record);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            localizations.noQRAttendanceRecordsFound,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedTeacherId != null
                ? localizations.noRecordsForSelectedTeacher(
                    teacherNames[selectedTeacherId] ??
                        localizations.unknownTeacher)
                : localizations.noTeachersScannedQR,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final localizations = AppLocalizations.of(context)!;
    final isLate = record.status == 'Late';
    final statusColor = isLate ? Colors.orange : Colors.green;
    final statusIcon = isLate ? Icons.schedule : Icons.check_circle;
    final teacherName =
        teacherNames[record.teacherId] ?? localizations.unknownTeacher;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with teacher name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '👨‍🏫 $teacherName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        '${record.subjectName.isEmpty ? localizations.generalClass : record.subjectName}',
                        style: const TextStyle(
                          fontSize: 16,
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
                    localizations.classTime,
                    '${_formatTime(record.classStartTime)} - ${_formatTime(record.classEndTime)}',
                    Icons.schedule,
                  ),
                  const SizedBox(height: 8),
                  _buildTimeRow(
                    localizations.scannedAt,
                    _formatTime(record.scannedTime),
                    Icons.qr_code_scanner,
                  ),
                  if (isLate) ...[
                    const SizedBox(height: 8),
                    _buildTimeRow(
                      localizations.delay,
                      localizations.minutesLate(record.scannedTime
                          .difference(record.classStartTime)
                          .inMinutes),
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
            fontWeight: FontWeight.w500,
            color: color ?? Colors.grey.shade700,
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
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
