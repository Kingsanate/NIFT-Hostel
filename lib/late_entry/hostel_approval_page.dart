import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../chat/chat_palette.dart';
import 'late_entry_tab.dart';
import 'leave_approval_tab.dart';
import 'models/entry_models.dart';
import 'services/pdf_service.dart';

/// Per-hostel module page with two tabs:
/// Late Entry (monthly records + PDF) and Leave Approval (form capture + PDF).
class HostelApprovalPage extends StatefulWidget {
  final String hostel;
  final List<Color> gradient;
  final Color glowColor;

  const HostelApprovalPage({
    super.key,
    required this.hostel,
    required this.gradient,
    required this.glowColor,
  });

  @override
  State<HostelApprovalPage> createState() => _HostelApprovalPageState();
}

class _HostelApprovalPageState extends State<HostelApprovalPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<LateEntryRecord> _lateEntries = [];
  List<LeaveApprovalRecord> _leaveApprovals = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    // Load from Hive in background — no blocking setState(\_loading = true)
    _loadDataBackground();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDataBackground() async {
    final results = await Future.wait([
      EntryStore.loadLateEntries(),
      EntryStore.loadLeaveApprovals(),
    ]);
    if (!mounted) return;
    setState(() {
      _lateEntries = (results[0] as List<LateEntryRecord>)
          .where((r) => r.hostel == widget.hostel)
          .toList();
      _leaveApprovals = (results[1] as List<LeaveApprovalRecord>)
          .where((r) => r.hostel == widget.hostel)
          .toList();
    });
  }

  void _addLateEntry(LateEntryRecord record) async {
    setState(() => _lateEntries = [record, ..._lateEntries]);
    await EntryStore.saveLateEntries(
        [record, ...await EntryStore.loadLateEntries()]);
  }

  void _deleteLateEntry(String id) async {
    final next = _lateEntries.where((r) => r.id != id).toList();
    setState(() => _lateEntries = next);
    await EntryStore.saveLateEntries(next);
  }

  void _addLeaveApproval(LeaveApprovalRecord record) async {
    setState(() => _leaveApprovals = [record, ..._leaveApprovals]);
    await EntryStore.saveLeaveApprovals(
        [record, ...await EntryStore.loadLeaveApprovals()]);
  }

  void _deleteLeaveApproval(String id) async {
    final next = _leaveApprovals.where((r) => r.id != id).toList();
    setState(() => _leaveApprovals = next);
    await EntryStore.saveLeaveApprovals(next);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLateTab = _tabCtrl.index == 0;

    final monthLateCount =
        _lateEntries.where((r) => r.inMonth(_month.year, _month.month)).length;
    final now = DateTime.now();
    final todayCount = _lateEntries.where((r) {
      return r.entryAt.year == now.year &&
          r.entryAt.month == now.month &&
          r.entryAt.day == now.day;
    }).length;
    final monthLeaveCount = _leaveApprovals
        .where((r) => r.inMonth(_month.year, _month.month))
        .length;

    return Scaffold(
      backgroundColor: ChatPalette.background,
      body: Stack(
        children: [
          // Subtle hostel-tinted ambient glow
          Positioned(
            top: -70,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.glowColor.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: ChatPalette.background,
                    border: Border(
                        bottom: BorderSide(color: ChatPalette.borderSoft)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded,
                            color: ChatPalette.text),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: widget.glowColor.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.hostel.contains('Girls')
                              ? Icons.girl_rounded
                              : Icons.boy_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.hostel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: ChatPalette.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2),
                            ),
                            Text(
                              'Students Entry Approval',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: ChatPalette.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.picture_as_pdf_rounded,
                            size: 22, color: ChatPalette.accentDeep),
                        tooltip: 'Export PDF',
                        onPressed: _exportPdf,
                      ),
                    ],
                  ),
                ),
              ),
              _buildMonthBar(),
              _buildStatsRow(
                monthLateCount,
                todayCount,
                monthLeaveCount,
                isLateTab,
              ),
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: ChatPalette.background,
                  border:
                      Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: widget.glowColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: widget.glowColor,
                  unselectedLabelColor: ChatPalette.muted,
                  labelStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Late Entry'),
                    Tab(text: 'Leave Approval'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                          LateEntryTab(
                            hostel: widget.hostel,
                            month: _month,
                            records: _lateEntries,
                            gradient: widget.gradient,
                            glowColor: widget.glowColor,
                            onAdd: _addLateEntry,
                            onDelete: _deleteLateEntry,
                          ),
                          LeaveApprovalTab(
                            hostel: widget.hostel,
                            month: _month,
                            records: _leaveApprovals,
                            gradient: widget.gradient,
                            glowColor: widget.glowColor,
                            onAdd: _addLeaveApproval,
                            onDelete: _deleteLeaveApproval,
                          ),
                        ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBar() {
    final canGoBack =
        _month.year > 2020 || (_month.year == 2020 && _month.month > 1);
    final canGoForward = _month.isBefore(DateTime.now());
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ChatPalette.background,
        border: Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded,
                color: canGoBack ? ChatPalette.text : ChatPalette.dim,
                size: 24),
            onPressed: canGoBack ? () => _shiftMonth(-1) : null,
          ),
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: ChatPalette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ChatPalette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        size: 14, color: widget.glowColor),
                    const SizedBox(width: 7),
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: TextStyle(
                          color: ChatPalette.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded,
                color: canGoForward ? ChatPalette.text : ChatPalette.dim,
                size: 24),
            onPressed: canGoForward ? () => _shiftMonth(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    int monthLate,
    int todayLate,
    int monthLeave,
    bool isLateTab,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
      decoration: BoxDecoration(
        color: ChatPalette.background,
        border: Border(bottom: BorderSide(color: ChatPalette.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              icon: isLateTab
                  ? Icons.schedule_rounded
                  : Icons.description_outlined,
              label: isLateTab ? 'This month' : 'This month',
              value: isLateTab ? '$monthLate' : '$monthLeave',
              color:
                  isLateTab ? ChatPalette.accentDeep : ChatPalette.accentAmber,
              index: 0,
            ),
          ),
          const SizedBox(width: 10),
          if (isLateTab)
            Expanded(
              child: _StatChip(
                icon: Icons.today_rounded,
                label: 'Today',
                value: '$todayLate',
                color: ChatPalette.accentGreen,
                index: 1,
              ),
            ),
          if (!isLateTab)
            Expanded(
              child: _StatChip(
                icon: Icons.verified_rounded,
                label: 'With forms',
                value:
                    '${_leaveApprovals.where((r) => r.inMonth(_month.year, _month.month) && ((r.formImageBase64 != null && r.formImageBase64!.isNotEmpty) || (r.formImageUrl != null && r.formImageUrl!.isNotEmpty))).length}',
                color: ChatPalette.accentGreen,
                index: 1,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final monthLabel = DateFormat('MMMM yyyy').format(_month);
    try {
      if (_tabCtrl.index == 0) {
        final records = _lateEntries
            .where((r) => r.inMonth(_month.year, _month.month))
            .toList();
        await PdfService.exportLateEntries(
          hostel: widget.hostel,
          month: _month,
          records: records,
        );
      } else {
        final records = _leaveApprovals
            .where((r) => r.inMonth(_month.year, _month.month))
            .toList();
        await PdfService.exportLeaveApprovals(
          hostel: widget.hostel,
          month: _month,
          records: records,
        );
      }
    } catch (e) {
      debugPrint('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF for $monthLabel.'),
            backgroundColor: ChatPalette.surfaceHigh,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int index;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ChatPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                      color: ChatPalette.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: ChatPalette.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
