import 'dart:convert';

class RuleItem {
  final String ruleNumber;
  final String category;
  final String title;
  final String description;

  RuleItem({
    required this.ruleNumber,
    required this.category,
    required this.title,
    required this.description,
  });

  factory RuleItem.fromJson(Map<String, dynamic> json) {
    return RuleItem(
      ruleNumber: (json['rule_number'] ?? json['ruleNumber'] ?? '').toString(),
      category: (json['category'] ?? 'General Conduct').toString(),
      title: (json['title'] ?? 'Rule').toString(),
      description: (json['description'] ?? json['content'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'rule_number': ruleNumber,
    'category': category,
    'title': title,
    'description': description,
  };
}

class RulesModel {
  final String id;
  final String hostelName;
  final String extractedText;
  final String? fileUrl;
  final DateTime createdAt;
  final List<RuleItem> rules;

  RulesModel({
    required this.id,
    required this.hostelName,
    required this.extractedText,
    this.fileUrl,
    required this.createdAt,
    List<RuleItem>? rules,
  }) : rules = rules ?? _parseRules(extractedText);

  static List<RuleItem> _parseRules(String text) {
    if (text.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((item) => RuleItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  factory RulesModel.fromJson(Map<String, dynamic> json) {
    final rawText = (json['extracted_text'] ?? json['extractedText'] ?? '').toString();
    final createdStr = json['created_at'] ?? json['createdAt'];
    DateTime parsedDate;
    if (createdStr is String && createdStr.isNotEmpty) {
      parsedDate = DateTime.tryParse(createdStr)?.toLocal() ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return RulesModel(
      id: (json['id'] ?? '').toString(),
      hostelName: (json['hostel_name'] ?? json['hostelName'] ?? '').toString(),
      extractedText: rawText,
      fileUrl: json['file_url'] as String? ?? json['fileUrl'] as String?,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'hostel_name': hostelName,
      'extracted_text': extractedText,
      'file_url': fileUrl,
    };
  }
}
