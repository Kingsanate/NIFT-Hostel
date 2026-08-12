enum MessageAuthor { user, assistant }

class Conversation {
  final String id;
  final String title;
  final String subtitle;
  final DateTime updatedAt;
  final List<Message> messages;

  const Conversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.messages,
  });

  Conversation copyWith({
    String? title,
    String? subtitle,
    DateTime? updatedAt,
    List<Message>? messages,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}

class Message {
  final String id;
  final String text;
  final DateTime createdAt;
  final MessageAuthor author;

  const Message({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.author,
  });

  bool get isUser => author == MessageAuthor.user;
}
