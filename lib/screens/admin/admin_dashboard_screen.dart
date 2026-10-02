import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../posts/create_post_screen.dart';
import '../posts/post_details_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> pendingPosts = [];
  List<Map<String, dynamic>> approvedPosts = [];
  List<Map<String, dynamic>> allUsers = [];

  List<Map<String, dynamic>> filteredPending = [];
  List<Map<String, dynamic>> filteredApproved = [];
  List<Map<String, dynamic>> filteredUsers = [];

  bool isLoading = true;
  bool isAdmin = false;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> checkAdmin() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = profile?['role'] ?? user.userMetadata?['role'] ?? 'student';

      if (role == 'admin') {
        setState(() {
          isAdmin = true;
        });

        await loadAllAdminData();
      } else {
        setState(() {
          isAdmin = false;
          isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Admin check error: $error');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadAllAdminData() async {
    try {
      final pendingResponse = await supabase
          .from('posts')
          .select('''
            *,
            profiles(full_name, department)
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final approvedResponse = await supabase
          .from('posts')
          .select('''
            *,
            profiles(full_name, department)
          ''')
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      final usersResponse = await supabase
          .from('profiles')
          .select('id, full_name, email, student_id, department, role')
          .order('full_name', ascending: true);

      if (!mounted) return;

      setState(() {
        pendingPosts = List<Map<String, dynamic>>.from(pendingResponse);
        approvedPosts = List<Map<String, dynamic>>.from(approvedResponse);
        allUsers = List<Map<String, dynamic>>.from(usersResponse);
        _applySearchFilter(searchController.text);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage('Could not load data: $error');
    }
  }

  void _applySearchFilter(String query) {
    if (query.trim().isEmpty) {
      filteredPending = List.from(pendingPosts);
      filteredApproved = List.from(approvedPosts);
      filteredUsers = List.from(allUsers);
      return;
    }

    final lower = query.toLowerCase();
    filteredPending = pendingPosts.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final author = (p['profiles']?['full_name'] ?? '')
          .toString()
          .toLowerCase();
      return title.contains(lower) ||
          desc.contains(lower) ||
          author.contains(lower);
    }).toList();

    filteredApproved = approvedPosts.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final author = (p['profiles']?['full_name'] ?? '')
          .toString()
          .toLowerCase();
      return title.contains(lower) ||
          desc.contains(lower) ||
          author.contains(lower);
    }).toList();

    filteredUsers = allUsers.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final dept = (u['department'] ?? '').toString().toLowerCase();
      final studentId = (u['student_id'] ?? '').toString().toLowerCase();
      return name.contains(lower) ||
          email.contains(lower) ||
          dept.contains(lower) ||
          studentId.contains(lower);
    }).toList();
  }

  Future<void> updatePostStatus(int postId, String status) async {
    try {
      await supabase.from('posts').update({'status': status}).eq('id', postId);

      await loadAllAdminData();

      if (!mounted) return;

      showMessage(
        status == 'approved' ? 'Post approved successfully.' : 'Post rejected.',
      );
    } catch (error) {
      showMessage('Could not update post: $error');
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      await supabase.from('posts').delete().eq('id', postId);
      await loadAllAdminData();

      if (!mounted) return;

      showMessage('Post deleted by admin.');
    } catch (error) {
      showMessage('Could not delete post: $error');
    }
  }

  Future<void> updateUserRole(
    String userId,
    String currentRole,
    String newRole,
  ) async {
    try {
      // 1. Try update DB table
      await supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId);

      await loadAllAdminData();

      if (!mounted) return;

      showMessage('User role updated to ${newRole.toUpperCase()}');
    } catch (error) {
      showMessage('Could not update role: $error');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> confirmAction(Map<String, dynamic> post, String status) async {
    final title = status == 'approved' ? 'Approve Post?' : 'Reject Post?';
    final message = status == 'approved'
        ? 'This post will become visible to all students.'
        : 'This post will be rejected.';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await updatePostStatus(post['id'], status);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(
          child: Text(
            'Access denied.\nAdmin privileges required.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh admin data',
              onPressed: loadAllAdminData,
            ),
            IconButton(
              icon: const Icon(Icons.directions_bus_outlined),
              tooltip: 'Create Bus Schedule',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreatePostScreen(
                      initialCategoryName: 'Bus Schedules',
                    ),
                  ),
                );
                loadAllAdminData();
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                text: 'Pending (${pendingPosts.length})',
                icon: const Icon(Icons.pending_actions),
              ),
              Tab(
                text: 'Approved (${approvedPosts.length})',
                icon: const Icon(Icons.check_circle_outline),
              ),
              Tab(
                text: 'Users (${allUsers.length})',
                icon: const Icon(Icons.manage_accounts),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search posts or user accounts...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              _applySearchFilter('');
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _applySearchFilter(val);
                  });
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPendingList(),
                  _buildApprovedList(),
                  _buildUserRolesList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (filteredPending.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadAllAdminData,
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                'No pending posts for review.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadAllAdminData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredPending.length,
        itemBuilder: (context, index) {
          final post = filteredPending[index];
          final studentName = post['profiles']?['full_name'] ?? 'Student';

          return Card(
            margin: const EdgeInsets.only(bottom: 15),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailsScreen(post: post),
                  ),
                );
                if (result == true) {
                  loadAllAdminData();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post['description'] ?? '',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'By: $studentName',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => confirmAction(post, 'rejected'),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => confirmAction(post, 'approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovedList() {
    if (filteredApproved.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadAllAdminData,
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                'No approved live posts.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadAllAdminData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredApproved.length,
        itemBuilder: (context, index) {
          final post = filteredApproved[index];
          final studentName = post['profiles']?['full_name'] ?? 'Student';

          return Card(
            margin: const EdgeInsets.only(bottom: 15),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailsScreen(post: post),
                  ),
                );
                if (result == true) {
                  loadAllAdminData();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            post['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          tooltip: 'Remove Post',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text(
                                  'Are you sure you want to delete this live post?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              deletePost(post['id']);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post['description'] ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'By: $studentName',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserRolesList() {
    if (filteredUsers.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadAllAdminData,
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Center(
              child: Text(
                'No user accounts found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadAllAdminData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final userItem = filteredUsers[index];
          final userId = userItem['id'];
          final name = userItem['full_name'] ?? 'Student';
          final email = userItem['email'] ?? '';
          final role = (userItem['role'] ?? 'student').toString().toLowerCase();
          final isAdminRole = role == 'admin';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                backgroundColor: isAdminRole
                    ? Colors.deepOrange.shade100
                    : Colors.blue.shade100,
                child: Icon(
                  isAdminRole ? Icons.admin_panel_settings : Icons.person,
                  color: isAdminRole ? Colors.deepOrange : Colors.blue,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$email\nRole: ${role.toUpperCase()}'),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdminRole
                      ? Colors.grey.shade200
                      : Colors.deepOrange,
                  foregroundColor: isAdminRole ? Colors.black87 : Colors.white,
                  elevation: 1,
                ),
                onPressed: () {
                  final targetRole = isAdminRole ? 'student' : 'admin';
                  final title = isAdminRole ? 'Make Student?' : 'Make Admin?';
                  final desc = isAdminRole
                      ? 'Demote $name to standard student access?'
                      : 'Promote $name to full Admin access?';

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(title),
                      content: Text(desc),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            updateUserRole(userId, role, targetRole);
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(isAdminRole ? 'Make Student' : 'Make Admin'),
              ),
            ),
          );
        },
      ),
    );
  }
}
