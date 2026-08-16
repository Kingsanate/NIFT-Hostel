import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../chat/chat_palette.dart';

/// Renders a student's profile photo when available, otherwise a
/// themed fallback icon. Safe against missing or malformed images.
/// Priority: profilePhotoBase64 → photoPath (URL) → fallback icon.
///
/// Features high-performance static memory caching and gapless playback
/// to guarantee ZERO flickering across frequent rebuilds, search typing,
/// and WebSocket sync events.
class StudentAvatar extends StatelessWidget {
  final String? photoBase64;
  final String? photoPath; // URL or null
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;

  static final Map<String, MemoryImage> _memoryImageCache = {};
  static final Map<String, Uint8List> _bytesCache = {};

  const StudentAvatar({
    super.key,
    required this.photoBase64,
    this.photoPath,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 36,
  });

  /// Memoized ImageProvider lookup ensuring the exact same ImageProvider
  /// identity is returned across all widget rebuilds.
  static ImageProvider? getImageProvider(String? photoBase64, [String? photoPath]) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      final clean = photoBase64.split(',').last.trim();
      if (clean.isNotEmpty) {
        final cached = _memoryImageCache[clean];
        if (cached != null) return cached;

        try {
          final bytes = _bytesCache.putIfAbsent(
            clean,
            () => base64Decode(clean),
          );
          final provider = MemoryImage(bytes);
          _memoryImageCache[clean] = provider;
          return provider;
        } catch (_) {
          return null;
        }
      }
    }

    if (photoPath != null && photoPath.isNotEmpty) {
      if (!photoPath.startsWith('data:') && photoPath.startsWith('http')) {
        return NetworkImage(photoPath);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = getImageProvider(photoBase64, photoPath);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fallbackColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: ChatPalette.border, width: 1),
      ),
      child: provider != null
          ? Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(fallbackIcon, size: size * 0.47, color: fallbackColor),
            )
          : Icon(fallbackIcon, size: size * 0.47, color: fallbackColor),
    );
  }
}
