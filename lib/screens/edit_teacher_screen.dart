import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/teacher.dart';

class EditTeacherScreen extends StatefulWidget {
  final Teacher teacher;

  const EditTeacherScreen({
    super.key,
    required this.teacher,
  });

  @override
  State<EditTeacherScreen> createState() => _EditTeacherScreenState();
}

class _EditTeacherScreenState extends State<EditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _subjectController;
  late TextEditingController _photoUrlController;
  late TextEditingController _yearsController;
  late TextEditingController _ratingController;
  late TextEditingController _ratingCountController;
  late TextEditingController _hourlyRateController;

  String _selectedGender = 'Male';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController(text: widget.teacher.fullName);
    _subjectController = TextEditingController(text: widget.teacher.subject);
    _photoUrlController =
        TextEditingController(text: widget.teacher.photoUrl ?? '');
    _yearsController = TextEditingController(
        text: widget.teacher.yearsOfExperience.toString());
    _ratingController =
        TextEditingController(text: widget.teacher.rating.toString());
    _ratingCountController =
        TextEditingController(text: widget.teacher.ratingCount.toString());
    _hourlyRateController =
        TextEditingController(text: widget.teacher.hourlyRate.toString());
    _selectedGender = widget.teacher.gender;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _subjectController.dispose();
    _photoUrlController.dispose();
    _yearsController.dispose();
    _ratingController.dispose();
    _ratingCountController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await ParseUser.currentUser();

      // Update the Teacher record in Parse
      final teacherObject = ParseObject('Teacher')
        ..objectId = widget.teacher.objectId
        ..set('fullName', _fullNameController.text.trim())
        ..set('subject', _subjectController.text.trim())
        ..set('gender', _selectedGender)
        ..set(
            'photo',
            _photoUrlController.text.trim().isEmpty
                ? null
                : _photoUrlController.text.trim())
        ..set('yearsOfExperience', int.tryParse(_yearsController.text) ?? 0)
        ..set('rating', double.tryParse(_ratingController.text) ?? 0.0)
        ..set('ratingCount', int.tryParse(_ratingCountController.text) ?? 0)
        ..set('hourlyRate', double.tryParse(_hourlyRateController.text) ?? 0.0)
        // Update audit fields
        ..set('lastModified', DateTime.now())
        ..set('modifiedBy', currentUser?.username ?? 'admin')
        // Update subjects array to include the current subject
        ..set('subjects', [_subjectController.text.trim()]);

      final response = await teacherObject.save();

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teacher information updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(
              context, true); // Return true to indicate changes were made
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to update teacher: ${response.error?.message ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating teacher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Teacher Information'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _photoUrlController.text.isNotEmpty
                            ? NetworkImage(_photoUrlController.text)
                            : null,
                        backgroundColor: Colors.blue[100],
                        child: _photoUrlController.text.isEmpty
                            ? Icon(Icons.person,
                                size: 50, color: Colors.blue[700])
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Edit ${widget.teacher.fullName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Personal Information Section
              _buildSectionCard(
                'Personal Information',
                Icons.person,
                [
                  _buildTextFormField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildGenderDropdown(),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _photoUrlController,
                    label: 'Photo URL (Optional)',
                    icon: Icons.image_outlined,
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Professional Information Section
              _buildSectionCard(
                'Professional Information',
                Icons.work,
                [
                  _buildTextFormField(
                    controller: _subjectController,
                    label: 'Subject',
                    icon: Icons.subject_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Subject is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _yearsController,
                    label: 'Years of Experience',
                    icon: Icons.timeline_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Years of experience is required';
                      }
                      final years = int.tryParse(value);
                      if (years == null || years < 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _hourlyRateController,
                    label: 'Hourly Rate (\$)',
                    icon: Icons.attach_money_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Hourly rate is required';
                      }
                      final rate = double.tryParse(value);
                      if (rate == null || rate < 0) {
                        return 'Please enter a valid hourly rate';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Rating Information Section
              _buildSectionCard(
                'Rating Information',
                Icons.star,
                [
                  _buildTextFormField(
                    controller: _ratingController,
                    label: 'Rating (0.0 - 5.0)',
                    icon: Icons.star_outline,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Rating is required';
                      }
                      final rating = double.tryParse(value);
                      if (rating == null || rating < 0 || rating > 5) {
                        return 'Please enter a rating between 0.0 and 5.0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _ratingCountController,
                    label: 'Number of Reviews',
                    icon: Icons.reviews_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Number of reviews is required';
                      }
                      final count = int.tryParse(value);
                      if (count == null || count < 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: 'Gender',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: ['Male', 'Female', 'Other'].map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value ?? 'Male';
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a gender';
        }
        return null;
      },
    );
  }
}
