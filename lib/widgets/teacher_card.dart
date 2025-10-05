import 'package:flutter/material.dart';

class TeacherCard extends StatelessWidget {
  final String name;
  final String subject;
  final String gender;
  final String? photoUrl;
  final int yearsOfExperience;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TeacherCard({
    super.key,
    required this.name,
    required this.subject,
    required this.gender,
    this.photoUrl,
    this.yearsOfExperience = 0,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 64,
                height: 64,
                child: (photoUrl != null && photoUrl!.isNotEmpty)
                    ? Image.network(photoUrl!, fit: BoxFit.cover)
                    : Image.network(
                        'https://randomuser.me/api/portraits/men/1.jpg',
                        fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Subject: $subject',
                      style: const TextStyle(fontSize: 12)),
                  Text('Gender: $gender', style: const TextStyle(fontSize: 12)),
                  Text('Experience: $yearsOfExperience years',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showEditTeacherDialog(
  BuildContext context, {
  required String initialName,
  required String initialSubject,
  required String initialGender,
  required int initialYearsOfExperience,
  required void Function(
          String name, String subject, String gender, int yearsOfExperience)
      onSave,
}) async {
  final nameController = TextEditingController(text: initialName);
  final subjectController = TextEditingController(text: initialSubject);
  String gender = initialGender;
  int years = initialYearsOfExperience;

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Edit Teacher'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              DropdownButtonFormField<String>(
                value: gender,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  gender = val ?? 'Male';
                },
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Years of Experience'),
                onChanged: (val) {
                  years = int.tryParse(val) ?? initialYearsOfExperience;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(
                nameController.text.trim(),
                subjectController.text.trim(),
                gender,
                years,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
