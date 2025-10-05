import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
  final GlobalKey qrKey = GlobalKey();

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
                              child: RepaintBoundary(
                                key: qrKey,
                                child: QrImageView(
                                  data: selectedClassId!,
                                  version: QrVersions.auto,
                                  size: 220.0,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              (cachedClasses.firstWhere(
                                    (cls) => cls['objectId'] == selectedClassId,
                                    orElse: () =>
                                        <String, String?>{'classname': ''},
                                  )['classname'] ??
                                  ''),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Save QR to Gallery'),
                              onPressed: () async {
                                try {
                                  RenderRepaintBoundary boundary =
                                      qrKey.currentContext!.findRenderObject()
                                          as RenderRepaintBoundary;
                                  ui.Image image =
                                      await boundary.toImage(pixelRatio: 3.0);
                                  ByteData? byteData = await image.toByteData(
                                      format: ui.ImageByteFormat.png);
                                  Uint8List pngBytes =
                                      byteData!.buffer.asUint8List();
                                  final result =
                                      await ImageGallerySaver.saveImage(
                                    pngBytes,
                                    quality: 100,
                                    name: 'class_qr_${selectedClassId}',
                                  );
                                  if (result['isSuccess'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('QR code saved to gallery')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to save QR code: ${result['errorMessage'] ?? 'Unknown error'}')),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to save QR code: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}
