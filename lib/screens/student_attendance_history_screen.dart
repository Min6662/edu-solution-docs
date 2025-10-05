import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../services/attendance_service.dart';
import '../services/cache_service.dart';
import '../services/class_service.dart';

class StudentAttendanceHistoryScreen extends StatefulWidget {
  final String? classId;
  const StudentAttendanceHistoryScreen({super.key, this.classId});

  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  List<Map<String, dynamic>> _attendanceRecords = [];
  String? _selectedClassId;
  String? _selectedStatus;
  DateTime? _selectedDate = DateTime.now(); // Set default to current date
  bool _loading = false;
  List<Map<String, dynamic>> _classList = [];

  final AttendanceService _attendanceService = AttendanceService();
  final CacheService _cacheService = CacheService();
  final String _cacheKey = 'attendance_history';

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.classId;
    _selectedDate = DateTime.now(); // Ensure default is set on init
    _loadClassList();
    _loadCachedAttendance();
    _fetchAttendance();
  }

  Future<void> _loadClassList() async {
    final classes = await ClassService.getClassList();
    setState(() {
      _classList = classes;
    });
  }

  Future<void> _loadCachedAttendance() async {
    final cached = await _cacheService.getList(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _attendanceRecords = List<Map<String, dynamic>>.from(cached);
      });
    }
  }

  Future<void> _fetchAttendance({bool clearCache = false}) async {
    setState(() {
      _loading = true;
    });
    if (clearCache) {
      await _cacheService.clear(_cacheKey);
    }
    final records = await _attendanceService.fetchStudentAttendance(
      classId: _selectedClassId,
      session: _selectedStatus, // Pass as session, not status
      date: _selectedDate,
    );
    List<Map<String, dynamic>> recordMaps;
    if (records.isNotEmpty && records.first is Map<String, dynamic>) {
      recordMaps = List<Map<String, dynamic>>.from(records);
    } else {
      recordMaps = records.map((r) {
        String? classname = r.get<String>('classname');
        if (classname == null || classname.isEmpty) {
          final classObj = r.get('class');
          if (classObj is ParseObject) {
            classname = classObj.get<String>('classname') ?? 'Unknown';
          } else {
            classname = 'Unknown';
          }
        }
        return {
          'status': r.get<String>('status') ?? '',
          'session': r.get<String>('session') ?? '',
          'date':
              r.get<DateTime>('date')?.toIso8601String().substring(0, 10) ?? '',
          'studentName': r.get<String>('studentName') ?? 'Unknown',
          'classname': classname,
        };
      }).toList();
    }
    // Debug print: show all records and session values
    debugPrint('Attendance records fetched:');
    for (final rec in recordMaps) {
      debugPrint(rec.toString());
    }
    // Apply filters to cached data
    List<Map<String, dynamic>> filtered = recordMaps;
    if (_selectedClassId != null) {
      final selectedClassObj = _classList.firstWhere(
        (cls) => cls['objectId'] == _selectedClassId,
        orElse: () => <String, dynamic>{},
      );
      final selectedClassName = selectedClassObj['classname'];
      if (selectedClassName != null) {
        filtered =
            filtered.where((r) => r['classname'] == selectedClassName).toList();
      }
    }
    // Fix: session filter should only apply if not null AND not empty AND not 'All Sessions'
    if (_selectedStatus != null &&
        _selectedStatus != '' &&
        _selectedStatus != 'Sessions') {
      filtered =
          filtered.where((r) => r['session'] == _selectedStatus).toList();
    }
    if (_selectedDate != null) {
      filtered = filtered.where((r) {
        final dateStr = r['date'] ?? '';
        if (dateStr.isEmpty) return false;
        final date = DateTime.tryParse(dateStr);
        return date != null &&
            date.year == _selectedDate!.year &&
            date.month == _selectedDate!.month &&
            date.day == _selectedDate!.day;
      }).toList();
    }
    await _cacheService.saveList(_cacheKey, recordMaps);
    setState(() {
      _attendanceRecords = filtered;
      _loading = false;
    });
  }

  void _refreshAttendance() async {
    await _cacheService.clear(_cacheKey);
    await _fetchAttendance(clearCache: true);
  }

  Widget _buildFilters() {
    // Use _classList for dropdown
    final classDropdownItems = [
      const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
      ..._classList.map((cls) => DropdownMenuItem<String?>(
            value: cls['objectId'] as String?,
            child: Text(cls['classname'] ?? ''),
          ))
    ];

    // Ensure selected value is valid
    if (_selectedClassId != null &&
        !_classList.any((cls) => cls['objectId'] == _selectedClassId)) {
      _selectedClassId = null;
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButton<String?>(
                hint: const Text('Class'),
                value: _selectedClassId,
                isExpanded: true,
                items: classDropdownItems,
                onChanged: (val) {
                  setState(() {
                    _selectedClassId = val;
                  });
                  _fetchAttendance();
                },
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButton<String?>(
                hint: const Text('Session'),
                value: _selectedStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem<String?>(
                      value: null, child: Text('All Sessions')),
                  DropdownMenuItem<String?>(
                      value: 'Morning', child: Text('Morning')),
                  DropdownMenuItem<String?>(
                      value: 'Afternoon', child: Text('Afternoon')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val;
                  });
                  _fetchAttendance();
                },
              ),
            ),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                    _fetchAttendance();
                  }
                },
                child: Text(_selectedDate == null
                    ? 'Date'
                    : _selectedDate!.toIso8601String().substring(0, 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await _fetchAttendance(clearCache: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_attendanceRecords.isEmpty
                    ? const Column(
                        children: [
                          SizedBox(height: 80),
                          Icon(Icons.history, size: 64, color: Colors.blue),
                          SizedBox(height: 24),
                          Text(
                            'Attendance history will appear here.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _attendanceRecords.length,
                        itemBuilder: (context, i) {
                          final record = _attendanceRecords[i];
                          final status = record['status'] ?? '';
                          final dateStr = record['date'] ?? 'Unknown';
                          final studentName =
                              record['studentName'] ?? 'Unknown';
                          final className = record['classname'] ?? 'Unknown';
                          final session = record['session'] ?? '';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                  'Class: $className\nDate: $dateStr\nSession: $session',
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
