import 'package:flutter/material.dart';

import '../../chat/chat_palette.dart';
import '../../scanner/models/student_model.dart';
import 'student_avatar.dart';

/// Helper to match students to a specific hostel.
bool matchesHostel(StudentModel s, String hostel) {
  final sHostel = s.hostel.toLowerCase().trim();
  final target = hostel.toLowerCase().trim();
  if (target.contains('boys')) {
    return sHostel.contains('boys') || sHostel.contains('male');
  }
  if (target.contains('umsawli')) {
    return sHostel.contains('umsawli') ||
        sHostel.contains('girls2') ||
        sHostel.contains('girls_2');
  }
  if (target.contains('nongthymmai')) {
    return sHostel.contains('nongthymmai') ||
        sHostel.contains('girls1') ||
        sHostel.contains('girls_1');
  }
  return sHostel.contains(target) || target.contains(sHostel);
}

/// Helper to match query against name, roll no, room no, or department.
bool matchesQuery(StudentModel s, String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return true;
  return s.name.toLowerCase().contains(q) ||
      s.rollNo.toLowerCase().contains(q) ||
      s.roomNo.toLowerCase().contains(q) ||
      s.department.toLowerCase().contains(q);
}

/// Modern, dense search bar input widget.
class StudentSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool loading;

  const StudentSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search student by name, roll no, or room',
    this.onChanged,
    this.onClear,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ChatPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: hasText ? ChatPalette.accentDeep : ChatPalette.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: ChatPalette.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: ChatPalette.dim,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ChatPalette.accentDeep,
                ),
              ),
            ),
          if (hasText)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ChatPalette.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: ChatPalette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-height, dense, modern student search results view.
/// Dynamically fills all remaining vertical space on the screen.
class StudentSearchResultsView extends StatefulWidget {
  final List<StudentModel> students;
  final String query;
  final Color glowColor;
  final ValueChanged<StudentModel> onSelected;
  final VoidCallback onClear;
  final String actionTooltip;

  const StudentSearchResultsView({
    super.key,
    required this.students,
    required this.query,
    required this.glowColor,
    required this.onSelected,
    required this.onClear,
    this.actionTooltip = 'Select',
  });

  @override
  State<StudentSearchResultsView> createState() => _StudentSearchResultsViewState();
}

class _StudentSearchResultsViewState extends State<StudentSearchResultsView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.students.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: ChatPalette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ChatPalette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  size: 28,
                  color: ChatPalette.muted,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No students found',
                style: TextStyle(
                  color: ChatPalette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'No student matching "${widget.query}" in this hostel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.onClear,
                icon: const Icon(Icons.clear_rounded, size: 15),
                label: const Text('Clear search',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.glowColor,
                  side: BorderSide(color: widget.glowColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header with result count
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
          child: Row(
            children: [
              Text(
                'MATCHING STUDENTS',
                style: TextStyle(
                  color: ChatPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.glowColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.students.length}',
                  style: TextStyle(
                    color: widget.glowColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Full-height scrollable list
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 2, 22, 80),
            itemCount: widget.students.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = widget.students[index];
              return _StudentCard(
                student: student,
                glowColor: widget.glowColor,
                actionTooltip: widget.actionTooltip,
                onTap: () => widget.onSelected(student),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StudentCard extends StatefulWidget {
  final StudentModel student;
  final Color glowColor;
  final String actionTooltip;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.glowColor,
    required this.actionTooltip,
    required this.onTap,
  });

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final detail = [
      s.rollNo,
      s.department,
      if (s.roomNo.isNotEmpty) 'Room ${s.roomNo}',
    ].where((t) => t.isNotEmpty).join(' · ');

    final fallbackIcon = s.gender == 'Female'
        ? Icons.girl_rounded
        : (s.name.toLowerCase().contains('g') && s.gender.isEmpty)
            ? Icons.girl_rounded
            : Icons.person_rounded;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.glowColor.withValues(alpha: 0.05)
                  : ChatPalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered
                    ? widget.glowColor.withValues(alpha: 0.35)
                    : ChatPalette.border,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? widget.glowColor.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: _hovered ? 12 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar
                StudentAvatar(
                  photoBase64: s.profilePhotoBase64,
                  photoPath: s.photoPath,
                  fallbackIcon: fallbackIcon,
                  fallbackColor: widget.glowColor,
                  size: 40,
                ),
                const SizedBox(width: 13),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ChatPalette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Action circular button
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.glowColor.withValues(alpha: _hovered ? 0.18 : 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.glowColor.withValues(alpha: _hovered ? 0.4 : 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 19,
                    color: widget.glowColor,
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

