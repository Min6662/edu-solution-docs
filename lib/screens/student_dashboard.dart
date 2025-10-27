import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'add_student_information_screen.dart';
import '../services/class_service.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StudentDashboard extends StatefulWidget {
  final int currentIndex;
  const StudentDashboard({super.key, this.currentIndex = 2});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  bool loading = false;
  String searchQuery = '';
  String error = '';
  String? userRole; // Add userRole field
  int _refreshCounter = 0; // Add refresh counter to force rebuilds

  @override
  void initState() {
    super.initState();
    _fetchUserRole(); // Fetch user role
    _loadCachedStudents();
  }

  // Helper method to get localized study fee period
  String _getLocalizedPeriod(String? englishPeriod) {
    if (englishPeriod == null || englishPeriod.isEmpty) return '';
    final l10n = AppLocalizations.of(context)!;
    switch (englishPeriod) {
      case '1 Month':
        return l10n.oneMonth;
      case '5 Months':
        return l10n.fiveMonths;
      case '1 Year':
        return l10n.oneYear;
      default:
        return englishPeriod;
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = await ParseUser.currentUser();
      final role = user?.get<String>('role');
      if (mounted) {
        setState(() {
          userRole = role;
        });
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  Future<void> _loadCachedStudents() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final box = await Hive.openBox('studentListBox');
      final cached = box.get('studentList') as List<dynamic>?;
      if (cached != null && cached.isNotEmpty) {
        allStudents =
            cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        filteredStudents = _filterStudents(searchQuery);
        setState(() {
          loading = false;
        });
      } else {
        await _loadStudents(forceRefresh: false);
      }
    } catch (e) {
      setState(() {
        error =
            '${AppLocalizations.of(context)!.failedToLoadCachedStudents}: ${e.toString()}';
        loading = false;
      });
    }
  }

  Future<void> _loadStudents({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final students =
          await ClassService.getStudentList(forceRefresh: forceRefresh);
      allStudents = students;
      final box = await Hive.openBox('studentListBox');
      await box.put('studentList', allStudents);
      filteredStudents = _filterStudents(searchQuery);
      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error =
            '${AppLocalizations.of(context)!.errorLoadingStudents}: ${e.toString()}';
      });
    }
  }

  Future<void> _refreshStudents() async {
    final box = await Hive.openBox('studentListBox');
    await box.delete('studentList');
    await _loadStudents(forceRefresh: true);
  }

  List<Map<String, dynamic>> _filterStudents(String query) {
    if (query.isEmpty) return allStudents;
    final lower = query.toLowerCase();
    return allStudents
        .where((stu) => (stu['name'] ?? '').toLowerCase().contains(lower))
        .toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value.trim();
      filteredStudents = _filterStudents(searchQuery);
    });
  }

  Future<Uint8List?> _getStudentImage(String studentId, String imageUrl) async {
    final box = Hive.box('studentImages');

    // Check cache first, but allow forcing refresh
    final cached = box.get(studentId);
    if (cached != null) {
      print('🖼️ Using cached image for student: $studentId');
      return Uint8List.fromList(List<int>.from(cached));
    }

    // Validate URL before attempting to load
    if (imageUrl.isNotEmpty &&
        imageUrl.startsWith('http') &&
        Uri.tryParse(imageUrl) != null) {
      try {
        print(
            '🌐 Loading fresh image for student: $studentId from: ${imageUrl.substring(0, 50)}...');
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          await box.put(studentId, response.bodyBytes);
          print('✅ Cached new image for student: $studentId');
          return response.bodyBytes;
        } else {
          print('❌ Failed to load image: HTTP ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error loading image for student $studentId: $e');
      }
    } else {
      print('❌ Invalid image URL for student $studentId: $imageUrl');
    }
    return null;
  }

  // Force refresh a specific student's image
  Future<void> _refreshStudentImage(String studentId) async {
    final box = Hive.box('studentImages');
    await box.delete(studentId);
    // Trigger a rebuild to reload the image
    if (mounted) {
      setState(() {});
    }
  }

  // Clear all image caches
  Future<void> _clearAllImageCaches() async {
    try {
      final box = Hive.box('studentImages');
      await box.clear();
      print('Cleared all image caches');
    } catch (e) {
      print('Error clearing image caches: $e');
    }
  }

  // Helper method to validate image URLs
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (!url.startsWith('http')) return false;
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteStudent(String studentId, String studentName) async {
    // Show confirmation dialog
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[600]),
              const SizedBox(width: 12),
              const Text('Confirm Deletion'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "$studentName"? This action cannot be undone.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Deleting $studentName...'),
              ],
            ),
            backgroundColor: Colors.orange[600],
          ),
        );

        // Delete from Parse Server
        final query = QueryBuilder<ParseObject>(ParseObject('Student'))
          ..whereEqualTo('objectId', studentId);
        final response = await query.query();

        if (response.success &&
            response.results != null &&
            response.results!.isNotEmpty) {
          final student = response.results!.first as ParseObject;
          final deleteResponse = await student.delete();

          if (deleteResponse.success) {
            // Remove from local cache
            setState(() {
              allStudents.removeWhere((s) => s['objectId'] == studentId);
              filteredStudents = _filterStudents(searchQuery);
            });

            // Update Hive cache
            final box = await Hive.openBox('studentListBox');
            await box.put('studentList', allStudents);

            // Show success message
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('$studentName deleted successfully'),
                  ],
                ),
                backgroundColor: Colors.green[600],
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            throw Exception('Failed to delete student from server');
          }
        } else {
          throw Exception('Student not found');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error deleting student: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _editStudent(Map<String, dynamic> studentData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentInformationScreen(
          studentData: studentData,
        ),
      ),
    );

    // If student was updated, refresh the list and clear image cache
    if (result == true) {
      print('=== DASHBOARD REFRESH DEBUG ===');
      print('Student update result: $result');
      print('Student data passed: ${studentData['name']}');
      print('Student ID: ${studentData['objectId']}');
      print('Starting cache clearing process...');

      // Clear ALL image caches to ensure fresh images
      await _clearAllImageCaches();

      // Clear the entire student list cache to force fresh data from server
      final studentListBox = await Hive.openBox('studentListBox');
      await studentListBox.delete('studentList');
      print('Cleared student list cache');

      // Force refresh the student list from server
      await _loadStudents(forceRefresh: true);
      print('Refreshed student list from server');

      // Increment refresh counter to force FutureBuilder rebuilds
      setState(() {
        _refreshCounter++;
      });
      print('Incremented refresh counter to: $_refreshCounter');
      print('==============================');
    } else {
      print('Student was not updated (result: $result)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.searchAndFindStudents,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () => _refreshStudents(),
                      tooltip: AppLocalizations.of(context)!.refresh,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.search,
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFF667EEA), width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (error.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                      strokeWidth: 3,
                    ),
                  )
                : filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No students found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final student = filteredStudents[i];
                          final name = student['name'] ?? '';
                          final years = student['yearsOfExperience'] ?? 0;

                          // Localize study fee period
                          String getLocalizedPeriod(String? englishPeriod) {
                            if (englishPeriod == null || englishPeriod.isEmpty)
                              return '';
                            final l10n = AppLocalizations.of(context)!;
                            switch (englishPeriod) {
                              case '1 Month':
                                return l10n.oneMonth;
                              case '5 Months':
                                return l10n.fiveMonths;
                              case '1 Year':
                                return l10n.oneYear;
                              default:
                                return englishPeriod;
                            }
                          }

                          final localizedStudyFeePeriod =
                              getLocalizedPeriod(student['studyFeePeriod']);

                          // Better fallback logic that handles empty strings
                          final originalPhoto = student['photo'];
                          final photoUrl = (originalPhoto == null ||
                                  originalPhoto.toString().trim().isEmpty)
                              ? '' // Set empty string instead of random image
                              : originalPhoto.toString();

                          final studentId = student['objectId'] ?? '';

                          // Debug print
                          print('=== DASHBOARD DEBUG ===');
                          print('Student: $name');
                          print('Original photo: "$originalPhoto"');
                          print('Is null: ${originalPhoto == null}');
                          print(
                              'Is empty: ${originalPhoto.toString().trim().isEmpty}');
                          print('Processed photoUrl: $photoUrl');
                          print('======================');

                          return FutureBuilder<Uint8List?>(
                            key: ValueKey(
                                '${studentId}_${photoUrl}_$_refreshCounter'),
                            future: _getStudentImage(studentId, photoUrl),
                            builder: (context, snapshot) {
                              return TeacherCard(
                                name: name,
                                role: AppLocalizations.of(context)!
                                    .studentOfAssalam,
                                years: years,
                                imageBytes: snapshot.data,
                                imageUrl: photoUrl,
                                studyFeePeriod: localizedStudyFeePeriod,
                                paidDate: student['paidDate'],
                                renewalDate: student['renewalDate'],
                                parentBusiness: student['parentBusiness'],
                                onDelete: () => _deleteStudent(studentId, name),
                                onTap: () {
                                  // Create a copy of student data with the processed photo URL
                                  final studentDataWithPhoto =
                                      Map<String, dynamic>.from(student);
                                  studentDataWithPhoto['photo'] = photoUrl;
                                  _editStudent(studentDataWithPhoto);
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddStudentInformationScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          tooltip: AppLocalizations.of(context)!.addStudent,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class TeacherCard extends StatelessWidget {
  final String name;
  final String role;
  final int years;
  final double? rating; // Make optional
  final int? ratingCount; // Make optional
  final String? hourlyRate; // Make optional for student cards
  final String imageUrl;
  final Uint8List? imageBytes;
  final VoidCallback? onDelete;
  final VoidCallback? onTap; // Add onTap callback

  // Payment tracking fields for students
  final String? studyFeePeriod;
  final String? paidDate;
  final String? renewalDate;
  final String? parentBusiness;

  const TeacherCard({
    super.key,
    required this.name,
    required this.role,
    required this.years,
    this.rating, // Optional
    this.ratingCount, // Optional
    this.hourlyRate, // Optional
    required this.imageUrl,
    this.imageBytes,
    this.onDelete,
    this.onTap, // Add onTap parameter

    // Payment tracking parameters
    this.studyFeePeriod,
    this.paidDate,
    this.renewalDate,
    this.parentBusiness,
  });

  Color _getRenewalColor() {
    if (renewalDate == null || renewalDate!.isEmpty) return Colors.grey;

    try {
      final renewal = DateTime.parse(renewalDate!);
      final now = DateTime.now();
      final daysDifference = renewal.difference(now).inDays;

      if (daysDifference < 0) {
        return Colors.red; // Overdue
      } else if (daysDifference <= 7) {
        return Colors.orange; // Due soon
      } else {
        return Colors.green; // On time
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getPaymentStatusText(BuildContext context) {
    if (renewalDate == null || renewalDate!.isEmpty) return '';

    try {
      final renewal = DateTime.parse(renewalDate!);
      final now = DateTime.now();
      final daysDifference = renewal.difference(now).inDays;
      final l10n = AppLocalizations.of(context)!;

      if (daysDifference < 0) {
        return l10n.paymentOverdue; // "Payment Overdue" / "ការបង់ប្រាក់យឺតពេល"
      } else if (daysDifference <= 7) {
        return l10n
            .paymentDueSoon; // "Payment Due Soon" / "ការបង់ប្រាក់ដល់ពេលឆាប់ៗ"
      } else {
        return l10n
            .paymentUpToDate; // "Payment Up to Date" / "ការបង់ប្រាក់ទាន់ពេល"
      }
    } catch (e) {
      return '';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Helper method to validate image URLs
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    if (!url.startsWith('http')) return false;
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Widget _buildProfileImage() {
    // If we have cached bytes, use them
    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
      );
    }

    // Check if the URL is valid before trying to load it
    if (_isValidImageUrl(imageUrl)) {
      return Image.network(
        imageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Return person icon for invalid images
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person,
              size: 36,
              color: Colors.grey[400],
            ),
          );
        },
      );
    }

    // Return person icon for invalid or empty URLs
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.person,
        size: 36,
        color: Colors.grey[400],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildProfileImage(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school,
                              size: 14, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF2D3748),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),

                    // Show payment info if available (for students)
                    if (studyFeePeriod != null &&
                        studyFeePeriod!.isNotEmpty) ...[
                      Tooltip(
                        message:
                            '${AppLocalizations.of(context)!.studyFeePeriod}: $studyFeePeriod',
                        child: Row(
                          children: [
                            Icon(Icons.payments,
                                size: 12, color: Colors.blue[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${AppLocalizations.of(context)!.fee}: $studyFeePeriod',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Show renewal date if available
                    if (renewalDate != null && renewalDate!.isNotEmpty) ...[
                      Tooltip(
                        message: _getPaymentStatusText(context),
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 12, color: _getRenewalColor()),
                            const SizedBox(width: 4),
                            Text(
                              '${AppLocalizations.of(context)!.renew}: ${_formatDate(renewalDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getRenewalColor(),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Fallback to years of experience if no payment info
                    if ((studyFeePeriod == null || studyFeePeriod!.isEmpty) &&
                        (renewalDate == null || renewalDate!.isEmpty))
                      Text(
                        '$years ${AppLocalizations.of(context)!.yearsOfExperience}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              if (onDelete != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[600],
                      size: 24,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete Student',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
