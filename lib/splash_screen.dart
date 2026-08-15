import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat/chat_page.dart';
import 'auth/login_page.dart';
import 'core/palette.dart';
import 'main.dart'; // For AppConfig

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Check local session immediately
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    // Background config sync
    AppConfig.loadFromOracle();

    // Snappy splash duration (300ms)
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final Widget destination = (token != null && token.isNotEmpty)
        ? const ChatPage()
        : const LoginPage();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secondary) => destination,
        transitionsBuilder: (ctx, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.bg,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient radial glows
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Pal.indigo.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1000.ms),

          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Pal.teal.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1000.ms),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glowing ring
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: Pal.indigoGradient,
                    boxShadow: Pal.glowShadow(Pal.indigo, opacity: 0.45, blur: 32),
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: Pal.surface,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, obj, err) => const Center(
                            child: Text(
                              'NIFT',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Pal.indigoLight,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 900.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 900.ms)
                    .shimmer(delay: 1000.ms, duration: 1500.ms, color: Pal.indigoLight.withValues(alpha: 0.4)),

                const SizedBox(height: 32),

                // App title
                ShaderMask(
                  shaderCallback: (bounds) => Pal.indigoGradient.createShader(bounds),
                  child: const Text(
                    'NIFT Hostel',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                )
                    .animate(delay: 350.ms)
                    .slideY(begin: 0.4, duration: 700.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 700.ms),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Pal.indigo10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Pal.indigo20),
                  ),
                  child: const Text(
                    'Smart Student Management System',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Pal.indigoLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
                    .animate(delay: 600.ms)
                    .slideY(begin: 0.4, duration: 600.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 600.ms),

                const SizedBox(height: 60),

                // Sleek loading indicator bar
                SizedBox(
                  width: 140,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const LinearProgressIndicator(
                      backgroundColor: Pal.border,
                      valueColor: AlwaysStoppedAnimation<Color>(Pal.indigo),
                    ),
                  ),
                ).animate(delay: 850.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

