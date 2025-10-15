import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import '../services/cache_service.dart';
import 'dart:io';
import 'dart:typed_data';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  File? imageFile;
  String? photoUrl;
  Uint8List? photoBytes;
  bool loading = false;
  bool _isFormChanged = false;
  String? userCacheKey;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _addListeners();
  }

  void _addListeners() {
    nameController.addListener(_onFormChanged);
    emailController.addListener(_onFormChanged);
    usernameController.addListener(_onFormChanged);
    phoneController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {
      _isFormChanged = true;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => loading = true);
    try {
      final user = await ParseUser.currentUser();
      if (user != null) {
        userCacheKey = 'photoBytes_${user.username ?? user.objectId}';
        final box = await Hive.openBox(CacheService.userBoxName);
        final cachedBytes = box.get(userCacheKey!);

        setState(() {
          nameController.text = user.get<String>('name') ?? '';
          emailController.text = user.emailAddress ?? '';
          usernameController.text = user.username ?? '';
          phoneController.text = user.get<String>('phoneNumber') ?? '';
          photoUrl = user.get<String>('photo');
          if (cachedBytes != null) {
            photoBytes = Uint8List.fromList(List<int>.from(cachedBytes));
          }
          loading = false;
          _isFormChanged = false;
        });
      } else {
        setState(() => loading = false);
        _showErrorMessage('Failed to fetch user info.');
      }
    } catch (e) {
      setState(() => loading = false);
      _showErrorMessage('Error loading profile: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          imageFile = File(pickedFile.path);
          _isFormChanged = true;
        });
      }
    } catch (e) {
      _showErrorMessage('Error picking image: $e');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF4A90E2)),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF4A90E2)),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final parseFile = ParseFile(file);
      final response = await parseFile.save();
      if (response.success && response.result != null) {
        return parseFile.url;
      }
      return null;
    } catch (e) {
      _showErrorMessage('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);

    try {
      final user = await ParseUser.currentUser();
      if (user != null) {
        String? uploadedPhotoUrl = photoUrl;

        // Upload new image if selected
        if (imageFile != null) {
          uploadedPhotoUrl = await _uploadImage(imageFile!);
          if (uploadedPhotoUrl == null) {
            setState(() => loading = false);
            return;
          }
        }

        // Update user data
        user.set('name', nameController.text.trim());
        user.emailAddress = emailController.text.trim();
        user.username = usernameController.text.trim();
        user.set('phoneNumber', phoneController.text.trim());
        user.set('photo', uploadedPhotoUrl ?? '');

        final response = await user.save();

        if (response.success) {
          // Update cache
          if (uploadedPhotoUrl != null &&
              uploadedPhotoUrl.isNotEmpty &&
              userCacheKey != null) {
            try {
              final box = await Hive.openBox(CacheService.userBoxName);
              if (imageFile != null) {
                final bytes = await imageFile!.readAsBytes();
                await box.put(userCacheKey!, bytes);
              }
            } catch (e) {
              print('Cache update error: $e');
            }
          }

          // Clear settings cache to refresh
          await CacheService.clearSettings();

          if (mounted) {
            _showSuccessMessage('Profile updated successfully!');
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          _showErrorMessage(
              response.error?.message ?? 'Failed to update profile');
        }
      } else {
        _showErrorMessage('No user found.');
      }
    } catch (e) {
      _showErrorMessage('Error saving profile: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.trim().isNotEmpty) {
      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
      if (!phoneRegex.hasMatch(value.trim()) || value.trim().length < 10) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A90E2),
                Color(0xFF7B68EE),
                Color(0xFF9B59B6),
              ],
            ),
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.only(left: 16, top: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          if (_isFormChanged && !loading)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: _saveProfile,
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4A90E2),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Image Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: imageFile != null
                                      ? FileImage(imageFile!)
                                      : (photoBytes != null
                                          ? MemoryImage(photoBytes!)
                                          : (photoUrl != null &&
                                                  photoUrl!.isNotEmpty
                                              ? NetworkImage(photoUrl!)
                                              : null)) as ImageProvider?,
                                  child: (imageFile == null &&
                                          photoBytes == null &&
                                          (photoUrl == null ||
                                              photoUrl!.isEmpty))
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4A90E2),
                                          Color(0xFF7B68EE)
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to change photo',
                            style: TextStyle(
                              color: Color(0xFF718096),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Form Fields
                    _buildSimpleProfileField(
                      label: 'Full Name',
                      controller: nameController,
                      validator: _validateName,
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF4A90E2),
                    ),

                    _buildSimpleProfileField(
                      label: 'Email Address',
                      controller: emailController,
                      validator: _validateEmail,
                      icon: Icons.email_outlined,
                      iconColor: const Color(0xFF10B981),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    _buildSimpleProfileField(
                      label: 'Username',
                      controller: usernameController,
                      validator: _validateUsername,
                      icon: Icons.alternate_email,
                      iconColor: const Color(0xFF8B5CF6),
                    ),

                    _buildSimpleProfileField(
                      label: 'Phone Number',
                      controller: phoneController,
                      validator: _validatePhone,
                      icon: Icons.phone_outlined,
                      iconColor: const Color(0xFFFF6B35),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 30),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF7B68EE)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A90E2).withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: loading ? null : _saveProfile,
                        child: loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_outlined,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSimpleProfileField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required IconData icon,
    required Color iconColor,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: iconColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: Color(0xFF718096)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
        ),
      ),
    );
  }
}
