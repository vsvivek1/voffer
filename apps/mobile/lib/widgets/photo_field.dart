import 'package:flutter/material.dart';

import '../app_state.dart';
import '../photos/photo_picker.dart';
import 'voffer_image.dart';

/// A photo on a form: either one already uploaded ([url]) or one just picked
/// on the device that still needs uploading ([picked]).
class PhotoValue {
  const PhotoValue.uploaded(String this.url) : picked = null;
  const PhotoValue.picked(PickedPhoto this.picked) : url = null;

  final String? url;
  final PickedPhoto? picked;

  /// Uploads a newly picked photo and returns its URL, or returns the
  /// existing URL. Null [value] means no photo.
  static Future<String?> resolve(AppState app, PhotoValue? value) async {
    final picked = value?.picked;
    if (picked == null) return value?.url;
    return app.repository.uploadPhoto(app.user!, picked);
  }
}

/// Lets a firm take or choose a photo, preview it and remove it.
class PhotoField extends StatefulWidget {
  const PhotoField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.aspectRatio = 16 / 9,
  });

  final String label;
  final PhotoValue? value;
  final ValueChanged<PhotoValue?> onChanged;
  final double aspectRatio;

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  bool _busy = false;

  Future<void> _pick(PhotoSource source) async {
    setState(() => _busy = true);
    try {
      final photo = await AppScope.read(context).photos.pick(source);
      if (photo != null) widget.onChanged(PhotoValue.picked(photo));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    final picked = value?.picked;
    final Widget preview;
    if (picked != null) {
      preview = Image.memory(
        picked.bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (value?.url != null) {
      preview = VofferImage(value!.url!);
    } else {
      preview = ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.add_a_photo_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: widget.aspectRatio, child: preview),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(PhotoSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(PhotoSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
            ),
            if (value != null)
              TextButton.icon(
                onPressed: _busy ? null : () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}
