import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../main.dart'; // Import to access RoleBasedHome
import '../services/cache_service.dart';

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key});

  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  ParseObject? currentSchool;
  bool loading = true;
  String error = '';
  String? userRole;

  // Form controllers
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Logo management
  File? _logoFile;
  String? _currentLogoUrl;
  bool _uploadingLogo = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _fetchCurrentSchool();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final user = await ParseUser.currentUser();
    setState(() {
      userRole = user?.get<String>('role')?.toLowerCase();
    });
  }

  bool get isAdmin => userRole == 'admin' || userRole == 'owner';

  Future<void> _fetchCurrentSchool() async {
    setState(() {
      loading = true;
      error = '';
    });

    // Try to get cached school info first for faster display
    final cachedSchoolInfo = await CacheService.getSchoolInfo();
    if (cachedSchoolInfo != null) {
      setState(() {
        _schoolNameController.text = cachedSchoolInfo['name'] ?? '';
        _addressController.text = cachedSchoolInfo['address'] ?? '';
        _phoneController.text = cachedSchoolInfo['phone'] ?? '';
        _emailController.text = cachedSchoolInfo['email'] ?? '';
        _currentLogoUrl = cachedSchoolInfo['logoUrl'];
        loading = false;
      });
    }

    try {
      final query = QueryBuilder<ParseObject>(ParseObject('School'));
      final response = await query.query();

      if (response.success &&
          response.results != null &&
          response.results!.isNotEmpty) {
        final school = response.results!.first;
        final schoolName = school.get<String>('name') ?? '';
        final schoolAddress = school.get<String>('address') ?? '';
        final schoolPhone = school.get<String>('phone') ?? '';
        final schoolEmail = school.get<String>('email') ?? '';
        final schoolLogoUrl = school.get<String>('logoUrl');

        // Cache the school information
        await CacheService.saveSchoolInfo(
          name: schoolName,
          logoUrl: schoolLogoUrl,
          address: schoolAddress,
          phone: schoolPhone,
          email: schoolEmail,
        );

        setState(() {
          currentSchool = school;
          _schoolNameController.text = schoolName;
          _addressController.text = schoolAddress;
          _phoneController.text = schoolPhone;
          _emailController.text = schoolEmail;
          _currentLogoUrl = schoolLogoUrl;
          loading = false;
        });
      } else {
        setState(() {
          error = 'No school found. Please contact administrator.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadLogo() async {
    if (_logoFile == null) return;

    setState(() {
      _uploadingLogo = true;
    });

    try {
      final parseFile = ParseFile(_logoFile!, name: 'school_logo.png');
      final response = await parseFile.save();

      if (response.success) {
        setState(() {
          _currentLogoUrl = parseFile.url;
          _logoFile = null;
          _uploadingLogo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded successfully!')),
        );
      } else {
        setState(() {
          _uploadingLogo = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to upload logo: ${response.error?.message}')),
        );
      }
    } catch (e) {
      setState(() {
        _uploadingLogo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading logo: $e')),
      );
    }
  }

  Future<void> _saveSchoolInfo() async {
    if (currentSchool == null) return;

    try {
      final schoolName = _schoolNameController.text;
      final schoolAddress = _addressController.text;
      final schoolPhone = _phoneController.text;
      final schoolEmail = _emailController.text;

      currentSchool!.set('name', schoolName);
      currentSchool!.set('address', schoolAddress);
      currentSchool!.set('phone', schoolPhone);
      currentSchool!.set('email', schoolEmail);
      if (_currentLogoUrl != null) {
        currentSchool!.set('logoUrl', _currentLogoUrl);
      }

      final response = await currentSchool!.save();

      if (response.success) {
        // Update cache with new school information
        await CacheService.saveSchoolInfo(
          name: schoolName,
          logoUrl: _currentLogoUrl,
          address: schoolAddress,
          phone: schoolPhone,
          email: schoolEmail,
        );

        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('School information updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update: ${response.error?.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _logout() async {
    try {
      final user = await ParseUser.currentUser();
      if (user != null) {
        await user.logout();
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleBasedHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('School Management'),
        backgroundColor: Colors.orange,
        actions: [
          if (isAdmin && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit School Info',
            ),
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset controllers to original values
                  _schoolNameController.text =
                      currentSchool?.get<String>('name') ?? '';
                  _addressController.text =
                      currentSchool?.get<String>('address') ?? '';
                  _phoneController.text =
                      currentSchool?.get<String>('phone') ?? '';
                  _emailController.text =
                      currentSchool?.get<String>('email') ?? '';
                  _logoFile = null;
                });
              },
              tooltip: 'Cancel',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSchoolInfo,
              tooltip: 'Save',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchCurrentSchool,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // School Logo Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.school, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'School Logo',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: _logoFile != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.file(
                                                _logoFile!,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : _currentLogoUrl != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    _currentLogoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return const Icon(
                                                        Icons.school,
                                                        size: 48,
                                                        color: Colors.grey,
                                                      );
                                                    },
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.school,
                                                  size: 48,
                                                  color: Colors.grey,
                                                ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_isEditing) ...[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _pickLogo,
                                            icon:
                                                const Icon(Icons.photo_library),
                                            label: const Text('Select Logo'),
                                          ),
                                          if (_logoFile != null) ...[
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: _uploadingLogo
                                                  ? null
                                                  : _uploadLogo,
                                              icon: _uploadingLogo
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    )
                                                  : const Icon(Icons.upload),
                                              label: const Text('Upload'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // School Information Section
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'School Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // School Name
                              TextFormField(
                                controller: _schoolNameController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'School Name',
                                  prefixIcon: Icon(Icons.school),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Address
                              TextFormField(
                                controller: _addressController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                  prefixIcon: Icon(Icons.location_on),
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),

                              // Phone
                              TextFormField(
                                controller: _phoneController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (!isAdmin)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Only administrators can edit school information.',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
