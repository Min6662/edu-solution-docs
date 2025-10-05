import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class SchoolRegistrationScreen extends StatefulWidget {
  const SchoolRegistrationScreen({super.key});

  @override
  State<SchoolRegistrationScreen> createState() =>
      _SchoolRegistrationScreenState();
}

class _SchoolRegistrationScreenState extends State<SchoolRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String schoolName = '';
  String address = '';
  String ownerName = '';
  String ownerEmail = '';
  String ownerPassword = '';
  String logoPath = '';

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Create a new Parse object for the School
        final school = ParseObject('School')
          ..set('name', schoolName)
          ..set('address', address)
          ..set('ownerName', ownerName)
          ..set('ownerEmail', ownerEmail)
          ..set('ownerPassword', ownerPassword);

        // Save the school object to the backend
        final response = await school.save();

        Navigator.of(context).pop(); // Dismiss loading indicator

        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School registered successfully!')),
          );
          Navigator.of(context).pop(); // Go back to the previous screen
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to register school: ${response.error?.message}')),
          );
        }
      } catch (e) {
        Navigator.of(context).pop(); // Dismiss loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register School'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'School Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Enter school name' : null,
                onSaved: (value) => schoolName = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (value) => value!.isEmpty ? 'Enter address' : null,
                onSaved: (value) => address = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Owner Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Enter owner name' : null,
                onSaved: (value) => ownerName = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Owner Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value!.isEmpty ? 'Enter owner email' : null,
                onSaved: (value) => ownerEmail = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Owner Password'),
                obscureText: true,
                validator: (value) =>
                    value!.isEmpty ? 'Enter owner password' : null,
                onSaved: (value) => ownerPassword = value!,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Register School'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
