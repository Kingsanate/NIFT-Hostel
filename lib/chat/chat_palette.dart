import 'package:flutter/material.dart';

/// Gen Z dark glassmorphic palette — NIFT Hostel
/// Global state for Dark Mode
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

class ChatPalette {
  const ChatPalette._();

  static bool get isDark => darkModeNotifier.value;

  // ── Backgrounds ──────────────────────────────────────────────────────────────
  static Color get background       => isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF0F4); 
  static Color get canvas           => isDark ? const Color(0xFF1E293B) : const Color(0xFFFDFDFD); 
  static Color get canvasDeep       => isDark ? const Color(0xFF0B1221) : const Color(0xFFE5E7EB); 
  static Color get sidebar          => isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FA); 
  static Color get sidebarElevated  => isDark ? const Color(0xFF334155) : const Color(0xFFEEF0F4); 

  // ── Surfaces ─────────────────────────────────────────────────────────────────
  static Color get surface          => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF); 
  static Color get surfaceHigh      => isDark ? const Color(0xFF334155) : const Color(0xFFFFFFFF); 
  static Color get surfaceHover     => isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB); 
  static Color get surfaceGlass     => isDark ? const Color(0x991E293B) : const Color(0xCCF8F9FA); 

  // ── Borders ──────────────────────────────────────────────────────────────────
  static Color get border           => isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB); 
  static Color get borderSoft       => isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6);
  static Color get borderGlow       => isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB); 

  // ── Text ─────────────────────────────────────────────────────────────────────
  static Color get text             => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A); 
  static Color get muted            => isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569); 
  static Color get dim              => isDark ? const Color(0xFF64748B) : const Color(0xFF64748B); 

  // ── Accent Professional Palette ──────────────────────────────────────────────
  static Color get accent           => isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8); 
  static Color get accentDeep       => isDark ? const Color(0xFF1D4ED8) : const Color(0xFF1E3A8A); 
  static Color get accentBlue       => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB); 
  static Color get accentGreen      => isDark ? const Color(0xFF10B981) : const Color(0xFF047857); 
  static Color get accentAmber      => isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309); 
  static Color get accentRose       => isDark ? const Color(0xFFF43F5E) : const Color(0xFFBE123C); 
  static Color get accentPurple     => isDark ? const Color(0xFFA855F7) : const Color(0xFF6D28D9); 

  // ── Gradients ─────────────────────────────────────────────────────────────────
  static List<Color> get gradientPrimary  => isDark ? const [Color(0xFF2563EB), Color(0xFF60A5FA)] : const [Color(0xFF1E3A8A), Color(0xFF2563EB)]; 
  static List<Color> get gradientGreen    => isDark ? const [Color(0xFF059669), Color(0xFF10B981)] : const [Color(0xFF064E3B), Color(0xFF059669)]; 
  static List<Color> get gradientAmber    => isDark ? const [Color(0xFFD97706), Color(0xFFFBBF24)] : const [Color(0xFF78350F), Color(0xFFD97706)]; 
  static List<Color> get gradientRose     => isDark ? const [Color(0xFFE11D48), Color(0xFFFB7185)] : const [Color(0xFF881337), Color(0xFFE11D48)];
  static List<Color> get gradientPurple   => isDark ? const [Color(0xFF7C3AED), Color(0xFFC084FC)] : const [Color(0xFF4C1D95), Color(0xFF7C3AED)];
}
