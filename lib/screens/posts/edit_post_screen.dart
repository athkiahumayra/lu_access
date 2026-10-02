import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({
    super.key,
    required this.post,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final fileUrlController = TextEditingController();
  final imageUrlController = TextEditingController();

  bool isSaving = false;
  String? categoryName;

  @override
  void initState() {
    super.initState();
    titleController.text = widget.post['title'] ?? '';
    descriptionController.text = widget.post['description'] ?? '';
    fileUrlController.text = widget.post['file_url'] ?? '';
    imageUrlController.text = widget.post['image_url'] ?? '';
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final catId = widget.post['category_id'];
    if (catId != null) {
      try {
        final cat = await Supabase.instance.client
            .from('categories')
            .select('name')
            .eq('id', catId)
            .maybeSingle();
        if (mounted && cat != null) {
          setState(() {
            categoryName = cat['name']?.toString();
          });
        }
      } catch (e) {
        debugPrint('Error loading category: $e');
      }
    }
  }

  bool get isNotesCategory =>
      categoryName != null &&
      categoryName!.toLowerCase().contains('notes');

  Future<void> updatePost() async {
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

    setState(() {
      isSaving = true;
    });

    try {
      final updateMap = <String, dynamic>{
        'title': title,
        'description': description,
        'status': 'pending',
      };

      if (isNotesCategory && fileUrl.isNotEmpty) {
        updateMap['file_url'] = fileUrl;
      }
      if (!isNotesCategory && imageUrl.isNotEmpty) {
        updateMap['image_url'] = imageUrl;
      }

      try {
        await Supabase.instance.client
            .from('posts')
            .update(updateMap)
            .eq('id', widget.post['id']);
      } catch (updateErr) {
        debugPrint('Primary update error: $updateErr. Retrying fallback update.');

        String fallbackDescription = description;
        if (isNotesCategory && fileUrl.isNotEmpty) {
          fallbackDescription += '\n\n[Attached Notes]: $fileUrl';
        }
        if (!isNotesCategory && imageUrl.isNotEmpty) {
          fallbackDescription += '\n\n[Attached Image]: $imageUrl';
        }

        await Supabase.instance.client.from('posts').update({
          'title': title,
          'description': fallbackDescription,
          'status': 'pending',
        }).eq('id', widget.post['id']);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Post updated successfully and submitted for admin review.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage('Failed to update post: $error');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
        title: const Text('Edit Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Post Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Updating your post will resubmit it for admin approval.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 25),

            // Title
            const Text(
              'Post Title *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Post Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            const Text(
              'Description *',
              style: TextStyle(fontWeight: FontWeight.bold),
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

            // Image Section (Only shown if NOT Notes & Study Materials)
            if (!isNotesCategory) ...[
              const Text(
                'Image',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],

            // Upload Notes Section (Only shown for Notes category)
            if (isNotesCategory) ...[
              const Text(
                'PDF Notes / Document Link',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: fileUrlController,
                decoration: InputDecoration(
                  labelText: 'PDF / Document Link',
                  hintText: 'Paste Google Drive, PDF, or Document link...',
                  prefixIcon:
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload your notes link (e.g. Google Drive, Dropbox, PDF link) for students to download.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 30),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : updatePost,
                child: isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save & Resubmit Post',
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
