import 'package:flutter/material.dart';
import 'dart:typed_data';

class TeacherCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final int yearsOfExperience;
  final double hourlyRate;
  final VoidCallback? onTap;
  final Uint8List? imageBytes;

  const TeacherCard({
    Key? key,
    required this.name,
    this.photoUrl,
    required this.yearsOfExperience,
    required this.hourlyRate,
    this.onTap,
    this.imageBytes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          print('DEBUG: TeacherCard InkWell onTap called');
          if (onTap != null) {
            print('DEBUG: Calling onTap callback');
            onTap!();
          } else {
            print('DEBUG: onTap callback is null');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageBytes != null
                    ? Image.memory(imageBytes!,
                        width: 64, height: 64, fit: BoxFit.cover)
                    : (photoUrl != null && photoUrl!.isNotEmpty
                        ? Image.network(photoUrl!,
                            width: 64, height: 64, fit: BoxFit.cover)
                        : Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey[300],
                            child: const Icon(Icons.person,
                                size: 40, color: Colors.grey),
                          )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('$yearsOfExperience years experience',
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('\$${hourlyRate.toStringAsFixed(2)}/hr',
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
