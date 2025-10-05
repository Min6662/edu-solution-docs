import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class StudentInformationScreen extends StatefulWidget {
  final String objectId;
  const StudentInformationScreen({super.key, required this.objectId});

  @override
  State<StudentInformationScreen> createState() =>
      _StudentInformationScreenState();
}

class _StudentInformationScreenState extends State<StudentInformationScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController gradeController = TextEditingController();
  TextEditingController studyStatusController = TextEditingController();
  TextEditingController attendanController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  String gender = 'Male';
  String? photoUrl;
  DateTime? dateOfBirth;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    setState(() => loading = true);
    final query = QueryBuilder<ParseObject>(ParseObject('Student'))
      ..whereEqualTo('objectId', widget.objectId);
    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final student = response.results!.first;
      setState(() {
        nameController.text = student.get<String>('name') ?? '';
        addressController.text = student.get<String>('address') ?? '';
        gradeController.text = student.get<String>('grade') ?? '';
        studyStatusController.text = student.get<String>('studyStatus') ?? '';
        attendanController.text = student.get<String>('attendan') ?? '';
        gender = student.get<String>('gender') ?? 'Male';
        photoUrl = student.get<String>('photo');
        final dobStr = student.get<String>('dateOfBirth');
        if (dobStr != null && dobStr.isNotEmpty) {
          dateOfBirth = DateTime.tryParse(dobStr);
          dobController.text = dobStr.split('T').first;
        }
        loading = false;
      });
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to fetch student: ${response.error?.message ?? 'Unknown error'}')),
      );
    }
  }

  int _calculateAge(DateTime? dob) {
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
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
        dobController.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  Future<void> _saveStudentEdits() async {
    setState(() => loading = true);
    final student = ParseObject('Student')..objectId = widget.objectId;
    student
      ..set('name', nameController.text.trim())
      ..set('address', addressController.text.trim())
      ..set('grade', gradeController.text.trim())
      ..set('studyStatus', studyStatusController.text.trim())
      ..set('attendan', attendanController.text.trim())
      ..set('gender', gender)
      ..set('dateOfBirth', dateOfBirth?.toIso8601String());
    final response = await student.save();
    if (response.success) {
      // Update all Enrolment records for this student with the new name
      final enrolQuery = QueryBuilder<ParseObject>(ParseObject('Enrolment'))
        ..whereEqualTo(
            'student', ParseObject('Student')..objectId = widget.objectId);
      final enrolResponse = await enrolQuery.query();
      if (enrolResponse.success && enrolResponse.results != null) {
        for (final enrol in enrolResponse.results!) {
          enrol.set('studentName', nameController.text.trim());
          await enrol.save();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student updated successfully!')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update student: ' +
                  (response.error?.message ?? 'Unknown error'))),
        );
      }
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8B7EDC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Student Information',
          style: TextStyle(
            color: Color(0xFF8B7EDC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        image: photoUrl != null && photoUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(photoUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: photoUrl == null || photoUrl!.isEmpty
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _editField('Name', nameController),
                  _editField('Address', addressController),
                  _genderDropdown(),
                  _editField('Date of Birth', dobController, isDate: true),
                  _infoCard(
                      'Age',
                      dateOfBirth != null
                          ? _calculateAge(dateOfBirth).toString()
                          : ''),
                  _editField('Grade', gradeController),
                  _editField('Study Status', studyStatusController),
                  _editField('Attendan', attendanController),
                  const SizedBox(height: 24),
                  _saveButton(),
                ],
              ),
            ),
    );
  }

  Widget _editField(String label, TextEditingController controller,
      {bool isDate = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: isDate,
        onTap: isDate ? _selectDate : null,
        decoration: InputDecoration(
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

  Widget _genderDropdown() {
    return Padding(
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

  Widget _infoCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF8B7EDC),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: loading ? null : _saveStudentEdits,
        child: loading
            ? const CircularProgressIndicator()
            : const Text('Save', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
