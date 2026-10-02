import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final courseCodeController = TextEditingController();
  final fileUrlController = TextEditingController();
  final imageUrlController = TextEditingController();

  bool isSaving = false;
  bool isAdmin = false;
  String? categoryName;
  String? selectedFileName;
  String? selectedImageName;

  @override
  void initState() {
    super.initState();
    titleController.text = widget.post['title'] ?? '';
    descriptionController.text = widget.post['description'] ?? '';
    courseCodeController.text = widget.post['course_code'] ?? '';
    fileUrlController.text = widget.post['file_url'] ?? '';
    imageUrlController.text = widget.post['image_url'] ?? '';
    _loadCategory();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        isAdmin = (profile?['role'] ?? user.userMetadata?['role']) == 'admin';
      });
    } catch (error) {
      debugPrint('Could not load user role: $error');
    }
  }

  Future<void> _pickAttachment({required bool pdf}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: pdf ? ['pdf'] : ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      final file = result.files.single;
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Please login first.');

      final folder = pdf ? 'notes' : 'images';
      final extension = file.extension ?? (pdf ? 'pdf' : 'jpg');
      final path =
          '$folder/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage
          .from('uploads')
          .uploadBinary(
            path,
            file.bytes!,
            fileOptions: const FileOptions(upsert: false),
          );

      final url = Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        if (pdf) {
          fileUrlController.text = url;
          selectedFileName = 'PDF uploaded';
        } else {
          imageUrlController.text = url;
          selectedImageName = 'Image uploaded';
        }
      });
    } catch (error) {
      showMessage('Could not upload attachment: $error');
    }
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
      categoryName != null && categoryName!.toLowerCase().contains('notes');

  bool get isBusCategory => categoryName?.toLowerCase() == 'bus schedules';

  bool get isProjectCategory =>
      categoryName?.toLowerCase() == 'project collaboration';

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

    if (isBusCategory && !isAdmin) {
      showMessage('Only admins can edit Bus Schedules posts.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final updateMap = <String, dynamic>{
        'title': title,
        'description': description,
        'status': isBusCategory ? 'approved' : 'pending',
      };

      if (isProjectCategory) {
        updateMap['course_code'] = courseCodeController.text.trim();
      }

      if (isNotesCategory && fileUrl.isNotEmpty) {
        updateMap['file_url'] = fileUrl;
      }
      if (!isNotesCategory && !isProjectCategory && imageUrl.isNotEmpty) {
        updateMap['image_url'] = imageUrl;
      }

      try {
        await Supabase.instance.client
            .from('posts')
            .update(updateMap)
            .eq('id', widget.post['id']);
      } catch (updateErr) {
        debugPrint(
          'Primary update error: $updateErr. Retrying fallback update.',
        );

        String fallbackDescription = description;
        if (isNotesCategory && fileUrl.isNotEmpty) {
          fallbackDescription += '\n\n[Attached Notes]: $fileUrl';
        }
        if (!isNotesCategory && !isProjectCategory && imageUrl.isNotEmpty) {
          fallbackDescription += '\n\n[Attached Image]: $imageUrl';
        }

        await Supabase.instance.client
            .from('posts')
            .update({
              'title': title,
              'description': fallbackDescription,
              'status': isBusCategory ? 'approved' : 'pending',
            })
            .eq('id', widget.post['id']);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBusCategory
                ? 'Bus schedule updated successfully.'
                : 'Post updated successfully and submitted for admin review.',
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    courseCodeController.dispose();
    fileUrlController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Post Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

            if (isProjectCategory) ...[
              const Text(
                'Course Code',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: courseCodeController,
                decoration: InputDecoration(
                  hintText: 'Example: CSE 101',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

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

            // Image upload is available for non-notes categories except projects.
            if (!isNotesCategory && !isProjectCategory) ...[
              const Text(
                'Image',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isSaving ? null : () => _pickAttachment(pdf: false),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  selectedImageName ??
                      (imageUrlController.text.isEmpty
                          ? 'Choose image'
                          : 'Replace image'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a JPG, PNG, or WEBP image.',
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

              OutlinedButton.icon(
                onPressed: isSaving ? null : () => _pickAttachment(pdf: true),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  selectedFileName ??
                      (fileUrlController.text.isEmpty
                          ? 'Choose PDF'
                          : 'Replace PDF'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose one PDF file for students to download.',
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
                    : Text(
                        isBusCategory
                            ? 'Save Bus Schedule'
                            : 'Save & Resubmit Post',
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
