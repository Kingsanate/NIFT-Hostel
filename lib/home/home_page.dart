import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/palette.dart';
import '../services/student_repository.dart';
import '../scanner/hostel_selection_page.dart';
import '../main.dart'; // For AppConfig
import '../chat/chat_page.dart';
import '../chat/widgets/conversation_list.dart';
import '../scanner/models/student_model.dart';
import '../profile/profile_page.dart';
import 'reminders_page.dart';
import '../chat/chat_palette.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Silent background sync
    StudentRepository.syncWithBackend();
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.bg,
      body: Stack(
        children: [
          // Subtle radial glow at top
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Pal.indigo.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Pal.amber.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main scroll content — instant 0ms reactive repository
          SafeArea(
            child: ValueListenableBuilder<List<StudentModel>>(
              valueListenable: StudentRepository.studentsNotifier,
              builder: (context, studentList, _) {
                final occupiedRoomSet = <String>{};
                for (final s in studentList) {
                  final room = s.roomNo.trim();
                  if (room.isNotEmpty &&
                      room != 'Pending' &&
                      room.toUpperCase() != 'TBD') {
                    occupiedRoomSet.add(room);
                  }
                }

                final recentEntries = studentList.take(3).map((s) {
                  return _StudentEntry(
                    name: s.name.isNotEmpty ? s.name : 'Unknown',
                    dept: s.department.isNotEmpty ? s.department : 'N/A',
                    room: s.roomNo.isNotEmpty ? s.roomNo : 'TBD',
                    time: _formatTimeAgo(s.createdAt),
                  );
                }).toList();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _TopBar()),
                    SliverToBoxAdapter(child: _WelcomeBanner()),
                    SliverToBoxAdapter(
                      child: _StatsRow(
                        totalStudents: studentList.length,
                        occupiedRooms: occupiedRoomSet.length,
                      ),
                    ),
                    SliverToBoxAdapter(child: _HeroScanCard(onTap: _openScanner)),
                    SliverToBoxAdapter(
                      child: _SecondaryActions(
                        onChat: _openChat,
                        onStudents: _openStudents,
                        totalStudents: studentList.length,
                      ),
                    ),
                    SliverToBoxAdapter(
                        child: _RecentSection(students: recentEntries)),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openStudents() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatPage(
          initialDestination: SidebarDestination.totalEntries,
        ),
      ),
    );
  }

  void _openScanner() async {
    final result = await Navigator.of(context).push<StudentModel>(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, sec) => const HostelSelectionPage(),
        transitionsBuilder: (ctx, anim, sec, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );

    if (result != null && mounted) {
      await StudentRepository.addStudent(result);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              initialDestination: SidebarDestination.totalEntries,
              newlyAddedStudent: result,
            ),
          ),
        );
      }
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatPage()),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Pal.indigoDark, Pal.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Pal.indigo.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Center(
                  child: Text(AppConfig.appName.isNotEmpty ? AppConfig.appName[0] : 'N',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: darkModeNotifier,
                    builder: (context, isDark, _) {
                      return Image.asset(
                        isDark
                            ? 'assets/images/nift_header_logo_dark.png'
                            : 'assets/images/nift_header_logo.png',
                        height: 28,
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hostel Shillong',
                    style: TextStyle(
                      color: ChatPalette.isDark ? Colors.white : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const Text('Smart Management System',
                  style: TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
          const Spacer(),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Pal.green10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Pal.green.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Pal.green, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .fadeOut(duration: 800.ms)
                    .then()
                    .fadeIn(duration: 800.ms),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        color: Pal.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Notification bell
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersPage()),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Pal.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Pal.border),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: Pal.textSub, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Pal.indigoDark, Pal.violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Pal.borderMid),
              ),
              child: Center(
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.3, curve: Curves.easeOut);
  }

  String get _initials {
    return 'W';
  }
}

// ── Welcome banner ────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final now = DateTime.now();
    final dateStr = '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting, Admin 👋',
              style: const TextStyle(
                  color: Pal.textMuted, fontSize: 13, fontWeight: FontWeight.w600))
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 4),
          Text('Hostel Dashboard',
              style: const TextStyle(
                  color: Pal.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0, height: 1.1))
              .animate()
              .fadeIn(delay: 150.ms, duration: 400.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),
          const SizedBox(height: 4),
          Text(dateStr,
              style: const TextStyle(color: Pal.textDim, fontSize: 12))
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
        ],
      ),
    );
  }

  String _weekday(int w) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int totalStudents;
  final int occupiedRooms;

  const _StatsRow({
    required this.totalStudents,
    required this.occupiedRooms,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat(totalStudents.toString(), 'Students', Pal.indigo, Icons.people_outline, Pal.indigo10),
      _Stat(occupiedRooms.toString(), 'Occupied', Pal.teal, Icons.bed_outlined, Pal.teal10),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final s = e.value;
          final delay = Duration(milliseconds: 300 + e.key * 100);
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                color: Pal.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: s.color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: s.color.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: s.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s.icon, color: s.color, size: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(s.value,
                      style: TextStyle(
                          color: s.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text(s.label,
                      style: const TextStyle(
                          color: Pal.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: delay, duration: 450.ms)
                .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack),
          );
        }).toList(),
      ),
    );
  }
}

class _Stat {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final Color bgColor;
  const _Stat(this.value, this.label, this.color, this.icon, this.bgColor);
}

// ── Hero scan card ────────────────────────────────────────────────────────────
class _HeroScanCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroScanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Pal.indigoDark, Pal.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Pal.indigoLight.withValues(alpha: 0.3)),
            boxShadow: Pal.glowShadow(Pal.indigo, opacity: 0.32, blur: 28),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Text('PRIMARY ACTION',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Scan New\nStudent Form',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    const Text('Use AI to extract student details\nfrom the admission form.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: Pal.indigoDark, size: 16),
                          SizedBox(width: 6),
                          Text('Open Scanner',
                              style: TextStyle(
                                  color: Pal.indigoDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(delay: 2000.ms, duration: 1500.ms),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Decorative icon stack
              Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.document_scanner_outlined,
                        color: Colors.white, size: 28),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.06, duration: 1800.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final c in [Pal.amber, Pal.teal, Pal.green])
                        Container(
                          width: 18,
                          height: 4,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 500.ms)
            .slideY(begin: 0.2, curve: Curves.easeOut),
      ),
    );
  }
}

// ── Secondary actions ─────────────────────────────────────────────────────────
class _SecondaryActions extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onStudents;
  final int totalStudents;

  const _SecondaryActions({
    required this.onChat,
    required this.onStudents,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _SecBtn(
              icon: Icons.smart_toy_outlined,
              label: 'AI Assistant',
              sub: 'Chat & drafts',
              color: Pal.teal,
              onTap: onChat,
              delay: 600.ms,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SecBtn(
              icon: Icons.people_alt_outlined,
              label: 'Students',
              sub: '$totalStudents enrolled',
              color: Pal.amber,
              onTap: onStudents,
              delay: 700.ms,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SecBtn(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              sub: 'Monthly stats',
              color: Pal.violet,
              onTap: onChat,
              delay: 800.ms,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  final Duration delay;

  const _SecBtn({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Pal.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    color: Pal.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub,
                style:
                    const TextStyle(color: Pal.textDim, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: 400.ms)
        .slideY(begin: 0.3, curve: Curves.easeOut);
  }
}

// ── Recent entries ────────────────────────────────────────────────────────────
class _RecentSection extends StatelessWidget {
  final List<_StudentEntry> students;
  const _RecentSection({required this.students});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Entries',
                  style: TextStyle(
                      color: Pal.text, fontSize: 14, fontWeight: FontWeight.w800)),
              Text('See all',
                  style: TextStyle(
                      color: Pal.indigoLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          )
              .animate()
              .fadeIn(delay: 900.ms, duration: 400.ms),
          const SizedBox(height: 12),
          ...students.asMap().entries.map(
                (e) => _RecentRow(entry: e.value, index: e.key),
              ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final _StudentEntry entry;
  final int index;
  const _RecentRow({required this.entry, required this.index});

  static const _colors = [Pal.indigo, Pal.teal, Pal.violet];

  @override
  Widget build(BuildContext context) {
    final c = _colors[index % _colors.length];
    final name = entry.name;
    final ini = name.split(' ').take(2).map((w) => w[0]).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: c.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(ini,
                  style: TextStyle(
                      color: c, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(
                        color: Pal.text, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${entry.dept} · Room ${entry.room}',
                    style:
                        const TextStyle(color: Pal.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(entry.time,
                  style:
                      const TextStyle(color: Pal.textDim, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Pal.green10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Added',
                    style: TextStyle(
                        color: Pal.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
            delay: Duration(milliseconds: 1000 + index * 120), duration: 400.ms)
        .slideX(begin: 0.1, curve: Curves.easeOut);
  }
}

class _StudentEntry {
  final String name;
  final String dept;
  final String room;
  final String time;
  const _StudentEntry(
      {required this.name,
      required this.dept,
      required this.room,
      required this.time});
}
