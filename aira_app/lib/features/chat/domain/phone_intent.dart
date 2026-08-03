// Phone and SMS intent detection for AIRA chat (Milestone 3).

enum PhoneIntent {
  none,
  makeCall,
  sendSms,
}

class PhoneCommand {
  final PhoneIntent intent;
  final Map<String, dynamic> params;
  final String originalMessage;

  const PhoneCommand({
    required this.intent,
    required this.params,
    required this.originalMessage,
  });

  bool get isPhoneCommand => intent != PhoneIntent.none;

  String get description {
    switch (intent) {
      case PhoneIntent.makeCall:
        final recipient = params['recipient'] as String? ?? 'Contact';
        return 'Make phone call to $recipient';
      case PhoneIntent.sendSms:
        final recipient = params['recipient'] as String? ?? 'Contact';
        return 'Send SMS to $recipient';
      default:
        return 'Phone action';
    }
  }
}

class PhoneIntentDetector {
  static PhoneCommand detect(String message) {
    final msg = message.trim();
    final lowerMsg = msg.toLowerCase();

    // ── 1. Phone Call Intent ──
    if (_matchesCall(lowerMsg)) {
      final recipientMatch = RegExp(r'(?:call|dial|phone|make a call to|place a call to)\s+([A-Za-z0-9\+\-\s]+?)(?:\s+now|\s+on|\s*$)', caseSensitive: false).firstMatch(msg);
      String recipient = recipientMatch?.group(1)?.trim() ?? '';
      recipient = recipient.replaceAll(RegExp(r'[\.\!\?]$'), '').trim();
      recipient = recipient.replaceAll(RegExp(r'^(to|a call to)\s+', caseSensitive: false), '').trim();

      return PhoneCommand(
        intent: PhoneIntent.makeCall,
        params: {
          'recipient': recipient.isNotEmpty ? recipient : msg,
        },
        originalMessage: message,
      );
    }

    // ── 2. SMS Intent ──
    if (_matchesSms(lowerMsg)) {
      final recipientMatch = RegExp(r'(?:to|sms|text)\s+([A-Za-z0-9\+\-\s]+?)(?:\s+saying|\s+with|\s+message|\s*:|$)', caseSensitive: false).firstMatch(msg);
      String recipient = recipientMatch?.group(1)?.trim() ?? '';
      recipient = recipient.replaceAll(RegExp(r'[\.\!\?]$'), '').trim();
      recipient = recipient.replaceAll(RegExp(r'^(to|sms|text)\s+', caseSensitive: false), '').trim();

      final bodyMatch = RegExp(r'(?:saying|message|body|with)[:\s]+(.+)', caseSensitive: false).firstMatch(msg);
      String body = bodyMatch?.group(1)?.trim() ?? '';

      return PhoneCommand(
        intent: PhoneIntent.sendSms,
        params: {
          'recipient': recipient.isNotEmpty ? recipient : msg,
          'body': body,
        },
        originalMessage: message,
      );
    }

    return PhoneCommand(intent: PhoneIntent.none, params: {}, originalMessage: message);
  }

  static bool _matchesCall(String lowerMsg) {
    if (lowerMsg.contains('call ') ||
        lowerMsg.startsWith('call') ||
        lowerMsg.contains('make a call') ||
        lowerMsg.contains('place a call') ||
        lowerMsg.startsWith('dial')) {
      // Exclude schedule meeting/calendar calls or phone call app queries
      if (lowerMsg.contains('schedule') || lowerMsg.contains('meeting') || lowerMsg.contains('zoom') || lowerMsg.contains('google meet')) {
        return false;
      }
      return true;
    }
    return false;
  }

  static bool _matchesSms(String lowerMsg) {
    return lowerMsg.contains('send sms') ||
        lowerMsg.contains('send text') ||
        lowerMsg.startsWith('text ') ||
        lowerMsg.startsWith('sms ') ||
        lowerMsg.contains('send a text') ||
        lowerMsg.contains('text message to');
  }
}
