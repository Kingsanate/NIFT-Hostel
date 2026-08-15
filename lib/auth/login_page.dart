import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_palette.dart';
import '../chat/chat_page.dart';
import '../medical/medical_dashboard.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    // ⚡ 1. Instant Medical Staff Logins (0ms)
    if ((email == 'doctor@nift.ac.in' || email == 'counsellor@nift.ac.in') && password == 'password123') {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (ctx, anim, _) => MedicalDashboardPage(
              role: email.contains('doctor') ? 'Doctor' : 'Counsellor',
            ),
            transitionsBuilder: (ctx, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
      }
      return;
    }

    // ⚡ 2. Instant Admin Bootstrap Logins (0ms)
    if ((email == 'admin' || email == 'admin@nifthostel.org') && (password == 'Admin@NIFT2026' || password == 'admin123')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'admin-bootstrap-token');
      await prefs.setString('user_data', jsonEncode({
        'id': 'admin-bootstrap-id',
        'username': 'admin',
        'role': 'admin',
        'fullName': 'System Administrator',
        'hostelId': 'all',
      }));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (ctx, anim, _) => const ChatPage(),
            transitionsBuilder: (ctx, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
      }

      // Background async token refresh
      ApiService.login(email, password);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.login(email, password);

      if (response['token'] == null && response['success'] != true) {
        if (mounted) {
          setState(() => _errorMessage = response['error'] ?? 'Invalid credentials. Please try again.');
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (ctx, anim, _) => const ChatPage(),
              transitionsBuilder: (ctx, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 150),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Connection error. Please check your network.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: Stack(
        children: [
          // ── Animated gradient background orbs ──
          _AnimatedOrbs(controller: _bgController),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      _buildLogo(),
                      const SizedBox(height: 36),

                      // Glass card
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              'Admin Portal',
                              style: TextStyle(
                                color: ChatPalette.text,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to manage NIFT Hostel',
                              style: TextStyle(
                                color: ChatPalette.muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ).animate().fadeIn(delay: 400.ms),
                            const SizedBox(height: 32),

                            // Email field
                            _LoginField(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'warden / doctor / counsellor',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              delay: 500,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            _LoginField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: '••••••••••',
                              icon: Icons.lock_outline_rounded,
                              delay: 600,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: ChatPalette.muted,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Password is required';
                                if (v.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Error message
                            if (_errorMessage != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: ChatPalette.accentRose.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ChatPalette.accentRose.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline_rounded,
                                        color: ChatPalette.accentRose, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: ChatPalette.accentRose,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 300.ms).shakeX(),

                            const SizedBox(height: 8),

                            // Sign In button
                            _SignInButton(
                              isLoading: _isLoading,
                              onTap: _signIn,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic),

                      const SizedBox(height: 32),

                      // Footer
                      Text(
                        'NIFT Hostel Management System\nFor authorised personnel & medical staff only',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ChatPalette.dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ).animate().fadeIn(delay: 900.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
            boxShadow: [
              BoxShadow(
                color: ChatPalette.accent.withValues(alpha: 0.4),
                blurRadius: 50,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, obj, err) => Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: ChatPalette.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
            .animate()
            .scale(duration: 800.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 24),
        Text(
          'NIFT Hostel',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.4),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: ChatPalette.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ChatPalette.accent.withValues(alpha: 0.3)),
          ),
          child: Text(
            'SHILLONG',
            style: TextStyle(
              color: const Color(0xFF4FC3F7), // Bright blue
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ).animate(delay: 300.ms).fadeIn(duration: 500.ms),
      ],
    );
  }
}

// ─── Glass Card ─────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ChatPalette.canvas.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ChatPalette.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: ChatPalette.accent.withValues(alpha: 0.06),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Input Field ────────────────────────────────────────────────────────────

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int delay;

  const _LoginField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.delay,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: ChatPalette.dim,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: ChatPalette.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: ChatPalette.muted.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, color: ChatPalette.muted, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: ChatPalette.surface.withValues(alpha: 0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ChatPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ChatPalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ChatPalette.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ChatPalette.accentRose),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: ChatPalette.accentRose, width: 1.5),
            ),
            errorStyle: TextStyle(color: ChatPalette.accentRose, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    ).animate().fadeIn(delay: delay.ms, duration: 400.ms).slideX(begin: 0.05, curve: Curves.easeOut);
  }
}

// ─── Sign In Button ──────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SignInButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [ChatPalette.surface, ChatPalette.surface]
                : ChatPalette.gradientPrimary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: ChatPalette.accent.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: ChatPalette.muted,
                  ),
                )
              : const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms).slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

// ─── Animated Background Orbs ────────────────────────────────────────────────

class _AnimatedOrbs extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedOrbs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Stack(
          children: [
            // Top-left orb — accent blue
            Positioned(
              left: -60 + (t * 40),
              top: -60 + (t * 30),
              child: _Orb(
                size: 280,
                color: ChatPalette.accent.withValues(alpha: 0.12),
              ),
            ),
            // Bottom-right orb — purple
            Positioned(
              right: -80 + (t * -20),
              bottom: size.height * 0.1 + (t * 40),
              child: _Orb(
                size: 320,
                color: ChatPalette.accentPurple.withValues(alpha: 0.10),
              ),
            ),
            // Center-right subtle orb
            Positioned(
              right: size.width * 0.1,
              top: size.height * 0.35 + (t * 30),
              child: _Orb(
                size: 180,
                color: ChatPalette.accentAmber.withValues(alpha: 0.06),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
