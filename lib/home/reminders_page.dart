import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../chat/chat_palette.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/confirm_dialog.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reminders = [];
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
    _setupRealtime();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtime() {
    _wsSubscription = WebSocketService.instance.events.listen((event) {
      if (event['type'] == 'REMINDERS_CHANGED') {
        _fetchReminders();
      }
    });
  }

  Future<void> _fetchReminders() async {
    try {
      final list = await ApiService.fetchReminders();
      if (mounted) {
        setState(() {
          _reminders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReminder(String id) async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Delete Reminder?',
      message: 'Are you sure you want to delete this reminder? This cannot be undone.',
      icon: Icons.notifications_off_outlined,
    );
    if (confirm != true || !mounted) return;

    // Optimistic 0ms UI update
    setState(() {
      _reminders.removeWhere((r) => r['id'].toString() == id);
    });

    try {
      await ApiService.deleteReminder(id);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  Future<void> _clearAllReminders() async {
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Clear All Reminders?',
      message: 'Are you sure you want to delete ALL reminders? This cannot be undone.',
      confirmLabel: 'Clear All',
      icon: Icons.delete_sweep_outlined,
    );
    if (confirm != true || !mounted) return;

    final toDelete = List<Map<String, dynamic>>.from(_reminders);
    setState(() {
      _reminders.clear();
    });

    for (final r in toDelete) {
      final id = r['id']?.toString();
      if (id != null) {
        await ApiService.deleteReminder(id);
      }
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return Colors.pinkAccent;
      case 'Medium':
        return Colors.amber;
      case 'Low':
        return Colors.cyanAccent;
      default:
        return Colors.amber;
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'High':
        return Icons.warning_amber_rounded;
      case 'Medium':
        return Icons.access_time_rounded;
      case 'Low':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatPalette.background,
      appBar: AppBar(
        backgroundColor: ChatPalette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: ChatPalette.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Reminders', style: TextStyle(color: ChatPalette.text, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          if (_reminders.isNotEmpty)
            IconButton(
              tooltip: 'Clear All',
              icon: Icon(Icons.clear_all_rounded, color: ChatPalette.text),
              onPressed: _clearAllReminders,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ChatPalette.accentPurple))
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 28, color: ChatPalette.dim.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No upcoming reminders', style: TextStyle(color: ChatPalette.dim, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _reminders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final rem = _reminders[index];
                    final String id = rem['id'].toString();
                    final title = rem['title']?.toString() ?? 'Reminder';
                    final message = rem['message']?.toString() ?? '';
                    final priority = rem['priority']?.toString() ?? 'Medium';
                    final dueDateStr = rem['due_date']?.toString();
                    
                    DateTime? dueDate;
                    if (dueDateStr != null) {
                      dueDate = DateTime.tryParse(dueDateStr);
                    }
                    
                    final color = _getPriorityColor(priority);

                    return Container(
                      decoration: BoxDecoration(
                        color: ChatPalette.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 3, color: color),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(color: ChatPalette.text, fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, size: 20, color: ChatPalette.dim),
                                      onPressed: () => _deleteReminder(id),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getPriorityIcon(priority), size: 12, color: color),
                                          const SizedBox(width: 4),
                                          Text(
                                            priority.toUpperCase(),
                                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: TextStyle(color: ChatPalette.dim, fontSize: 14, height: 1.4),
                                ),
                                if (dueDate != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: color),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Due: ${DateFormat('MMM dd, yyyy - hh:mm a').format(dueDate.toLocal())}',
                                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.1);
                  },
                ),
    );
  }
}
