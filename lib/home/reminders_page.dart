import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat/chat_palette.dart';
import 'package:intl/intl.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    _fetchReminders();
    _setupRealtime();
  }

  void _setupRealtime() {
    Supabase.instance.client
        .channel('public:reminders')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reminders',
            callback: (payload) {
              _fetchReminders();
            })
        .subscribe();
  }

  Future<void> _fetchReminders() async {
    try {
      final res = await Supabase.instance.client
          .from('reminders')
          .select('id, title, message, priority, due_date')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _reminders = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reminders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReminder(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatPalette.surface,
        title: Text('Delete Reminder', style: TextStyle(color: ChatPalette.text)),
        content: Text('Are you sure you want to delete this reminder?', style: TextStyle(color: ChatPalette.dim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('reminders').delete().eq('id', id);
      // Realtime listener will handle the UI update
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  Future<void> _clearAllReminders() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatPalette.surface,
        title: Text('Clear All Reminders', style: TextStyle(color: ChatPalette.text)),
        content: Text('Are you sure you want to delete ALL reminders? This cannot be undone.', style: TextStyle(color: ChatPalette.dim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Supabase trick: eq on a non-null column to delete all rows, or you can use neq
      await Supabase.instance.client.from('reminders').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    } catch (e) {
      debugPrint('Error clearing reminders: $e');
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
                      Icon(Icons.notifications_off_outlined, size: 64, color: ChatPalette.dim.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('No upcoming reminders', style: TextStyle(color: ChatPalette.dim, fontSize: 16)),
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
                                        style: TextStyle(color: ChatPalette.text, fontSize: 16, fontWeight: FontWeight.w700),
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
