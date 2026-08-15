import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'medical_history_page.dart';
import 'medical_reports_page.dart';
import 'medical_profile_page.dart';
import '../auth/login_page.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class MedicalDashboardPage extends StatefulWidget {
  final String role; // 'Doctor' or 'Counsellor'
  
  const MedicalDashboardPage({super.key, required this.role});

  @override
  State<MedicalDashboardPage> createState() => _MedicalDashboardPageState();
}

class _MedicalDashboardPageState extends State<MedicalDashboardPage> {
  int _currentIndex = 0; // For BottomNavigationBar

  List<Map<String, dynamic>> _waitingAppointments = [];
  int _treatedCount = 0;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    
    // Live WebSocket Stream for instant appointments
    _wsSubscription = WebSocketService.instance.events.listen((event) {
      if (event['type'] == 'MEDICAL_CHANGED') {
        _fetchAppointments();
      }
    });
  }

  Future<void> _fetchAppointments() async {
    try {
      final list = await ApiService.fetchMedicalAppointments();
      if (mounted) {
        final roleType = widget.role.toLowerCase();
        final waiting = list.where((apt) {
          final s = (apt['status'] ?? 'pending').toString().toLowerCase();
          final type = (apt['appointment_type'] ?? apt['doctor_name'] ?? '').toString().toLowerCase();
          final matchesRole = type.isEmpty || type.contains(roleType) || (roleType == 'doctor' && type.contains('physician'));
          return (s == 'waiting' || s == 'pending') && matchesRole;
        }).toList();

        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final completedToday = list.where((apt) {
          final s = (apt['status'] ?? '').toString().toLowerCase();
          final compAt = (apt['completed_at'] ?? apt['created_at'] ?? '').toString();
          return s == 'completed' && compAt.startsWith(todayStr);
        }).length;

        setState(() {
          _waitingAppointments = waiting;
          _treatedCount = completedToday;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch appointments: $e');
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, _) => const LoginPage(),
        transitionsBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine which page to show based on BottomNav index
    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildHomeTab();
        break;
      case 1:
        body = MedicalHistoryPage(doctorName: widget.role);
        break;
      case 2:
        body = const MedicalReportsPage();
        break;
      case 3:
        body = MedicalProfilePage(role: widget.role, onSignOut: _logout);
        break;
      default:
        body = _buildHomeTab();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2F7), // Light grayish-blue background
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2A4365),
        unselectedItemColor: const Color(0xFFA0AEC0),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEBF8F9), Color(0xFFDFE9F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false, // Let BottomNav handle safe area at the bottom
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsAndButton(),
            const SizedBox(height: 32),
            _buildQueueSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A202C),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                Text(
                  widget.role == 'Doctor' ? 'Medical Officer' : 'Counsellor',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A202C),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Shillong Campus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A5568),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
          GestureDetector(
            onTap: () {
              setState(() => _currentIndex = 3); // Go to Profile
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.person_outline_rounded, color: Color(0xFF1A202C), size: 22),
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildStatsAndButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_today_outlined,
                  count: _waitingAppointments.length,
                  label: 'Booked',
                  bgColor: const Color(0xFFC6F6D5), // Light Green
                  textColor: const Color(0xFF22543D), // Dark Green
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  icon: Icons.medical_services_outlined,
                  count: _treatedCount,
                  label: 'Treated',
                  bgColor: const Color(0xFFC3DAFE), // Light Blue
                  textColor: const Color(0xFF2C5282), // Dark Blue
                ),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Manual appointment booking coming soon!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF2C7A7B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38B2AC), Color(0xFF2C7A7B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38B2AC).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'New Appointment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildQueueSection() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Queue',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A202C),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _waitingAppointments.isEmpty
                ? const Center(
                    child: Text(
                      'No appointments in queue.',
                      style: TextStyle(color: Color(0xFF718096), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    itemCount: _waitingAppointments.length,
                    itemBuilder: (context, index) {
                      final apt = _waitingAppointments[index];
                      // Determine status based on position
                      String pillText = index == 0 ? 'Next Up' : 'Waiting';
                      Color pillBgColor = index == 0 ? const Color(0xFFFEFCBF) : const Color(0xFFEDF2F7); // Yellowish vs Grayish
                      Color pillTextColor = index == 0 ? const Color(0xFF975A16) : const Color(0xFF4A5568);

                      return _QueueCard(
                        apt: apt,
                        pillText: pillText,
                        pillBgColor: pillBgColor,
                        pillTextColor: pillTextColor,
                        onComplete: (String diagnosis, bool referred) async {
                          try {
                            final aptId = (apt['id'] ?? '').toString();
                            await ApiService.updateAppointment(aptId, {
                              'status': 'completed',
                              'appointment_type': widget.role.toLowerCase(),
                              'doctor_notes': diagnosis,
                              'referred': referred,
                              'completed_at': DateTime.now().toUtc().toIso8601String(),
                            });

                            if (mounted) {
                              setState(() {
                                _treatedCount++;
                              });
                              _fetchAppointments();
                            }
                          } catch (e) {
                            debugPrint('Error updating appointment: $e');
                          }
                        },
                      ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(begin: 0.05);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card Component ───────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color bgColor;
  final Color textColor;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor.withValues(alpha: 0.6), size: 20),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // A subtle circular decorative element to mimic the loader in design
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: textColor.withValues(alpha: 0.3), width: 2.5),
            ),
          )
        ],
      ),
    );
  }
}

// ─── Queue Card Component ──────────────────────────────────────────────────
class _QueueCard extends StatefulWidget {
  final Map<String, dynamic> apt;
  final String pillText;
  final Color pillBgColor;
  final Color pillTextColor;
  final Function(String, bool) onComplete;

  const _QueueCard({
    required this.apt,
    required this.pillText,
    required this.pillBgColor,
    required this.pillTextColor,
    required this.onComplete,
  });

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  void _showCompletionDialog() {
    final TextEditingController diagnosisController = TextEditingController();
    bool referred = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38B2AC).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF38B2AC), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Complete Appointment',
                        style: TextStyle(color: Color(0xFF1A202C), fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Show Warden Notes
                  if (widget.apt['warden_notes'] != null && widget.apt['warden_notes'].toString().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEFCBF).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF6E05E).withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Warden Notes / Symptoms:', style: TextStyle(color: Color(0xFF975A16), fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(widget.apt['warden_notes'], style: const TextStyle(color: Color(0xFF744210), fontSize: 14)),
                        ],
                      )
                    ),
                  
                  const Text('Diagnosis & Advice Given', style: TextStyle(color: Color(0xFF4A5568), fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: diagnosisController,
                    maxLines: 4,
                    style: const TextStyle(color: Color(0xFF2D3748)),
                    decoration: InputDecoration(
                      hintText: 'Enter treatment details, prescribed medicines, or general advice...',
                      hintStyle: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF7FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      value: referred,
                      onChanged: (val) => setModalState(() => referred = val),
                      activeThumbColor: const Color(0xFF38B2AC),
                      title: const Text(
                        'Referred to Hospital',
                        style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Mark if further escalation is required',
                        style: TextStyle(color: Color(0xFF718096), fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onComplete(diagnosisController.text, referred);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: const Color(0xFF38B2AC),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save & Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime createdAt = widget.apt['created_at'] != null 
        ? DateTime.parse(widget.apt['created_at']).toLocal() 
        : DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(createdAt);

    return GestureDetector(
      onTap: _showCompletionDialog,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            // Profile Image Placeholder or Actual Photo
            Builder(
              builder: (context) {
                final base64String = widget.apt['profile_photo_base64']?.toString();
                final photoPath = widget.apt['photo_path']?.toString();
                ImageProvider? imageProvider;

                if (photoPath != null && photoPath.isNotEmpty) {
                  imageProvider = NetworkImage(photoPath);
                } else if (base64String != null && base64String.isNotEmpty) {
                  try {
                    String cleanBase64 = base64String.split(',').last.replaceAll(RegExp(r'\s+'), '');
                    final decodedBytes = base64Decode(cleanBase64);
                    imageProvider = MemoryImage(decodedBytes);
                  } catch (e) {
                    imageProvider = const AssetImage('assets/images/logo.png');
                  }
                } else {
                  imageProvider = const AssetImage('assets/images/logo.png');
                }

                return Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE2E8F0),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.apt['student_name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.apt['department'] ?? 'Unknown Dept',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.pillBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.pillText,
                    style: TextStyle(
                      color: widget.pillTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
