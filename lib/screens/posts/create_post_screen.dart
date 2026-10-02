import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialCategoryName;

  const CreatePostScreen({
    super.key,
    this.initialCategoryName,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final fileUrlController = TextEditingController();
  final imageUrlController = TextEditingController();

  bool isSubmitting = false;

  bool get isNotesCategory =>
      widget.initialCategoryName != null &&
      widget.initialCategoryName!.toLowerCase().contains('notes');

  Future<void> createPost() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final fileUrl = fileUrlController.text.trim();
    final imageUrl = imageUrlController.text.trim();

    if (title.isEmpty) {
      showMessage('Please enter a title.');
      return;
    }

    if (description.isEmpty) {
      showMessage('Please enter a description.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      showMessage('Please login first.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // 1. Ensure user profile exists in profiles table
      try {
        final profileCheck = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (profileCheck == null) {
          final fullName = user.userMetadata?['full_name'] ??
              (user.email != null && user.email!.contains('@')
                  ? user.email!.split('@')[0]
                  : 'Student');
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'full_name': fullName,
            'email': user.email ?? '',
            'student_id': user.userMetadata?['student_id'] ?? '',
            'department': user.userMetadata?['department'] ?? '',
            'role': user.userMetadata?['role'] ?? 'student',
          });
        }
      } catch (profileErr) {
        debugPrint('Profile check warning: $profileErr');
      }

      // 2. Resolve category ID
      int? categoryId;
      if (widget.initialCategoryName != null &&
          widget.initialCategoryName!.trim().isNotEmpty) {
        try {
          final catSearch = widget.initialCategoryName!
              .replaceAll("Notes & Study Materials", "Notes");
          final catList = await Supabase.instance.client
              .from('categories')
              .select('id')
              .ilike('name', '%$catSearch%');

          if (catList.isNotEmpty) {
            categoryId = catList.first['id'] as int?;
          }
        } catch (catErr) {
          debugPrint('Category lookup warning: $catErr');
        }
      }

      // 3. Prepare post payload
      final postMap = <String, dynamic>{
        'user_id': user.id,
        'title': title,
        'description': description,
        'price': 0.0,
        'status': 'pending',
      };

      if (categoryId != null) {
        postMap['category_id'] = categoryId;
      }

      if (isNotesCategory && fileUrl.isNotEmpty) {
        postMap['file_url'] = fileUrl;
      }

      if (!isNotesCategory && imageUrl.isNotEmpty) {
        postMap['image_url'] = imageUrl;
      }

      // Primary insert
      try {
        await Supabase.instance.client.from('posts').insert(postMap);
      } catch (insertErr) {
        debugPrint('Primary insert error: $insertErr. Retrying fallback insert.');

        String fallbackDescription = description;
        if (isNotesCategory && fileUrl.isNotEmpty) {
          fallbackDescription += '\n\n[Attached Notes]: $fileUrl';
        }
        if (!isNotesCategory && imageUrl.isNotEmpty) {
          fallbackDescription += '\n\n[Attached Image]: $imageUrl';
        }

        final fallbackMap = <String, dynamic>{
          'user_id': user.id,
          'title': title,
          'description': fallbackDescription,
          'price': 0.0,
          'status': 'pending',
        };

        if (categoryId != null) {
          fallbackMap['category_id'] = categoryId;
        }

        try {
          await Supabase.instance.client.from('posts').insert(fallbackMap);
        } catch (fallbackErr2) {
          final basicMap = <String, dynamic>{
            'user_id': user.id,
            'title': title,
            'description': fallbackDescription,
            'status': 'pending',
          };
          await Supabase.instance.client.from('posts').insert(basicMap);
        }
      }

      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Post submitted successfully! Waiting for admin approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      titleController.clear();
      descriptionController.clear();
      fileUrlController.clear();
      imageUrlController.clear();

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      showMessage('Failed to create post: $error');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    fileUrlController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialCategoryName != null
            ? 'Create ${widget.initialCategoryName}'
            : 'Create Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initialCategoryName == 'Notes & Study Materials'
                  ? 'Upload Lecture Notes & Study Materials'
                  : widget.initialCategoryName == 'Lost and Found'
                      ? 'Post Lost or Found Item'
                      : 'Create a New Post',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNotesCategory
                  ? 'Share lecture notes and study materials with LU students.'
                  : 'Share details, photos, or announcements with LU students.',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 25),

            // Title
            const Text(
              'Post Title *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: widget.initialCategoryName == 'Lost and Found'
                    ? 'Example: Found Blue ID Card / Lost Wallet near cafeteria'
                    : 'Example: CSE 101 Lecture Notes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            const Text(
              'Description *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe your post details...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Image Option (Shown for Lost and Found & non-Notes categories)
            if (!isNotesCategory) ...[
              const Text(
                'Image',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: imageUrlController,
                decoration: InputDecoration(
                  hintText: 'Paste image URL or photo link of found item...',
                  prefixIcon:
                      const Icon(Icons.image_outlined, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Students can upload/share a photo link of the found item or post image.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Upload Notes / Material Link Section (Only shown for Notes category)
            if (isNotesCategory) ...[
              const Text(
                'Upload PDF Notes or Document Link *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: fileUrlController,
                decoration: InputDecoration(
                  labelText: 'PDF / Document Link',
                  hintText: 'Paste Google Drive, Dropbox, or PDF link...',
                  prefixIcon:
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste direct link to Google Drive, Dropbox, or PDF document file.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : createPost,
                child: isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Post for Approval',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
