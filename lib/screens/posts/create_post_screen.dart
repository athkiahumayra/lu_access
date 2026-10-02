import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostScreen extends StatefulWidget {
  final String? initialCategoryName;

  const CreatePostScreen({super.key, this.initialCategoryName});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final courseCodeController = TextEditingController();

  bool isSubmitting = false;
  bool isAdmin = false;
  String? fileUrl;
  String? imageUrl;
  String? selectedFileName;
  String? selectedImageName;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  bool get isNotesCategory =>
      widget.initialCategoryName != null &&
      widget.initialCategoryName!.toLowerCase().contains('notes');

  bool get isBusCategory =>
      widget.initialCategoryName?.toLowerCase() == 'bus schedules';

  bool get isProjectCategory =>
      widget.initialCategoryName?.toLowerCase() == 'project collaboration';

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

  Future<String?> _uploadFile({required bool pdf}) async {
    final result = await FilePicker.platform.pickFiles(
      type: pdf ? FileType.custom : FileType.image,
      allowedExtensions: pdf ? ['pdf'] : ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return null;

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
          fileOptions: FileOptions(upsert: false),
        );

    return Supabase.instance.client.storage.from('uploads').getPublicUrl(path);
  }

  Future<void> _pickPdf() async {
    try {
      final url = await _uploadFile(pdf: true);
      if (url == null || !mounted) return;
      setState(() {
        fileUrl = url;
        selectedFileName = 'PDF uploaded';
      });
    } catch (error) {
      showMessage('Could not upload PDF: $error');
    }
  }

  Future<void> _pickImage() async {
    try {
      final url = await _uploadFile(pdf: false);
      if (url == null || !mounted) return;
      setState(() {
        imageUrl = url;
        selectedImageName = 'Image uploaded';
      });
    } catch (error) {
      showMessage('Could not upload image: $error');
    }
  }

  Future<void> createPost() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty) {
      showMessage('Please enter a title.');
      return;
    }

    if (description.isEmpty) {
      showMessage('Please enter a description.');
      return;
    }

    if (isBusCategory && !isAdmin) {
      showMessage('Only admins can create Bus Schedules posts.');
      return;
    }

    if (isNotesCategory && fileUrl == null) {
      showMessage('Please upload a PDF.');
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
          final fullName =
              user.userMetadata?['full_name'] ??
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
          final catSearch = widget.initialCategoryName!.replaceAll(
            "Notes & Study Materials",
            "Notes",
          );
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
        'status': isBusCategory ? 'approved' : 'pending',
      };

      if (categoryId != null) {
        postMap['category_id'] = categoryId;
      }

      if (isProjectCategory && courseCodeController.text.trim().isNotEmpty) {
        postMap['course_code'] = courseCodeController.text.trim();
      }

      if (isNotesCategory && fileUrl != null) {
        postMap['file_url'] = fileUrl;
      }

      if (!isNotesCategory && !isProjectCategory && imageUrl != null) {
        postMap['image_url'] = imageUrl;
      }

      // Primary insert
      try {
        await Supabase.instance.client.from('posts').insert(postMap);
      } catch (insertErr) {
        debugPrint(
          'Primary insert error: $insertErr. Retrying fallback insert.',
        );

        String fallbackDescription = description;
        if (isNotesCategory && fileUrl != null) {
          fallbackDescription += '\n\n[Attached Notes]: $fileUrl';
        }
        if (!isNotesCategory && !isProjectCategory && imageUrl != null) {
          fallbackDescription += '\n\n[Attached Image]: $imageUrl';
        }

        final fallbackMap = <String, dynamic>{
          'user_id': user.id,
          'title': title,
          'description': fallbackDescription,
          'price': 0.0,
          'status': isBusCategory ? 'approved' : 'pending',
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
            'status': isBusCategory ? 'approved' : 'pending',
          };
          await Supabase.instance.client.from('posts').insert(basicMap);
        }
      }

      if (!mounted) return;

      setState(() {
        isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBusCategory
                ? 'Bus schedule published successfully.'
                : 'Post submitted successfully! Waiting for admin approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      titleController.clear();
      descriptionController.clear();
      courseCodeController.clear();
      fileUrl = null;
      imageUrl = null;

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    courseCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialCategoryName != null
              ? 'Create ${widget.initialCategoryName}'
              : 'Create Post',
        ),
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isNotesCategory
                  ? 'Share lecture notes and study materials with LU students.'
                  : 'Share details, photos, or announcements with LU students.',
              style: const TextStyle(color: Colors.grey),
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

            // Image upload is available for non-notes categories except projects.
            if (!isNotesCategory && !isProjectCategory) ...[
              const Text(
                'Image',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isSubmitting ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(selectedImageName ?? 'Choose image'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a JPG, PNG, or WEBP image.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
            ],

            // Upload Notes / Material Link Section (Only shown for Notes category)
            if (isNotesCategory) ...[
              const Text(
                'Upload PDF Notes or Document Link *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              OutlinedButton.icon(
                onPressed: isSubmitting ? null : _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(selectedFileName ?? 'Choose PDF'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose one PDF file to attach to this post.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isBusCategory
                            ? 'Publish Bus Schedule'
                            : 'Submit Post for Approval',
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
