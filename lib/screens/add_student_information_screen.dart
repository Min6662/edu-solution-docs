import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import '../services/language_service.dart';
import '../services/class_service.dart';
import '../services/cache_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AddStudentInformationScreen extends StatefulWidget {
  final Map<String, dynamic>?
      studentData; // Add optional student data for editing

  const AddStudentInformationScreen({super.key, this.studentData});

  @override
  State<AddStudentInformationScreen> createState() =>
      _AddStudentInformationScreenState();
}

class _AddStudentInformationScreenState
    extends State<AddStudentInformationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController gradeController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController studyStatusController = TextEditingController();
  final TextEditingController motherNameController = TextEditingController();
  final TextEditingController fatherNameController = TextEditingController();
  final TextEditingController parentBusinessController =
      TextEditingController();
  final TextEditingController placeOfBirthController = TextEditingController();
  DateTime? dateOfBirth;
  File? imageFile;
  String? existingImageUrl;
  bool photoDeleted = false; // Flag to track if photo was intentionally deleted
  bool loading = false;
  bool get isEditing => widget.studentData != null;

  // Class selection variables
  List<Map<String, dynamic>> classList = [];
  Map<String, dynamic>? selectedMorningClass;
  Map<String, dynamic>? selectedEveningClass;
  bool loadingClasses = false;

  // Study fee period dropdown
  final List<String> studyFeePeriods = ['1 Month', '5 Months', '1 Year'];

  // Helper methods to map between localized and stored values
  String _getLocalizedPeriod(String? englishPeriod) {
    if (englishPeriod == null) return '';
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

  String _getEnglishPeriod(String? localizedPeriod) {
    if (localizedPeriod == null) return '';
    final l10n = AppLocalizations.of(context)!;
    if (localizedPeriod == l10n.oneMonth) return '1 Month';
    if (localizedPeriod == l10n.fiveMonths) return '5 Months';
    if (localizedPeriod == l10n.oneYear) return '1 Year';
    return localizedPeriod;
  }

  String? selectedStudyFeePeriod;

  // Payment date tracking
  DateTime? paidDate;
  DateTime? renewalDate;

  void _calculateRenewalDate() {
    if (paidDate != null && selectedStudyFeePeriod != null) {
      print('=== CALCULATING RENEWAL DATE ===');
      print('Paid Date: $paidDate');
      print('Study Fee Period: $selectedStudyFeePeriod');

      // Convert to English period if it's localized
      final englishPeriod = _getEnglishPeriod(selectedStudyFeePeriod);

      switch (englishPeriod) {
        case '1 Month':
          renewalDate =
              DateTime(paidDate!.year, paidDate!.month + 1, paidDate!.day);
          break;
        case '5 Months':
          renewalDate =
              DateTime(paidDate!.year, paidDate!.month + 5, paidDate!.day);
          break;
        case '1 Year':
          renewalDate =
              DateTime(paidDate!.year + 1, paidDate!.month, paidDate!.day);
          break;
      }

      print('Calculated Renewal Date: $renewalDate');
      print('===============================');
    } else {
      print(
          'Cannot calculate renewal date - paidDate: $paidDate, selectedStudyFeePeriod: $selectedStudyFeePeriod');
    }
  }

  void _updateGradeController() {
    String gradeText = '';
    if (selectedMorningClass != null && selectedEveningClass != null) {
      gradeText =
          '${selectedMorningClass!['classname']} / ${selectedEveningClass!['classname']}';
    } else if (selectedMorningClass != null) {
      gradeText = '${selectedMorningClass!['classname']} (Morning)';
    } else if (selectedEveningClass != null) {
      gradeText = '${selectedEveningClass!['classname']} (Evening)';
    }
    gradeController.text = gradeText;
  }

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (isEditing) {
      _populateFields();
    } else {
      // For new students, load any cached form data (text fields and image)
      // Class selections will be restored after classes are loaded
      _loadFormDataFromCache();
    }

    // Add listeners to save form data as user types
    _addFormListeners();
  }

  void _addFormListeners() {
    // No controller for dropdown, but save to cache on change
    nameController.addListener(_saveFormDataToCache);
    gradeController.addListener(_saveFormDataToCache);
    addressController.addListener(_saveFormDataToCache);
    phoneController.addListener(_saveFormDataToCache);
    studyStatusController.addListener(_saveFormDataToCache);
    motherNameController.addListener(_saveFormDataToCache);
    fatherNameController.addListener(_saveFormDataToCache);
    parentBusinessController.addListener(_saveFormDataToCache);
    placeOfBirthController.addListener(_saveFormDataToCache);
  }

  Future<void> _loadClasses() async {
    setState(() {
      loadingClasses = true;
    });

    try {
      // Try to load from cache first
      await _loadClassesFromCache();

      // Load fresh data in background
      final classes = await ClassService.getClassList();
      if (classes.isNotEmpty) {
        setState(() {
          classList = classes;
          loadingClasses = false;
        });

        // Save to cache
        await _saveClassesToCache(classes);

        // If editing and classes are loaded, populate class selection
        if (isEditing && classList.isNotEmpty) {
          _populateClassSelection();
        } else if (!isEditing) {
          // If new student and cached form data exists, restore class selections
          final box = await Hive.openBox('addStudentCache');
          final cachedData = box.get('draftFormData');
          if (cachedData != null) {
            await _restoreClassSelections(
                Map<String, dynamic>.from(cachedData));
          }
        }
      }
    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        loadingClasses = false;
      });
    }
  }

  @override
  void dispose() {
    // Remove listeners
    nameController.removeListener(_saveFormDataToCache);
    gradeController.removeListener(_saveFormDataToCache);
    addressController.removeListener(_saveFormDataToCache);
    phoneController.removeListener(_saveFormDataToCache);
    studyStatusController.removeListener(_saveFormDataToCache);
    motherNameController.removeListener(_saveFormDataToCache);
    fatherNameController.removeListener(_saveFormDataToCache);
    parentBusinessController.removeListener(_saveFormDataToCache);
    placeOfBirthController.removeListener(_saveFormDataToCache);

    // Dispose controllers
    nameController.dispose();
    gradeController.dispose();
    addressController.dispose();
    phoneController.dispose();
    studyStatusController.dispose();
    motherNameController.dispose();
    fatherNameController.dispose();
    parentBusinessController.dispose();
    placeOfBirthController.dispose();

    super.dispose();
  }

  Future<void> _loadClassesFromCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      final cachedData = box.get('classList');

      if (cachedData != null && cachedData is List) {
        final cachedClasses = List<Map<String, dynamic>>.from(
            cachedData.map((item) => Map<String, dynamic>.from(item)));

        if (cachedClasses.isNotEmpty) {
          setState(() {
            classList = cachedClasses;
            loadingClasses = false;
          });
          print('Loaded ${cachedClasses.length} classes from cache');
        }
      }
    } catch (e) {
      print('Error loading classes from cache: $e');
    }
  }

  Future<void> _saveClassesToCache(List<Map<String, dynamic>> classes) async {
    try {
      final box = await Hive.openBox('addStudentCache');
      await box.put('classList', classes);
      print('Saved ${classes.length} classes to cache');
    } catch (e) {
      print('Error saving classes to cache: $e');
    }
  }

  // Cache methods for form data
  Future<void> _saveFormDataToCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      final formData = {
        'name': nameController.text,
        'grade': gradeController.text,
        'address': addressController.text,
        'phoneNumber': phoneController.text,
        'studyStatus': studyStatusController.text,
        'motherName': motherNameController.text,
        'fatherName': fatherNameController.text,
        'parentBusiness': parentBusinessController.text,
        'placeOfBirth': placeOfBirthController.text,
        'morningClassId': selectedMorningClass?['objectId'],
        'morningClassName': selectedMorningClass?['classname'],
        'eveningClassId': selectedEveningClass?['objectId'],
        'eveningClassName': selectedEveningClass?['classname'],
        'existingImageUrl': existingImageUrl,
        'photoDeleted': photoDeleted, // Save deletion flag
        'hasImageFile': imageFile != null,
        'imageFileName': imageFile?.path.split('/').last,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'studyFeePeriod': selectedStudyFeePeriod,
        'paidDate': paidDate?.toIso8601String(),
        'renewalDate': renewalDate?.toIso8601String(),
      };

      await box.put('draftFormData', formData);

      // Cache the image file separately if it exists
      if (imageFile != null) {
        await _saveImageToCache();
      }

      print(
          'Form data saved to cache (including image info and deletion flag)');
    } catch (e) {
      print('Error saving form data to cache: $e');
    }
  }

  Future<void> _saveImageToCache() async {
    try {
      if (imageFile == null) return;

      final box = await Hive.openBox('addStudentCache');
      final bytes = await imageFile!.readAsBytes();
      await box.put('cachedImageBytes', bytes);
      await box.put('cachedImagePath', imageFile!.path);
      print('Image saved to cache: ${imageFile!.path}');
    } catch (e) {
      print('Error saving image to cache: $e');
    }
  }

  Future<void> _loadImageFromCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      final cachedBytes = box.get('cachedImageBytes');
      final cachedPath = box.get('cachedImagePath');

      if (cachedBytes != null && cachedPath != null) {
        // Create a temporary file from cached bytes
        final tempDir = Directory.systemTemp;
        final fileName =
            'cached_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final tempFile = File('${tempDir.path}/$fileName');

        await tempFile.writeAsBytes(List<int>.from(cachedBytes));

        setState(() {
          imageFile = tempFile;
        });

        print('Image loaded from cache: $cachedPath');
      }
    } catch (e) {
      print('Error loading image from cache: $e');
    }
  }

  Future<void> _loadFormDataFromCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      final cachedData = box.get('draftFormData');

      if (cachedData != null && cachedData is Map) {
        final formData = Map<String, dynamic>.from(cachedData);

        // Check if cache is not too old (within 24 hours)
        final timestamp = formData['timestamp'] as int?;
        if (timestamp != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final difference = now.difference(cacheTime);

          if (difference.inHours < 24) {
            setState(() {
              nameController.text = formData['name'] ?? '';
              gradeController.text = formData['grade'] ?? '';
              addressController.text = formData['address'] ?? '';
              phoneController.text = formData['phoneNumber'] ?? '';
              studyStatusController.text = formData['studyStatus'] ?? '';
              motherNameController.text = formData['motherName'] ?? '';
              fatherNameController.text = formData['fatherName'] ?? '';
              placeOfBirthController.text = formData['placeOfBirth'] ?? '';
              parentBusinessController.text = formData['parentBusiness'] ?? '';
              existingImageUrl = formData['existingImageUrl'];
              photoDeleted =
                  formData['photoDeleted'] ?? false; // Restore deletion flag
              selectedStudyFeePeriod = formData['studyFeePeriod'];

              // Restore payment dates
              if (formData['paidDate'] != null) {
                paidDate = DateTime.parse(formData['paidDate']);
              }
              if (formData['renewalDate'] != null) {
                renewalDate = DateTime.parse(formData['renewalDate']);
              }
            });

            // Load cached image if available
            if (formData['hasImageFile'] == true) {
              await _loadImageFromCache();
            }

            // Restore class selections if available and classList is loaded
            await _restoreClassSelections(formData);

            print(
                'Form data loaded from cache (including image and dropdown selections)');
          } else {
            // Cache is too old, clear it
            await _clearFormDataCache();
          }
        }
      }
    } catch (e) {
      print('Error loading form data from cache: $e');
    }
  }

  Future<void> _restoreClassSelections(Map<String, dynamic> formData) async {
    // Wait a bit to ensure classList is loaded
    int attempts = 0;
    while (classList.isEmpty && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (classList.isNotEmpty) {
      final morningClassId = formData['morningClassId'];
      final eveningClassId = formData['eveningClassId'];

      print(
          'Restoring class selections - Morning: $morningClassId, Evening: $eveningClassId');
      print(
          'Available classes: ${classList.map((c) => '${c['objectId']}: ${c['classname']}').join(', ')}');

      setState(() {
        if (morningClassId != null) {
          try {
            selectedMorningClass = classList.firstWhere(
              (cls) => cls['objectId'] == morningClassId,
            );
            print(
                'Restored morning class: ${selectedMorningClass!['classname']}');
          } catch (e) {
            print('Cached morning class not found: $morningClassId');
          }
        }

        if (eveningClassId != null) {
          try {
            selectedEveningClass = classList.firstWhere(
              (cls) => cls['objectId'] == eveningClassId,
            );
            print(
                'Restored evening class: ${selectedEveningClass!['classname']}');
          } catch (e) {
            print('Cached evening class not found: $eveningClassId');
          }
        }
      });

      // Update grade controller based on restored selections
      _updateGradeController();
    } else {
      print('No classList available for class selection restoration');
    }
  }

  Future<void> _clearFormDataCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      await box.delete('draftFormData');
      await box.delete('cachedImageBytes');
      await box.delete('cachedImagePath');
      print('Form data and image cache cleared');
    } catch (e) {
      print('Error clearing form data cache: $e');
    }
  }

  // Clear all cache data
  Future<void> _clearAllCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      await box.clear();

      // Also reset form state
      setState(() {
        selectedMorningClass = null;
        selectedEveningClass = null;
        imageFile = null;
        existingImageUrl = null;
        photoDeleted = false; // Reset deletion flag
      });

      // Clear all text controllers
      nameController.clear();
      gradeController.clear();
      addressController.clear();
      phoneController.clear();
      studyStatusController.clear();
      motherNameController.clear();
      fatherNameController.clear();
      placeOfBirthController.clear();

      print('All cache and form data cleared');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared - form reset'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }

  // Debug method to show cache contents
  Future<void> _debugShowCache() async {
    try {
      final box = await Hive.openBox('addStudentCache');
      print('=== CACHE DEBUG INFO ===');
      print('Cache keys: ${box.keys.toList()}');

      final formData = box.get('draftFormData');
      if (formData != null) {
        print('Form data cache:');
        final data = Map<String, dynamic>.from(formData);
        data.forEach((key, value) {
          if (key == 'cachedImageBytes') {
            print('  $key: [${value.length} bytes]');
          } else {
            print('  $key: $value');
          }
        });
      }

      final classList = box.get('classList');
      if (classList != null) {
        print('Cached classes: ${(classList as List).length} items');
      }

      final imageBytes = box.get('cachedImageBytes');
      if (imageBytes != null) {
        print('Cached image: ${imageBytes.length} bytes');
      }

      print('========================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache info logged - check console'),
            backgroundColor: Colors.green[600],
          ),
        );
      }
    } catch (e) {
      print('Error showing cache debug: $e');
    }
  }

  void _populateClassSelection() {
    final data = widget.studentData!;

    print('=== CLASS SELECTION POPULATION DEBUG ===');
    print('Student data keys: ${data.keys.toList()}');
    print('classList length: ${classList.length}');
    print('classList sample: ${classList.take(2).toList()}');

    // Handle morning class
    final morningClassId = data['morningClassId'];
    print('Morning class ID from data: "$morningClassId"');
    if (morningClassId != null) {
      try {
        selectedMorningClass = classList.firstWhere(
          (cls) => cls['objectId'] == morningClassId,
        );
        print('Found morning class: ${selectedMorningClass!['classname']}');
      } catch (e) {
        print('Morning class with ID $morningClassId not found in classList');
        print(
            'Available class IDs: ${classList.map((c) => c['objectId']).toList()}');
      }
    }

    // Handle evening class
    final eveningClassId = data['eveningClassId'];
    print('Evening class ID from data: "$eveningClassId"');
    if (eveningClassId != null) {
      try {
        selectedEveningClass = classList.firstWhere(
          (cls) => cls['objectId'] == eveningClassId,
        );
        print('Found evening class: ${selectedEveningClass!['classname']}');
      } catch (e) {
        print('Evening class with ID $eveningClassId not found in classList');
        print(
            'Available class IDs: ${classList.map((c) => c['objectId']).toList()}');
      }
    }

    // If no class IDs found in student data, try to load from Enrolment table
    if (morningClassId == null && eveningClassId == null) {
      print(
          'No class IDs in student data, attempting to load from Enrolment table...');
      _loadClassesFromEnrolments();
    }

    print('Final selectedMorningClass: $selectedMorningClass');
    print('Final selectedEveningClass: $selectedEveningClass');
    print('=====================================');

    setState(() {});
  }

  // Load student's classes from Enrolment table (fallback method)
  Future<void> _loadClassesFromEnrolments() async {
    try {
      final studentId = widget.studentData!['objectId'];
      if (studentId == null) return;

      print('Loading enrolments for student ID: $studentId');

      final query = QueryBuilder<ParseObject>(ParseObject('Enrolment'))
        ..whereEqualTo('student', ParseObject('Student')..objectId = studentId);

      final response = await query.query();
      if (response.success && response.results != null) {
        print('Found ${response.results!.length} enrolments');

        for (final enrolment in response.results!) {
          final classPointer = enrolment.get<ParseObject>('class');
          final type = enrolment.get<String>('type');
          final classId = classPointer?.objectId;

          print('Enrolment type: $type, classId: $classId');

          if (classId != null) {
            try {
              final classInfo = classList.firstWhere(
                (cls) => cls['objectId'] == classId,
              );

              if (type == 'morning') {
                selectedMorningClass = classInfo;
                print(
                    'Set morning class from enrolment: ${classInfo['classname']}');
              } else if (type == 'evening') {
                selectedEveningClass = classInfo;
                print(
                    'Set evening class from enrolment: ${classInfo['classname']}');
              }
            } catch (e) {
              print('Class with ID $classId not found in classList');
            }
          }
        }

        setState(() {});
      }
    } catch (e) {
      print('Error loading classes from enrolments: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force rebuild when dependencies change to ensure image loads
    if (isEditing && mounted) {
      setState(() {});
    }
  }

  void _populateFields() {
    final data = widget.studentData!;
    selectedStudyFeePeriod = data['studyFeePeriod'];

    // Enhanced debug logging
    print('=== ENHANCED EDIT SCREEN DEBUG ===');
    print('Complete student data received:');
    data.forEach((key, value) {
      print('  $key: "$value" (${value.runtimeType})');
    });
    print('=====================================');

    nameController.text = data['name'] ?? '';
    gradeController.text = data['grade'] ?? '';
    addressController.text = data['address'] ?? '';
    phoneController.text = data['phoneNumber'] ?? '';
    studyStatusController.text = data['studyStatus'] ?? '';
    motherNameController.text = data['motherName'] ?? '';
    fatherNameController.text = data['fatherName'] ?? '';
    placeOfBirthController.text = data['placeOfBirth'] ?? '';
    existingImageUrl = data['photo'];
    parentBusinessController.text = data['parentBusiness'] ?? '';

    // Restore payment dates
    if (data['paidDate'] != null) {
      try {
        paidDate = DateTime.parse(data['paidDate']);
      } catch (e) {
        print('Error parsing paidDate: $e');
      }
    }
    if (data['renewalDate'] != null) {
      try {
        renewalDate = DateTime.parse(data['renewalDate']);
      } catch (e) {
        print('Error parsing renewalDate: $e');
      }
    }

    // Debug print populated values
    print('=== POPULATED FIELD VALUES ===');
    print('Name: "${nameController.text}"');
    print('Grade: "${gradeController.text}"');
    print('Address: "${addressController.text}"');
    print('Phone: "${phoneController.text}"');
    print('Study Status: "${studyStatusController.text}"');
    print('Mother Name: "${motherNameController.text}"');
    print('Father Name: "${fatherNameController.text}"');
    print('Place of Birth: "${placeOfBirthController.text}"');
    print('Photo URL: "$existingImageUrl"');
    print('===============================');

    if (data['dateOfBirth'] != null) {
      try {
        dateOfBirth = DateTime.parse(data['dateOfBirth']);
        print('Date of Birth parsed: $dateOfBirth');
      } catch (e) {
        print('Error parsing date: $e');
      }
    } else {
      print('No dateOfBirth found in data');
    }
  }

  Future<void> _pickImage() async {
    final imageSource = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.chooseImageSource),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: Text(AppLocalizations.of(context)!.takePhoto),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: Text(AppLocalizations.of(context)!.chooseFromGallery),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (imageSource == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: imageSource);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        photoDeleted = false; // Reset deletion flag when new image is selected
      });
      // Save form data including new image to cache
      await _saveFormDataToCache();
    }
  }

  Future<String?> _uploadImage(File file) async {
    final parseFile = ParseFile(file);
    final response = await parseFile.save();
    if (response.success && response.result != null) {
      return parseFile.url;
    }
    return null;
  }

  // Create or update Enrolment records for selected classes
  Future<void> _createEnrolments(ParseObject savedStudent) async {
    try {
      if (isEditing) {
        // For editing, first delete existing enrolments for this student
        await _deleteExistingEnrolments(savedStudent.objectId!);
      }

      // Create morning class enrolment if selected
      if (selectedMorningClass != null) {
        final morningEnrolment = ParseObject('Enrolment');
        morningEnrolment.set('student', savedStudent);
        morningEnrolment.set('class',
            ParseObject('Class')..objectId = selectedMorningClass!['objectId']);
        morningEnrolment.set('type', 'morning');
        // TODO: Add school when multi-tenant system is implemented
        // morningEnrolment.set('school', ParseObject('School')..objectId = currentSchoolId);

        final morningResponse = await morningEnrolment.save();
        if (!morningResponse.success) {
          print('Failed to create morning enrolment: ${morningResponse.error}');
        }
      }

      // Create evening class enrolment if selected
      if (selectedEveningClass != null) {
        final eveningEnrolment = ParseObject('Enrolment');
        eveningEnrolment.set('student', savedStudent);
        eveningEnrolment.set('class',
            ParseObject('Class')..objectId = selectedEveningClass!['objectId']);
        eveningEnrolment.set('type', 'evening');
        // TODO: Add school when multi-tenant system is implemented
        // eveningEnrolment.set('school', ParseObject('School')..objectId = currentSchoolId);

        final eveningResponse = await eveningEnrolment.save();
        if (!eveningResponse.success) {
          print('Failed to create evening enrolment: ${eveningResponse.error}');
        }
      }

      // Clear enrolled students cache for affected classes so they refresh
      if (selectedMorningClass != null) {
        await CacheService.clearEnrolledStudents(
            selectedMorningClass!['objectId']);
      }
      if (selectedEveningClass != null) {
        await CacheService.clearEnrolledStudents(
            selectedEveningClass!['objectId']);
      }
    } catch (e) {
      print('Error creating enrolments: $e');
    }
  }

  // Delete existing enrolments for a student (used when editing)
  Future<void> _deleteExistingEnrolments(String studentId) async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Enrolment'))
        ..whereEqualTo('student', ParseObject('Student')..objectId = studentId);

      final response = await query.query();
      if (response.success && response.results != null) {
        for (final enrolment in response.results!) {
          await enrolment.delete();
        }
      }
    } catch (e) {
      print('Error deleting existing enrolments: $e');
    }
  }

  Future<void> _saveStudent() async {
    // Validate required fields
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Name is required'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    if (selectedMorningClass == null && selectedEveningClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Please select at least one class (morning or evening)'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    setState(() => loading = true);
    String? photoUrl = existingImageUrl;

    // If photo was intentionally deleted, set to empty string
    if (photoDeleted) {
      photoUrl = '';
    }
    // If user selected a new image, upload it
    else if (imageFile != null) {
      photoUrl = await _uploadImage(imageFile!);
    } else if (isEditing) {
      // For editing, only keep the original photo if it's not the fallback URL or empty
      final originalPhoto = widget.studentData!['photo'];
      if (originalPhoto != null &&
          originalPhoto.toString().trim().isNotEmpty &&
          !originalPhoto.toString().contains('randomuser.me')) {
        photoUrl = originalPhoto.toString();
      } else {
        photoUrl = '';
      }
    }

    try {
      ParseObject student;

      if (isEditing) {
        // Update existing student
        final objectId = widget.studentData!['objectId'];
        student = ParseObject('Student')..objectId = objectId;
      } else {
        // Create new student
        student = ParseObject('Student');
      }

      student
        ..set('name', nameController.text.trim())
        ..set('grade', gradeController.text.trim())
        ..set('address', addressController.text.trim())
        ..set('phoneNumber', phoneController.text.trim())
        ..set('studyStatus', studyStatusController.text.trim())
        ..set('motherName', motherNameController.text.trim())
        ..set('fatherName', fatherNameController.text.trim())
        ..set('parentBusiness', parentBusinessController.text.trim())
        ..set('placeOfBirth', placeOfBirthController.text.trim())
        ..set('dateOfBirth', dateOfBirth?.toIso8601String())
        ..set('photo', photoUrl ?? '')
        ..set('studyFeePeriod', selectedStudyFeePeriod)
        ..set('paidDate', paidDate?.toIso8601String())
        ..set('renewalDate', renewalDate?.toIso8601String());

      // Set morning class relationship if selected
      if (selectedMorningClass != null) {
        student.set('morningClass',
            ParseObject('Class')..objectId = selectedMorningClass!['objectId']);
        student.set('morningClassId', selectedMorningClass!['objectId']);
        student.set('morningClassName', selectedMorningClass!['classname']);
      }

      // Set evening class relationship if selected
      if (selectedEveningClass != null) {
        student.set('eveningClass',
            ParseObject('Class')..objectId = selectedEveningClass!['objectId']);
        student.set('eveningClassId', selectedEveningClass!['objectId']);
        student.set('eveningClassName', selectedEveningClass!['classname']);
      }

      // For backward compatibility, set grade to combined class names
      String gradeText = '';
      if (selectedMorningClass != null && selectedEveningClass != null) {
        gradeText =
            '${selectedMorningClass!['classname']} / ${selectedEveningClass!['classname']}';
      } else if (selectedMorningClass != null) {
        gradeText = '${selectedMorningClass!['classname']} (Morning)';
      } else if (selectedEveningClass != null) {
        gradeText = '${selectedEveningClass!['classname']} (Evening)';
      }
      student.set('grade', gradeText);

      print('=== SAVE STUDENT DEBUG ===');
      print('Student: ${nameController.text.trim()}');
      print('IsEditing: $isEditing');
      print('ImageFile selected: ${imageFile != null}');
      print('PhotoUrl being saved: "$photoUrl"');
      print('Study Fee Period: "$selectedStudyFeePeriod"');
      print('Paid Date: "$paidDate"');
      print('Renewal Date: "$renewalDate"');
      print('Parent Business: "${parentBusinessController.text.trim()}"');
      print('========================');

      final response = await student.save();

      if (response.success) {
        // Create Enrolment records for selected classes
        await _createEnrolments(response.result!);

        setState(() => loading = false);

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing
                  ? l10n.studentUpdatedSuccessfully
                  : l10n.studentAddedSuccessfully),
              backgroundColor: Colors.green[600],
            ),
          );

          // Clear form cache when student is successfully saved
          if (!isEditing) {
            await _clearFormDataCache();
          }

          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing
                  ? '${l10n.failedToUpdateStudent}: ${response.error?.message ?? l10n.unknownError}'
                  : '${l10n.failedToAddStudent}: ${response.error?.message ?? l10n.unknownError}'),
              backgroundColor: Colors.red[600],
            ),
          );
        }
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Widget _inputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2D3748),
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF667EEA),
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
            borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _morningClassDropdownField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(maxWidth: double.infinity),
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
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: selectedMorningClass,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF9500),
                  Color(0xFFFFB84D)
                ], // Orange gradient for morning
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wb_sunny,
                color: Colors.white, size: 20), // Morning sun icon
          ),
          labelText: AppLocalizations.of(context)!.morningClass,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFFFF9500),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
            borderSide: const BorderSide(color: Color(0xFFFF9500), width: 2),
          ),
        ),
        items: loadingClasses
            ? []
            : classList.map((classItem) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: classItem,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      classItem['classname'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              }).toList(),
        onChanged: loadingClasses
            ? null
            : (Map<String, dynamic>? newValue) {
                setState(() {
                  selectedMorningClass = newValue;
                  _updateGradeController();
                });
                // Save form data when class selection changes
                _saveFormDataToCache();
              },
        hint: loadingClasses
            ? const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Loading classes...'),
                ],
              )
            : Text(
                AppLocalizations.of(context)!.selectMorningClass,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  Widget _eveningClassDropdownField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(maxWidth: double.infinity),
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
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: selectedEveningClass,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF667EEA),
                  Color(0xFF764BA2)
                ], // Purple gradient for evening
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.nights_stay,
                color: Colors.white, size: 20), // Evening moon icon
          ),
          labelText: AppLocalizations.of(context)!.eveningClass,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF667EEA),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
            borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
          ),
        ),
        items: loadingClasses
            ? []
            : classList.map((classItem) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: classItem,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    child: Text(
                      classItem['classname'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D3748),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                );
              }).toList(),
        onChanged: loadingClasses
            ? null
            : (Map<String, dynamic>? newValue) {
                setState(() {
                  selectedEveningClass = newValue;
                  _updateGradeController();
                });
                // Save form data when class selection changes
                _saveFormDataToCache();
              },
        hint: loadingClasses
            ? const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Loading classes...'),
                ],
              )
            : Text(
                AppLocalizations.of(context)!.selectEveningClass,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
      ),
    );
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

  // Helper method to build profile image widget
  // Check if user has an image (either new file or existing URL)
  bool _hasImage() {
    if (photoDeleted) return false; // If photo was deleted, don't show it
    return imageFile != null || _isValidImageUrl(existingImageUrl);
  }

  // Delete the current image
  Future<void> _deleteImage() async {
    final l10n = AppLocalizations.of(context)!;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        imageFile = null;
        existingImageUrl = null;
        photoDeleted = true; // Mark as intentionally deleted
      });

      // Update cache to reflect image deletion
      await _saveFormDataToCache();

      // Clear cached image
      try {
        final box = await Hive.openBox('addStudentCache');
        await box.delete('cachedImageBytes');
        await box.delete('cachedImagePath');
      } catch (e) {
        print('Error clearing cached image: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildProfileImage() {
    print(
        'Building profile image - imageFile: ${imageFile != null}, existingImageUrl: $existingImageUrl, photoDeleted: $photoDeleted');

    // If photo was intentionally deleted, show placeholder
    if (photoDeleted) {
      print('Photo was deleted, showing placeholder');
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[100],
        child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
      );
    }

    // If user has selected a new image file, show that
    if (imageFile != null) {
      print('Showing new image file');
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[100],
        backgroundImage: FileImage(imageFile!),
      );
    }

    // If we have a valid existing image URL, show it
    if (_isValidImageUrl(existingImageUrl)) {
      print('Showing existing image from URL: $existingImageUrl');
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[100],
        child: ClipOval(
          child: Image.network(
            existingImageUrl!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 120,
                height: 120,
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading profile image: $error');
              return Icon(Icons.person, size: 60, color: Colors.grey[400]);
            },
          ),
        ),
      );
    }

    // Default placeholder
    print('Showing default placeholder');
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.grey[100],
      child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(2005, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        dateOfBirth = picked;
      });
    }
  }

  Future<void> _selectPaidDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: paidDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        paidDate = picked;
        _calculateRenewalDate();
      });
      print('=== PAID DATE SELECTED ===');
      print('Paid Date: $paidDate');
      print('Renewal Date: $renewalDate');
      print('Study Fee Period: $selectedStudyFeePeriod');
      print('========================');
      _saveFormDataToCache(); // Save to cache when date changes
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget _studyFeeDropdownField() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: DropdownButtonFormField<String>(
          value: _getLocalizedPeriod(selectedStudyFeePeriod),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments, color: Colors.white, size: 20),
            ),
            labelText: AppLocalizations.of(context)!.studyFeePeriod,
            labelStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: const TextStyle(
              color: Color(0xFF667EEA),
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
              borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
            ),
          ),
          items: [
            AppLocalizations.of(context)!.oneMonth,
            AppLocalizations.of(context)!.fiveMonths,
            AppLocalizations.of(context)!.oneYear
          ].map((period) {
            return DropdownMenuItem<String>(
              value: period,
              child: Text(
                period,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2D3748),
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedStudyFeePeriod = _getEnglishPeriod(newValue);
              _calculateRenewalDate(); // Recalculate renewal date when period changes
            });
            _saveFormDataToCache();
          },
          hint: Text(
            AppLocalizations.of(context)!.selectStudyFeePeriod,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    Widget _renewPaymentButton() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: Text(
            AppLocalizations.of(context)!.renewPayment,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667EEA),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            if (selectedStudyFeePeriod != null) {
              setState(() {
                paidDate = DateTime.now();
                _calculateRenewalDate();
              });
              _saveFormDataToCache();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.paymentRenewed(
                      renewalDate != null
                          ? renewalDate!.toIso8601String().split('T').first
                          : 'N/A')),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!
                      .pleaseSelectStudyFeePeriodFirst),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
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
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cache Debug'),
                                content: const Text('Choose cache action:'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _debugShowCache();
                                    },
                                    child: const Text('Show Cache Info'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _clearAllCache();
                                    },
                                    child: const Text('Clear All Cache'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            isEditing ? l10n.editStudent : l10n.addStudent,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      // Debug: Clear cache button (remove in production)
                      if (!isEditing) // Only show for new students
                        IconButton(
                          icon: const Icon(Icons.clear_all,
                              color: Colors.white70),
                          onPressed: _clearAllCache,
                          tooltip: 'Clear cached form data',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Profile Image Section
                  Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      children: [
                        Text(
                          l10n.studentPhoto,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                _buildProfileImage(),
                                // Camera/Edit button
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF667EEA),
                                          Color(0xFF764BA2)
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                                // Delete button (only show if there's an image)
                                if (_hasImage())
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: _deleteImage,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.3),
                                              spreadRadius: 1,
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: const Icon(Icons.delete,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.tapToChangePhoto,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Form Fields Section
                  Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.studentInformation,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _inputField(
                            icon: Icons.person_outline,
                            label: l10n.name,
                            controller: nameController),
                        _morningClassDropdownField(),
                        _eveningClassDropdownField(),
                        _inputField(
                            icon: Icons.home_outlined,
                            label: l10n.address,
                            controller: addressController),
                        _studyFeeDropdownField(),
                        _inputField(
                            icon: Icons.calendar_today,
                            label: AppLocalizations.of(context)!.paidDate,
                            controller: TextEditingController(
                                text: paidDate != null
                                    ? paidDate!
                                        .toIso8601String()
                                        .split('T')
                                        .first
                                    : ''),
                            readOnly: true,
                            onTap: _selectPaidDate),
                        if (renewalDate != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.orange[600]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!
                                            .renewalDate,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                      Text(
                                        renewalDate!
                                            .toIso8601String()
                                            .split('T')
                                            .first,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _renewPaymentButton(),
                        _inputField(
                            icon: Icons.phone_outlined,
                            label: l10n.phoneNumber,
                            controller: phoneController),
                        _inputField(
                            icon: Icons.school_outlined,
                            label: l10n.studyStatus,
                            controller: studyStatusController),
                        _inputField(
                            icon: Icons.woman,
                            label: l10n.motherName,
                            controller: motherNameController),
                        _inputField(
                            icon: Icons.man,
                            label: l10n.fatherName,
                            controller: fatherNameController),
                        _inputField(
                            icon: Icons.business_center,
                            label: AppLocalizations.of(context)!.parentBusiness,
                            controller: parentBusinessController),
                        _inputField(
                            icon: Icons.location_on_outlined,
                            label: l10n.placeOfBirth,
                            controller: placeOfBirthController),
                        _inputField(
                            icon: Icons.cake_outlined,
                            label: l10n.dateOfBirth,
                            controller: TextEditingController(
                                text: dateOfBirth != null
                                    ? dateOfBirth!
                                        .toIso8601String()
                                        .split('T')
                                        .first
                                    : ''),
                            readOnly: true,
                            onTap: _selectDate),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Save Button
                  Container(
                    width: double.infinity,
                    height: 60,
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: loading ? null : _saveStudent,
                      child: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEditing ? Icons.update : Icons.save,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isEditing ? l10n.updateStudent : l10n.save,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
