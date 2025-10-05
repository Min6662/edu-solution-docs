import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddTeacherInformationScreen extends StatefulWidget {
  const AddTeacherInformationScreen({super.key});

  @override
  State<AddTeacherInformationScreen> createState() =>
      _AddTeacherInformationScreenState();
}

class _AddTeacherInformationScreenState
    extends State<AddTeacherInformationScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  String gender = 'Male';
  File? imageFile;
  bool loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
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

  Future<void> _saveTeacher() async {
    setState(() => loading = true);
    String? photoUrl;
    if (imageFile != null) {
      photoUrl = await _uploadImage(imageFile!);
    }

    final currentUser = await ParseUser.currentUser();
    final teacher = ParseObject('Teacher')
      ..set('fullName', fullNameController.text.trim())
      ..set('gender', gender)
      ..set('subject', subjectController.text.trim())
      ..set('photo', photoUrl ?? '')
      // Initialize new fields
      ..set('hasUserAccount', false)
      ..set('isAccountActive', true)
      ..set('subjects',
          [subjectController.text.trim()]) // Convert single subject to array
      ..set('assignedClasses', []) // Empty array initially
      ..set('maxClassesPerDay', 6)
      ..set('availableDays',
          ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'])
      ..set('createdBy', currentUser?.username ?? 'admin')
      ..set('lastModified', DateTime.now());

    // TODO: Replace with actual school context when multi-tenant system is implemented
    // For now, this will be null until school selection is implemented
    // teacher.set('school', ParseObject('School')..objectId = currentSchoolId);
    final response = await teacher.save();
    setState(() => loading = false);
    if (response.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher added successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to add teacher: ${response.error?.message ?? 'Unknown error'}')),
        );
      }
    }
  }

  Widget _inputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          filled: true,
          fillColor: const Color(0xFFEDEDED),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Teacher', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage:
                          imageFile != null ? FileImage(imageFile!) : null,
                      child: imageFile == null
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _inputField(
                  icon: Icons.person,
                  label: 'Full Name',
                  controller: fullNameController),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: gender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      gender = val ?? 'Male';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFEDEDED),
                  ),
                ),
              ),
              _inputField(
                  icon: Icons.book,
                  label: 'Subject',
                  controller: subjectController),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: loading ? null : _saveTeacher,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('Save', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
