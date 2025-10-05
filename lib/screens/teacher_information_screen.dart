import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class TeacherInformationScreen extends StatefulWidget {
  final String objectId;
  const TeacherInformationScreen({super.key, required this.objectId});

  @override
  State<TeacherInformationScreen> createState() =>
      _TeacherInformationScreenState();
}

class _TeacherInformationScreenState extends State<TeacherInformationScreen> {
  bool loading = true;
  String error = '';
  String? name;
  String? photoUrl;
  String? email;
  String? username;

  @override
  void initState() {
    super.initState();
    _fetchTeacherInfo();
  }

  Future<void> _fetchTeacherInfo() async {
    setState(() {
      loading = true;
      error = '';
    });
    final query = QueryBuilder<ParseObject>(ParseObject('Teacher'))
      ..whereEqualTo('objectId', widget.objectId);
    final response = await query.query();
    if (response.success &&
        response.results != null &&
        response.results!.isNotEmpty) {
      final teacher = response.results!.first as ParseObject;
      setState(() {
        name = teacher.get<String>('fullName') ?? '';
        photoUrl = teacher.get<String>('photo');
        email = teacher.get<String>('subject') ?? '';
        username = teacher.get<String>('gender') ?? '';
        loading = false;
      });
    } else {
      setState(() {
        error = 'Failed to fetch teacher info.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Teacher Information',
            style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            photoUrl != null && photoUrl!.isNotEmpty
                                ? NetworkImage(photoUrl!)
                                : null,
                        child: photoUrl == null || photoUrl!.isEmpty
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(name ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      if (username != null && username!.isNotEmpty)
                        Text('Gender: $username',
                            style: const TextStyle(fontSize: 16)),
                      if (email != null && email!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Subject: $email',
                              style: const TextStyle(fontSize: 16)),
                        ),
                    ],
                  ),
                ),
    );
  }
}
