import 'package:flutter/material.dart';
import '../chat/chat_palette.dart';
import 'hostel_approval_page.dart';

/// Late Entry / Leave Approved — placeholder module.
/// Dedicated to managing late entry registrations and leave approvals.
class LateEntryPage extends StatefulWidget {
  final bool compact;
  final VoidCallback onMenuPressed;

  const LateEntryPage({
    super.key,
    required this.compact,
    required this.onMenuPressed,
  });

  @override
  State<LateEntryPage> createState() => _LateEntryPageState();
}

class _LateEntryPageState extends State<LateEntryPage>
    with AutomaticKeepAliveClientMixin {
  String? _selectedHostel;

  @override
  bool get wantKeepAlive => true;

  static const _hostels = [
    _HostelDef(
      name: 'Boys Hostel',
      subtitle: 'Male students',
      icon: Icons.boy_rounded,
    ),
    _HostelDef(
      name: 'Umsawli Girls',
      subtitle: 'Umsawli campus',
      icon: Icons.girl_rounded,
    ),
    _HostelDef(
      name: 'Nongthymmai Girls',
      subtitle: 'Nongthymmai campus',
      icon: Icons.girl_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: ChatPalette.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _buildHostelSelector(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ChatPalette.background,
          border: Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
        ),
        child: Row(
          children: [
            if (widget.compact) ...[
              IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: ChatPalette.text,
                ),
                onPressed: widget.onMenuPressed,
              ),
              const SizedBox(width: 8),
            ] else ...[
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                'Late Entry / Leave Approved',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostelSelector(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Students Entry Approval',
            style: TextStyle(
              color: ChatPalette.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Record and manage approved late entries and leave granted for students. Select the hostel below to continue.',
            style: TextStyle(
              color: ChatPalette.muted,
              fontSize: 12.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Select hostel',
            style: TextStyle(
              color: ChatPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          ..._hostels.asMap().entries.map((entry) {
            final def = entry.value;
            final selected = _selectedHostel == def.name;
            final gradient = _gradientFor(def.name);
            final glow = _glowColorFor(def.name);
            return Padding(
              padding: EdgeInsets.only(
                  bottom: entry.key < _hostels.length - 1 ? 12 : 0),
              child: _HostelCard(
                def: def,
                gradient: gradient,
                glowColor: glow,
                selected: selected,
                onTap: () => _openHostelPage(def, gradient, glow),
              ),
            );
          }),
          const SizedBox(height: 22),
          _buildNoticePanel(),
          const SizedBox(height: 24),
          _buildFooter(),
        ],
      ),
    );
  }

  void _openHostelPage(_HostelDef def, List<Color> gradient, Color glow) {
    setState(() {
      _selectedHostel = _selectedHostel == def.name ? null : def.name;
    });

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => HostelApprovalPage(
          hostel: def.name,
          gradient: gradient,
          glowColor: glow,
        ),
        transitionsBuilder: (context, anim, secAnim, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutQuart)),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutQuart),
            ),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  Widget _buildNoticePanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ChatPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ChatPalette.accentDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: ChatPalette.accentDeep,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please note:',
                  style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Late entry requests must be submitted immediately upon arrival. Provide accurate details to help us maintain hostel security and student safety.',
                  style: TextStyle(
                    color: ChatPalette.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 13,
            color: ChatPalette.muted.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 6),
          Text(
            'Your safety. Our priority.',
            style: TextStyle(
              color: ChatPalette.muted.withValues(alpha: 0.55),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hostel selector card ────────────────────────────────────────────────────────
class _HostelDef {
  final String name;
  final String subtitle;
  final IconData icon;
  const _HostelDef({
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

class _HostelCard extends StatefulWidget {
  final _HostelDef def;
  final List<Color> gradient;
  final Color glowColor;
  final bool selected;
  final VoidCallback onTap;

  const _HostelCard({
    required this.def,
    required this.gradient,
    required this.glowColor,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_HostelCard> createState() => _HostelCardState();
}

class _HostelCardState extends State<_HostelCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected || _pressed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  widget.glowColor.withValues(alpha: isActive ? 0.18 : 0.12),
                  ChatPalette.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: widget.glowColor
                    .withValues(alpha: widget.selected ? 0.5 : 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(
                      alpha: (_hovered || widget.selected) ? 0.45 : 0.32),
                  blurRadius: (_hovered || widget.selected) ? 20 : 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon tile
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.def.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.selected
                            ? '✓ ${widget.def.name}'
                            : widget.def.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.selected
                              ? widget.glowColor
                              : ChatPalette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.def.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ChatPalette.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Leading tile: check when selected, arrow otherwise
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradient
                          .map((c) => c.withValues(alpha: 0.2))
                          .toList(),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: widget.glowColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    widget.selected
                        ? Icons.check_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: widget.selected ? Colors.white : widget.glowColor,
                    size: widget.selected ? 18 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Palette helpers per hostel ──────────────────────────────────────────────────
List<Color> _gradientFor(String hostel) {
  switch (hostel) {
    case 'Umsawli Girls':
      return ChatPalette.gradientGreen;
    case 'Nongthymmai Girls':
      return ChatPalette.gradientAmber;
    case 'Boys Hostel':
    default:
      return ChatPalette.gradientPrimary;
  }
}

Color _glowColorFor(String hostel) {
  switch (hostel) {
    case 'Umsawli Girls':
      return ChatPalette.accentGreen;
    case 'Nongthymmai Girls':
      return ChatPalette.accentAmber;
    case 'Boys Hostel':
    default:
      return ChatPalette.accentDeep;
  }
}
