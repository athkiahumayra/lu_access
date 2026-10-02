import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'message_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> conversations = [];
  Map<String, String> userNames = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadConversations();
  }

  Future<void> loadConversations() async {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    try {
      final response = await supabase
          .from('messages')
          .select('''
            id,
            sender_id,
            receiver_id,
            message,
            created_at
          ''')
          .or(
            'sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}',
          )
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> allMessages =
          List<Map<String, dynamic>>.from(response);

      final Map<String, Map<String, dynamic>> uniqueChats = {};
      final Set<String> otherUserIds = {};

      for (final message in allMessages) {
        final otherUserId = message['sender_id'] == currentUser.id
            ? message['receiver_id']
            : message['sender_id'];

        if (otherUserId != null) {
          otherUserIds.add(otherUserId);
          if (!uniqueChats.containsKey(otherUserId)) {
            uniqueChats[otherUserId] = message;
          }
        }
      }

      // Fetch profile names for other users
      if (otherUserIds.isNotEmpty) {
        final profilesResponse = await supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', otherUserIds.toList());

        for (final profile in profilesResponse) {
          userNames[profile['id']] = profile['full_name'] ?? 'Student';
        }
      }

      if (!mounted) return;

      setState(() {
        conversations = uniqueChats.values.toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading messages: $e'),
        ),
      );
    }
  }

  void _showNewChatDialog() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final profiles = await supabase
          .from('profiles')
          .select('id, full_name, department')
          .neq('id', currentUser.id)
          .order('full_name');

      if (!mounted) return;

      final List<Map<String, dynamic>> students =
          List<Map<String, dynamic>>.from(profiles);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          String searchKey = '';
          return StatefulBuilder(
            builder: (context, setModalState) {
              final filtered = students.where((s) {
                final name = (s['full_name'] ?? '').toString().toLowerCase();
                final dept = (s['department'] ?? '').toString().toLowerCase();
                return name.contains(searchKey.toLowerCase()) ||
                    dept.contains(searchKey.toLowerCase());
              }).toList();

              return Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Start New Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search student by name or department...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchKey = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No students found.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, idx) {
                                final student = filtered[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: Text(
                                    student['full_name'] ?? 'Student',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    student['department'] ?? 'Leading University',
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MessageScreen(
                                          receiverId: student['id'],
                                          receiverName:
                                              student['full_name'] ?? 'Student',
                                        ),
                                      ),
                                    ).then((_) => loadConversations());
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load student list: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _showNewChatDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        tooltip: 'Start Chat',
        child: const Icon(Icons.message),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No conversations yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showNewChatDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Message a Student'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadConversations,
                  child: ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final message = conversations[index];

                      final otherUserId =
                          message['sender_id'] == currentUser?.id
                              ? message['receiver_id']
                              : message['sender_id'];

                      final name = userNames[otherUserId] ?? 'Student';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(
                            Icons.person,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          message['message'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessageScreen(
                                receiverId: otherUserId,
                                receiverName: name,
                              ),
                            ),
                          ).then((_) {
                            loadConversations();
                          });
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
