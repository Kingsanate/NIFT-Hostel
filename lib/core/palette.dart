import 'package:flutter/material.dart';

/// NIFT Slate — Design Token Palette
abstract final class Pal {
  // ── Backgrounds ──────────────────────────────────────────────────────────────
  static const bg       = Color(0xFF06091A);
  static const surface  = Color(0xFF0B1122);
  static const card     = Color(0xFF0F172A);
  static const cardHigh = Color(0xFF1A2540);
  static const panel    = Color(0xFF162032);

  // ── Borders ──────────────────────────────────────────────────────────────────
  static const border     = Color(0xFF1E2D47);
  static const borderMid  = Color(0xFF253A5C);
  static const borderHigh = Color(0xFF2E4A70);

  // ── Brand — Indigo ────────────────────────────────────────────────────────────
  static const indigo      = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const indigoDark  = Color(0xFF4338CA);
  static const indigo10    = Color(0x1A6366F1);
  static const indigo20    = Color(0x336366F1);
  static const indigo40    = Color(0x666366F1);

  // ── Brand — Amber (gold accent) ───────────────────────────────────────────────
  static const amber       = Color(0xFFF59E0B);
  static const amberLight  = Color(0xFFFBBF24);
  static const amber10     = Color(0x1AF59E0B);
  static const amber20     = Color(0x33F59E0B);

  // ── Brand — Teal ─────────────────────────────────────────────────────────────
  static const teal        = Color(0xFF06B6D4);
  static const tealLight   = Color(0xFF22D3EE);
  static const teal10      = Color(0x1A06B6D4);

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const green   = Color(0xFF10B981);
  static const green10 = Color(0x1A10B981);
  static const rose    = Color(0xFFF43F5E);
  static const rose10  = Color(0x1AF43F5E);
  static const violet  = Color(0xFF8B5CF6);

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const text      = Color(0xFFF1F5F9);
  static const textSub   = Color(0xFFCBD5E1);
  static const textMuted = Color(0xFF94A3B8);
  static const textDim   = Color(0xFF64748B);
  static const textFaint = Color(0xFF334155);

  // ── Scanner specific ─────────────────────────────────────────────────────────
  static const scanLine     = indigo;
  static const scanCorner   = amber;
  static const scanOverlay  = Color(0xCC06091A);

  // ── Gradients ─────────────────────────────────────────────────────────────────
  static const indigoGradient = LinearGradient(
    colors: [indigoDark, indigo, indigoLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const amberGradient = LinearGradient(
    colors: [Color(0xFFD97706), amber, amberLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const tealGradient = LinearGradient(
    colors: [Color(0xFF0891B2), teal, tealLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const roseGradient = LinearGradient(
    colors: [Color(0xFFE11D48), rose, Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glassBorder = Color(0x26FFFFFF);
  static const glassSurface = Color(0x1A1E2D47);

  // ── Glow Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double opacity = 0.3, double blur = 16, double spread = 0}) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 4),
    ),
  ];
}

