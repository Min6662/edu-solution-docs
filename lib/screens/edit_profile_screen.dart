import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  File? imageFile;
  String? photoUrl;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => loading = true);
    final user = await ParseUser.currentUser();
    if (user != null) {
      setState(() {
        nameController.text = user.get<String>('name') ?? '';
        emailController.text = user.emailAddress ?? '';
        usernameController.text = user.username ?? '';
        passwordController.text = '';
        phoneController.text = user.get<String>('phoneNumber') ?? '';
        photoUrl = user.get<String>('photo');
        loading = false;
      });
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch user info.')),
      );
    }
  }

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

  Future<void> _saveProfile() async {
    setState(() => loading = true);
    final user = await ParseUser.currentUser();
    if (user != null) {
      String? uploadedPhotoUrl = photoUrl;
      if (imageFile != null) {
        uploadedPhotoUrl = await _uploadImage(imageFile!);
      }
      user.set('name', nameController.text.trim());
      user.emailAddress = emailController.text.trim();
      user.username = usernameController.text.trim();
      if (passwordController.text.isNotEmpty) {
        user.password = passwordController.text;
      }
      user.set('phoneNumber', phoneController.text.trim());
      user.set('photo', uploadedPhotoUrl ?? '');
      final response = await user.save();
      setState(() => loading = false);
      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to update profile: ${response.error?.message ?? 'Unknown error'}')),
          );
        }
      }
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found.')),
      );
    }
  }

  Widget _profileField(String label, TextEditingController controller,
      {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: label,
            suffixIcon: isPassword ? const Icon(Icons.visibility_off) : null,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black),
            onPressed: loading ? null : _saveProfile,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: imageFile != null
                          ? FileImage(imageFile!)
                          : (photoUrl != null && photoUrl!.isNotEmpty)
                              ? NetworkImage(photoUrl!)
                              : const NetworkImage(
                                      'https://randomuser.me/api/portraits/men/1.jpg')
                                  as ImageProvider,
                      child: imageFile == null &&
                              (photoUrl == null || photoUrl!.isEmpty)
                          ? const Icon(Icons.person,
                              size: 40, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _profileField('Name', nameController),
                _profileField('Email address', emailController),
                _profileField('User name', usernameController),
                _profileField('Password', passwordController, isPassword: true),
                _profileField('Phone number', phoneController),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: loading ? null : _saveProfile,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text('Save',
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
