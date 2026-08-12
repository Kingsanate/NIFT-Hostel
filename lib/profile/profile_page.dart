import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/chat_palette.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Populate fields from the currently signed-in Supabase user
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};

    _nameController = TextEditingController(
      text: meta['full_name']?.toString() ?? meta['name']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: meta['phone']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: user?.email ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String get _initials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
          },
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!',
                style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: ChatPalette.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: ChatPalette.accentRose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ChatPalette.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ChatPalette.border),
        ),
        title: Text('Sign Out',
            style: TextStyle(
                color: ChatPalette.text, fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: ChatPalette.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: ChatPalette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out',
                style: TextStyle(
                    color: ChatPalette.accentRose,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (ctx, anim, secondary) => const LoginPage(),
          transitionsBuilder: (ctx, anim, secondary, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
        (_) => false,
      );
      // Trigger network sign out in background for immediate UI response
      Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ChatPalette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ChatPalette.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: ChatPalette.text, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('My Profile',
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const Spacer(),
                  // Sign out shortcut in header
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: ChatPalette.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                ChatPalette.accentRose.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: ChatPalette.accentRose, size: 15),
                          const SizedBox(width: 5),
                          Text('Sign Out',
                              style: TextStyle(
                                  color: ChatPalette.accentRose,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: ChatPalette.gradientPrimary,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                                color: ChatPalette.border, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: ChatPalette.accent.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _nameController,
                              builder: (ctx, child) => Text(
                                _initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 38),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: ChatPalette.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: ChatPalette.border),
                            ),
                            child: Icon(Icons.camera_alt_rounded,
                                color: ChatPalette.muted, size: 16),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .scaleXY(begin: 0.8, curve: Curves.easeOutBack),

                  const SizedBox(height: 8),

                  // Email label (read-only badge)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: ChatPalette.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: ChatPalette.accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _emailController.text.isNotEmpty
                            ? _emailController.text
                            : 'No email',
                        style: TextStyle(
                          color: ChatPalette.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 36),

                  // Name field
                  _BuildTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    icon: Icons.person_rounded,
                    delay: 300,
                  ),
                  const SizedBox(height: 20),

                  // Phone field
                  _BuildTextField(
                    label: 'Contact Number',
                    controller: _phoneController,
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    delay: 400,
                  ),
                  const SizedBox(height: 20),

                  // Email — read-only
                  _BuildTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    icon: Icons.email_rounded,
                    delay: 500,
                    readOnly: true,
                    hint: 'Email cannot be changed here',
                  ),

                  const SizedBox(height: 50),

                  // Save button
                  GestureDetector(
                    onTap: _saveProfile,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSaving
                              ? [ChatPalette.surface, ChatPalette.surface]
                              : ChatPalette.gradientPrimary,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isSaving
                            ? []
                            : [
                                BoxShadow(
                                  color: ChatPalette.accent
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _isSaving
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: ChatPalette.muted,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text Field ──────────────────────────────────────────────────────────────

class _BuildTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int delay;
  final bool readOnly;
  final String? hint;
  final TextInputType? keyboardType;

  const _BuildTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.delay,
    this.readOnly = false,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: ChatPalette.dim,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: readOnly
                ? ChatPalette.surface.withValues(alpha: 0.4)
                : ChatPalette.canvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ChatPalette.border),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: readOnly ? ChatPalette.dim : ChatPalette.muted,
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  style: TextStyle(
                      color: readOnly ? ChatPalette.dim : ChatPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: ChatPalette.dim.withValues(alpha: 0.5),
                        fontSize: 13),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (readOnly)
                Icon(Icons.lock_outline_rounded,
                    color: ChatPalette.dim, size: 14),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 400.ms)
        .slideX(begin: 0.1, curve: Curves.easeOut);
  }
}
