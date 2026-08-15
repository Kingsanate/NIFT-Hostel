import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../chat_palette.dart';
import '../models/chat_models.dart';
import 'message_input.dart';
import '../../profile/profile_page.dart';
import '../../home/reminders_page.dart';
import '../services/chat_service.dart';

class ChatWindow extends StatefulWidget {
  final Conversation? conversation;
  final bool isGenerating;
  final String? streamingText;
  final bool sidebarVisible;
  final VoidCallback onMenuPressed;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSend;

  const ChatWindow({
    super.key,
    required this.conversation,
    required this.isGenerating,
    this.streamingText,
    required this.sidebarVisible,
    required this.onMenuPressed,
    required this.onNewChat,
    required this.onSend,
  });

  @override
  State<ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<ChatWindow> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant ChatWindow old) {
    super.didUpdateWidget(old);
    final oldCount = old.conversation?.messages.length ?? 0;
    final newCount = widget.conversation?.messages.length ?? 0;
    final streamChanged = old.streamingText?.length != widget.streamingText?.length;
    
    if (oldCount != newCount || old.isGenerating != widget.isGenerating || streamChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBottom());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.conversation?.messages ?? const <Message>[];

    return Container(
      color: ChatPalette.background,
      child: Column(children: [
        _Header(
          title: widget.conversation?.title,
          sidebarVisible: widget.sidebarVisible,
          onMenu: widget.onMenuPressed,
          onNewChat: widget.onNewChat,
        ),
        Expanded(
          child: msgs.isEmpty
              ? _EmptyState(onPrompt: widget.onSend)
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
                  itemCount: msgs.length + (widget.isGenerating ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= msgs.length) return _ThinkingBubble(text: widget.streamingText);
                    return _MessageTile(message: msgs[i], index: i);
                  },
                ),
        ),
        MessageInput(enabled: !widget.isGenerating, onSend: widget.onSend),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String? title;
  final bool sidebarVisible;
  final VoidCallback onMenu;
  final VoidCallback onNewChat;
  const _Header(
      {this.title,
      required this.sidebarVisible,
      required this.onMenu,
      required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ChatPalette.background,
          border: Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
        ),
        child: Row(children: [
          // Sidebar toggle
          _HeaderBtn(
            icon: sidebarVisible ? Icons.menu_open_rounded : Icons.menu_rounded,
            onTap: onMenu,
            tooltip: sidebarVisible ? 'Close sidebar' : 'Open sidebar',
          ),
          SizedBox(width: 8),
          // Title
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'NIFT ',
                    style: TextStyle(
                      color: ChatPalette.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextSpan(
                    text: 'Hostel Shillong',
                    style: TextStyle(
                      color: ChatPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Notification bell — navigates to RemindersPage
          Tooltip(
            message: 'Reminders',
            child: ValueListenableBuilder<bool>(
              valueListenable: ChatService.hasNewReminder,
              builder: (context, hasNew, child) {
                return Badge(
                  isLabelVisible: hasNew,
                  backgroundColor: Colors.redAccent,
                  offset: const Offset(-4, 4),
                  child: IconButton(
                    onPressed: () {
                      ChatService.hasNewReminder.value = false;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RemindersPage()),
                      );
                    },
                    icon: const Icon(Icons.notifications_none_rounded, size: 21),
                    color: ChatPalette.muted,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      hoverColor: ChatPalette.surfaceHover,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          // Avatar
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF8AB4F8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text('A',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _HeaderBtn(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 21, color: ChatPalette.muted),
          style: IconButton.styleFrom(
            minimumSize: Size(40, 40),
            hoverColor: ChatPalette.surfaceHover,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onPrompt;
  const _EmptyState({required this.onPrompt});

  static const _suggestions = [
    _Suggestion(
      icon: Icons.meeting_room_outlined,
      color: Color(0xFF8AB4F8),
      title: 'Show the total Number of Rooms',
      sub: 'Filter by specific hostel',
    ),
    _Suggestion(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF81C995),
      title: 'Attendance summary',
      sub: 'Late entries & absentees',
    ),
    _Suggestion(
      icon: Icons.bed_outlined,
      color: Color(0xFFFDD663),
      title: 'Rooms Occupancy and Availability list',
      sub: 'See current bed availability',
    ),
  ];

  PopupMenuItem<String> _buildPopupItem(String hostel, IconData icon, Color color) {
    return PopupMenuItem<String>(
      value: hostel,
      padding: EdgeInsets.zero,
      height: 40,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hostel,
                style: TextStyle(
                  color: ChatPalette.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withValues(alpha: 0.8), size: 10)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveX(begin: 0, end: 3, duration: 1.seconds, curve: Curves.easeInOut),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Official NIFT Logo with thin black border
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.black87, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/nift_official_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, obj, err) => Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.elasticOut,
                      duration: 600.ms),
              const SizedBox(height: 20),
              Text('How may I help you?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ))
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOut),
              const SizedBox(height: 8),
              Text(
                'Ask anything about hostel operations, students records\nwith rules and regulations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ChatPalette.muted, fontSize: 14, height: 1.5),
              )
                  .animate()
                  .fadeIn(delay: 180.ms, duration: 400.ms),
              const SizedBox(height: 32),
              // 2×2 suggestion grid
              LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 480;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: _suggestions.asMap().entries.map((e) {
                    final w = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2;
                    return Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<String>(
                        tooltip: 'Select Hostel',
                        offset: const Offset(0, 50),
                        color: ChatPalette.surface,
                        elevation: 32,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: ChatPalette.borderSoft, width: 2),
                        ),
                        onSelected: (hostel) {
                          onPrompt('${e.value.title} for $hostel');
                        },
                        itemBuilder: (context) => [
                          _buildPopupItem('Boys Hostel', Icons.boy_rounded, ChatPalette.accentBlue),
                          _buildPopupItem('Umsawli Girls Hostel', Icons.girl_rounded, ChatPalette.accentPurple),
                          _buildPopupItem('Nongthymmai Girls Hostel', Icons.girl_rounded, ChatPalette.accentRose),
                        ],
                        child: _SuggestionCard(
                          suggestion: e.value,
                          width: w,
                          onTap: null,
                          delay: Duration(milliseconds: 300 + e.key * 80),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  const _Suggestion(
      {required this.icon,
      required this.color,
      required this.title,
      required this.sub});
}

class _SuggestionCard extends StatefulWidget {
  final _Suggestion suggestion;
  final double width;
  final VoidCallback? onTap;
  final Duration delay;
  const _SuggestionCard(
      {required this.suggestion,
      required this.width,
      this.onTap,
      required this.delay});

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    return SizedBox(
      width: widget.width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: 150.ms,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hovered ? ChatPalette.surfaceHigh : ChatPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered
                    ? s.color.withValues(alpha: 0.4)
                    : ChatPalette.border,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: s.color.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: s.color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(s.icon, color: s.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: TextStyle(
                              color: ChatPalette.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      Text(s.sub,
                          style: TextStyle(
                              color: ChatPalette.muted,
                              fontSize: 12,
                              height: 1.3)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: 15,
                    color: _hovered ? s.color : ChatPalette.dim),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: widget.delay, duration: 350.ms)
        .slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

// ── Message tile ──────────────────────────────────────────────────────────────
class _MessageTile extends StatelessWidget {
  final Message message;
  final int index;
  const _MessageTile({required this.message, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: message.isUser
              ? _UserBubble(message: message)
              : _AiBubble(message: message),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }
}

// ── User bubble ───────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final Message message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1557B0), Color(0xFF1A73E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, height: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF8AB4F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text('A',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI bubble ─────────────────────────────────────────────────────────────────
class _AiBubble extends StatelessWidget {
  final Message message;
  const _AiBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ani Chat',
                    style: TextStyle(
                        color: ChatPalette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                  decoration: BoxDecoration(
                    color: ChatPalette.canvas,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: ChatPalette.border),
                  ),
                  child: _FormattedMessageView(
                    text: message.text,
                  ),
                ),
                const SizedBox(height: 6),
                _MessageActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _ActionBtn(icon: Icons.content_copy_rounded, tooltip: 'Copy',
          onTap: () {}),
      const SizedBox(width: 2),
      _ActionBtn(icon: Icons.thumb_up_alt_outlined, tooltip: 'Good response',
          onTap: () {}),
      const SizedBox(width: 2),
      _ActionBtn(icon: Icons.thumb_down_alt_outlined, tooltip: 'Bad response',
          onTap: () {}),
      const SizedBox(width: 2),
      _ActionBtn(icon: Icons.refresh_rounded, tooltip: 'Regenerate',
          onTap: () {}),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(30, 30),
            fixedSize: const Size(30, 30),
            foregroundColor: ChatPalette.dim,
            hoverColor: ChatPalette.surfaceHover,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
          icon: Icon(icon, size: 15),
        ),
      );
}

// ── Thinking bubble (or Live Stream) ──────────────────────────────────────────
class _ThinkingBubble extends StatelessWidget {
  final String? text;
  const _ThinkingBubble({this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ani Chat',
                        style: TextStyle(
                            color: ChatPalette.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: ChatPalette.canvas,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(color: ChatPalette.border),
                      ),
                      child: (text != null && text!.isNotEmpty)
                          ? _FormattedMessageView(
                              text: text!,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                3,
                                (i) => Container(
                                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                      color: ChatPalette.accent,
                                      shape: BoxShape.circle),
                                )
                                    .animate(onPlay: (c) => c.repeat())
                            .moveY(
                                begin: 0,
                                end: -6,
                                delay: Duration(milliseconds: i * 180),
                                duration: 450.ms,
                                curve: Curves.easeOut)
                            .then()
                            .moveY(end: 0, duration: 450.ms),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Formatted Message Markdown View (Zero Raw Asterisks) ───────────────────────
class _FormattedMessageView extends StatelessWidget {
  final String text;

  const _FormattedMessageView({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: ChatPalette.text,
      fontSize: 13,
      height: 1.55,
      letterSpacing: 0.1,
    );

    final lines = text.split('\n');
    final List<Widget> lineWidgets = [];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        lineWidgets.add(const SizedBox(height: 6));
        continue;
      }

      // Check for markdown headers (### or ## or #)
      if (trimmed.startsWith('### ')) {
        final headerContent = trimmed.substring(4).replaceAll(RegExp(r'\*\*|\*'), '').trim();
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 3),
            child: Text(
              headerContent,
              style: style.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: (style.fontSize ?? 13) + 1.5,
                color: ChatPalette.text,
              ),
            ),
          ),
        );
        continue;
      } else if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        final headerContent = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').replaceAll(RegExp(r'\*\*|\*'), '').trim();
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              headerContent,
              style: style.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: (style.fontSize ?? 13) + 2.5,
                color: ChatPalette.text,
              ),
            ),
          ),
        );
        continue;
      }

      // Check if line is a bullet item (- or * or • or number.)
      final isBullet = RegExp(r'^(\s*[-*•]|\s*\d+\.)\s+').hasMatch(rawLine);
      String lineToParse = rawLine;
      Widget? leadingPrefix;

      if (isBullet) {
        final bulletMatch = RegExp(r'^(\s*)([-*•]|\d+\.)\s+(.*)$').firstMatch(rawLine);
        if (bulletMatch != null) {
          final bulletSymbol = bulletMatch.group(2)!;
          final content = bulletMatch.group(3)!;
          lineToParse = content;

          final isNum = RegExp(r'^\d+\.').hasMatch(bulletSymbol);
          leadingPrefix = Padding(
            padding: const EdgeInsets.only(right: 6, top: 1),
            child: Text(
              isNum ? bulletSymbol : '•',
              style: TextStyle(
                color: ChatPalette.accent,
                fontWeight: FontWeight.w800,
                fontSize: (style.fontSize ?? 13),
              ),
            ),
          );
        }
      }

      final spans = _parseMarkdownSpans(lineToParse, style);

      if (leadingPrefix != null) {
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leadingPrefix,
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(children: spans),
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: SelectableText.rich(
              TextSpan(children: spans),
              style: style,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lineWidgets,
    );
  }

  static List<InlineSpan> _parseMarkdownSpans(String line, TextStyle baseStyle) {
    final List<InlineSpan> spans = [];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(line)) {
      if (match.start > lastEnd) {
        final plainText = line.substring(lastEnd, match.start).replaceAll('*', '');
        if (plainText.isNotEmpty) {
          spans.add(TextSpan(text: plainText, style: baseStyle));
        }
      }

      final boldContent = match.group(1) ?? '';
      spans.add(
        TextSpan(
          text: boldContent,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: ChatPalette.text,
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      final remainder = line.substring(lastEnd).replaceAll('*', '');
      if (remainder.isNotEmpty) {
        spans.add(TextSpan(text: remainder, style: baseStyle));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: line.replaceAll('*', ''), style: baseStyle));
    }

    return spans;
  }
}
