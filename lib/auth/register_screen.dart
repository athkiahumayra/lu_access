import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final studentIdController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final departmentController = TextEditingController();
  final adminPasswordController = TextEditingController();

  String selectedRole = 'student';
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureAdminPassword = true;

  Future<void> handleAdminAccess() async {
    final enteredPassword = adminPasswordController.text.trim();

    if (enteredPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter admin password.'),
        ),
      );
      return;
    }

    if (enteredPassword != '7890') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect admin password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Password matches "7890" -> Grant Admin access
    setState(() {
      isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        // Update currently logged in user to admin role
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'role': 'admin'}),
        );
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'email': user.email ?? '',
            'full_name': user.userMetadata?['full_name'] ?? 'Admin',
            'role': 'admin',
          });
        } catch (e) {
          debugPrint('Profile update error: $e');
        }
      } else {
        // Sign in or create admin session in Supabase
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: 'admin@lu.edu.bd',
            password: 'adminPassword7890',
          );
        } catch (_) {
          final res = await Supabase.instance.client.auth.signUp(
            email: 'admin@lu.edu.bd',
            password: 'adminPassword7890',
            data: {
              'full_name': 'Campus Admin',
              'role': 'admin',
            },
          );
          if (res.user != null) {
            try {
              await Supabase.instance.client.from('profiles').upsert({
                'id': res.user!.id,
                'email': 'admin@lu.edu.bd',
                'full_name': 'Campus Admin',
                'role': 'admin',
              });
            } catch (e) {
              debugPrint('Admin profile upsert error: $e');
            }
          }
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin access granted!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin access error: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> register() async {
    if (selectedRole == 'admin') {
      await handleAdminAccess();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final fullName = fullNameController.text.trim();
      final studentId = studentIdController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final department = departmentController.text.trim();

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'student_id': studentId,
          'department': department,
          'role': 'student',
        },
      );

      final user = response.user;

      if (user != null) {
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'full_name': fullName,
            'student_id': studentId,
            'email': email,
            'department': department,
            'role': 'student',
          });
        } catch (e) {
          debugPrint('Profile upsert error: $e');
        }
      }

      if (!mounted) return;

      if (response.session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student Account created successfully!'),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
          ),
        );

        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    studentIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    departmentController.dispose();
    adminPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedRole == 'admin' ? 'Admin Access' : 'Create Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              Text(
                selectedRole == 'admin' ? 'Admin Verification' : 'Join LU Access',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              // Account Type Choice
              const Text(
                'Account Type *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 18),
                          SizedBox(width: 6),
                          Text('Student Account'),
                        ],
                      ),
                      selected: selectedRole == 'student',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedRole = 'student';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings, size: 18),
                          SizedBox(width: 6),
                          Text('Admin Account'),
                        ],
                      ),
                      selected: selectedRole == 'admin',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedRole = 'admin';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ADMIN FORM
              if (selectedRole == 'admin') ...[
                const Text(
                  'Enter Admin Security Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: adminPasswordController,
                  obscureText: obscureAdminPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => register(),
                  decoration: InputDecoration(
                    labelText: 'Admin Password *',
                    hintText: 'Enter Admin Password',
                    prefixIcon: const Icon(Icons.admin_panel_settings, color: Colors.deepOrange),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureAdminPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureAdminPassword = !obscureAdminPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoading ? null : register,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Access Admin Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ]
              // STUDENT FORM
              else ...[
                TextFormField(
                  controller: fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your full name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: studentIdController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Student / Employee ID',
                    prefixIcon: Icon(Icons.card_membership),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your ID';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your email';
                    }

                    if (!value.contains('@')) {
                      return 'Enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: departmentController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Department (e.g. CSE, EEE, BBA)',
                    prefixIcon: Icon(Icons.domain),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => register(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 25),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : register,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Create Student Account',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 15),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
