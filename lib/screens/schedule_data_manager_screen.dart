import 'package:flutter/material.dart';
import '../utils/schedule_checker.dart';

class ScheduleDataManagerScreen extends StatefulWidget {
  const ScheduleDataManagerScreen({super.key});

  @override
  State<ScheduleDataManagerScreen> createState() =>
      _ScheduleDataManagerScreenState();
}

class _ScheduleDataManagerScreenState extends State<ScheduleDataManagerScreen> {
  Map<String, dynamic>? scheduleData;
  bool isLoading = true;
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
    _checkScheduleData();
  }

  Future<void> _checkScheduleData() async {
    setState(() {
      isLoading = true;
    });

    final data = await ScheduleChecker.checkScheduleData();

    setState(() {
      scheduleData = data;
      isLoading = false;
    });
  }

  Future<void> _addSampleData() async {
    setState(() {
      isAdding = true;
    });

    final success = await ScheduleChecker.addSampleScheduleEntries();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sample schedule entries added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _checkScheduleData(); // Refresh data
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to add sample entries. Make sure you have teachers and classes in your database.'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      isAdding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Data Manager'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule Data Status',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _buildStatusRow(
                                'Has Schedule Data:',
                                scheduleData?['hasData'] == true
                                    ? 'Yes'
                                    : 'No'),
                            if (scheduleData?['hasData'] == true) ...[
                              _buildStatusRow('Total Entries:',
                                  '${scheduleData?['totalEntries'] ?? 0}'),
                              _buildStatusRow('Teachers with Schedules:',
                                  '${scheduleData?['teacherCount'] ?? 0}'),
                              _buildStatusRow('Classes with Schedules:',
                                  '${scheduleData?['classCount'] ?? 0}'),
                              _buildStatusRow(
                                  'Days Covered:',
                                  (scheduleData?['days'] as List?)
                                          ?.join(', ') ??
                                      'None'),
                              _buildStatusRow(
                                  'Time Slots:',
                                  (scheduleData?['timeSlots'] as List?)
                                          ?.join(', ') ??
                                      'None'),
                            ],
                            if (scheduleData?['error'] != null)
                              _buildStatusRow('Error:', scheduleData!['error']),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Current Time Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Time Info',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusRow('Current Day:',
                                ScheduleChecker.getCurrentDayName()),
                            _buildStatusRow('Current Time Slot:',
                                ScheduleChecker.getCurrentTimeSlot()),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sample Entries (if data exists)
                    if (scheduleData?['hasData'] == true &&
                        scheduleData?['sampleEntries'] != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sample Schedule Entries',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ...(scheduleData!['sampleEntries'] as List)
                                  .map((entry) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    '${entry['teacher']} - ${entry['class']} - ${entry['day']} ${entry['timeSlot']} - ${entry['subject']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checkScheduleData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isAdding ? null : _addSampleData,
                            icon: isAdding
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add),
                            label: Text(
                                isAdding ? 'Adding...' : 'Add Sample Data'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Instructions
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'What to do next:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (scheduleData?['hasData'] != true) ...[
                              const Text(
                                  '📝 Your Schedule table is empty or missing data.'),
                              const SizedBox(height: 4),
                              const Text('🔧 You can either:'),
                              const SizedBox(height: 4),
                              const Text(
                                  '  1. Click "Add Sample Data" to create test entries'),
                              const SizedBox(height: 4),
                              const Text(
                                  '  2. Use your existing Time Table screen to add schedules'),
                              const SizedBox(height: 4),
                              const Text(
                                  '  3. Import your existing schedule data'),
                            ] else ...[
                              const Text('✅ Great! You have schedule data.'),
                              const SizedBox(height: 4),
                              const Text(
                                  '🎯 Your QR attendance system should work now!'),
                              const SizedBox(height: 4),
                              const Text(
                                  '📱 Test by scanning QR codes with class codes.'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
