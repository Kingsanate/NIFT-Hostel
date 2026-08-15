import 'dart:convert';

import 'package:flutter/material.dart';

import '../../chat/chat_palette.dart';

/// Renders a student's profile photo when available, otherwise a
/// themed fallback icon. Safe against missing or malformed images.
/// Priority: profilePhotoBase64 → photoPath (URL) → fallback icon.
class StudentAvatar extends StatelessWidget {
  final String? photoBase64;
  final String? photoPath; // URL or null
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double size;

  const StudentAvatar({
    super.key,
    required this.photoBase64,
    this.photoPath,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;

    // 1. Prefer base64 (already decoded, instant render)
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        provider = MemoryImage(base64Decode(photoBase64!.split(',').last));
      } catch (_) {
        provider = null;
      }
    }

    // 2. Fall back to network URL (guard against accidental base64 in photoPath)
    if (provider == null && photoPath != null && photoPath!.isNotEmpty) {
      if (!photoPath!.startsWith('data:') && photoPath!.startsWith('http')) {
        provider = NetworkImage(photoPath!);
      }
    }

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
          ? Image(image: provider, fit: BoxFit.cover)
          : Icon(fallbackIcon, size: size * 0.47, color: fallbackColor),
    );
  }
}
