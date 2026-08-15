import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../chat/chat_palette.dart';
import '../main.dart'; // For AppConfig
import 'scanner_page.dart';
import 'models/student_model.dart';

class HostelSelectionPage extends StatefulWidget {
  const HostelSelectionPage({super.key});

  @override
  State<HostelSelectionPage> createState() => _HostelSelectionPageState();
}

class _HostelSelectionPageState extends State<HostelSelectionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    super.dispose();
  }

  void _selectHostel(BuildContext context, String hostel) async {
    final result = await Navigator.of(context).push<StudentModel>(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => ScannerPage(selectedHostel: hostel),
        transitionsBuilder: (context, anim, secAnim, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
    if (result != null && context.mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: Stack(
        children: [
          // ── Animated background orbs ──────────────────────────────────────
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (context, child) {
              final t = _orbCtrl.value * 2 * math.pi;
              return Stack(children: [
                Positioned(
                  top: 60 + 30 * math.sin(t),
                  left: -60 + 20 * math.cos(t * 0.7),
                  child: _GlowOrb(color: ChatPalette.accentDeep.withValues(alpha: 0.5), size: 220),
                ),
                Positioned(
                  bottom: 120 + 20 * math.cos(t),
                  right: -80 + 15 * math.sin(t * 0.5),
                  child: _GlowOrb(color: ChatPalette.accentPurple.withValues(alpha: 0.5), size: 180),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.4,
                  left: MediaQuery.of(context).size.width * 0.3,
                  child: _GlowOrb(color: ChatPalette.accentGreen.withValues(alpha: 0.5), size: 120),
                ),
              ]);
            },
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    _GlassIconBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: 14),
                    ShaderMask(
                      shaderCallback: (b) => LinearGradient(
                        colors: ChatPalette.gradientPrimary,
                      ).createShader(b),
                      child: Text(AppConfig.appName,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                  ]),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),

                SizedBox(height: 40),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hosteller Entry',
                          style: TextStyle(
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [ChatPalette.accent, ChatPalette.accentDeep],
                              ).createShader(
                                  const Rect.fromLTWH(0, 0, 280, 60)),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1,
                          ))
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 500.ms)
                          .slideY(begin: 0.3),
                      SizedBox(height: 10),
                      Text(
                        'Choose a hostel below to start\nscanning the admission form.',
                        style: TextStyle(
                            color: ChatPalette.muted,
                            fontSize: 13,
                            height: 1.5),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 500.ms)
                          .slideY(begin: 0.2),
                    ],
                  ),
                ),

                SizedBox(height: 48),

                // Hostel cards
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    children: [
                      _HostelCard(
                        title: 'Boys Hostel',
                        subtitle: 'Scan male student forms',
                        icon: Icons.boy_rounded,
                        gradient: ChatPalette.gradientPrimary,
                        glowColor: ChatPalette.accentDeep,
                        delay: 0,
                        onTap: () => _selectHostel(context, 'Boys Hostel'),
                      ),
                      SizedBox(height: 16),
                      _HostelCard(
                        title: 'Umsawli Girls',
                        subtitle: 'Umsawli campus hostel',
                        icon: Icons.girl_rounded,
                        gradient: ChatPalette.gradientGreen,
                        glowColor: ChatPalette.accentGreen,
                        delay: 100,
                        onTap: () => _selectHostel(context, 'Umsawli Girls'),
                      ),
                      SizedBox(height: 16),
                      _HostelCard(
                        title: 'Nongthymmai Girls',
                        subtitle: 'Nongthymmai campus hostel',
                        icon: Icons.girl_rounded,
                        gradient: ChatPalette.gradientAmber,
                        glowColor: ChatPalette.accentAmber,
                        delay: 200,
                        onTap: () =>
                            _selectHostel(context, 'Nongthymmai Girls'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glow orb ──────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.1), Colors.transparent],
          ),
        ),
      );
}

// ── Glass icon button ──────────────────────────────────────────────────────────
class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ChatPalette.surfaceGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: ChatPalette.text, size: 20),
        ),
      );
}

// ── Hostel card ───────────────────────────────────────────────────────────────
class _HostelCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;
  final int delay;
  final VoidCallback onTap;

  const _HostelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_HostelCard> createState() => _HostelCardState();
}

class _HostelCardState extends State<_HostelCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 95,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                widget.glowColor.withValues(alpha: 0.12),
                ChatPalette.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: widget.glowColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: _pressed ? 0.5 : 0.35),
                blurRadius: _pressed ? 28 : 20,
                spreadRadius: _pressed ? 2 : 2,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Shimmer sheen
                AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (context, child) => Positioned(
                    left: -120 + _shimmerCtrl.value * 320,
                    top: 0,
                    bottom: 0,
                    width: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Card content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Icon with gradient container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: widget.glowColor.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(widget.icon,
                            color: Colors.white, size: 28),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(widget.title,
                                style: TextStyle(
                                    color: ChatPalette.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3)),
                            SizedBox(height: 2),
                            Text(widget.subtitle,
                                style: TextStyle(
                                    color: ChatPalette.muted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: widget.gradient.map((c) =>
                                  c.withValues(alpha: 0.2)).toList()),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: widget.glowColor.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                            color: widget.glowColor, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: widget.delay.ms, duration: 500.ms)
            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}
