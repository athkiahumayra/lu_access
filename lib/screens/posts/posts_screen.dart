import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'create_post_screen.dart';
import 'post_details_screen.dart';

class PostsScreen extends StatefulWidget {
  final String categoryName;

  const PostsScreen({super.key, required this.categoryName});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  List<Map<String, dynamic>> allPosts = [];
  List<Map<String, dynamic>> filteredPosts = [];

  bool isLoading = true;
  bool isSearching = false;
  bool isAdmin = false;

  bool get isBusSchedules =>
      widget.categoryName.toLowerCase() == 'bus schedules';

  bool get isProjectCategory =>
      widget.categoryName.toLowerCase() == 'project collaboration';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPosts();
    _loadRole();
  }

  Future<void> _loadRole() async {
    if (!isBusSchedules) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      isAdmin = (profile?['role'] ?? user.userMetadata?['role']) == 'admin';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadPosts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final categoryList = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .ilike(
            'name',
            '%${widget.categoryName.replaceAll("Notes & Study Materials", "Notes")}%',
          );

      List<int> categoryIds = [];

      if (categoryList.isNotEmpty) {
        categoryIds = List<int>.from(categoryList.map((c) => c['id']));
      }

      var query = Supabase.instance.client.from('posts').select('''
            *,
            profiles(id, full_name)
          ''');

      if (!isBusSchedules) {
        query = query.eq('status', 'approved');
      }

      if (categoryIds.isNotEmpty) {
        query = query.inFilter('category_id', categoryIds);
      }

      final data = await query.order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        allPosts = List<Map<String, dynamic>>.from(data);
        filteredPosts = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading posts: $error');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load posts: $error')));
    }
  }

  void _filterPosts(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        filteredPosts = List.from(allPosts);
      });
      return;
    }

    final lower = query.toLowerCase();
    setState(() {
      filteredPosts = allPosts.where((post) {
        final title = (post['title'] ?? '').toString().toLowerCase();
        final desc = (post['description'] ?? '').toString().toLowerCase();
        return title.contains(lower) || desc.contains(lower);
      }).toList();
    });
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: 'Filter in category...',
                  border: InputBorder.none,
                ),
                onChanged: _filterPosts,
              )
            : Text(widget.categoryName),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            tooltip: isSearching ? 'Close Search' : 'Search Posts',
            onPressed: () {
              setState(() {
                if (isSearching) {
                  isSearching = false;
                  _searchController.clear();
                  filteredPosts = List.from(allPosts);
                } else {
                  isSearching = true;
                }
              });
            },
          ),
          if (!isBusSchedules || isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create Post',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePostScreen(
                      initialCategoryName: widget.categoryName,
                    ),
                  ),
                );
                loadPosts();
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredPosts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSearching
                          ? 'No matching posts found.'
                          : 'No posts available in "${widget.categoryName}".',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    if (!isBusSchedules || isAdmin)
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatePostScreen(
                                initialCategoryName: widget.categoryName,
                              ),
                            ),
                          );
                          loadPosts();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Post'),
                      ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadPosts,
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount:
                    filteredPosts.length +
                    (widget.categoryName.contains('Notes') ||
                            widget.categoryName.toLowerCase().contains('lost')
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  final isSpecialCategory =
                      widget.categoryName.contains('Notes') ||
                      widget.categoryName.toLowerCase().contains('lost');

                  if (isSpecialCategory && index == 0) {
                    final isNotes = widget.categoryName.contains('Notes');
                    return Card(
                      color: Colors.blue.shade50,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(
                                isNotes
                                    ? Icons.upload_file
                                    : Icons.find_in_page_outlined,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isNotes
                                        ? 'Have lecture notes to share?'
                                        : 'Lost or found an item on campus?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isNotes
                                        ? 'Upload and share your study notes.'
                                        : 'Post details & upload found item image.',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreatePostScreen(
                                      initialCategoryName: widget.categoryName,
                                    ),
                                  ),
                                );
                                loadPosts();
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                isNotes ? 'Upload Notes' : 'Post Item',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final postIndex = isSpecialCategory ? index - 1 : index;
                  final post = filteredPosts[postIndex];
                  final profile = post['profiles'];
                  final studentName = profile != null
                      ? profile['full_name'] ?? 'Student'
                      : 'Student';

                  final hasFile =
                      post['file_url'] != null &&
                      post['file_url'].toString().trim().isNotEmpty;

                  final hasImage =
                      post['image_url'] != null &&
                      post['image_url'].toString().trim().isNotEmpty;

                  final courseCode = (post['course_code'] ?? '')
                      .toString()
                      .trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                          loadPosts();
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
                            if (isProjectCategory && courseCode.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  courseCode,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              post['description'] ?? '',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            if (hasImage) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  post['image_url'].toString().trim(),
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ],
                            if (hasFile) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.attach_file,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Notes Attached',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _openFile(post['file_url'].toString()),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Download PDF'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    studentName,
                                    style: const TextStyle(color: Colors.grey),
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
            ),
    );
  }
}
