import 'package:flutter/material.dart';
import '../../main.dart'; // For AppConfig
import 'package:flutter_animate/flutter_animate.dart';
import '../chat_palette.dart';
import '../../profile/profile_page.dart';
import '../../settings/settings_page.dart';

enum SidebarDestination { newChat, hostellerEntry, totalEntries, events, rules, attendance }

class ConversationList extends StatelessWidget {
  final SidebarDestination selectedDestination;
  final int totalEntryCount;
  final VoidCallback onNewChat;
  final VoidCallback onHostellerEntry;
  final VoidCallback onTotalEntries;
  final VoidCallback onEvents;
  final VoidCallback onRules;
  final VoidCallback onAttendance;
  final VoidCallback? onClose;

  const ConversationList({
    super.key,
    required this.selectedDestination,
    this.totalEntryCount = 0,
    required this.onNewChat,
    required this.onHostellerEntry,
    required this.onTotalEntries,
    required this.onEvents,
    required this.onRules,
    required this.onAttendance,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatPalette.sidebar,
        border: Border(
          right: BorderSide(
            color: ChatPalette.borderGlow.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SidebarHeader(onClose: onClose),
        _NewChatButton(onTap: onNewChat),
        _SectionLabel('WORKSPACE'),
        _NavItem(
          icon: Icons.document_scanner_outlined,
          label: 'Students Entry',
          gradient: ChatPalette.gradientPrimary,
          selected: selectedDestination == SidebarDestination.hostellerEntry,
          onTap: onHostellerEntry,
        ),
        _NavItem(
          icon: Icons.people_alt_outlined,
          label: 'Students',
          badge: totalEntryCount > 0 ? '$totalEntryCount' : null,
          gradient: ChatPalette.gradientGreen,
          selected: selectedDestination == SidebarDestination.totalEntries,
          onTap: onTotalEntries,
        ),
        _NavItem(
          icon: Icons.fact_check_outlined,
          label: 'Attendance',
          gradient: ChatPalette.gradientAmber,
          selected: selectedDestination == SidebarDestination.attendance,
          onTap: onAttendance,
        ),
        _NavItem(
          icon: Icons.event_note_outlined,
          label: 'Events',
          gradient: ChatPalette.gradientAmber,
          selected: selectedDestination == SidebarDestination.events,
          onTap: onEvents,
        ),
        _NavItem(
          icon: Icons.gavel_outlined,
          label: 'Rules & Regulations',
          gradient: ChatPalette.gradientPurple,
          selected: selectedDestination == SidebarDestination.rules,
          onTap: onRules,
        ),
        const Expanded(child: SizedBox()),
        const _SidebarFooter(),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _SidebarHeader extends StatelessWidget {
  final VoidCallback? onClose;
  const _SidebarHeader({this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Row(children: [
          // Logo with gradient + glow
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ChatPalette.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: ChatPalette.accentDeep.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset(
                'assets/images/nift_logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(AppConfig.appName.isNotEmpty ? AppConfig.appName[0] : 'A',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(
                    colors: [ChatPalette.text, ChatPalette.accent],
                  ).createShader(b),
                  child: Text(AppConfig.appName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2)),
                ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.menu_open_rounded,
                  color: ChatPalette.muted, size: 20),
              style: IconButton.styleFrom(
                minimumSize: Size(34, 34),
                padding: EdgeInsets.zero,
                hoverColor: ChatPalette.surfaceHover,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── New Chat Button ───────────────────────────────────────────────────────────
class _NewChatButton extends StatefulWidget {
  final VoidCallback onTap;
  const _NewChatButton({required this.onTap});

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hovered
                    ? ChatPalette.gradientPrimary
                    : [
                        ChatPalette.accentDeep.withValues(alpha: 0.15),
                        ChatPalette.accent.withValues(alpha: 0.08),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ChatPalette.accent.withValues(alpha: _hovered ? 0.6 : 0.25),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: ChatPalette.accentDeep.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded,
                    color: _hovered ? Colors.white : ChatPalette.accent,
                    size: 18),
                SizedBox(width: 7),
                Text('New Chat',
                    style: TextStyle(
                        color: _hovered ? Colors.white : ChatPalette.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
        child: Text(label,
            style: TextStyle(
                color: ChatPalette.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
      );
}

// ── Nav item ──────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final List<Color> gradient;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.badge,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.gradient.first;
    final isActive = widget.selected || _hovered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: 180.ms,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: widget.selected
                  ? LinearGradient(
                      colors: [
                        glowColor.withValues(alpha: 0.2),
                        glowColor.withValues(alpha: 0.06),
                      ],
                    )
                  : _hovered
                      ? LinearGradient(
                          colors: widget.gradient,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.03),
                            Colors.white.withValues(alpha: 0.01),
                          ],
                        ),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: glowColor.withValues(alpha: 0.35), width: 1)
                  : null,
              boxShadow: (widget.selected || _hovered)
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: _hovered ? 0.3 : 0.2),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Row(children: [
              // Icon with gradient when selected, or solid white when hovered
              _hovered
                  ? Icon(widget.icon, color: Colors.white, size: 18)
                  : widget.selected
                      ? ShaderMask(
                          shaderCallback: (b) =>
                              LinearGradient(colors: widget.gradient).createShader(b),
                          child: Icon(widget.icon, color: Colors.white, size: 18),
                        )
                      : Icon(widget.icon,
                          color: ChatPalette.text.withValues(alpha: 0.9),
                          size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                        color: _hovered
                            ? Colors.white
                            : widget.selected
                                ? ChatPalette.text
                                : ChatPalette.text.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: (widget.selected || _hovered)
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
              if (widget.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: _hovered 
                        ? null 
                        : LinearGradient(
                            colors: widget.gradient
                                .map((c) => c.withValues(alpha: 0.25))
                                .toList(),
                          ),
                    color: _hovered ? Colors.white : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _hovered 
                          ? Colors.transparent 
                          : widget.gradient.first.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(widget.badge!,
                      style: TextStyle(
                          color: _hovered ? widget.gradient.first : widget.gradient.last,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: ChatPalette.borderGlow.withValues(alpha: 0.1),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Row(children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: ChatPalette.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ChatPalette.accentDeep.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Center(
                child: Text('A',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin',
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('NIFT Hostel Shillong',
                      style: TextStyle(color: ChatPalette.text.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              icon: Icon(Icons.settings_outlined,
                  color: ChatPalette.text.withValues(alpha: 0.8), size: 18),
              style: IconButton.styleFrom(
                minimumSize: Size(32, 32),
                padding: EdgeInsets.zero,
                hoverColor: ChatPalette.surfaceHover,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),
    );
  }
}
