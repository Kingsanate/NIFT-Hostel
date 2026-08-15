import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../chat/chat_palette.dart';
import '../../scanner/models/student_model.dart';
import '../../services/student_repository.dart';
import 'models/entry_models.dart';
import 'widgets/student_avatar.dart';
import 'widgets/student_search_bar.dart';

/// "Late Entry" tab — search a student, record a dated/time-stamped
/// late entry (one per student per day), shown grouped by day.
class LateEntryTab extends StatefulWidget {
  final String hostel;
  final DateTime month;
  final List<LateEntryRecord> records;
  final List<Color> gradient;
  final Color glowColor;
  final ValueChanged<LateEntryRecord> onAdd;
  final ValueChanged<String> onDelete;

  const LateEntryTab({
    super.key,
    required this.hostel,
    required this.month,
    required this.records,
    required this.gradient,
    required this.glowColor,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<LateEntryTab> createState() => _LateEntryTabState();
}

class _LateEntryTabState extends State<LateEntryTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;

    return ValueListenableBuilder<List<StudentModel>>(
      valueListenable: StudentRepository.studentsNotifier,
      builder: (context, allStudents, _) {
        final hostelStudents = allStudents
            .where((s) => matchesHostel(s, widget.hostel))
            .toList();

        final searchResults = isSearching
            ? hostelStudents.where((s) => matchesQuery(s, _query)).toList()
            : <StudentModel>[];

        final monthRecords = widget.records
            .where((r) => r.inMonth(widget.month.year, widget.month.month))
            .toList()
          ..sort((a, b) => b.entryAt.compareTo(a.entryAt));

        final grouped = <DateTime, List<LateEntryRecord>>{};
        for (final r in monthRecords) {
          final day = DateTime(r.entryAt.year, r.entryAt.month, r.entryAt.day);
          grouped.putIfAbsent(day, () => []).add(r);
        }
        final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed search bar at the top
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
              child: StudentSearchBar(
                controller: _searchController,
                hint: 'Search student to record late entry…',
                onChanged: (_) => _onSearchChanged(),
                onClear: _clearSearch,
              ),
            ),
            // Full-height scrollable body occupying all remaining space
            Expanded(
              child: isSearching
                  ? StudentSearchResultsView(
                      students: searchResults,
                      query: _query,
                      glowColor: widget.glowColor,
                      actionTooltip: 'Record Late Entry',
                      onSelected: (student) {
                        _openAddSheet(student);
                        _clearSearch();
                      },
                      onClear: _clearSearch,
                    )
                  : monthRecords.isEmpty
                      ? _buildEmpty()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(22, 4, 22, 80),
                          children: [
                            for (final day in days) ...[
                              _DayHeader(day: day, count: grouped[day]!.length),
                              const SizedBox(height: 8),
                              for (final rec in grouped[day]!)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _EntryRow(
                                    record: rec,
                                    glowColor: widget.glowColor,
                                    onDelete: widget.onDelete,
                                  ),
                                ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ChatPalette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ChatPalette.border),
            ),
            child: Icon(Icons.schedule_rounded,
                size: 24, color: ChatPalette.muted),
          ),
          const SizedBox(height: 12),
          Text(
            'No late entries this month',
            style: TextStyle(
              color: ChatPalette.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search a student above to record a late entry.',
            style: TextStyle(color: ChatPalette.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddSheet(StudentModel student) async {
    final now = DateTime.now();
    var entryAt = now;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ChatPalette.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _AddEntrySheet(
        student: student,
        initial: entryAt,
        onChange: (dt) => entryAt = dt,
      ),
    );

    if (confirmed != true || !mounted) return;

    final record = LateEntryRecord(
      id: 'LE${DateTime.now().microsecondsSinceEpoch}',
      studentId: student.id,
      name: student.name,
      rollNo: student.rollNo,
      hostel: widget.hostel,
      department: student.department,
      semester: student.semester,
      roomNo: student.roomNo,
      photoBase64: student.profilePhotoBase64,
      entryAt: entryAt,
    );

    final duplicate = widget.records.any(
      (r) =>
          r.studentId == student.id &&
          r.entryAt.year == entryAt.year &&
          r.entryAt.month == entryAt.month &&
          r.entryAt.day == entryAt.day,
    );

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${student.name} already has a late entry recorded today.'),
          backgroundColor: ChatPalette.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    widget.onAdd(record);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Late entry recorded for ${student.name}'),
        backgroundColor: ChatPalette.surfaceHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final int count;

  const _DayHeader({required this.day, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = day.year == DateTime.now().year &&
            day.month == DateTime.now().month &&
            day.day == DateTime.now().day
        ? 'Today'
        : DateFormat('EEE, dd MMM').format(day);
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: ChatPalette.accentDeep,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
              color: ChatPalette.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: ChatPalette.accentDeep.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: ChatPalette.accentDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final LateEntryRecord record;
  final Color glowColor;
  final ValueChanged<String> onDelete;

  const _EntryRow({
    required this.record,
    required this.glowColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final detail = [
      record.rollNo,
      record.department,
      if (record.semester.isNotEmpty) 'Sem ${record.semester}',
      if (record.roomNo.isNotEmpty) 'Room ${record.roomNo}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ChatPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          StudentAvatar(
            photoBase64: record.photoBase64,
            fallbackIcon: Icons.schedule_rounded,
            fallbackColor: glowColor,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ChatPalette.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ChatPalette.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('hh:mm a').format(record.entryAt),
                  style: TextStyle(
                      color: glowColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
              const SizedBox(height: 3),
              GestureDetector(
                onTap: () => onDelete(record.id),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ChatPalette.accentRose.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 14, color: ChatPalette.accentRose),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  final StudentModel student;
  final DateTime initial;
  final ValueChanged<DateTime> onChange;

  const _AddEntrySheet({
    required this.student,
    required this.initial,
    required this.onChange,
  });

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _date = widget.initial;
    _time = TimeOfDay.fromDateTime(widget.initial);
  }

  DateTime get _combined =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Late Entry',
                style: TextStyle(
                    color: ChatPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                StudentAvatar(
                  photoBase64: widget.student.profilePhotoBase64,
                  fallbackIcon: widget.student.gender == 'Female'
                      ? Icons.girl_rounded
                      : Icons.person_rounded,
                  fallbackColor: ChatPalette.accentDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        [
                          widget.student.rollNo,
                          widget.student.department,
                          if (widget.student.roomNo.isNotEmpty)
                            'Room ${widget.student.roomNo}',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: ChatPalette.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Date',
                    value: DateFormat('dd MMM yyyy').format(_date),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(nowYear + 1, 12, 31),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.fromSeed(
                                seedColor: ChatPalette.accentDeep,
                                surface: ChatPalette.surface),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                        widget.onChange(_combined);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: _time.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.fromSeed(
                                seedColor: ChatPalette.accentDeep,
                                surface: ChatPalette.surface),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _time = picked);
                        widget.onChange(_combined);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ChatPalette.accentDeep,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save Entry',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int get nowYear => DateTime.now().year;

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: ChatPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ChatPalette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: ChatPalette.accentDeep),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: ChatPalette.dim,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
