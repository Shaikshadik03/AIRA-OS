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
  listDriveFiles,
  searchDriveFiles,
  uploadToDrive,
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
      case WorkspaceIntent.listDriveFiles:
        return 'List recent Google Drive files';
      case WorkspaceIntent.searchDriveFiles:
        return 'Search Google Drive for ${params['query'] ?? 'files'}';
      case WorkspaceIntent.uploadToDrive:
        return 'Upload file to Google Drive: ${params['filename'] ?? 'Note'}';
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
      case WorkspaceIntent.listDriveFiles:
      case WorkspaceIntent.searchDriveFiles:
      case WorkspaceIntent.uploadToDrive:
        return 'folder';
      default:
        return 'workspace';
    }
  }
}

class WorkspaceIntentDetector {
  static WorkspaceCommand detect(String message) {
    final msg = message.toLowerCase().trim();

    // ── Email intents ──
    if (_matches(msg, ['send email', 'write email', 'compose email', 'email to', 'send a mail', 'send mail', 'mail to', 'send an email'])) {
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

    if (_matches(msg, ['check email', 'read email', 'show email', 'open email', 'my emails', 'inbox', 'summarize my', 'summarize last', 'summarize email', 'recent emails'])) {
      return WorkspaceCommand(intent: WorkspaceIntent.readEmails, params: {}, originalMessage: message);
    }

    // ── Calendar intents ──
    if (_matches(msg, ['schedule meeting', 'create event', 'add event', 'book meeting', 'schedule a call', 'set reminder', 'add an event'])) {
      final titleMatch = RegExp(r'(called|named|titled|about|for|with)?\s*(.+?)(?:\s+on\s+|\s+at\s+|\s+tomorrow|\s+today|\s*$)', caseSensitive: false).firstMatch(message);
      final dateMatch = RegExp(r'(on|for)?\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|today|\d+[st|nd|rd|th]*\s+\w+)', caseSensitive: false).firstMatch(message);
      final timeMatch = RegExp(r'at\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)', caseSensitive: false).firstMatch(message);
      return WorkspaceCommand(
        intent: WorkspaceIntent.createEvent,
        params: {
          if (titleMatch != null) 'title': titleMatch.group(2) ?? message,
          if (dateMatch != null) 'date': dateMatch.group(2) ?? '',
          if (timeMatch != null) 'time': timeMatch.group(1) ?? '',
        },
        originalMessage: message,
      );
    }

    if (_matches(msg, ['show calendar', 'my events', 'upcoming events', 'my schedule', 'what do i have today', 'meetings today', 'on my calendar', 'my calendar', 'this week'])) {
      return WorkspaceCommand(intent: WorkspaceIntent.listEvents, params: {}, originalMessage: message);
    }

    // ── Docs intents ──
    if (_matches(msg, ['create doc', 'new document', 'write a doc', 'create a document', 'make a doc', 'create a doc'])) {
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
    if (_matches(msg, ['create sheet', 'create a sheet', 'new sheet', 'create spreadsheet', 'create a spreadsheet', 'new spreadsheet', 'make a sheet'])) {
      final titleMatch = RegExp(r'(?:called|named|titled|sheet|spreadsheet)\s+(.+)', caseSensitive: false).firstMatch(message);
      String title = titleMatch?.group(1)?.trim() ?? 'New Spreadsheet';
      title = title.replaceAll(RegExp(r'^(called|named|titled)\s+', caseSensitive: false), '');
      return WorkspaceCommand(
        intent: WorkspaceIntent.createSheet,
        params: {'title': title.isNotEmpty ? title : 'New Spreadsheet'},
        originalMessage: message,
      );
    }

    if (_matches(msg, ['add row', 'append row', 'add entry', 'insert row', 'add to sheet', 'append to sheet', 'add row to', 'add a row'])) {
      final targetMatch = RegExp(r'(?:to|in)\s+(?:sheet|spreadsheet)?\s*([A-Za-z0-9_\-\s]+?)(?:[:\s]+with|[:\s]+values|:|\s+data|\s+row|$)', caseSensitive: false).firstMatch(message);
      String target = targetMatch?.group(1)?.trim() ?? 'Spreadsheet';
      
      List<String> values = [];
      final valuesMatch = RegExp(r'(?:with|values|:)\s+(.+)', caseSensitive: false).firstMatch(message);
      if (valuesMatch != null) {
        var valStr = valuesMatch.group(1) ?? '';
        valStr = valStr.replaceAll(RegExp(r'^(values|with)\s+', caseSensitive: false), '');
        values = valStr.split(RegExp(r'[,|;]|\s+and\s+')).map((s) => s.trim().replaceAll(RegExp(r'\.$'), '')).where((s) => s.isNotEmpty).toList();
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

    if (_matches(msg, ['read sheet', 'show sheet', 'open sheet', 'get sheet', 'view sheet', 'read spreadsheet', 'show spreadsheet', 'read the data from', 'read data from', 'read the sheet'])) {
      final targetMatch = RegExp(r'(?:sheet|spreadsheet|from)\s+(.+)', caseSensitive: false).firstMatch(message);
      String target = targetMatch?.group(1)?.trim() ?? '';
      target = target.replaceAll(RegExp(r'^(called|named|titled|data from|from)\s+', caseSensitive: false), '').replaceAll(RegExp(r'\.$'), '');

      return WorkspaceCommand(
        intent: WorkspaceIntent.readSheet,
        params: {'sheetTarget': target},
        originalMessage: message,
      );
    }

    // ── Google Drive Intents ──
    // 1. List recent files
    if (_matches(msg, ['list my recent files', 'recent files in drive', 'show my drive', 'list drive files', 'my drive files', 'show drive', 'list recent drive files', 'list my recent drive files'])) {
      return WorkspaceCommand(
        intent: WorkspaceIntent.listDriveFiles,
        params: {},
        originalMessage: message,
      );
    }

    // 2. Search drive / open folder
    if (_matches(msg, ['search drive for', 'search drive', 'find file in drive', 'find in drive', 'open my project folder', 'find file', 'open folder'])) {
      final queryMatch = RegExp(r'(?:for|drive|folder|file)\s+(.+)', caseSensitive: false).firstMatch(message);
      String query = queryMatch?.group(1)?.trim() ?? 'Project';
      query = query.replaceAll(RegExp(r'^(for|folder|file|in drive)\s+', caseSensitive: false), '');

      return WorkspaceCommand(
        intent: WorkspaceIntent.searchDriveFiles,
        params: {'query': query.isNotEmpty ? query : 'Project'},
        originalMessage: message,
      );
    }

    // 3. Upload to Drive
    if (_matches(msg, ['upload to drive', 'upload note to drive', 'upload a text note to drive', 'upload text note to drive', 'save to drive', 'create file in drive'])) {
      final nameMatch = RegExp(r'(?:drive|file|note)[:\s]+([A-Za-z0-9_\-\.\s]+?)(?:[:\s]+with|[:\s]+content|:|$)', caseSensitive: false).firstMatch(message);
      String filename = nameMatch?.group(1)?.trim() ?? 'Note';

      final contentMatch = RegExp(r'(?:content|with|saying|:)\s+(.+)', caseSensitive: false).firstMatch(message);
      String content = contentMatch?.group(1)?.trim() ?? message;

      return WorkspaceCommand(
        intent: WorkspaceIntent.uploadToDrive,
        params: {
          'filename': filename,
          'content': content,
        },
        originalMessage: message,
      );
    }

    return WorkspaceCommand(intent: WorkspaceIntent.none, params: {}, originalMessage: message);
  }

  static bool _matches(String msg, List<String> patterns) {
    return patterns.any((p) => msg.contains(p));
  }
}
