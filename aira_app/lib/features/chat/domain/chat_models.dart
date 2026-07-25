/// Chat message model used in the Flutter app.
class ChatMessage {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;
  final bool isStreaming;
  final String? base64Image;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isStreaming = false,
    this.base64Image,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      base64Image: json['base64Image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'base64Image': base64Image,
    };
  }

  /// Create a temporary user message before server response.
  factory ChatMessage.userTemp(String content) {
    return ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: '',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
  }

  /// Create a streaming assistant message placeholder.
  factory ChatMessage.streamingPlaceholder() {
    return ChatMessage(
      id: 'streaming_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: '',
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );
  }

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    String? base64Image,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      base64Image: base64Image ?? this.base64Image,
    );
  }
}

/// Conversation model.
class Conversation {
  final String id;
  final String userId;
  final String? title;
  final String? summary;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.userId,
    this.title,
    this.summary,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'],
      summary: json['summary'],
      isPinned: json['is_pinned'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      messages: (json['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m))
              .toList() ??
          [],
    );
  }

  String get displayTitle => title ?? 'New Chat';
  String get timeAgo {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }
}
