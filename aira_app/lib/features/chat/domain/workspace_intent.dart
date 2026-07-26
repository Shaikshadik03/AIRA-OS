// Workspace intent detection for AIRA chat.

enum WorkspaceIntent {
  none,
  sendEmail,
  readEmails,
  createEvent,
  listEvents,
  createDoc,
  readDoc,
  openSheet,
  unknown,
}

class WorkspaceCommand {
  final WorkspaceIntent intent;
  final Map<String, String> params;
  final String originalMessage;

  const WorkspaceCommand({
    required this.intent,
    required this.params,
    required this.originalMessage,
  });

  bool get isWorkspaceCommand => intent != WorkspaceIntent.none;

  String get description {
    switch (intent) {
      case WorkspaceIntent.sendEmail:
        return 'Send email to ${params['to'] ?? 'recipient'}';
      case WorkspaceIntent.readEmails:
        return 'Read recent emails';
      case WorkspaceIntent.createEvent:
        return 'Create calendar event: ${params['title'] ?? 'New Event'}';
      case WorkspaceIntent.listEvents:
        return 'Show upcoming calendar events';
      case WorkspaceIntent.createDoc:
        return 'Create Google Doc: ${params['title'] ?? 'New Document'}';
      case WorkspaceIntent.readDoc:
        return 'Open Google Doc';
      case WorkspaceIntent.openSheet:
        return 'Open Google Sheet';
      default:
        return 'Google Workspace action';
    }
  }

  String get iconName {
    switch (intent) {
      case WorkspaceIntent.sendEmail:
      case WorkspaceIntent.readEmails:
        return 'email';
      case WorkspaceIntent.createEvent:
      case WorkspaceIntent.listEvents:
        return 'calendar';
      case WorkspaceIntent.createDoc:
      case WorkspaceIntent.readDoc:
        return 'document';
      case WorkspaceIntent.openSheet:
        return 'spreadsheet';
      default:
        return 'workspace';
    }
  }
}

class WorkspaceIntentDetector {
  static WorkspaceCommand detect(String message) {
    final msg = message.toLowerCase().trim();

    // ── Email intents ──
    if (_matches(msg, ['send email', 'write email', 'compose email', 'email to', 'send a mail', 'send mail'])) {
      final toMatch = RegExp(r'to\s+([A-Za-z0-9._%+\-@]+)', caseSensitive: false).firstMatch(message);
      final subjectMatch = RegExp(r'(subject|about|regarding)[:\s]+(.+?)(?:\s+saying|\s+with|\s*$)', caseSensitive: false).firstMatch(message);
      final bodyMatch = RegExp(r'saying\s+(.+)', caseSensitive: false).firstMatch(message);
      return WorkspaceCommand(
        intent: WorkspaceIntent.sendEmail,
        params: {
          if (toMatch != null) 'to': toMatch.group(1) ?? '',
          if (subjectMatch != null) 'subject': subjectMatch.group(2) ?? '',
          if (bodyMatch != null) 'body': bodyMatch.group(1) ?? '',
        },
        originalMessage: message,
      );
    }

    if (_matches(msg, ['check email', 'read email', 'show email', 'open email', 'my emails', 'inbox'])) {
      return WorkspaceCommand(intent: WorkspaceIntent.readEmails, params: {}, originalMessage: message);
    }

    // ── Calendar intents ──
    if (_matches(msg, ['schedule meeting', 'create event', 'add event', 'book meeting', 'schedule a call', 'set reminder'])) {
      final titleMatch = RegExp(r'(meeting|event|call|reminder)\s+(for|about|with|on)?\s*(.+?)(?:\s+on\s+|\s+at\s+|\s*$)', caseSensitive: false).firstMatch(message);
      final dateMatch = RegExp(r'(on|for)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|today|\d+[st|nd|rd|th]*\s+\w+)', caseSensitive: false).firstMatch(message);
      final timeMatch = RegExp(r'at\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)', caseSensitive: false).firstMatch(message);
      return WorkspaceCommand(
        intent: WorkspaceIntent.createEvent,
        params: {
          if (titleMatch != null) 'title': titleMatch.group(3) ?? message,
          if (dateMatch != null) 'date': dateMatch.group(2) ?? '',
          if (timeMatch != null) 'time': timeMatch.group(1) ?? '',
        },
        originalMessage: message,
      );
    }

    if (_matches(msg, ['show calendar', 'my events', 'upcoming events', 'my schedule', 'what do i have today', 'meetings today'])) {
      return WorkspaceCommand(intent: WorkspaceIntent.listEvents, params: {}, originalMessage: message);
    }

    // ── Docs intents ──
    if (_matches(msg, ['create doc', 'new document', 'write a doc', 'create a document', 'make a doc'])) {
      final titleMatch = RegExp(r'(called|named|titled|about)\s+(.+)', caseSensitive: false).firstMatch(message);
      return WorkspaceCommand(
        intent: WorkspaceIntent.createDoc,
        params: {if (titleMatch != null) 'title': titleMatch.group(2) ?? 'New Document'},
        originalMessage: message,
      );
    }

    if (_matches(msg, ['open doc', 'read doc', 'show doc', 'open document'])) {
      return WorkspaceCommand(intent: WorkspaceIntent.readDoc, params: {}, originalMessage: message);
    }

    // ── Sheets intents ──
    if (_matches(msg, ['open sheet', 'google sheet', 'spreadsheet', 'open spreadsheet'])) {
      return WorkspaceCommand(intent: WorkspaceIntent.openSheet, params: {}, originalMessage: message);
    }

    return WorkspaceCommand(intent: WorkspaceIntent.none, params: {}, originalMessage: message);
  }

  static bool _matches(String msg, List<String> patterns) {
    return patterns.any((p) => msg.contains(p));
  }
}
