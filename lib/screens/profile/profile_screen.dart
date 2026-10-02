import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'my_posts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    Map<String, dynamic>? data;
    try {
      data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (e) {
      debugPrint('DB profile query error: $e');
    }

    final meta = user.userMetadata ?? {};
    final metaName = meta['full_name']?.toString().trim();
    final metaStudentId = meta['student_id']?.toString().trim();
    final metaDept = meta['department']?.toString().trim();
    final metaRole = meta['role']?.toString().trim();

    final dbName = data?['full_name']?.toString().trim();
    final dbStudentId = data?['student_id']?.toString().trim();
    final dbDept = data?['department']?.toString().trim();
    final dbRole = data?['role']?.toString().trim();

    final emailPrefix = user.email != null && user.email!.contains('@')
        ? user.email!.split('@')[0]
        : 'Student';

    // Prioritize non-email-prefix names
    String finalName = 'Student';
    if (dbName != null && dbName.isNotEmpty && dbName != emailPrefix) {
      finalName = dbName;
    } else if (metaName != null && metaName.isNotEmpty) {
      finalName = metaName;
    } else if (dbName != null && dbName.isNotEmpty) {
      finalName = dbName;
    } else {
      finalName = emailPrefix;
    }

    final finalStudentId = (dbStudentId != null && dbStudentId.isNotEmpty)
        ? dbStudentId
        : (metaStudentId ?? '');

    final finalDept = (dbDept != null && dbDept.isNotEmpty)
        ? dbDept
        : (metaDept ?? '');

    final finalRole = (dbRole != null && dbRole.isNotEmpty)
        ? dbRole
        : (metaRole ?? 'student');

    final resolvedProfile = {
      'id': user.id,
      'full_name': finalName,
      'student_id': finalStudentId,
      'email': user.email ?? '',
      'department': finalDept,
      'role': finalRole,
    };

    if (!mounted) return;

    setState(() {
      profile = resolvedProfile;
      isLoading = false;
    });
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _updateSingleField(String field, String value) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. ALWAYS update Supabase Auth user metadata FIRST (never blocked by Postgres RLS)
      final newMeta = Map<String, dynamic>.from(user.userMetadata ?? {});
      newMeta[field] = value;

      await supabase.auth.updateUser(
        UserAttributes(
          data: newMeta,
        ),
      );

      // 2. Best-effort update to database 'profiles' table
      try {
        final updates = <String, dynamic>{
          field: value,
          'email': user.email ?? '',
        };

        final res = await supabase
            .from('profiles')
            .update(updates)
            .eq('id', user.id)
            .select();

        if (res.isEmpty) {
          final fullRow = {
            'id': user.id,
            'email': user.email ?? '',
            'full_name': profile?['full_name'] ?? 'Student',
            'student_id': profile?['student_id'] ?? '',
            'department': profile?['department'] ?? '',
            'role': profile?['role'] ?? 'student',
          };
          fullRow[field] = value;
          await supabase.from('profiles').upsert(fullRow);
        }
      } catch (dbErr) {
        debugPrint('Profiles DB update error (handled): $dbErr');
      }

      await loadProfile();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated successfully!')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $error')),
      );
    }
  }

  void _showEditStudentIdDialog() {
    final controller = TextEditingController(
      text: profile?['student_id'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Student ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Student ID',
            hintText: 'e.g. 201-115-001',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateSingleField('student_id', controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDepartmentDialog() {
    final controller = TextEditingController(
      text: profile?['department'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Department'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Department',
            hintText: 'e.g. CSE, EEE, BBA',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateSingleField('department', controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditRoleDialog() {
    String tempRole = (profile?['role'] ?? 'student').toString().toLowerCase();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Account Role'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tempRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'student',
                      child: Text('Student (Standard access)'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Admin (Full moderation access)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        tempRole = val;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateSingleField('role', tempRole);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isUpdating = true;
                          });

                          try {
                            await supabase.auth.updateUser(
                              UserAttributes(
                                password: passwordController.text.trim(),
                              ),
                            );

                            if (!context.mounted) return;

                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password updated successfully!',
                                ),
                              ),
                            );
                          } catch (error) {
                            setDialogState(() {
                              isUpdating = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to update password: $error',
                                ),
                              ),
                            );
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'LU Access',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.school_rounded,
        size: 48,
        color: Colors.blue,
      ),
      children: [
        const Text(
          'LU Access is the official student portal app for Leading University students. '
          'Easily share study notes, buy/sell books, collaborate on projects, and discover campus services.',
        ),
      ],
    );
  }

  void _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: profile),
      ),
    );
    if (result == true) {
      loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit All Profile Info',
            onPressed: _openEditProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _openEditProfile,
                child: const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.blue,
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                profile?['full_name'] ?? 'Student',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 25),

              // Student ID Card (Interactive Quick Edit Button)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.card_membership, color: Colors.blue),
                  title: const Text('Student ID'),
                  subtitle: Text(
                    (profile?['student_id'] != null &&
                            profile!['student_id'].toString().isNotEmpty)
                        ? profile!['student_id']
                        : 'Tap to set Student ID',
                    style: TextStyle(
                      color: (profile?['student_id'] != null &&
                              profile!['student_id'].toString().isNotEmpty)
                          ? Colors.black87
                          : Colors.blue,
                      fontWeight: (profile?['student_id'] != null &&
                              profile!['student_id'].toString().isNotEmpty)
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onTap: _showEditStudentIdDialog,
                ),
              ),

              // Department Card (Interactive Quick Edit Button)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.domain, color: Colors.blue),
                  title: const Text('Department'),
                  subtitle: Text(
                    (profile?['department'] != null &&
                            profile!['department'].toString().isNotEmpty)
                        ? profile!['department']
                        : 'Tap to set Department',
                    style: TextStyle(
                      color: (profile?['department'] != null &&
                              profile!['department'].toString().isNotEmpty)
                          ? Colors.black87
                          : Colors.blue,
                      fontWeight: (profile?['department'] != null &&
                              profile!['department'].toString().isNotEmpty)
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onTap: _showEditDepartmentDialog,
                ),
              ),

              // Role Card (Interactive Quick Edit Button for Student vs Admin)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Colors.blue),
                  title: const Text('Role'),
                  subtitle: Text(
                    (profile?['role'] ?? 'student').toString().toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  trailing: const Icon(Icons.swap_horiz, color: Colors.blue),
                  onTap: _showEditRoleDialog,
                ),
              ),

              const SizedBox(height: 10),

              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.post_add, color: Colors.blue),
                  title: const Text(
                    'My Posts',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('View and manage your submitted posts'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyPostsScreen(),
                      ),
                    );
                  },
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_reset_outlined),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account security password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showChangePasswordDialog,
                ),
              ),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About LU Access'),
                  subtitle: const Text('App version & information'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showAboutDialog,
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
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
