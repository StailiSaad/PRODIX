import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../data/services/supabase_backend_service.dart';
import '../../../../core/theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final List<Uint8List> _mediaBytes = [];
  final List<String> _mediaExtensions = [];
  bool _isCreating = false;
  String _visibility = 'public';

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;

    for (final image in picked) {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      if (mounted) {
        setState(() {
          _mediaBytes.add(bytes);
          _mediaExtensions.add(ext);
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last;
    if (mounted) {
      setState(() {
        _mediaBytes.add(bytes);
        _mediaExtensions.add(ext);
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaBytes.removeAt(index);
      _mediaExtensions.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_mediaBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one photo or video')),
      );
      return;
    }

    final svc = context.read<SupabaseBackendService>();
    setState(() => _isCreating = true);

    try {
      await svc.createPost(
        caption: _captionCtrl.text.trim(),
        mediaBytes: _mediaBytes,
        mediaExtensions: _mediaExtensions,
        visibility: _visibility,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor,
        elevation: 0,
        title: const Text('New Post', style: TextStyle(color: AppTheme.textMain)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isCreating ? null : _submit,
              child: _isCreating
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3F008E)),
                    )
                  : const Text('Share'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media preview grid
            if (_mediaBytes.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _mediaBytes.length,
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _mediaBytes[i],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => _removeMedia(i),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

            const SizedBox(height: 16),

            // Add media buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickMedia,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam, size: 18),
                  label: const Text('Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Caption
            TextField(
              controller: _captionCtrl,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: AppTheme.textVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
              ),
            ),

            const SizedBox(height: 20),

            // Visibility toggle
            Text('Visibility', style: TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _visibility = 'public'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _visibility == 'public'
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : AppTheme.cardHighColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _visibility == 'public'
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.public, size: 24, color: _visibility == 'public' ? AppTheme.primaryColor : AppTheme.textVariant),
                          const SizedBox(height: 4),
                          Text('Public', style: TextStyle(
                            color: _visibility == 'public' ? AppTheme.primaryColor : AppTheme.textVariant,
                            fontWeight: _visibility == 'public' ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          )),
                          Text('Visible to everyone', style: TextStyle(
                            color: AppTheme.textVariant,
                            fontSize: 11,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _visibility = 'friends'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _visibility == 'friends'
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : AppTheme.cardHighColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _visibility == 'friends'
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people, size: 24, color: _visibility == 'friends' ? AppTheme.primaryColor : AppTheme.textVariant),
                          const SizedBox(height: 4),
                          Text('Amis', style: TextStyle(
                            color: _visibility == 'friends' ? AppTheme.primaryColor : AppTheme.textVariant,
                            fontWeight: _visibility == 'friends' ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          )),
                          Text('Friends only', style: TextStyle(
                            color: AppTheme.textVariant,
                            fontSize: 11,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardHighColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _visibility == 'public'
                          ? 'Your post will be visible to everyone on the FYP feed.'
                          : 'Your post will only be visible to your friends.',
                      style: const TextStyle(color: AppTheme.textVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
