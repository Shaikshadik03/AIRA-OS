// Memory intent detection for AIRA chat.

enum MemoryIntent {
  none,
  saveMemory,
  listMemories,
  clearMemories,
}

class MemoryCommand {
  final MemoryIntent intent;
  final String content;
  final String category;
  final String originalMessage;

  const MemoryCommand({
    required this.intent,
    this.content = '',
    this.category = 'general',
    required this.originalMessage,
  });

  bool get isMemoryCommand => intent != MemoryIntent.none;
}

class MemoryIntentDetector {
  static MemoryCommand detect(String message) {
    final msg = message.toLowerCase().trim();

    // ── 1. Clear / Forget memories ──
    if (_matches(msg, ['forget everything', 'clear all memories', 'delete all memories', 'clear my memories', 'reset memory'])) {
      return MemoryCommand(
        intent: MemoryIntent.clearMemories,
        originalMessage: message,
      );
    }

    // ── 2. List / Show memories ──
    if (_matches(msg, [
      'what do you remember',
      'show my memories',
      'list my memories',
      'show memories',
      'list memories',
      'what do you know about me',
      'my saved memories',
      'view memories',
    ])) {
      return MemoryCommand(
        intent: MemoryIntent.listMemories,
        originalMessage: message,
      );
    }

    // ── 3. Save Memory Explicit Commands ──
    if (msg.startsWith('remember that ') ||
        msg.startsWith('remember my ') ||
        msg.startsWith('remember ') ||
        msg.startsWith('note that ') ||
        msg.startsWith('save memory ') ||
        msg.startsWith('keep in mind ')) {
      
      final cleanText = message
          .replaceAll(RegExp(r'^(remember that|remember my|remember|note that|save memory|keep in mind)\s+', caseSensitive: false), '')
          .trim();

      String category = 'general';
      if (cleanText.toLowerCase().contains('email') || cleanText.toLowerCase().contains('contact')) {
        category = 'contact';
      } else if (cleanText.toLowerCase().contains('prefer') || cleanText.toLowerCase().contains('like')) {
        category = 'preference';
      }

      return MemoryCommand(
        intent: MemoryIntent.saveMemory,
        content: cleanText,
        category: category,
        originalMessage: message,
      );
    }

    // ── 4. Natural Contact / Preference statements ──
    // e.g., "rahul is my colleague and his email is rahul@gmail.com"
    if (RegExp(r'([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})').hasMatch(message) &&
        (msg.contains('is my') || msg.contains('email is') || msg.contains('contact is'))) {
      return MemoryCommand(
        intent: MemoryIntent.saveMemory,
        content: message,
        category: 'contact',
        originalMessage: message,
      );
    }

    return MemoryCommand(
      intent: MemoryIntent.none,
      originalMessage: message,
    );
  }

  static bool _matches(String msg, List<String> patterns) {
    return patterns.any((p) => msg.contains(p));
  }
}
