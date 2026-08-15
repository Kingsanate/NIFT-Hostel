import 'package:flutter/material.dart';

/// Butter-smooth slide+fade page route used across the app's
/// Students Entry Approval module (and shareable elsewhere).
Route<T> smoothSlideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, anim1, anim2) => page,
      transitionsBuilder: (context, anim, secAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutQuart);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curve),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 400),
    );
