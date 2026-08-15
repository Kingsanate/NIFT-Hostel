import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

class MedicalReportsPage extends StatefulWidget {
  const MedicalReportsPage({super.key});

  @override
  State<MedicalReportsPage> createState() => _MedicalReportsPageState();
}

class _MedicalReportsPageState extends State<MedicalReportsPage> {
  int _totalConsultations = 0;
  int _totalPatients = 0;
  bool _isLoading = true;

  // Selected Date State
  late String _selectedMonth;
  late String _selectedYear;
  
  final List<String> _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  late List<String> _years;

  @override
  void initState() {
    super.initState();
    // Default to current month/year
    final now = DateTime.now();
    _selectedMonth = _months[now.month - 1];
    _selectedYear = now.year.toString();
    
    // Generate years from 2023 to current year
    _years = List.generate(now.year - 2023 + 1, (index) => (2023 + index).toString());
    
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      int monthIndex = _months.indexOf(_selectedMonth) + 1;
      int year = int.parse(_selectedYear);
      String monthPrefix = '$year-${monthIndex.toString().padLeft(2, '0')}';

      final list = await ApiService.fetchMedicalAppointments();
      final filtered = list.where((apt) {
        final date = (apt['created_at'] ?? apt['completed_at'] ?? '').toString();
        return date.startsWith(monthPrefix);
      }).toList();
          
      if (mounted) {
        final List<dynamic> data = filtered;
        _totalConsultations = data.length;
        
        // Count unique patients by roll number
        final Set<String> uniquePatients = {};
        for (var apt in data) {
          if (apt['student_roll_no'] != null) {
            uniquePatients.add(apt['student_roll_no'].toString());
          }
        }
        _totalPatients = uniquePatients.length;
        
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching reports data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FAFC),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Monthly Health Reports',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A202C),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Review aggregated health data and generate comprehensive reports.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF718096),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDateSelector(),
                    const SizedBox(height: 24),
                    _buildOverviewCard(),
                    const SizedBox(height: 16),
                    _buildDetailedReportCard(),
                    const SizedBox(height: 16),
                    _buildTopConcernsCard(),
                    const SizedBox(height: 32),
                  ],
                ),
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

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDropdown(_selectedMonth, _months, (val) {
            setState(() => _selectedMonth = val!);
            _fetchStats();
          }),
          Container(
            height: 20,
            width: 1,
            color: const Color(0xFFCBD5E1),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          _buildDropdown(_selectedYear, _years, (val) {
            setState(() => _selectedYear = val!);
            _fetchStats();
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
  
  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF4A5568)),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2D3748)),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Very light green
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insert_chart_outlined, color: Color(0xFF2F855A), size: 18),
              const SizedBox(width: 8),
              Text(
                'Overview: $_selectedMonth $_selectedYear',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF276749), // Dark green
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatMiniCard('Patients Seen', _isLoading ? '...' : '$_totalPatients'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatMiniCard('Consultations', _isLoading ? '...' : '$_totalConsultations'),
              ),
            ],
          )
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05);
  }

  Widget _buildStatMiniCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA0AEC0))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A202C))),
        ],
      ),
    );
  }

  Widget _buildDetailedReportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8), // Deep blue icon background
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Detailed Monthly Report',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A202C)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a comprehensive PDF including demographic breakdown, medication usage, and operational metrics.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF718096), height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comprehensive Report PDF generation coming soon!')),
                );
              },
              icon: const Icon(Icons.download, size: 16, color: Colors.white),
              label: const Text('Download PDF Report', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildTopConcernsCard() {
    // Mocked data for the UI
    final List<Map<String, String>> concerns = [
      {'rank': '1', 'title': 'Respiratory Infections (URI)', 'subtitle': 'Viral fever, cough, cold', 'pct': '35%'},
      {'rank': '2', 'title': 'Gastroenteritis', 'subtitle': 'Food poisoning, indigestion', 'pct': '22%'},
      {'rank': '3', 'title': 'Dermatological Issues', 'subtitle': 'Rashes, allergic reactions', 'pct': '15%'},
      {'rank': '4', 'title': 'Musculoskeletal', 'subtitle': 'Sprains, back pain', 'pct': '10%'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xFF2C5282), size: 20),
              SizedBox(width: 8),
              Text('Top Health Concerns', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2C5282))),
            ],
          ),
          const SizedBox(height: 20),
          ...concerns.map((c) => _buildConcernRow(c['rank']!, c['title']!, c['subtitle']!, c['pct']!)),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildConcernRow(String rank, String title, String subtitle, String pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              rank,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF63B3ED)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
              ],
            ),
          ),
          Text(pct, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2D3748))),
        ],
      ),
    );
  }
}
