import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../posts/post_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> posts = [];
  bool isLoading = false;
  bool hasSearched = false;
  String searchedKeyword = '';

  Future<void> searchPosts(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      setState(() {
        posts = [];
        hasSearched = false;
        searchedKeyword = '';
      });
      return;
    }

    setState(() {
      isLoading = true;
      hasSearched = true;
      searchedKeyword = query;
    });

    try {
      final response = await supabase
          .from('posts')
          .select('''
            *,
            profiles(full_name, department)
          ''')
          .eq('status', 'approved')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        posts = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $error'),
        ),
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Campus Posts'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: searchPosts,
              onChanged: (val) {
                if (val.trim().isEmpty && hasSearched) {
                  setState(() {
                    posts = [];
                    hasSearched = false;
                    searchedKeyword = '';
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search notes, announcements, project team...',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: () => searchPosts(searchController.text),
                ),
                suffixIcon: searchController.text.isNotEmpty || hasSearched
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            posts = [];
                            hasSearched = false;
                            searchedKeyword = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : !hasSearched
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'Search for notes, announcements, services and more.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : posts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.sentiment_dissatisfied,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results found for "$searchedKeyword".\nTry searching with different terms.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                final profile = post['profiles'];
                                final studentName = profile != null
                                    ? profile['full_name'] ?? 'Student'
                                    : 'Student';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      child: const Icon(
                                        Icons.article,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    title: Text(
                                      post['title'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        '$studentName\n${post['description'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PostDetailsScreen(
                                            post: post,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
