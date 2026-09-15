import 'package:aira_app/core/services/android_action_registry.dart';
import 'package:aira_app/core/services/android_action_service.dart';

/// Command representation for detected Android actions.
class AndroidActionCommand {
  final AndroidActionType type;
  final Map<String, dynamic> params;
  final String originalMessage;
  final String responseMessage;
  final Map<String, dynamic>? actionData;

  const AndroidActionCommand({
    required this.type,
    required this.params,
    required this.originalMessage,
    required this.responseMessage,
    this.actionData,
  });

  bool get isAction => type != AndroidActionType.safetyBoundaryHalted || actionData != null;
}

/// Bilingual NLP detector for native Android actions (English & Telugu) within supported boundaries.
class AndroidActionDetector {
  static final _actionService = AndroidActionService();

  /// Check if the query triggers an Android supported action
  static bool isAndroidAction(String message) {
    final lower = message.toLowerCase().trim();

    // Protected security keywords
    if (AndroidActionRegistry.isProtectedSecurityBoundary(lower)) {
      return true;
    }

    final triggers = [
      // Messaging
      'whatsapp', 'sms', 'message', 'draft', 'compose', 'send to', 'send email', 'email', 'mail',
      'raayi', 'rayi', 'pampu', 'draft cheyyi', 'draft cheyi',
      // Calendar
      'calendar', 'add to calendar', 'schedule meeting', 'create event',
      'calendar lo', 'meeting add cheyyi', 'event create cheyyi',
      // Navigation
      'navigate', 'directions', 'google maps', 'maps', 'traffic to',
      'navigation on cheyyi', 'directions chudu', 'dharilo', 'route chupinchu',
      'chupinchu', 'route chudu', 'route',
      // Media
      'play music', 'pause music', 'resume music', 'next song', 'previous song',
      'patalu pettu', 'patalu play', 'music aapu', 'pata marchu', 'volume penchu',
      // Guided Task Handoffs
      'swiggy', 'zomato', 'uber', 'ola', 'amazon', 'flipkart',
      'order food', 'book cab', 'order biryani', 'cab book cheyyi', 'order cheyyi',
    ];

    return triggers.any((t) => lower.contains(t));
  }

  /// Parse the message into an executable AndroidActionCommand
  static AndroidActionCommand? parse(String message) {
    final msg = message.trim();
    final lower = msg.toLowerCase();

    // ── 1. Protected Security Guardrail (Banking / Lock Screen) ──
    if (AndroidActionRegistry.isProtectedSecurityBoundary(lower)) {
      final targetApp = lower.contains('gpay') || lower.contains('google pay')
          ? 'Google Pay'
          : (lower.contains('phonepe')
              ? 'PhonePe'
              : (lower.contains('paytm') ? 'Paytm' : 'Banking App'));

      final actionData = _actionService.prepareSecurityBoundaryNotice(
        requestedAction: msg,
        targetApp: targetApp,
      );

      final isTelugu = lower.contains('cheyyi') || lower.contains('pampu') || lower.contains('lo');
      final responseMsg = isTelugu
          ? '🛡️ **భద్రతా నిబంధనలు (Security Guardrail):**\n\n'
            'మీ ఆర్థిక మరియు వ్యక్తిగత భద్రత దృష్ట్యా, AIRA నేరుగా మనీ ట్రాన్స్‌ఫర్ చేయడం లేదా UPI PIN ఎంటర్ చేయడం చేయదు.\n\n'
            'మీరు నేరుగా చెల్లించడానికి నేను **$targetApp** ని సురక్షితంగా ఓపెన్ చేయగలను.'
          : '🛡️ **Security Guardrail Active:**\n\n'
            'For your financial safety, AIRA strictly cannot execute automated money transfers, '
            'enter UPI PINs, or bypass phone lock screens.\n\n'
            'I have prepared a safe launch of **$targetApp** so you can authenticate securely.';

      return AndroidActionCommand(
        type: AndroidActionType.safetyBoundaryHalted,
        params: {'app': targetApp, 'query': msg},
        originalMessage: msg,
        responseMessage: responseMsg,
        actionData: actionData,
      );
    }

    // ── 2. Message Drafting (WhatsApp, SMS, Email) ──
    // e.g. "Draft a WhatsApp message to Rahul saying I will be 15 mins late"
    // e.g. "Rahul ki WhatsApp lo message draft cheyyi late ga vastha ani"
    final msgCommand = _detectMessageDraft(msg, lower);
    if (msgCommand != null) return msgCommand;

    // ── 3. Calendar Event Preparation ──
    // e.g. "Add team sync to calendar tomorrow at 4 PM"
    // e.g. "Repu 10 AM ki calendar lo meeting add cheyyi"
    final calCommand = _detectCalendarAction(msg, lower);
    if (calCommand != null) return calCommand;

    // ── 4. Navigation & Directions ──
    // e.g. "Navigate to Rajiv Gandhi International Airport"
    // e.g. "Airport ki navigation start cheyyi"
    final navCommand = _detectNavigation(msg, lower);
    if (navCommand != null) return navCommand;

    // ── 5. Media Controls ──
    // e.g. "Play music", "Pause", "Patalu pettu"
    final mediaCommand = _detectMediaControl(msg, lower);
    if (mediaCommand != null) return mediaCommand;

    // ── 6. Guided App Task Handoff ──
    // e.g. "Order biryani on Swiggy", "Book an Uber to Secunderabad"
    // e.g. "Swiggy lo pizza order cheyyi", "Uber lo cab book cheyyi"
    final handoffCommand = _detectTaskHandoff(msg, lower);
    if (handoffCommand != null) return handoffCommand;

    return null;
  }

  // ── Helper Detectors ───────────────────────────────────────────────────────

  static AndroidActionCommand? _detectMessageDraft(String original, String lower) {
    final isWhatsApp = lower.contains('whatsapp');
    final isSms = lower.contains('sms') || lower.contains('text message');
    final isEmail = lower.contains('email') || lower.contains('mail');
    final isDraft = lower.contains('draft') ||
        lower.contains('compose') ||
        lower.contains('message') ||
        lower.contains('raayi') ||
        lower.contains('rayi') ||
        lower.contains('pampu');

    if (!isWhatsApp && !isSms && !isEmail && !isDraft) return null;

    String app = isWhatsApp ? 'WhatsApp' : (isSms ? 'SMS' : (isEmail ? 'Email' : 'WhatsApp'));
    String recipient = 'Contact';
    String body = 'Hello from AIRA';

    // Telugu pattern: "[Name] ki [App] lo message draft cheyyi [body] ani"
    final teluguMatch = RegExp(
      r'([a-zA-Z0-9\s]+?)\s+ki\s+(?:whatsapp|sms|mail)?\s*(?:lo)?\s*(?:message)?\s*(?:draft\s+cheyyi|pampu|raayi)?\s*(?:saying|that|ani)?\s*(.+)?',
      caseSensitive: false,
    ).firstMatch(original);

    if (teluguMatch != null && (lower.contains('ki') || lower.contains('ani'))) {
      recipient = teluguMatch.group(1)?.trim() ?? 'Friend';
      final rawBody = teluguMatch.group(2);
      body = rawBody != null ? rawBody.replaceAll(RegExp(r'\s*ani$', caseSensitive: false), '').trim() : 'Hello';
      if (body.isEmpty) body = 'Hello';
    } else {
      // English pattern: "(Draft|Send|Compose) (WhatsApp|SMS|Email) to [Recipient] (saying|that) [Body]"
      final engMatch = RegExp(
        r'(?:draft|send|compose|write)\s+(?:a\s+)?(?:whatsapp\s+message|sms|email|message)?\s*(?:to\s+)?([a-zA-Z0-9\s@\.\+]+?)(?:\s+saying|\s+that|\s+with|\s*:\s*|\s+about)?\s+(.+)?',
        caseSensitive: false,
      ).firstMatch(original);

      if (engMatch != null) {
        final rawRecipient = engMatch.group(1);
        recipient = rawRecipient != null ? rawRecipient.replaceAll(RegExp(r'^(?:a|the)\s+', caseSensitive: false), '').trim() : 'Contact';
        body = engMatch.group(2)?.trim() ?? 'Hello';
      }
    }

    String? subject;
    if (isEmail && body.toLowerCase().contains('subject')) {
      final subMatch = RegExp(r'subject\s+(.+?)(?:\s+body\s+(.+)|$)', caseSensitive: false).firstMatch(body);
      if (subMatch != null) {
        subject = subMatch.group(1)?.trim();
        body = subMatch.group(2)?.trim() ?? body;
      }
    }

    final actionData = _actionService.prepareMessageDraft(
      app: app,
      recipient: recipient,
      message: body,
      phone: recipient.replaceAll(RegExp(r'[^0-9\+]'), ''),
      subject: subject,
    );

    final isTelugu = lower.contains('cheyyi') || lower.contains('ki') || lower.contains('ani');
    final responseMsg = isTelugu
        ? '✍️ **మెసేజ్ సిద్ధం చేయబడింది ($app):**\n\n'
          '• **స్వీకర్త:** $recipient\n'
          '• **విషయం:** "$body"\n\n'
          '*గమనిక: భద్రతా కారణాల దృష్ట్యా మెసేజ్ పంపే ముందు మీ నిర్ధారణ అవసరం.*'
        : '✍️ **Draft Message Prepared ($app):**\n\n'
          '• **Recipient:** $recipient\n'
          '• **Message:** "$body"\n\n'
          '*Note: For security, AIRA requires your authorization before transmission.*';

    return AndroidActionCommand(
      type: AndroidActionType.composeMessage,
      params: {'app': app, 'recipient': recipient, 'body': body, 'subject': subject},
      originalMessage: original,
      responseMessage: responseMsg,
      actionData: actionData,
    );
  }

  static AndroidActionCommand? _detectCalendarAction(String original, String lower) {
    if (!lower.contains('calendar') && !lower.contains('meeting') && !lower.contains('event')) {
      return null;
    }
    if (!lower.contains('add') && !lower.contains('create') && !lower.contains('schedule') &&
        !lower.contains('cheyyi') && !lower.contains('pettu')) {
      return null;
    }

    String title = 'Meeting with Team';
    if (lower.contains('standup')) {
      title = 'Team Standup';
    } else if (lower.contains('doctor') || lower.contains('dentist')) {
      title = 'Doctor Appointment';
    } else if (lower.contains('sync')) {
      title = 'Project Sync';
    } else {
      final titleMatch = RegExp(r'(?:meeting|event|reminder)\s+(?:with|for|\:)?\s*([a-zA-Z0-9\s]+?)(?:\s+tomorrow|\s+today|\s+at|\s+on|$)', caseSensitive: false).firstMatch(lower);
      if (titleMatch != null) {
        title = titleMatch.group(1)?.trim() ?? 'Meeting';
      }
    }

    final now = DateTime.now();
    final isTomorrow = lower.contains('tomorrow') || lower.contains('repu');
    final targetDate = isTomorrow ? now.add(const Duration(days: 1)) : now;
    final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, 10, 0);

    final actionData = _actionService.prepareCalendarAction(
      title: title,
      startTime: startTime,
      endTime: startTime.add(const Duration(hours: 1)),
      description: 'Scheduled via AIRA Assistant',
    );

    final isTelugu = lower.contains('cheyyi') || lower.contains('repu') || lower.contains('lo');
    final responseMsg = isTelugu
        ? '📅 **క్యాలెండర్ ఈవెంట్ సిద్ధం చేయబడింది:**\n\n'
          '• **ఈవెంట్:** $title\n'
          '• **సమయం:** ${actionData['startTimeFormatted']}\n\n'
          '*గమనిక: మీ క్యాలెండర్‌లో సమీక్షించి సేవ్ చేయడానికి సిద్ధంగా ఉంది.*'
        : '📅 **Calendar Event Prepared:**\n\n'
          '• **Event:** $title\n'
          '• **Time:** ${actionData['startTimeFormatted']}\n\n'
          '*Note: Event is ready to review and save in your native Calendar.*';

    return AndroidActionCommand(
      type: AndroidActionType.calendarEvent,
      params: {'title': title, 'startTime': startTime.toIso8601String()},
      originalMessage: original,
      responseMessage: responseMsg,
      actionData: actionData,
    );
  }

  static AndroidActionCommand? _detectNavigation(String original, String lower) {
    final isNav = lower.contains('navigate') ||
        lower.contains('navigation') ||
        lower.contains('directions') ||
        lower.contains('route') ||
        lower.contains('chupinchu') ||
        (lower.contains('maps') && (lower.contains('to') || lower.contains('dharilo') || lower.contains('chudu')));

    if (!isNav) return null;

    final destMatch = RegExp(
      r'(?:navigate to|directions to|route to|traffic to|directions for)\s+(.+?)(?:\s+on google maps|\s+on maps|$)',
      caseSensitive: false,
    ).firstMatch(original);

    // Telugu: "[Dest] ki navigation start cheyyi" or "[Dest] ki route chupinchu"
    final teluguDestMatch = RegExp(
      r'([a-zA-Z0-9\s]+?)\s+ki\s+(?:navigation|maps|route)?\s*(?:start\s+cheyyi|on\s+cheyyi|chudu|chupinchu)?',
      caseSensitive: false,
    ).firstMatch(original);

    String destination = destMatch?.group(1)?.trim() ??
        (teluguDestMatch != null && lower.contains('ki') ? teluguDestMatch.group(1)?.trim() ?? 'Destination' : 'Destination');

    if (destination.isEmpty) destination = 'Destination';

    final actionData = {
      'actionType': AndroidActionType.navigateMaps.name,
      'destination': destination,
      'status': 'ready_to_navigate',
    };

    final isTelugu = lower.contains('cheyyi') || lower.contains('ki') || lower.contains('chudu');
    final responseMsg = isTelugu
        ? '🗺️ **గూగుల్ మ్యాప్స్ నావిగేషన్ సిద్ధం:**\n\n'
          '• **గమ్యస్థానం:** $destination\n'
          '• **యాక్షన్:** లైవ్ టర్న్-బై-టర్న్ నావిగేషన్ ప్రారంభించబడుతుంది.'
        : '🗺️ **Google Maps Navigation Ready:**\n\n'
          '• **Destination:** $destination\n'
          '• **Action:** Launching live turn-by-turn navigation.';

    return AndroidActionCommand(
      type: AndroidActionType.navigateMaps,
      params: {'destination': destination},
      originalMessage: original,
      responseMessage: responseMsg,
      actionData: actionData,
    );
  }

  static AndroidActionCommand? _detectMediaControl(String original, String lower) {
    if (lower.contains('play music') ||
        lower.contains('patalu pettu') ||
        lower.contains('play songs') ||
        lower.contains('patalu play') ||
        lower.contains('play cheyyi')) {
      return AndroidActionCommand(
        type: AndroidActionType.controlMedia,
        params: const {'action': 'play'},
        originalMessage: original,
        responseMessage: '▶️ **Resuming media playback** on your Android device.',
        actionData: const {'actionType': 'controlMedia', 'action': 'play'},
      );
    }
    if (lower.contains('pause music') ||
        lower.contains('music aapu') ||
        lower.contains('pause playback') ||
        lower == 'pause') {
      return AndroidActionCommand(
        type: AndroidActionType.controlMedia,
        params: const {'action': 'pause'},
        originalMessage: original,
        responseMessage: '⏸️ **Paused media playback** on your Android device.',
        actionData: const {'actionType': 'controlMedia', 'action': 'pause'},
      );
    }
    if (lower.contains('next song') || lower.contains('next track') || lower.contains('next pata')) {
      return AndroidActionCommand(
        type: AndroidActionType.controlMedia,
        params: const {'action': 'next'},
        originalMessage: original,
        responseMessage: '⏭️ **Skipped to next track** on your Android device.',
        actionData: const {'actionType': 'controlMedia', 'action': 'next'},
      );
    }
    if (lower.contains('previous song') || lower.contains('previous track') || lower.contains('mundu pata')) {
      return AndroidActionCommand(
        type: AndroidActionType.controlMedia,
        params: const {'action': 'previous'},
        originalMessage: original,
        responseMessage: '⏮️ **Playing previous track** on your Android device.',
        actionData: const {'actionType': 'controlMedia', 'action': 'previous'},
      );
    }
    return null;
  }

  static AndroidActionCommand? _detectTaskHandoff(String original, String lower) {
    String? targetApp;
    String? goal;

    if (lower.contains('swiggy')) {
      targetApp = 'Swiggy';
      goal = lower.replaceAll(RegExp(r'(?:on swiggy|swiggy lo|order|in swiggy|please)'), '').trim();
      if (goal.isEmpty) goal = 'Dishes';
    } else if (lower.contains('zomato')) {
      targetApp = 'Zomato';
      goal = lower.replaceAll(RegExp(r'(?:on zomato|zomato lo|order|in zomato|please)'), '').trim();
      if (goal.isEmpty) goal = 'Food';
    } else if (lower.contains('uber')) {
      targetApp = 'Uber';
      goal = lower.replaceAll(RegExp(r'(?:on uber|uber lo|book cab|book a ride|to|cab|ride)'), '').trim();
      if (goal.isEmpty) goal = 'Destination';
    } else if (lower.contains('ola')) {
      targetApp = 'Ola';
      goal = lower.replaceAll(RegExp(r'(?:on ola|ola lo|book cab|cab|ride|to)'), '').trim();
      if (goal.isEmpty) goal = 'Destination';
    } else if (lower.contains('amazon')) {
      targetApp = 'Amazon';
      goal = lower.replaceAll(RegExp(r'(?:on amazon|amazon lo|buy|search for|in amazon)'), '').trim();
      if (goal.isEmpty) goal = 'Products';
    } else if (lower.contains('flipkart')) {
      targetApp = 'Flipkart';
      goal = lower.replaceAll(RegExp(r'(?:on flipkart|flipkart lo|buy|search for|in flipkart)'), '').trim();
      if (goal.isEmpty) goal = 'Products';
    }

    if (targetApp == null) return null;
    final goalStr = goal ?? 'Items';

    final actionData = _actionService.prepareAppTaskHandoff(
      targetApp: targetApp,
      goal: goalStr,
      searchQuery: goalStr,
    );

    final steps = (actionData['steps'] as List?)?.cast<String>() ?? [];
    final stepsFormatted = steps.map((s) => '• $s').join('\n');

    final isTelugu = lower.contains('cheyyi') || lower.contains('lo');
    final responseMsg = isTelugu
        ? '🛍️ **టాస్క్ హ్యాండ్ఆఫ్ గైడ్ ($targetApp):**\n\n'
          'నేను $targetApp యాప్‌ని "$goal" కోసం ఓపెన్ చేస్తున్నాను. మీరు సులభంగా పూర్తి చేయడానికి సూచనలు:\n\n'
          '$stepsFormatted\n\n'
          '*గమనిక: మీ భద్రత కొరకు పేమెంట్ మరియు అడ్రస్ సెలెక్షన్ మీరు నేరుగా చేయాలి.*'
        : '🛍️ **Guided Task Handoff ($targetApp):**\n\n'
          'I am launching $targetApp with "$goal" pre-filtered. Here is how to complete your task:\n\n'
          '$stepsFormatted\n\n'
          '*Note: For security, AIRA does not perform payment or checkout screens autonomously.*';

    return AndroidActionCommand(
      type: AndroidActionType.taskHandoff,
      params: {'targetApp': targetApp, 'goal': goal},
      originalMessage: original,
      responseMessage: responseMsg,
      actionData: actionData,
    );
  }
}
