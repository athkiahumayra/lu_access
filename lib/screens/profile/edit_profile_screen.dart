import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfileScreen({
    super.key,
    this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController fullNameController;
  late TextEditingController studentIdController;
  late TextEditingController departmentController;

  String selectedRole = 'student';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController(
      text: widget.profile?['full_name'] ?? '',
    );
    studentIdController = TextEditingController(
      text: widget.profile?['student_id'] ?? '',
    );
    departmentController = TextEditingController(
      text: widget.profile?['department'] ?? '',
    );

    final currentRole = (widget.profile?['role'] ?? 'student').toString().toLowerCase();
    selectedRole = currentRole == 'admin' ? 'admin' : 'student';
  }

  @override
  void dispose() {
    fullNameController.dispose();
    studentIdController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      final name = fullNameController.text.trim();
      final studentId = studentIdController.text.trim();
      final dept = departmentController.text.trim();

      // 1. First try to UPDATE existing profile row
      final updateResponse = await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': name,
            'student_id': studentId,
            'department': dept,
            'role': selectedRole,
            'email': user.email ?? '',
          })
          .eq('id', user.id)
          .select();

      // 2. If no row was updated, UPSERT / INSERT new profile row
      if (updateResponse.isEmpty) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? '',
          'full_name': name,
          'student_id': studentId,
          'department': dept,
          'role': selectedRole,
        });
      }

      // 3. Update user metadata in Supabase Auth as well
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': name,
            'student_id': studentId,
            'department': dept,
            'role': selectedRole,
          },
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('Save profile error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: studentIdController,
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  prefixIcon: Icon(Icons.card_membership),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your student ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department (e.g. CSE, EEE, BBA)',
                  prefixIcon: Icon(Icons.domain),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Role Selector Dropdown
              const Text(
                'Account Role',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Student'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedRole = val;
                    });
                  }
                },
              ),

              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveProfile,
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
