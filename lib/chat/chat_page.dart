import 'package:flutter/material.dart';

import 'chat_palette.dart';
import 'models/chat_models.dart';
import 'widgets/chat_window.dart';
import 'widgets/conversation_list.dart';
import '../scanner/hostel_selection_page.dart';
import '../scanner/models/student_model.dart';
import '../students/student_entries_page.dart';
import 'dart:async';
import '../main.dart'; // For AppConfig
import '../events/events_page.dart';
import '../rules/rules_page.dart';
import '../attendance/attendance_page.dart';
import 'services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  // Students added via scanner
  List<StudentModel> _addedStudents = [];

  // Map to store ChatService instances for different conversations
  final Map<String, ChatService> _chatServices = {};

  // Additional database state
  List<Map<String, dynamic>> _roomsData = [];
  List<Map<String, dynamic>> _attendanceData = [];
  List<Map<String, dynamic>> _complaintsData = [];
  List<Map<String, dynamic>> _rulesData = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedDestination = widget.initialDestination ?? SidebarDestination.newChat;
    if (widget.newlyAddedStudent != null) {
      _addedStudents.insert(0, widget.newlyAddedStudent!);
    }
    _conversations = [];
    _loadCachedData();
    _fetchDatabaseState();

    // Start background timer to refresh configuration and data from Supabase periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _fetchDatabaseState();
        AppConfig.loadFromSupabase();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStudentsJson = prefs.getString('cached_students');
      
      if (cachedStudentsJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedStudentsJson);
        final cachedStudentsList = decoded.map((e) => e as Map<String, dynamic>).toList();
        
        final allStudents = <StudentModel>[];
        allStudents.addAll(cachedStudentsList.map((e) => StudentModel.fromSupabase(e, e['hostel'] ?? 'Unknown')));
        
        if (mounted) {
          setState(() {
            _addedStudents = allStudents..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> _fetchDatabaseState() async {
    try {
      // Helper function to fetch data and return empty list on failure
      Future<List<Map<String, dynamic>>> safeFetch(String table, [String columns = '*']) async {
        try {
          final res = await Supabase.instance.client.from(table).select(columns);
          return List<Map<String, dynamic>>.from(res);
        } catch (e) {
          debugPrint('Warning: Could not fetch table $table - $e');
          return [];
        }
      }

      final prefs = await SharedPreferences.getInstance();
      Future<List<Map<String, dynamic>>> fetchRules() async {
        final freshRules = await safeFetch('hostel_rules', 'hostel_name, extracted_text');
        if (freshRules.isNotEmpty) {
          prefs.setString('cached_rules', jsonEncode(freshRules));
          return freshRules;
        }
        final cached = prefs.getString('cached_rules');
        if (cached != null) {
          try {
            return List<Map<String, dynamic>>.from(jsonDecode(cached));
          } catch (e) {
            debugPrint('Failed to decode cached rules: $e');
          }
        }
        return [];
      }

      final responses = await Future.wait([
        safeFetch('students'), // Unified students table
        safeFetch('attendance_records'),
        safeFetch('complaints'),
        fetchRules(),
        safeFetch('rooms'), // Add rooms table
      ]);

      final allStudents = <StudentModel>[];
      final allRooms = <Map<String, dynamic>>[];
      final allAttendance = <Map<String, dynamic>>[];
      final allComplaints = <Map<String, dynamic>>[];
      final allRules = <Map<String, dynamic>>[];

      if (responses.length >= 5) {
        // Parse the unified students
        String mapHostelId(String? id) {
          if (id == 'boys_hostel') return 'Boys Hostel';
          if (id == 'umsawli_girls') return 'Umsawli Girls';
          if (id == 'nongthymmai_girls') return 'Nongthymmai Girls';
          return 'Boys Hostel'; // fallback
        }
        allStudents.addAll(responses[0].map((e) => StudentModel.fromSupabase(e, mapHostelId(e['hostelId']?.toString()))));

        // Use actual rooms table from database
        allRooms.addAll(responses[4]);

        allAttendance.addAll(responses[1]);
        allComplaints.addAll(responses[2]);
        allRules.addAll(responses[3]);
      }

      if (mounted) {
        setState(() {
          _addedStudents = allStudents..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _roomsData = allRooms;
          _attendanceData = allAttendance;
          _complaintsData = allComplaints;
          _rulesData = allRules;
        });
      }
      
      // Update cache with latest student data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_students', jsonEncode(responses[0]));
      } catch (cacheError) {
        debugPrint('Failed to cache students: $cacheError');
      }
    } catch (e) {
      debugPrint('Error fetching database state: $e');
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
                  onEvents: () {
                    Navigator.of(context).pop();
                    Future.microtask(_openEvents);
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
                  onEvents: _openEvents,
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
    // Show student entries page
    if (_selectedDestination == SidebarDestination.totalEntries) {
      return StudentEntriesPage(
        entries: _addedStudents,
        onScanNew: _openScanner,
        onBack: () => setState(
            () => _selectedDestination = SidebarDestination.newChat),
        onDeleteStudent: (id) {
          setState(() {
            _addedStudents.removeWhere((s) => s.id == id);
          });
        },
        onUpdateStudent: (updatedStudent) {
          setState(() {
            final idx = _addedStudents.indexWhere((s) => s.id == updatedStudent.id);
            if (idx != -1) {
              _addedStudents[idx] = updatedStudent;
            }
          });
        },
      );
    }

    // Show events page
    if (_selectedDestination == SidebarDestination.events) {
      return EventsPage(
        compact: compact,
        onMenuPressed: () {
          if (compact) {
            Scaffold.of(ctx).openDrawer();
          } else {
            setState(() => _sidebarVisible = !_sidebarVisible);
          }
        },
      );
    }

    // Show rules page
    if (_selectedDestination == SidebarDestination.rules) {
      return RulesPage(
        compact: compact,
        onMenuPressed: () {
          if (compact) {
            Scaffold.of(ctx).openDrawer();
          } else {
            setState(() => _sidebarVisible = !_sidebarVisible);
          }
        },
      );
    }

    // Show attendance page
    if (_selectedDestination == SidebarDestination.attendance) {
      return AttendancePage(
        students: _addedStudents,
        compact: compact,
        onMenuPressed: () {
          if (compact) {
            Scaffold.of(ctx).openDrawer();
          } else {
            setState(() => _sidebarVisible = !_sidebarVisible);
          }
        },
      );
    }

    // Show chat window
    return ChatWindow(
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
    );
  }

  Widget _buildSidebar({
    required VoidCallback onClose,
    required VoidCallback onNewChat,
    required VoidCallback onHostellerEntry,
    required VoidCallback onTotalEntries,
    required VoidCallback onEvents,
    required VoidCallback onRules,
    required VoidCallback onAttendance,
  }) {
    final total = _addedStudents.length; // real entries
    return ConversationList(
      selectedDestination: _selectedDestination,
      totalEntryCount: total,
      onNewChat: onNewChat,
      onHostellerEntry: onHostellerEntry,
      onTotalEntries: onTotalEntries,
      onEvents: onEvents,
      onRules: onRules,
      onAttendance: onAttendance,
      onClose: onClose,
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
      setState(() {
        _addedStudents.insert(0, result);
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

  void _openEvents() {
    setState(() => _selectedDestination = SidebarDestination.events);
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

    // Database state is already fetched periodically or on init.
    // Do NOT fetch it synchronously here, as it delays the AI stream by 4 seconds.
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
      final res = await Supabase.instance.client.from('hostel_rules').select();
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
    // Fast synchronous fetch of latest configuration and rules to guarantee freshness
    try {
      await Future.wait([
        AppConfig.loadFromSupabase(),
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
    
    String finalReply = '';
    // Use the streaming method — update state on each chunk for word-by-word display
    await for (final chunk in service.sendMessageStream(
      prompt, 
      previousMessages, 
      _addedStudents,
      _roomsData,
      _attendanceData,
      _complaintsData,
      _rulesData,
    )) {
      if (!mounted) break;
      finalReply = chunk;
      setState(() => _streamingText = chunk); // 🔥 Updates bubble live
    }
    return finalReply;
  }
}
