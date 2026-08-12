import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_palette.dart';
import 'models/rules_model.dart';
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

class _RulesPageState extends State<RulesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _hostels = ['Boys Hostel', 'Umsawli Girls', 'Nongthymmai Girls'];
  
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, RulesModel?> _rulesData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _hostels.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchRules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index != _tabController.previousIndex) {
      setState(() {});
    }
  }

  Future<void> _fetchRules() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('hostel_rules').select();
      
      final Map<String, RulesModel> fetched = {};
      for (final row in res) {
        final r = RulesModel.fromJson(row);
        fetched[r.hostelName] = r;
      }
      
      if (mounted) {
        setState(() {
          _rulesData = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching rules: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rules. Did you run the SQL script? ($e)')),
        );
      }
    }
  }

  Future<void> _uploadRules() async {
    final activeHostel = _hostels[_tabController.index];
    
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Need bytes for Gemini
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception("Could not read file data.");
      }

      setState(() => _isProcessing = true);
      debugPrint('File picked: ${file.name}, size: ${file.bytes!.length} bytes');

      // Determine mime type
      String mimeType = 'application/pdf';
      if (file.extension?.toLowerCase() == 'jpg' || file.extension?.toLowerCase() == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (file.extension?.toLowerCase() == 'png') {
        mimeType = 'image/png';
      }
      
      debugPrint('Determined mimeType: $mimeType');

      // 1. Extract text using Gemini
      final extractionService = ExtractionService(apiKeys: AppConfig.activeKeys);
      debugPrint('Starting Gemini extraction...');
      final extractedText = await extractionService.extractRulesFromDocument(
        fileBytes: file.bytes!,
        mimeType: mimeType,
      );
      
      debugPrint('Gemini extraction finished. Length: ${extractedText.length}');

      // 2. Try to upload to storage (soft fail if bucket doesn't exist)
      String? fileUrl;
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        await Supabase.instance.client.storage
            .from('rules_documents')
            .uploadBinary(fileName, file.bytes!);
        
        fileUrl = Supabase.instance.client.storage
            .from('rules_documents')
            .getPublicUrl(fileName);
      } catch (storageError) {
        debugPrint('Storage upload failed (bucket might be missing), continuing with just text: $storageError');
      }

      // 3. Save to database (Upsert basically, delete old if exists)
      final existingRule = _rulesData[activeHostel];
      if (existingRule != null) {
         await Supabase.instance.client.from('hostel_rules').delete().eq('id', existingRule.id);
      }

      final newRule = RulesModel(
        id: '', // Supabase generates UUID
        hostelName: activeHostel,
        extractedText: extractedText,
        fileUrl: fileUrl,
        createdAt: DateTime.now(),
      );

      final inserted = await Supabase.instance.client
          .from('hostel_rules')
          .insert(newRule.toJson())
          .select()
          .single();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_rules');

      if (mounted) {
        setState(() {
          _rulesData[activeHostel] = RulesModel.fromJson(inserted);
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rules extracted and uploaded successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading rules: $e'), backgroundColor: ChatPalette.accentRose),
        );
      }
    }
  }

  Future<void> _deleteRules() async {
    final activeHostel = _hostels[_tabController.index];
    final existingRule = _rulesData[activeHostel];
    
    if (existingRule == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatPalette.surface,
        title: Text('Remove Rules', style: TextStyle(color: ChatPalette.text)),
        content: Text('Are you sure you want to remove the rules for $activeHostel?', style: TextStyle(color: ChatPalette.dim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ChatPalette.text))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: ChatPalette.accentRose),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete')
          ),
        ],
      )
    );
    
    if (confirm != true) return;
    
    setState(() => _isProcessing = true);
    try {
      await Supabase.instance.client.from('hostel_rules').delete().eq('id', existingRule.id);
      
      // Optionally delete from storage if URL exists, but skipping for brevity/safety
      
      if (mounted) {
        setState(() {
          _rulesData.remove(activeHostel);
          _isProcessing = false;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_rules');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete rules: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: _isLoading 
            ? Center(child: CircularProgressIndicator(color: ChatPalette.accentBlue))
            : TabBarView(
                controller: _tabController,
                children: _hostels.map((h) => _buildTabContent(h)).toList(),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (widget.compact ? 16 : 32),
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        color: ChatPalette.surface,
        border: Border(bottom: BorderSide(color: ChatPalette.border)),
      ),
      child: Row(
        children: [
          if (widget.compact) ...[
            IconButton(
              icon: Icon(Icons.menu, color: ChatPalette.text),
              onPressed: widget.onMenuPressed,
            ),
            const SizedBox(width: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: ChatPalette.gradientPurple),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.gavel_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rules & Regulations',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ChatPalette.text,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Manage disciplinary guidelines and policies',
                  style: TextStyle(
                    fontSize: 14,
                    color: ChatPalette.dim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: ChatPalette.background,
      child: TabBar(
        controller: _tabController,
        isScrollable: widget.compact,
        indicatorColor: ChatPalette.accentPurple,
        labelColor: ChatPalette.accentPurple,
        unselectedLabelColor: ChatPalette.dim,
        tabs: _hostels.map((h) => Tab(text: h)).toList(),
      ),
    );
  }

  Widget _buildTabContent(String hostelName) {
    final rules = _rulesData[hostelName];
    
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ChatPalette.accentPurple),
            const SizedBox(height: 16),
            Text('Processing document with AI...', style: TextStyle(color: ChatPalette.dim)),
          ],
        )
      );
    }
    
    if (rules == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: ChatPalette.dim.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No rules found for $hostelName', style: TextStyle(color: ChatPalette.text, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Upload a PDF or Image to automatically extract rules.', style: TextStyle(color: ChatPalette.dim)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _uploadRules,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ChatPalette.accentPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _showManualEntryDialog(hostelName),
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Paste Text Manually'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ChatPalette.text,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: BorderSide(color: ChatPalette.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Text('Extracted Rules', style: TextStyle(color: ChatPalette.text, fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploadRules,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload New'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ChatPalette.text,
                      side: BorderSide(color: ChatPalette.border),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showManualEntryDialog(hostelName, initialText: rules.extractedText),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Text'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ChatPalette.text,
                      side: BorderSide(color: ChatPalette.border),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _deleteRules,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ChatPalette.accentRose,
                      side: BorderSide(color: ChatPalette.accentRose.withValues(alpha: 0.3)),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatPalette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ChatPalette.border),
              ),
              child: SingleChildScrollView(
                child: _buildRulesContent(rules.extractedText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesContent(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: decoded.length,
          itemBuilder: (context, index) {
            final rule = decoded[index] as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatPalette.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ChatPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ChatPalette.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rule['rule_number']?.toString() ?? '${index + 1}',
                          style: TextStyle(color: ChatPalette.accentPurple, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule['title']?.toString() ?? 'Rule',
                          style: TextStyle(color: ChatPalette.text, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (rule['category'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ChatPalette.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rule['category'].toString(),
                            style: TextStyle(color: ChatPalette.dim, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    rule['description']?.toString() ?? '',
                    style: TextStyle(color: ChatPalette.dim, height: 1.5, fontSize: 14),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      // Not JSON, fallback to standard text
    }

    // Fallback standard text
    return SelectableText(
      text,
      style: TextStyle(
        color: ChatPalette.text,
        height: 1.6,
      ),
    );
  }

  void _showManualEntryDialog(String hostelName, {String? initialText}) {
    final textController = TextEditingController(text: initialText);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatPalette.surface,
        title: Text('Manual Rules Entry - $hostelName', style: TextStyle(color: ChatPalette.text)),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: textController,
            maxLines: 15,
            style: TextStyle(color: ChatPalette.text),
            decoration: InputDecoration(
              hintText: 'Paste or type the rules here...',
              hintStyle: TextStyle(color: ChatPalette.dim),
              filled: true,
              fillColor: ChatPalette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ChatPalette.border),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ChatPalette.dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ChatPalette.accentPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (textController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              
              setState(() => _isProcessing = true);
              try {
                final existingRule = _rulesData[hostelName];
                if (existingRule != null) {
                   await Supabase.instance.client.from('hostel_rules').delete().eq('id', existingRule.id);
                }

                final newRule = RulesModel(
                  id: '',
                  hostelName: hostelName,
                  extractedText: textController.text.trim(),
                  fileUrl: null,
                  createdAt: DateTime.now(),
                );

                final inserted = await Supabase.instance.client
                    .from('hostel_rules')
                    .insert(newRule.toJson())
                    .select()
                    .single();

                if (mounted) {
                  setState(() {
                    _rulesData[hostelName] = RulesModel.fromJson(inserted);
                    _isProcessing = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rules saved successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving rules: $e')),
                  );
                }
              }
            },
            child: const Text('Save Rules'),
          ),
        ],
      ),
    );
  }
}
