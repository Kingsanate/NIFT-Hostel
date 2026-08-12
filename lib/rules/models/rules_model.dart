class RulesModel {
  final String id;
  final String hostelName;
  final String extractedText;
  final String? fileUrl;
  final DateTime createdAt;

  RulesModel({
    required this.id,
    required this.hostelName,
    required this.extractedText,
    this.fileUrl,
    required this.createdAt,
  });

  factory RulesModel.fromJson(Map<String, dynamic> json) {
    return RulesModel(
      id: json['id'] as String,
      hostelName: json['hostel_name'] as String,
      extractedText: json['extracted_text'] as String,
      fileUrl: json['file_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
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
