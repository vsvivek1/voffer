import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shows an uploaded image. Demo mode stores uploads as `data:` URIs, so
/// those are decoded in memory; anything else is fetched and cached.
class VofferImage extends StatelessWidget {
  const VofferImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    if (url.startsWith('data:')) {
      final bytes = Uri.tryParse(url)?.data?.contentAsBytes();
      if (bytes == null) return placeholder;
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
