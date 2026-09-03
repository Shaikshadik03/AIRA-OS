import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_service.dart';
import 'notification_monitor_service.dart';

enum ReplyDraftStatus { pending, sending, sent, dismissed, failed }

class PendingReplyDraft {
  final String id;
  final String replyKey;
  final String packageName;
  final String appName;
  final String sender;
  final String incomingMessage;
  String draftedReply;
  ReplyDraftStatus status;
  final DateTime timestamp;
  int delayRemainingSeconds;

  PendingReplyDraft({
    required this.id,
    required this.replyKey,
    required this.packageName,
    required this.appName,
    required this.sender,
    required this.incomingMessage,
    required this.draftedReply,
    this.status = ReplyDraftStatus.pending,
    required this.timestamp,
    this.delayRemainingSeconds = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'replyKey': replyKey,
      'packageName': packageName,
      'appName': appName,
      'sender': sender,
      'incomingMessage': incomingMessage,
      'draftedReply': draftedReply,
      'status': status.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory PendingReplyDraft.fromMap(Map<String, dynamic> map) {
    return PendingReplyDraft(
      id: map['id']?.toString() ?? '',
      replyKey: map['replyKey']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? '',
      sender: map['sender']?.toString() ?? '',
      incomingMessage: map['incomingMessage']?.toString() ?? '',
      draftedReply: map['draftedReply']?.toString() ?? '',
      status: ReplyDraftStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReplyDraftStatus.pending,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] is int ? map['timestamp'] : (int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0),
      ),
    );
  }
}

class SmartReplyService extends ChangeNotifier {
  static final SmartReplyService _instance = SmartReplyService._internal();
  factory SmartReplyService() => _instance;
  SmartReplyService._internal();

  static const MethodChannel _channel = MethodChannel('com.aira.os/device_control');
  static const String _storageKey = 'aira_pending_reply_drafts_v1';

  final List<PendingReplyDraft> _drafts = [];
  final StreamController<List<PendingReplyDraft>> _draftsStreamController =
      StreamController<List<PendingReplyDraft>>.broadcast();

  StreamSubscription? _notifSubscription;
  bool _isInitialized = false;

  List<PendingReplyDraft> get drafts => List.unmodifiable(_drafts);
  List<PendingReplyDraft> get activePendingDrafts =>
      _drafts.where((d) => d.status == ReplyDraftStatus.pending || d.status == ReplyDraftStatus.sending).toList();
  Stream<List<PendingReplyDraft>> get onDraftsChanged => _draftsStreamController.stream;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadPersistedDrafts();

    // Listen to real-time incoming notifications from NotificationMonitorService
    final notifService = NotificationMonitorService();
    _notifSubscription?.cancel();
    _notifSubscription = notifService.onNotificationReceived.listen(_handleIncomingNotification);
  }

  Future<void> _handleIncomingNotification(InterceptedNotification notif) async {
    // Only process messaging notifications that support Android RemoteInput
    if (!notif.canReply || notif.replyKey == null || notif.replyKey!.isEmpty) {
      return;
    }
    if (notif.category != 'messaging' && !notif.packageName.contains('whatsapp') && !notif.packageName.contains('telegram')) {
      return;
    }

    final messageText = notif.text.trim();
    final sender = notif.title.trim();
    if (messageText.isEmpty) return;

    // Avoid duplicate draft for same replyKey
    if (_drafts.any((d) => d.replyKey == notif.replyKey)) {
      return;
    }

    // Generate AI Smart Reply in background
    final draftedReply = await generateCasualDraft(sender: sender, messageText: messageText);

    final draft = PendingReplyDraft(
      id: 'reply_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      replyKey: notif.replyKey!,
      packageName: notif.packageName,
      appName: notif.appName,
      sender: sender.isNotEmpty ? sender : 'Sender',
      incomingMessage: messageText,
      draftedReply: draftedReply,
      status: ReplyDraftStatus.pending,
      timestamp: DateTime.now(),
    );

    _drafts.insert(0, draft);
    if (_drafts.length > 50) {
      _drafts.removeLast();
    }

    await _persistDrafts();
    notifyListeners();
    _draftsStreamController.add(List.unmodifiable(_drafts));
  }

  /// Manually process a notification for testing or foreground triggers
  Future<PendingReplyDraft?> processNotification(InterceptedNotification notif) async {
    await _handleIncomingNotification(notif);
    final match = _drafts.where((d) => d.replyKey == notif.replyKey);
    return match.isNotEmpty ? match.first : null;
  }

  /// Manually insert a draft (useful for testing & scheduled task cards)
  void addDraft(PendingReplyDraft draft) {
    _drafts.insert(0, draft);
    notifyListeners();
    _draftsStreamController.add(List.unmodifiable(_drafts));
  }

  /// System prompt generator supporting natural code-mixed Telugu + English casual conversational tone
  Future<String> generateCasualDraft({
    required String sender,
    required String messageText,
  }) async {
    final systemPrompt = """
You are drafting a quick text reply for Arshan (a casual, friendly Indian CSE student & developer).
Tone and Style Guidelines:
1. Super natural, casual, and friendly — like replying to a friend or classmate.
2. Short and crisp: exactly 1 to 2 short sentences. No greetings like "Dear", "Hello Arshan", or signatures.
3. Code-Mixed Telugu + English Support:
   - If the message contains Telugu words (e.g., 'ekkada', 'cheppu', 'ra', 'bhayya', 'eppudu', 'em chestunnav', 'osthava', 'sare'), or if casual colloquial context fits, reply in natural conversational code-mixed Telugu+English using Latin script (e.g., "Haa bro, just ippude choosa", "Sure, 10 mins lo vastha", "Sare evening matladadam", "Avuna! Cool bro", "Enti visheshalu?").
   - If the message is in plain English, reply in punchy, casual, helpful conversational English (e.g., "Yeah sounds good, will check it out!", "On it, 5 mins lo ping chesta", "Got it, thanks for letting me know!").
4. NEVER be formal, corporate, or robotic.
5. Return ONLY the reply message text, nothing else.
""";

    final prompt = """
Incoming message from: $sender
Message: "$messageText"

Draft a quick casual reply:
""";

    try {
      final reply = await LlmService().chat(
        userMessage: prompt,
        systemPromptOverride: systemPrompt,
      );

      final cleaned = reply.replaceAll('"', '').trim();
      return cleaned.isNotEmpty ? cleaned : "Sure, will get back to you in a bit!";
    } catch (_) {
      // Fallback casual draft
      if (messageText.toLowerCase().contains('ekkada') || messageText.toLowerCase().contains('where')) {
        return "Just on my way bro, 10 mins lo ostha.";
      }
      return "Sure bro, will check and tell you in 5 mins!";
    }
  }

  /// Regenerate a draft with high temperature for fresh alternatives
  Future<void> regenerateDraft(String draftId) async {
    final index = _drafts.indexWhere((d) => d.id == draftId);
    if (index == -1) return;

    final draft = _drafts[index];
    final freshReply = await generateCasualDraft(
      sender: draft.sender,
      messageText: draft.incomingMessage,
    );

    draft.draftedReply = freshReply;
    await _persistDrafts();
    notifyListeners();
    _draftsStreamController.add(List.unmodifiable(_drafts));
  }

  /// Update drafted reply text as user edits it in the card
  void updateDraftText(String draftId, String newText) {
    final index = _drafts.indexWhere((d) => d.id == draftId);
    if (index != -1) {
      _drafts[index].draftedReply = newText;
      _persistDrafts();
      notifyListeners();
      _draftsStreamController.add(List.unmodifiable(_drafts));
    }
  }

  /// Dismiss draft without sending
  Future<void> dismissDraft(String draftId) async {
    final index = _drafts.indexWhere((d) => d.id == draftId);
    if (index != -1) {
      _drafts[index].status = ReplyDraftStatus.dismissed;
      await _persistDrafts();
      notifyListeners();
      _draftsStreamController.add(List.unmodifiable(_drafts));
    }
  }

  /// Fire reply through Android RemoteInput with anti-bot randomized delay (1.5s - 3.2s)
  Future<bool> sendReply({
    required String draftId,
    required String finalReplyText,
  }) async {
    final index = _drafts.indexWhere((d) => d.id == draftId);
    if (index == -1) return false;

    final draft = _drafts[index];
    draft.draftedReply = finalReplyText;
    draft.status = ReplyDraftStatus.sending;
    notifyListeners();
    _draftsStreamController.add(List.unmodifiable(_drafts));

    // Randomized delay between 1500ms and 3200ms to avoid bot-pattern detection
    final randomDelayMs = 1500 + Random().nextInt(1700);
    final totalSeconds = (randomDelayMs / 1000).ceil();

    for (int sec = totalSeconds; sec > 0; sec--) {
      draft.delayRemainingSeconds = sec;
      notifyListeners();
      _draftsStreamController.add(List.unmodifiable(_drafts));
      await Future.delayed(const Duration(milliseconds: 750));
    }

    // Invoke native RemoteInput PendingIntent
    bool success = false;
    try {
      final dynamic res = await _channel.invokeMethod('sendNotificationReply', {
        'replyKey': draft.replyKey,
        'replyText': finalReplyText,
      });
      if (res is Map && res['success'] == true) {
        success = true;
      }
    } catch (_) {
      success = false;
    }

    draft.status = success ? ReplyDraftStatus.sent : ReplyDraftStatus.failed;
    draft.delayRemainingSeconds = 0;
    await _persistDrafts();
    notifyListeners();
    _draftsStreamController.add(List.unmodifiable(_drafts));
    return success;
  }

  Future<void> _persistDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = jsonEncode(_drafts.map((d) => d.toMap()).toList());
      await prefs.setString(_storageKey, jsonList);
    } catch (_) {}
  }

  Future<void> _loadPersistedDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _drafts.clear();
        for (final item in list) {
          if (item is Map) {
            _drafts.add(PendingReplyDraft.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _drafts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
    _draftsStreamController.add([]);
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _draftsStreamController.close();
    super.dispose();
  }
}
