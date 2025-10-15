import 'package:flutter/material.dart';

class FontTestScreen extends StatelessWidget {
  const FontTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Font Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Default Font:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'តារាងសិស្ស - Student List',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            const Text(
              'NotoSansKhmer Font:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'តារាងសិស្ស - Student List',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'NotoSansKhmer',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'System Default Font:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'តារាងសិស្ស - Student List',
              style: TextStyle(
                fontSize: 18,
                fontFamily: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
