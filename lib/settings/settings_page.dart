import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/chat_palette.dart';
import '../auth/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = _prefs.getBool('darkMode') ?? false;
      _notifications = _prefs.getBool('notifications') ?? true;
    });
  }

  void _toggleDarkMode(bool value) {
    setState(() => _darkMode = value);
    _prefs.setBool('darkMode', value);
    darkModeNotifier.value = value;
  }

  void _toggleNotifications(bool value) {
    setState(() => _notifications = value);
    _prefs.setBool('notifications', value);
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
                      child: Icon(Icons.arrow_back_rounded, color: ChatPalette.text, size: 20),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Settings',
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 16),
                  Text('PREFERENCES',
                      style: TextStyle(
                          color: ChatPalette.dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0)).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),

                  _SettingsSwitch(
                    icon: Icons.dark_mode_rounded,
                    color: ChatPalette.accentPurple,
                    title: 'Dark Mode',
                    subtitle: 'Toggle dark appearance',
                    value: _darkMode,
                    onChanged: _toggleDarkMode,
                    delay: 300,
                  ),
                  const SizedBox(height: 12),
                  _SettingsSwitch(
                    icon: Icons.notifications_active_rounded,
                    color: ChatPalette.accentAmber,
                    title: 'Notifications',
                    subtitle: 'Receive alerts for new entries',
                    value: _notifications,
                    onChanged: _toggleNotifications,
                    delay: 400,
                  ),

                  SizedBox(height: 48),

                  // Sign Out
                  GestureDetector(
                    onTap: () async {
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
                                  color: ChatPalette.text,
                                  fontWeight: FontWeight.w900)),
                          content: Text(
                            'Are you sure you want to sign out?',
                            style: TextStyle(color: ChatPalette.muted),
                          ),
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
                      if (confirmed == true && context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          PageRouteBuilder(
                            pageBuilder: (ctx, anim, secondary) => const LoginPage(),
                            transitionsBuilder: (ctx, anim, secondary, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration:
                                const Duration(milliseconds: 500),
                          ),
                          (_) => false,
                        );
                        // Trigger network sign out in background for immediate UI response
                        Supabase.instance.client.auth.signOut();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: ChatPalette.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ChatPalette.accentRose.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text('Sign Out',
                            style: TextStyle(
                                color: ChatPalette.accentRose,
                                fontSize: 15,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                  
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

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final int delay;

  const _SettingsSwitch({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatPalette.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: ChatPalette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: ChatPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: color,
            inactiveTrackColor: ChatPalette.border,
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms, duration: 400.ms).slideX(begin: 0.1, curve: Curves.easeOut);
  }
}
