import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/login_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../messages/messages_screen.dart';
import '../posts/create_post_screen.dart';
import '../posts/posts_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String studentName = 'Student';
  String userRole = 'student';
  bool isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    loadStudentProfile();
  }

  Future<void> loadStudentProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final name =
          profile?['full_name'] ??
          user.userMetadata?['full_name'] ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@')[0]
              : 'Student');

      final role = profile?['role'] ?? 'student';

      setState(() {
        studentName = name;
        userRole = role;
        isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading profile: $error');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'LU Access';
    if (_currentIndex == 1) {
      appBarTitle = 'Student Profile';
    } else if (_currentIndex == 2) {
      appBarTitle = 'Admin Profile';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (userRole == 'admin' && _currentIndex == 0)
            IconButton(
              icon: const Icon(
                Icons.admin_panel_settings,
                color: Colors.deepOrange,
              ),
              tooltip: 'Admin Dashboard',
              onPressed: () {
                setState(() {
                  _currentIndex = 2;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.message_outlined),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MessagesScreen()),
              );
            },
          ),
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () {
                setState(() {
                  _currentIndex = 1;
                });
              },
            ),
        ],
      ),

      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 4,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Post'),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, userRole == 'admin' ? 2 : 1),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 2 && userRole != 'admin') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access Denied: Admin privileges required.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Student Profile',
          ),
          if (userRole == 'admin')
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin Profile',
            ),
        ],
      ),

      body: IndexedStack(
        index: _currentIndex.clamp(0, userRole == 'admin' ? 2 : 1),
        children: [
          // Index 0: Home Main Content
          _buildHomeBody(context),

          // Index 1: Student Profile
          const ProfileScreen(),

          // Index 2: Admin Profile (Only if Admin)
          if (userRole == 'admin')
            const AdminDashboardScreen()
          else
            const Center(
              child: Text(
                'Access Denied.\nAdmin privileges required.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLoading ? 'Loading...' : 'Welcome, $studentName',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Leading University Student Portal',
                style: TextStyle(color: Colors.grey),
              ),
              if (userRole == 'admin') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.deepOrange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (userRole == 'admin') ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.deepOrange.shade50,
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.deepOrange,
                ),
                title: const Text(
                  'Admin Moderation Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Review pending posts & user activities'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  setState(() {
                    _currentIndex = 2;
                  });
                },
              ),
            ),
          ],

          const SizedBox(height: 25),

          const Text(
            'Campus Services',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _serviceCard(
                icon: Icons.menu_book,
                title: 'Notes & Materials',
                color: const Color(0xFFE3F2FD),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PostsScreen(
                        categoryName: 'Notes & Study Materials',
                      ),
                    ),
                  );
                },
              ),
              _serviceCard(
                icon: Icons.find_in_page_outlined,
                title: 'Lost and Found',
                color: const Color(0xFFFFF3E0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PostsScreen(categoryName: 'Lost and Found'),
                    ),
                  );
                },
              ),
              _serviceCard(
                icon: Icons.groups,
                title: 'Project Collaboration',
                color: const Color(0xFFE8F5E9),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PostsScreen(
                        categoryName: 'Project Collaboration',
                      ),
                    ),
                  );
                },
              ),
              _serviceCard(
                icon: Icons.info,
                title: 'Campus Information',
                color: const Color(0xFFFFEBEE),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PostsScreen(categoryName: 'Campus Information'),
                    ),
                  );
                },
              ),
              _serviceCard(
                icon: Icons.directions_bus_outlined,
                title: 'Bus Schedules',
                color: const Color(0xFFE8EAF6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PostsScreen(categoryName: 'Bus Schedules'),
                    ),
                  );
                },
              ),
              _serviceCard(
                icon: Icons.search,
                title: 'Search All',
                color: const Color(0xFFE0F7FA),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.blueGrey.shade800),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
