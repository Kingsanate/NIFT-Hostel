import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../chat/chat_palette.dart';
import 'models/rules_model.dart';
import 'data/default_rules.dart';
import '../scanner/services/extraction_service.dart';
import '../main.dart';

class RulesPage extends StatefulWidget {
  final bool compact;
  final VoidCallback onMenuPressed;

  const RulesPage({
    super.key,
    required this.compact,
    required this.onMenuPressed,
  });

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final List<String> _hostels = [
    'Boys Hostel',
    'Umsawli Girls',
    'Nongthymmai Girls',
  ];

  final Map<String, String> _hostelCapacity = {
    'Boys Hostel': '54 Beds',
    'Umsawli Girls': '127 Beds',
    'Nongthymmai Girls': '153 Beds',
  };

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Capacity',
    'Timings',
    'Mess & Refectory',
    'Leaves & Visitors',
    'Prohibited Items',
    'General Conduct',
  ];

  @override
  bool get wantKeepAlive => true;

  bool _isProcessing = false;
  Map<String, RulesModel> _rulesData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _hostels.length, vsync: this);
    _tabController.addListener(_handleTabChange);

    // 1. Immediately seed official rules for 0ms instant display
    _rulesData = DefaultRulesData.getDefaultRulesModels();

    // 2. Background server fetch
    _fetchRules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index != _tabController.previousIndex) {
      setState(() {});
    }
  }

  Future<void> _fetchRules() async {
    try {
      final res = await ApiService.fetchRules();
      if (res.isNotEmpty) {
        final Map<String, RulesModel> fetched = Map.from(_rulesData);
        for (final row in res) {
          final r = RulesModel.fromJson(Map<String, dynamic>.from(row));
          if (r.rules.isNotEmpty) {
            fetched[r.hostelName] = r;
          }
        }
        if (mounted) {
          setState(() {
            _rulesData = fetched;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching server rules: $e');
    }
  }

  Future<void> _uploadRules() async {
    final activeHostel = _hostels[_tabController.index];

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception("Could not read file data.");
      }

      setState(() => _isProcessing = true);

      String mimeType = 'application/pdf';
      if (file.extension?.toLowerCase() == 'jpg' ||
          file.extension?.toLowerCase() == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (file.extension?.toLowerCase() == 'png') {
        mimeType = 'image/png';
      }

      final extractionService =
          ExtractionService(apiKeys: AppConfig.activeKeys);
      final extractedText = await extractionService.extractRulesFromDocument(
        fileBytes: file.bytes!,
        mimeType: mimeType,
      );

      final res = await ApiService.saveRule(
        hostelName: activeHostel,
        extractedText: extractedText,
      );

      final ruleData = res['rule'] ?? {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'hostel_name': activeHostel,
        'extracted_text': extractedText,
        'created_at': DateTime.now().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_rules');

      if (mounted) {
        setState(() {
          _rulesData[activeHostel] =
              RulesModel.fromJson(Map<String, dynamic>.from(ruleData));
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rules for $activeHostel updated successfully! ✓',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading rules: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: ChatPalette.accentRose,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _resetToDefault() {
    final activeHostel = _hostels[_tabController.index];
    final defaults = DefaultRulesData.getDefaultRulesModels();
    if (defaults.containsKey(activeHostel)) {
      setState(() {
        _rulesData[activeHostel] = defaults[activeHostel]!;
      });
      ApiService.saveRule(
        hostelName: activeHostel,
        extractedText: defaults[activeHostel]!.extractedText,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset to official $activeHostel handbook rules ✓',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('timings')) return const Color(0xFF2563EB); // Royal Blue
    if (cat.contains('capacity')) return const Color(0xFF059669); // Emerald Green
    if (cat.contains('mess') || cat.contains('refectory')) {
      return const Color(0xFFEA580C); // Warm Orange
    }
    if (cat.contains('prohibited') || cat.contains('ragging')) {
      return const Color(0xFFDC2626); // Crimson Red
    }
    if (cat.contains('leave') || cat.contains('visitor')) {
      return const Color(0xFFD97706); // Amber
    }
    return const Color(0xFF7C3AED); // Vivid Violet
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('timings')) return Icons.schedule_rounded;
    if (cat.contains('capacity')) return Icons.meeting_room_rounded;
    if (cat.contains('mess') || cat.contains('refectory')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('prohibited') || cat.contains('ragging')) {
      return Icons.gpp_bad_rounded;
    }
    if (cat.contains('leave') || cat.contains('visitor')) {
      return Icons.no_accounts_rounded;
    }
    return Icons.verified_user_rounded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Column(
        children: [
          _buildHeader(),
          _buildSegmentedHostelSwitcher(),
          _buildSearchAndFilters(),
          Expanded(
            child: _isProcessing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Processing and extracting rules with AI...',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children:
                        _hostels.map((h) => _buildHostelRulesView(h)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (widget.compact ? 12 : 20),
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          if (widget.compact) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
              onPressed: widget.onMenuPressed,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rules & Regulations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Official disciplinary policies, schedules & code of conduct',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
            color: Colors.white,
            elevation: 6,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'upload') _uploadRules();
              if (val == 'reset') _resetToDefault();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_rounded,
                        size: 18, color: Color(0xFF6366F1)),
                    const SizedBox(width: 10),
                    Text('Upload Rule Document',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.restore_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Text('Reset Official Handbook',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedHostelSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Slate 100
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: _hostels.asMap().entries.map((entry) {
            final idx = entry.key;
            final name = entry.value;
            final isSelected = _tabController.index == idx;
            final isBoys = name.toLowerCase().contains('boys');
            final capacity = _hostelCapacity[name] ?? '';

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _tabController.animateTo(idx);
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isBoys
                                ? Icons.male_rounded
                                : Icons.female_rounded,
                            size: 16,
                            color: isSelected
                                ? (isBoys
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF9333EA))
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF64748B),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        capacity,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? (isBoys
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF9333EA))
                              : const Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _searchQuery.isNotEmpty
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFE2E8F0),
                width: _searchQuery.isNotEmpty ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search_rounded,
                  color: _searchQuery.isNotEmpty
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0F172A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search fine, in-time, curfew, mess timings, ragging...',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF94A3B8), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Category Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                final color = cat == 'All'
                    ? const Color(0xFF6366F1)
                    : _getCategoryColor(cat);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostelRulesView(String hostelName) {
    final rulesModel = _rulesData[hostelName] ??
        DefaultRulesData.getDefaultRulesModels()[hostelName];
    final allRules = rulesModel?.rules ?? [];

    final filteredRules = allRules.where((rule) {
      final matchesCat = _selectedCategory == 'All' ||
          rule.category.toLowerCase() == _selectedCategory.toLowerCase();

      if (!matchesCat) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final inTitle = rule.title.toLowerCase().contains(query);
      final inDesc = rule.description.toLowerCase().contains(query);
      final inCategory = rule.category.toLowerCase().contains(query);
      final inNum = rule.ruleNumber.toLowerCase().contains(query);

      return inTitle || inDesc || inCategory || inNum;
    }).toList();

    return Column(
      children: [
        // Quick Stats Summary Banner
        _buildStatsBanner(hostelName),

        // Result Count Indicator when searching/filtering
        if (_searchQuery.isNotEmpty || _selectedCategory != 'All')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded,
                    size: 15, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text(
                  'Showing ${filteredRules.length} of ${allRules.length} rules',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategory = 'All';
                    });
                  },
                  child: Text(
                    'Clear Filters',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6366F1),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Rules Cards List
        Expanded(
          child: filteredRules.isEmpty
              ? _buildEmptySearchState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredRules.length,
                  itemBuilder: (ctx, idx) {
                    final rule = filteredRules[idx];
                    return _buildRuleCard(rule, idx + 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsBanner(String hostelName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Hostel In-Time', '9:00 PM', const Color(0xFF2563EB),
              Icons.access_time_filled_rounded),
          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
          _buildStatItem('Night Roll-Call', '10:30 PM', const Color(0xFFD97706),
              Icons.notifications_active_rounded),
          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
          _buildStatItem('Anti-Ragging', 'Zero Tolerance',
              const Color(0xFFDC2626), Icons.shield_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 38, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching rules found',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try searching for other terms like "fine", "mess", "gate", "room", "visitor"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                });
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text('View All Rules',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(RuleItem rule, int index) {
    final catColor = _getCategoryColor(rule.category);
    final catIcon = _getCategoryIcon(rule.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Color Strip (3px)
            Container(
              height: 3.5,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [catColor, catColor.withValues(alpha: 0.4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            // Card Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 8),
              child: Row(
                children: [
                  // Rule Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'RULE ${rule.ruleNumber.padLeft(2, '0')}',
                      style: GoogleFonts.plusJakartaSans(
                        color: catColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Category Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(catIcon, size: 12, color: const Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Text(
                          rule.category,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Copy Button
                  IconButton(
                    onPressed: () {
                      final copyText =
                          '${rule.title}\n\n${rule.description}';
                      Clipboard.setData(ClipboardData(text: copyText));
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Rule ${rule.ruleNumber} copied to clipboard ✓',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: const Color(0xFF334155),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    color: const Color(0xFF94A3B8),
                    tooltip: 'Copy Rule',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    rule.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF0F172A),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Enhanced Description with dynamic bullet & component parsing
                  _buildFormattedDescription(rule.description, catColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedDescription(String text, Color catColor) {
    if (text.contains('•')) {
      final lines = text.split('\n');
      final List<Widget> widgets = [];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('•')) {
          final bulletContent = trimmed.substring(1).trim();

          // 1. Check if bullet point is a progressive penalty (Violation / Fine / Expulsion)
          final isPenalty = bulletContent.toLowerCase().contains('violation') ||
              bulletContent.toLowerCase().contains('fine') ||
              bulletContent.toLowerCase().contains('expulsion');

          // 2. Check if bullet point is a meal timing
          final isMeal = bulletContent.toLowerCase().contains('breakfast') ||
              bulletContent.toLowerCase().contains('lunch') ||
              bulletContent.toLowerCase().contains('snack') ||
              bulletContent.toLowerCase().contains('dinner');

          IconData bulletIcon = Icons.fiber_manual_record_rounded;
          Color bulletColor = catColor;
          Color bgColor = const Color(0xFFF8FAFC);
          Color borderColor = const Color(0xFFE2E8F0);

          if (isPenalty) {
            bulletIcon = Icons.warning_amber_rounded;
            bulletColor = const Color(0xFFDC2626);
            bgColor = const Color(0xFFFEF2F2);
            borderColor = const Color(0xFFFECACA);
          } else if (isMeal) {
            bulletIcon = Icons.restaurant_menu_rounded;
            bulletColor = const Color(0xFFEA580C);
            bgColor = const Color(0xFFFFF7ED);
            borderColor = const Color(0xFFFFEDD5);
          }

          widgets.add(
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      bulletIcon,
                      size: isPenalty || isMeal ? 14 : 7,
                      color: bulletColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bulletContent,
                      style: GoogleFonts.inter(
                        color: isPenalty
                            ? const Color(0xFF991B1B)
                            : (isMeal
                                ? const Color(0xFF9A3412)
                                : const Color(0xFF334155)),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: isPenalty || isMeal
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Regular paragraph
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                trimmed,
                style: GoogleFonts.inter(
                  color: const Color(0xFF334155), // Slate 700
                  fontSize: 13.5,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          );
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    // Default formatted paragraph
    return Text(
      text,
      style: GoogleFonts.inter(
        color: const Color(0xFF334155), // Slate 700
        fontSize: 13.5,
        height: 1.6,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
