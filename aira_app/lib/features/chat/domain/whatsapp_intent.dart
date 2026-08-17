import 'package:url_launcher/url_launcher.dart';

enum WhatsAppIntentType {
  draftMessage,
  sendDirect,
  unknown,
}

class WhatsAppCommand {
  final WhatsAppIntentType intent;
  final String recipient;
  final String message;
  final bool isWhatsAppCommand;

  const WhatsAppCommand({
    required this.intent,
    required this.recipient,
    required this.message,
    this.isWhatsAppCommand = false,
  });

  factory WhatsAppCommand.none() => const WhatsAppCommand(
        intent: WhatsAppIntentType.unknown,
        recipient: '',
        message: '',
        isWhatsAppCommand: false,
      );
}

class WhatsAppIntentDetector {
  WhatsAppIntentDetector._();

  static WhatsAppCommand detect(String input) {
    final lower = input.toLowerCase().trim();

    if (!lower.contains('whatsapp') && !lower.contains('whats app')) {
      return WhatsAppCommand.none();
    }

    // Pattern 1: "send whatsapp to [recipient] saying [message]"
    final sendToSaying = RegExp(
      r'(?:send|draft|write|message)\s+(?:a\s+)?whatsapp\s+(?:message\s+)?to\s+([a-zA-Z0-9\s+]+?)\s+(?:saying|that|with message|with text)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(input);

    if (sendToSaying != null) {
      final recipient = sendToSaying.group(1)?.trim() ?? '';
      final message = sendToSaying.group(2)?.trim() ?? '';
      return WhatsAppCommand(
        intent: WhatsAppIntentType.sendDirect,
        recipient: recipient,
        message: message,
        isWhatsAppCommand: true,
      );
    }

    // Pattern 2: "whatsapp [recipient] saying [message]"
    final whatsappSaying = RegExp(
      r'whatsapp\s+([a-zA-Z0-9\s+]+?)\s+(?:saying|that|with)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(input);

    if (whatsappSaying != null) {
      final recipient = whatsappSaying.group(1)?.trim() ?? '';
      final message = whatsappSaying.group(2)?.trim() ?? '';
      return WhatsAppCommand(
        intent: WhatsAppIntentType.sendDirect,
        recipient: recipient,
        message: message,
        isWhatsAppCommand: true,
      );
    }

    // Pattern 3: "draft whatsapp to [recipient] about [topic]"
    final draftToAbout = RegExp(
      r'(?:draft|write|compose|create)\s+(?:a\s+)?whatsapp\s+(?:message\s+)?to\s+([a-zA-Z0-9\s+]+?)\s+(?:about|regarding|for)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(input);

    if (draftToAbout != null) {
      final recipient = draftToAbout.group(1)?.trim() ?? '';
      final topic = draftToAbout.group(2)?.trim() ?? '';
      return WhatsAppCommand(
        intent: WhatsAppIntentType.draftMessage,
        recipient: recipient,
        message: topic,
        isWhatsAppCommand: true,
      );
    }

    // Pattern 4: General "send whatsapp" or "open whatsapp"
    return WhatsAppCommand(
      intent: WhatsAppIntentType.draftMessage,
      recipient: '',
      message: input,
      isWhatsAppCommand: true,
    );
  }

  /// Opens WhatsApp with the given phone number or message pre-filled.
  static Future<bool> openWhatsApp({String? phone, required String message}) async {
    final encodedMsg = Uri.encodeComponent(message);
    Uri uri;

    if (phone != null && phone.trim().isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');
    } else {
      uri = Uri.parse('whatsapp://send?text=$encodedMsg');
    }

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web WhatsApp URL
        final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedMsg');
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      return false;
    }
  }
}
