// Workspace intent detection for AIRA chat.

enum WorkspaceIntent {
  none,
  sendEmail,
  readEmails,
  createEvent,
  listEvents,
  createDoc,
  readDoc,
  createSheet,
  appendSheetRow,
  readSheet,
  openSheet,
  unknown,
}

class WorkspaceCommand {
  final WorkspaceIntent intent;
  final Map<String, dynamic> params;
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
      case WorkspaceIntent.createSheet:
        return 'Create Google Sheet: ${params['title'] ?? 'New Spreadsheet'}';
      case WorkspaceIntent.appendSheetRow:
        return 'Add row to Google Sheet: ${params['sheetTarget'] ?? 'Sheet'}';
      case WorkspaceIntent.readSheet:
      case WorkspaceIntent.openSheet:
        return 'Read Google Sheet: ${params['sheetTarget'] ?? 'Sheet'}';
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
      case WorkspaceIntent.createSheet:
      case WorkspaceIntent.appendSheetRow:
      case WorkspaceIntent.readSheet:
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
    if (_matches(msg, ['send email', 'write email', 'compose email', 'email to', 'send a mail', 'send mail', 'mail to'])) {
      final explicitEmailMatch = RegExp(r'([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})').firstMatch(message);
      final toMatch = RegExp(r'(?:to|mail to)\s+([A-Za-z0-9._%+\-@]+)', caseSensitive: false).firstMatch(message);

      String recipient = '';
      if (explicitEmailMatch != null) {
        recipient = explicitEmailMatch.group(1)!;
      } else if (toMatch != null) {
        recipient = toMatch.group(1)!;
      }

      final subjectMatch = RegExp(r'(?:subject|about|regarding|asking)[:\s]+(.+?)(?:\s+saying|\s+with|\s*$)', caseSensitive: false).firstMatch(message);
      final bodyMatch = RegExp(r'(?:saying|body|message)[:\s]+(.+)', caseSensitive: false).firstMatch(message);

      return WorkspaceCommand(
        intent: WorkspaceIntent.sendEmail,
        params: {
          'to': recipient,
          if (subjectMatch != null) 'subject': subjectMatch.group(1)?.trim() ?? '',
          if (bodyMatch != null) 'body': bodyMatch.group(1)?.trim() ?? '',
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
    // 1. Create Sheet
    if (_matches(msg, ['create sheet', 'create a sheet', 'new sheet', 'create spreadsheet', 'new spreadsheet', 'make a sheet'])) {
      final titleMatch = RegExp(r'(?:called|named|titled|sheet|spreadsheet)\s+(.+)', caseSensitive: false).firstMatch(message);
      String title = titleMatch?.group(1)?.trim() ?? 'New Spreadsheet';
      title = title.replaceAll(RegExp(r'^(called|named|titled)\s+', caseSensitive: false), '');
      return WorkspaceCommand(
        intent: WorkspaceIntent.createSheet,
        params: {'title': title.isNotEmpty ? title : 'New Spreadsheet'},
        originalMessage: message,
      );
    }

    // 2. Append/Add row to Sheet
    if (_matches(msg, ['add row', 'append row', 'add entry', 'insert row', 'add to sheet', 'append to sheet', 'add row to'])) {
      final targetMatch = RegExp(r'(?:to|in)\s+(?:sheet|spreadsheet)?\s*([A-Za-z0-9_\-\s]+?)(?:[:\s]+with|[:\s]+values|:|\s+data|\s+row|$)', caseSensitive: false).firstMatch(message);
      String target = targetMatch?.group(1)?.trim() ?? 'Spreadsheet';
      
      // Extract values after colon or "with"
      List<String> values = [];
      final valuesMatch = RegExp(r'(?:with|values|:)\s+(.+)', caseSensitive: false).firstMatch(message);
      if (valuesMatch != null) {
        final valStr = valuesMatch.group(1) ?? '';
        values = valStr.split(RegExp(r'[,|;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }

      return WorkspaceCommand(
        intent: WorkspaceIntent.appendSheetRow,
        params: {
          'sheetTarget': target,
          'values': values,
        },
        originalMessage: message,
      );
    }

    // 3. Read/Show Sheet
    if (_matches(msg, ['read sheet', 'show sheet', 'open sheet', 'get sheet', 'view sheet', 'read spreadsheet', 'show spreadsheet'])) {
      final targetMatch = RegExp(r'(?:sheet|spreadsheet)\s+(.+)', caseSensitive: false).firstMatch(message);
      String target = targetMatch?.group(1)?.trim() ?? '';
      target = target.replaceAll(RegExp(r'^(called|named|titled)\s+', caseSensitive: false), '');

      return WorkspaceCommand(
        intent: WorkspaceIntent.readSheet,
        params: {'sheetTarget': target},
        originalMessage: message,
      );
    }

    return WorkspaceCommand(intent: WorkspaceIntent.none, params: {}, originalMessage: message);
  }

  static bool _matches(String msg, List<String> patterns) {
    return patterns.any((p) => msg.contains(p));
  }
}
