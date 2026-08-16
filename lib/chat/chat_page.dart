import 'dart:async';
import 'package:flutter/material.dart';

import 'chat_palette.dart';
import 'models/chat_models.dart';
import 'widgets/chat_window.dart';
import 'widgets/conversation_list.dart';
import '../scanner/hostel_selection_page.dart';
import '../scanner/models/student_model.dart';
import '../students/student_entries_page.dart';
import '../main.dart'; // For AppConfig
import '../rules/rules_page.dart';
import '../rules/data/default_rules.dart';
import '../attendance/attendance_page.dart';
import '../late_entry/late_entry_page.dart';
import 'services/chat_service.dart';
import '../services/api_service.dart';
import '../services/student_repository.dart';

class ChatPage extends StatefulWidget {
  final SidebarDestination? initialDestination;
  final StudentModel? newlyAddedStudent;

  const ChatPage({
    super.key,
    this.initialDestination,
    this.newlyAddedStudent,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late List<Conversation> _conversations;
  String? _selectedConversationId;
  String? _generatingConversationId;
  String? _streamingText; // Live streaming buffer shown while AI is responding
  late SidebarDestination _selectedDestination;
  bool _sidebarVisible = true;

  // Map to store ChatService instances for different conversations
  final Map<String, ChatService> _chatServices = {};

  // Additional database state - seeded with default rules immediately
  List<Map<String, dynamic>> _rulesData = DefaultRulesData.getDefaultRulesModels()
      .values
      .map((m) => m.toJson())
      .toList();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedDestination = widget.initialDestination ?? SidebarDestination.newChat;
    if (widget.newlyAddedStudent != null) {
      StudentRepository.addStudent(widget.newlyAddedStudent!);
    }
    _conversations = [];

    // Trigger silent background sync
    StudentRepository.syncWithBackend();
    _fetchRules();

    // Fallback periodic sync every 60s
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        StudentRepository.syncWithBackend();
        _fetchRules();
        AppConfig.loadFromOracle();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRules() async {
    try {
      final rules = await ApiService.fetchRules();
      if (rules.isNotEmpty && mounted) {
        setState(() {
          _rulesData = rules.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {}
  }

  int get _destinationIndex {
    switch (_selectedDestination) {
      case SidebarDestination.newChat:
        return 0;
      case SidebarDestination.totalEntries:
        return 1;
      case SidebarDestination.lateEntry:
        return 2;
      case SidebarDestination.rules:
        return 3;
      case SidebarDestination.attendance:
        return 4;
      case SidebarDestination.hostellerEntry:
        return 0;
    }
  }

  Conversation? get _selectedConversation {
    for (final c in _conversations) {
      if (c.id == _selectedConversationId) return c;
    }
    return null;
  }

  bool get _isGenerating =>
      _generatingConversationId != null &&
      _generatingConversationId == _selectedConversationId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          return Scaffold(
        backgroundColor: ChatPalette.background,
        drawer: compact
            ? Drawer(
                width: constraints.maxWidth < 360
                    ? constraints.maxWidth * 0.92
                    : 300,
                backgroundColor: ChatPalette.sidebar,
                shape: const RoundedRectangleBorder(),
                child: _buildSidebar(
                  onClose: () => Navigator.of(context).pop(),
                  onNewChat: () {
                    Navigator.of(context).pop();
                    Future.microtask(_startNewChat);
                  },
                  onHostellerEntry: () {
                    Navigator.of(context).pop();
                    Future.microtask(_openScanner);
                  },
                  onTotalEntries: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => setState(
                        () => _selectedDestination =
                            SidebarDestination.totalEntries));
                  },
                  onLateEntry: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => setState(
                        () => _selectedDestination =
                            SidebarDestination.lateEntry));
                  },
                  onRules: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => setState(
                        () => _selectedDestination =
                            SidebarDestination.rules));
                  },
                  onAttendance: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => setState(
                        () => _selectedDestination =
                            SidebarDestination.attendance));
                  },
                ),
              )
            : null,
        body: Builder(builder: (ctx) {
          return Row(children: [
            if (!compact && _sidebarVisible)
              SizedBox(
                width: 280,
                child: _buildSidebar(
                  onClose: () => setState(() => _sidebarVisible = false),
                  onNewChat: _startNewChat,
                  onHostellerEntry: _openScanner,
                  onTotalEntries: () => setState(
                      () => _selectedDestination =
                          SidebarDestination.totalEntries),
                  onLateEntry: () => setState(
                      () => _selectedDestination =
                          SidebarDestination.lateEntry),
                  onRules: () => setState(
                      () => _selectedDestination =
                          SidebarDestination.rules),
                  onAttendance: () => setState(
                      () => _selectedDestination =
                          SidebarDestination.attendance),
                ),
              ),
            Expanded(child: _buildMainArea(ctx, compact)),
          ]);
        }),
      );
        });
      },
    );
  }

  Widget _buildMainArea(BuildContext ctx, bool compact) {
    return ValueListenableBuilder<List<StudentModel>>(
      valueListenable: StudentRepository.studentsNotifier,
      builder: (context, studentList, _) {
        return IndexedStack(
          index: _destinationIndex,
          children: [
            // 0: Chat Window
            ChatWindow(
              conversation: _selectedConversation,
              isGenerating: _isGenerating,
              streamingText: _streamingText,
              sidebarVisible: !compact && _sidebarVisible,
              onMenuPressed: () {
                if (compact) {
                  Scaffold.of(ctx).openDrawer();
                } else {
                  setState(() => _sidebarVisible = !_sidebarVisible);
                }
              },
              onNewChat: _startNewChat,
              onSend: _sendMessage,
            ),

            // 1: Student Entries Page
            StudentEntriesPage(
              entries: studentList,
              onScanNew: _openScanner,
              onBack: () => setState(
                  () => _selectedDestination = SidebarDestination.newChat),
              onDeleteStudent: (student) async {
                final ok = await StudentRepository.deleteStudent(student);
                return ok;
              },
              onUpdateStudent: (updatedStudent) async {
                await StudentRepository.updateStudent(updatedStudent);
                ApiService.updateStudent(updatedStudent.id, updatedStudent.toBackend())
                    .catchError((e) => false);
              },
            ),

            // 2: Late Entry Page
            LateEntryPage(
              compact: compact,
              onMenuPressed: () {
                if (compact) {
                  Scaffold.of(ctx).openDrawer();
                } else {
                  setState(() => _sidebarVisible = !_sidebarVisible);
                }
              },
            ),

            // 3: Rules Page
            RulesPage(
              compact: compact,
              onMenuPressed: () {
                if (compact) {
                  Scaffold.of(ctx).openDrawer();
                } else {
                  setState(() => _sidebarVisible = !_sidebarVisible);
                }
              },
            ),

            // 4: Attendance Page
            AttendancePage(
              students: studentList,
              compact: compact,
              onMenuPressed: () {
                if (compact) {
                  Scaffold.of(ctx).openDrawer();
                } else {
                  setState(() => _sidebarVisible = !_sidebarVisible);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar({
    required VoidCallback onClose,
    required VoidCallback onNewChat,
    required VoidCallback onHostellerEntry,
    required VoidCallback onTotalEntries,
    required VoidCallback onLateEntry,
    required VoidCallback onRules,
    required VoidCallback onAttendance,
  }) {
    return ValueListenableBuilder<List<StudentModel>>(
      valueListenable: StudentRepository.studentsNotifier,
      builder: (context, studentList, _) {
        return ConversationList(
          selectedDestination: _selectedDestination,
          totalEntryCount: studentList.length,
          onNewChat: onNewChat,
          onHostellerEntry: onHostellerEntry,
          onTotalEntries: onTotalEntries,
          onLateEntry: onLateEntry,
          onRules: onRules,
          onAttendance: onAttendance,
          onClose: onClose,
        );
      },
    );
  }

  void _startNewChat() {
    final now = DateTime.now();
    final conv = Conversation(
      id: 'c${now.microsecondsSinceEpoch}',
      title: 'New chat',
      subtitle: 'Start a new conversation',
      updatedAt: now,
      messages: const [],
    );
    setState(() {
      _conversations.insert(0, conv);
      _selectedConversationId = conv.id;
      _selectedDestination = SidebarDestination.newChat;
    });
  }



  void _openScanner() async {
    final prev = _selectedDestination;
    setState(() => _selectedDestination = SidebarDestination.hostellerEntry);

    final result = await Navigator.of(context).push<StudentModel>(
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const HostelSelectionPage(),
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

    if (result != null && mounted) {
      await StudentRepository.addStudent(result);
      if (!mounted) return;
      setState(() {
        _selectedDestination = SidebarDestination.totalEntries;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded,
                color: ChatPalette.accentGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${result.name} added successfully!',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
          backgroundColor: ChatPalette.canvas,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() => _selectedDestination = prev);
    }
  }

  Future<void> _sendMessage(String text) async {
    final now = DateTime.now();
    var conv = _selectedConversation;

    if (conv == null) {
      conv = Conversation(
        id: 'c${now.microsecondsSinceEpoch}',
        title: _titleFrom(text),
        subtitle: text,
        updatedAt: now,
        messages: const [],
      );
      _conversations.insert(0, conv);
      _selectedConversationId = conv.id;
      _selectedDestination = SidebarDestination.newChat;
    }

    final isFirst = conv.messages.isEmpty;
    final userMsg = Message(
      id: 'm${now.microsecondsSinceEpoch}',
      text: text,
      createdAt: now,
      author: MessageAuthor.user,
    );

    setState(() {
      final updated = conv!.copyWith(
        title: isFirst ? _titleFrom(text) : conv.title,
        subtitle: text,
        updatedAt: now,
        messages: [...conv.messages, userMsg],
      );
      _store(updated);
      _selectedConversationId = updated.id;
      _generatingConversationId = updated.id;
    });

    final reply = await _getAiReply(text, conv);
    if (!mounted) return;

    final latest = _convById(conv.id);
    if (latest == null) return;

    final replyTime = DateTime.now();
    setState(() {
      _streamingText = null;
      _store(latest.copyWith(
        updatedAt: replyTime,
        messages: [
          ...latest.messages,
          Message(
            id: 'm${replyTime.microsecondsSinceEpoch}',
            text: reply,
            createdAt: replyTime,
            author: MessageAuthor.assistant,
          ),
        ],
      ));
      _generatingConversationId = null;
    });
  }

  void _store(Conversation c) {
    final i = _conversations.indexWhere((x) => x.id == c.id);
    if (i == -1) {
      _conversations.insert(0, c);
    } else {
      _conversations[i] = c;
    }
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Conversation? _convById(String id) {
    for (final c in _conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  String _titleFrom(String prompt) {
    final words = prompt.trim().split(RegExp(r'\s+'));
    final t = words.take(5).join(' ');
    return t.length <= 32 ? t : '${t.substring(0, 29)}…';
  }

  Future<void> _fetchRulesOnly() async {
    try {
      final res = await ApiService.fetchRules();
      if (mounted) {
        setState(() {
          _rulesData = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Error fetching rules: $e');
    }
  }

  Future<String> _getAiReply(String prompt, Conversation conv) async {
    try {
      await Future.wait([
        AppConfig.loadFromOracle(),
        _fetchRulesOnly(),
      ]).timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('Quick config/rules sync failed or timed out: $e');
    }

    if (!_chatServices.containsKey(conv.id)) {
      _chatServices[conv.id] = ChatService();
    }
    final service = _chatServices[conv.id]!;
    final previousMessages = conv.messages;
    final students = StudentRepository.students;
    
    String finalReply = '';
    await for (final chunk in service.sendMessageStream(
      prompt, 
      previousMessages, 
      students,
      const [],
      const [],
      _rulesData,
    )) {
      if (!mounted) break;
      finalReply = chunk;
      setState(() => _streamingText = chunk);
    }
    return finalReply;
  }
}
