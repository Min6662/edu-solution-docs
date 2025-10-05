import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import '../screens/class_qr_code_screen.dart';
import '../services/class_service.dart';
import '../screens/enrolled_students_screen.dart';

class ClassList extends StatefulWidget {
  const ClassList({super.key});

  @override
  State<ClassList> createState() => _ClassListState();
}

class _ClassListState extends State<ClassList> {
  List<Map<String, dynamic>> classList = [];
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadCachedClassList();
  }

  Future<void> _loadCachedClassList() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final box = await Hive.openBox('classListBox');
      final cached = box.get('classList') as List<dynamic>?;
      if (cached != null && cached.isNotEmpty) {
        classList =
            cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() {
          loading = false;
        });
      } else {
        await _loadClassList(forceRefresh: false);
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load cached classes: \\${e.toString()}';
        loading = false;
      });
    }
  }

  Future<void> _loadClassList({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final classes = await ClassService.getClassList();
      classList = classes;
      final box = await Hive.openBox('classListBox');
      await box.put('classList', classList);
      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load classes: \\${e.toString()}';
        loading = false;
      });
    }
  }

  Future<void> _refreshClassList() async {
    final box = await Hive.openBox('classListBox');
    await box.delete('classList');
    await _loadClassList(forceRefresh: true);
  }

  void _showAddClassDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Class'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Class Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newClass = ParseObject('Class')..set('classname', name);
                  final response = await newClass.save();
                  if (response.success) {
                    Navigator.of(context).pop();
                    _loadClassList(forceRefresh: true);
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Class List'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            tooltip: 'Class QR Codes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClassQRCodeScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Class List',
            onPressed: () {
              _refreshClassList();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Classes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error.isNotEmpty
                      ? Center(
                          child: Text(error,
                              style: const TextStyle(color: Colors.red)))
                      : classList.isEmpty
                          ? const Center(child: Text('No classes found.'))
                          : ListView.builder(
                              itemCount: classList.length,
                              itemBuilder: (context, index) {
                                final classObj = classList[index];
                                final className =
                                    classObj['classname'] ?? 'Class';
                                final classId = classObj['objectId'] ?? '';
                                return Card(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 2,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    onTap: () {
                                      _showEditClassDialog(classObj);
                                    },
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange[100],
                                      child: Icon(Icons.class_,
                                          color: Colors.orange[700]),
                                    ),
                                    title: Text(className),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange[400],
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EnrolledStudentsScreen(
                                              classId: classId,
                                              className: className,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('View'),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClassDialog,
        backgroundColor: Colors.blue,
        tooltip: 'Add Class',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditClassDialog(Map<String, dynamic> classObj) {
    final controller = TextEditingController(text: classObj['classname'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Class'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Class Name'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Delete class
                final classPointer = ParseObject('Class')
                  ..objectId = classObj['objectId'];
                await classPointer.delete();
                Navigator.of(context).pop();
                _loadClassList(forceRefresh: true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final classPointer = ParseObject('Class')
                    ..objectId = classObj['objectId'];
                  classPointer.set('classname', newName);
                  await classPointer.save();
                  Navigator.of(context).pop();
                  _loadClassList(forceRefresh: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
