import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddStudentInformationScreen extends StatefulWidget {
  const AddStudentInformationScreen({super.key});

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
  DateTime? dateOfBirth;
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

  Future<void> _saveStudent() async {
    setState(() => loading = true);
    String? photoUrl;
    if (imageFile != null) {
      photoUrl = await _uploadImage(imageFile!);
    }
    final student = ParseObject('Student')
      ..set('name', nameController.text.trim())
      ..set('grade', gradeController.text.trim())
      ..set('address', addressController.text.trim())
      ..set('phoneNumber', phoneController.text.trim())
      ..set('studyStatus', studyStatusController.text.trim())
      ..set('dateOfBirth', dateOfBirth?.toIso8601String())
      ..set('photo', photoUrl ?? '');

    // TODO: Replace with actual school context when multi-tenant system is implemented
    // For now, this will be null until school selection is implemented
    // student.set('school', ParseObject('School')..objectId = currentSchoolId);
    final response = await student.save();
    setState(() => loading = false);
    if (response.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to add student: ${response.error?.message ?? 'Unknown error'}')),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
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

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Student', style: TextStyle(color: Colors.black)),
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
              const SizedBox(height: 32),
              _inputField(
                  icon: Icons.person,
                  label: 'Name',
                  controller: nameController),
              _inputField(
                  icon: Icons.grade,
                  label: 'Grade',
                  controller: gradeController),
              _inputField(
                  icon: Icons.home,
                  label: 'Address',
                  controller: addressController),
              _inputField(
                  icon: Icons.phone,
                  label: 'Phone Number',
                  controller: phoneController),
              _inputField(
                  icon: Icons.school,
                  label: 'Study Status',
                  controller: studyStatusController),
              _inputField(
                  icon: Icons.cake,
                  label: 'Date of Birth',
                  controller: TextEditingController(
                      text: dateOfBirth != null
                          ? dateOfBirth!.toIso8601String().split('T').first
                          : ''),
                  readOnly: true,
                  onTap: _selectDate),
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
                  onPressed: loading ? null : _saveStudent,
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
