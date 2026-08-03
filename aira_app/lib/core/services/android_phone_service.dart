import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';
import 'package:aira_app/core/services/supabase_memory_service.dart';

/// Native Android Phone & SMS Control Service (Milestone 3).
/// Enables placing phone calls and sending SMS messages using native Android Intent & Permission APIs.
class AndroidPhoneService {
  static final AndroidPhoneService _instance = AndroidPhoneService._internal();
  factory AndroidPhoneService() => _instance;
  AndroidPhoneService._internal();

  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();
  final SupabaseMemoryService _memoryService = SupabaseMemoryService();

  /// Resolve a contact name or raw number input into a valid phone number.
  /// Tier 1: Raw digit / + phone number.
  /// Tier 2: Google Contacts API search (`phoneNumbers` mask).
  /// Tier 3: Saved AI Memory lookup in Supabase.
  Future<Map<String, String>> resolvePhoneNumber(String recipient) async {
    final cleanRecipient = recipient.trim();
    if (cleanRecipient.isEmpty) {
      throw Exception('Please specify a contact name or phone number.');
    }

    // Check if recipient is already a phone number (e.g. +919876543210 or 9876543210)
    final digitsOnly = cleanRecipient.replaceAll(RegExp(r'[^\d\+]'), '');
    if (digitsOnly.length >= 7) {
      return {
        'name': cleanRecipient,
        'phone': cleanRecipient,
        'source': 'direct',
      };
    }

    // Tier 2: Search Google Contacts API
    if (_workspace.isConnected) {
      try {
        final googleMatch = await _workspace.searchGoogleContactPhone(cleanRecipient);
        if (googleMatch != null && googleMatch['phone'] != null && googleMatch['phone']!.isNotEmpty) {
          return {
            'name': googleMatch['name'] ?? cleanRecipient,
            'phone': googleMatch['phone']!,
            'source': 'Google Contacts',
          };
        }
      } catch (_) {}
    }

    // Tier 3: Search AI Memory in Supabase
    try {
      final memories = await _memoryService.listMemories();
      for (final m in memories) {
        final text = (m['content'] as String? ?? '').toLowerCase();
        if (text.contains(cleanRecipient.toLowerCase()) && (text.contains('phone') || text.contains('number') || text.contains('mobile'))) {
          final numberMatch = RegExp(r'(\+?\d[\d\s\-\(\)]{7,}\d)').firstMatch(m['content']);
          if (numberMatch != null) {
            return {
              'name': cleanRecipient,
              'phone': numberMatch.group(1)!.trim(),
              'source': 'AI Memory',
            };
          }
        }
      }
    } catch (_) {}

    return {
      'name': cleanRecipient,
      'phone': '',
      'source': 'none',
    };
  }

  /// Make a phone call via native Android `ACTION_CALL` / `ACTION_DIAL` intent.
  Future<Map<String, dynamic>> makePhoneCall({required String recipient}) async {
    final contactInfo = await resolvePhoneNumber(recipient);
    final phone = contactInfo['phone'] ?? '';
    final name = contactInfo['name'] ?? recipient;
    final source = contactInfo['source'] ?? '';

    if (phone.isEmpty) {
      throw Exception(
        'Could not find a phone number for "$recipient" in your Google Contacts or AI Memory.\n\nPlease provide their phone number like:\n> *"Call +91 9876543210"*',
      );
    }

    // Request Android CALL_PHONE permission
    final permissionStatus = await Permission.phone.request();
    if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
      // Fallback: Use tel: dialer launch if direct call permission is not granted
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d\+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return {
        'success': true,
        'name': name,
        'phone': phone,
        'source': source,
      };
    } else {
      throw Exception('Could not launch phone dialer for number "$phone".');
    }
  }

  /// Send an SMS message via native Android `ACTION_SENDTO` intent.
  Future<Map<String, dynamic>> sendSms({
    required String recipient,
    required String body,
  }) async {
    final contactInfo = await resolvePhoneNumber(recipient);
    final phone = contactInfo['phone'] ?? '';
    final name = contactInfo['name'] ?? recipient;
    final source = contactInfo['source'] ?? '';

    if (phone.isEmpty) {
      throw Exception(
        'Could not find a phone number for "$recipient" in your Google Contacts or AI Memory.\n\nPlease provide their phone number like:\n> *"Send SMS to +91 9876543210 saying Hello"*',
      );
    }

    final smsBody = body.trim().isNotEmpty ? body.trim() : 'Hello from AIRA OS';

    // Request Android SEND_SMS permission
    await Permission.sms.request();

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d\+]'), '');
    final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(smsBody)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return {
        'success': true,
        'name': name,
        'phone': phone,
        'body': smsBody,
        'source': source,
      };
    } else {
      throw Exception('Could not launch SMS app for number "$phone".');
    }
  }
}
