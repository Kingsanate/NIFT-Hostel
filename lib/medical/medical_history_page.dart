import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'prescription_pdf_generator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

class MedicalHistoryPage extends StatefulWidget {
  final String doctorName;

  const MedicalHistoryPage({super.key, required this.doctorName});

  @override
  State<MedicalHistoryPage> createState() => _MedicalHistoryPageState();
}

class _MedicalHistoryPageState extends State<MedicalHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filterHistory();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final list = await ApiService.fetchMedicalAppointments();
      final completed = list.where((apt) => (apt['status'] ?? '').toString().toLowerCase() == 'completed').toList();
      
      if (mounted) {
        setState(() {
          _history = completed;
          _filteredHistory = List.from(_history);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterHistory() {
    if (_searchQuery.isEmpty) {
      _filteredHistory = List.from(_history);
    } else {
      _filteredHistory = _history.where((apt) {
        final name = (apt['student_name'] ?? '').toLowerCase();
        final rollNo = (apt['student_roll_no'] ?? '').toLowerCase();
        final notes = (apt['doctor_notes'] ?? '').toLowerCase();
        return name.contains(_searchQuery) || rollNo.contains(_searchQuery) || notes.contains(_searchQuery);
      }).toList();
    }
  }

  String _getDiagnosisPillText(String? notes) {
    if (notes == null || notes.isEmpty) return 'Consultation';
    // Take the first 2-3 words of the notes to act as a summary/diagnosis
    List<String> words = notes.split(RegExp(r'\s+'));
    if (words.length <= 3) return notes;
    return '${words.take(3).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    // This container acts as the body since we removed Scaffold/AppBar
    return Container(
      color: const Color(0xFFF7FAFC), // Light background
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Consultation History',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A202C),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Review past patient consultations and medical records.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF718096),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSearchAndFilterCard(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF2C7A7B))),
                    )
                  else if (_filteredHistory.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No completed consultations yet.' : 'No results found.',
                          style: const TextStyle(fontSize: 14, color: Color(0xFFA0AEC0), fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildHistoryCard(_filteredHistory[index], index),
                          childCount: _filteredHistory.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.add_box, color: Color(0xFF2C5282), size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'NIFT Shillong Health',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C5282),
                ),
              ),
            ],
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE2E8F0),
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'), // Placeholder
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1A202C)),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search by student name, ID, or diagno...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA0AEC0)),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFA0AEC0), size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: Colors.transparent, // Let the card's white background show
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildHistoryCard(Map<String, dynamic> apt, int index) {
    final dateStr = apt['completed_at'];
    final date = dateStr != null 
        ? DateTime.parse(dateStr).toLocal()
        : DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date).toUpperCase();
    
    final dept = apt['department'] ?? 'Unknown Dept';
    final rollNo = apt['student_roll_no'] ?? 'No ID';
    final diagnosisPill = _getDiagnosisPillText(apt['doctor_notes']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFF1E40AF), width: 5), // Dark Blue/Teal accent border
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Row
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF718096)),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF718096),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Name and Photo Row
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final base64String = apt['profile_photo_base64']?.toString();
                      final photoPath = apt['photo_path']?.toString();
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
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE2E8F0),
                          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apt['student_name'] ?? 'Unknown Student',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A202C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $rollNo • $dept',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Diagnosis Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF8FF), // Light blue
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  diagnosisPill,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3182CE), // Darker blue
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // View Treatment Action
              InkWell(
                onTap: () {
                  PrescriptionPdfGenerator.generateAndPrintPrescription(
                    appointment: apt,
                    doctorName: widget.doctorName,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Treatment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B6CB0), // Strong blue link
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: Color(0xFF2B6CB0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.05);
  }

}

