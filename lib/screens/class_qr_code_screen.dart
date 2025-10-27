import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';

class ClassQRCodeScreen extends StatefulWidget {
  const ClassQRCodeScreen({super.key});

  @override
  State<ClassQRCodeScreen> createState() => _ClassQRCodeScreenState();
}

class _ClassQRCodeScreenState extends State<ClassQRCodeScreen> {
  List<Map<String, dynamic>> cachedClasses = [];
  String? selectedClassId;
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadCachedClasses();
  }

  Future<void> _loadCachedClasses() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final box = await Hive.openBox('classBox');
      final List<dynamic>? cached = box.get('classes') as List<dynamic>?;
      if (cached != null && cached.isNotEmpty) {
        cachedClasses = List<Map<String, dynamic>>.from(cached);
        setState(() {
          loading = false;
        });
      } else {
        // If cache is empty, fetch from Parse and save to Hive
        await _fetchClasses();
        // Try loading again from cache after fetch
        final List<dynamic>? cachedAfterFetch =
            box.get('classes') as List<dynamic>?;
        if (cachedAfterFetch != null && cachedAfterFetch.isNotEmpty) {
          cachedClasses = List<Map<String, dynamic>>.from(cachedAfterFetch);
          setState(() {
            loading = false;
          });
        } else {
          setState(() {
            error = 'No classes found.';
            loading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load cached classes.';
        loading = false;
      });
    }
  }

  Future<void> _fetchClasses() async {
    setState(() {
      loading = true;
      error = '';
    });
    final query = QueryBuilder<ParseObject>(ParseObject('Class'));
    final response = await query.query();
    if (response.success && response.results != null) {
      final List<ParseObject> parseClasses =
          List<ParseObject>.from(response.results!);
      cachedClasses = parseClasses
          .map((cls) => {
                'objectId': cls.get<String>('objectId'),
                'classname': cls.get<String>('classname'),
              })
          .toList();
      final box = await Hive.openBox('classBox');
      await box.put('classes', cachedClasses);
      setState(() {
        loading = false;
      });
    } else {
      setState(() {
        error = 'Failed to fetch classes.';
        loading = false;
      });
    }
  }

  Future<void> _refreshClasses() async {
    final box = await Hive.openBox('classBox');
    await box.delete('classes');
    await _fetchClasses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class QR Code'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Classes',
            onPressed: () async {
              await _refreshClasses();
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Class:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      DropdownButton<String>(
                        value: selectedClassId,
                        hint: const Text('Choose a class'),
                        items: cachedClasses.map((cls) {
                          final id = cls['objectId'] ?? '';
                          final name = cls['classname'] ?? 'Unnamed';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedClassId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      if (selectedClassId != null)
                        Column(
                          children: [
                            Center(
                              child: Text(
                                (cachedClasses.firstWhere(
                                      (cls) =>
                                          cls['objectId'] == selectedClassId,
                                      orElse: () =>
                                          <String, String?>{'classname': ''},
                                    )['classname'] ??
                                    ''),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Save to Gallery temporarily disabled
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info,
                                      color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Save to Gallery feature temporarily disabled for Android compatibility',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}
