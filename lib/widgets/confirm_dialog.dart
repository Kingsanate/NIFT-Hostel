import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../chat/chat_palette.dart';

/// Reusable, lightweight confirmation dialog used across the app for all
/// delete / remove / destructive actions.
///
/// Returns `true` when the user confirms, `false` / `null` otherwise.
class ConfirmDialog {
  const ConfirmDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    IconData icon = Icons.delete_forever_rounded,
    Color? accent,
    bool barrierDismissible = true,
  }) {
    final danger = accent ?? ChatPalette.accentRose;
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ChatPalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: danger.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: danger.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: danger, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ChatPalette.dim,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: ChatPalette.surfaceHigh,
                      ),
                        child: Text(
                          cancelLabel,
                          style: TextStyle(
                            color: ChatPalette.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: danger,
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(
              begin: const Offset(0.95, 0.95),
              duration: 180.ms,
              curve: Curves.easeOutCubic,
            ).fadeIn(),
      ),
    );
  }
}
