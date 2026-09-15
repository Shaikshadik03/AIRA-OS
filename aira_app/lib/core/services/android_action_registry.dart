/// Explicit Android Action & Supported Boundary Registry for AIRA OS (Stage K).
/// Defines allowlisted apps, documented intents/deep links, supported capabilities,
/// and strict security boundaries (banking, lock screen, credentials).
library;

enum AndroidActionCategory {
  communication,
  navigation,
  entertainment,
  foodCommerce,
  productivity,
  protectedSecurity,
}

enum AndroidActionType {
  composeMessage,
  calendarEvent,
  navigateMaps,
  deepLinkSearch,
  controlMedia,
  taskHandoff,
  safetyBoundaryHalted,
}

class SupportedApp {
  final String id;
  final String name;
  final String packageName;
  final AndroidActionCategory category;
  final bool canDeepLink;
  final bool requiresHandoff;
  final bool isProtectedSecurityBoundary;
  final List<String> supportedActions;
  final String? limitationNotice;

  const SupportedApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.category,
    this.canDeepLink = true,
    this.requiresHandoff = false,
    this.isProtectedSecurityBoundary = false,
    required this.supportedActions,
    this.limitationNotice,
  });
}

class AndroidActionRegistry {
  static const List<SupportedApp> allApps = [
    // ── Communication ──
    SupportedApp(
      id: 'whatsapp',
      name: 'WhatsApp',
      packageName: 'com.whatsapp',
      category: AndroidActionCategory.communication,
      supportedActions: ['draft_message', 'open_chat', 'open_app'],
      limitationNotice: 'Messages are pre-filled as drafts. User confirmation is required before transmission.',
    ),
    SupportedApp(
      id: 'messages',
      name: 'SMS / Messages',
      packageName: 'com.google.android.apps.messaging',
      category: AndroidActionCategory.communication,
      supportedActions: ['draft_sms', 'open_sms', 'open_app'],
      limitationNotice: 'Drafts SMS in the native composer with pre-filled recipient and text.',
    ),
    SupportedApp(
      id: 'gmail',
      name: 'Gmail',
      packageName: 'com.google.android.gm',
      category: AndroidActionCategory.communication,
      supportedActions: ['draft_email', 'open_inbox', 'open_app'],
      limitationNotice: 'Opens native email composer with subject and body pre-populated.',
    ),
    SupportedApp(
      id: 'telegram',
      name: 'Telegram',
      packageName: 'org.telegram.messenger',
      category: AndroidActionCategory.communication,
      supportedActions: ['open_chat', 'open_app'],
    ),

    // ── Navigation & Mobility ──
    SupportedApp(
      id: 'maps',
      name: 'Google Maps',
      packageName: 'com.google.android.apps.maps',
      category: AndroidActionCategory.navigation,
      supportedActions: ['turn_by_turn_navigation', 'search_places', 'open_app'],
    ),
    SupportedApp(
      id: 'uber',
      name: 'Uber',
      packageName: 'com.ubercab',
      category: AndroidActionCategory.navigation,
      requiresHandoff: true,
      supportedActions: ['launch_ride_request', 'open_app'],
      limitationNotice: 'AIRA launches Uber with destination pre-filled. User selects ride tier and payment.',
    ),
    SupportedApp(
      id: 'ola',
      name: 'Ola',
      packageName: 'com.olacabs.customer',
      category: AndroidActionCategory.navigation,
      requiresHandoff: true,
      supportedActions: ['launch_ride_request', 'open_app'],
      limitationNotice: 'AIRA launches Ola. User confirms pickup and ride tier.',
    ),

    // ── Entertainment & Media ──
    SupportedApp(
      id: 'spotify',
      name: 'Spotify',
      packageName: 'com.spotify.music',
      category: AndroidActionCategory.entertainment,
      supportedActions: ['search_music', 'play_pause', 'next_track', 'previous_track', 'open_app'],
    ),
    SupportedApp(
      id: 'youtube',
      name: 'YouTube',
      packageName: 'com.google.android.youtube',
      category: AndroidActionCategory.entertainment,
      supportedActions: ['search_videos', 'open_app'],
    ),
    SupportedApp(
      id: 'youtube_music',
      name: 'YouTube Music',
      packageName: 'com.google.android.apps.youtube.music',
      category: AndroidActionCategory.entertainment,
      supportedActions: ['search_music', 'play_pause', 'next_track', 'open_app'],
    ),

    // ── Food Delivery & Commerce ──
    SupportedApp(
      id: 'swiggy',
      name: 'Swiggy',
      packageName: 'in.swiggy.android',
      category: AndroidActionCategory.foodCommerce,
      requiresHandoff: true,
      supportedActions: ['search_food_dishes', 'open_app'],
      limitationNotice: 'AIRA searches the dish/restaurant on Swiggy. Cart checkout and payment must be completed by user.',
    ),
    SupportedApp(
      id: 'zomato',
      name: 'Zomato',
      packageName: 'com.application.zomato',
      category: AndroidActionCategory.foodCommerce,
      requiresHandoff: true,
      supportedActions: ['search_food_dishes', 'open_app'],
      limitationNotice: 'AIRA searches the restaurant/dish on Zomato. Cart checkout and payment must be completed by user.',
    ),
    SupportedApp(
      id: 'amazon',
      name: 'Amazon Shopping',
      packageName: 'in.amazon.mShop.android.shopping',
      category: AndroidActionCategory.foodCommerce,
      requiresHandoff: true,
      supportedActions: ['search_products', 'open_app'],
      limitationNotice: 'AIRA searches the item in Amazon. User reviews specifications, selects address, and pays.',
    ),
    SupportedApp(
      id: 'flipkart',
      name: 'Flipkart',
      packageName: 'com.flipkart.android',
      category: AndroidActionCategory.foodCommerce,
      requiresHandoff: true,
      supportedActions: ['search_products', 'open_app'],
      limitationNotice: 'AIRA searches the product on Flipkart. User confirms item and checkout.',
    ),

    // ── Productivity & System ──
    SupportedApp(
      id: 'calendar',
      name: 'Google Calendar',
      packageName: 'com.google.android.calendar',
      category: AndroidActionCategory.productivity,
      supportedActions: ['create_event', 'view_agenda', 'open_app'],
      limitationNotice: 'Events are prepared via native Android Intent. User reviews and saves.',
    ),
    SupportedApp(
      id: 'clock',
      name: 'Clock / Alarm',
      packageName: 'com.google.android.deskclock',
      category: AndroidActionCategory.productivity,
      supportedActions: ['set_alarm', 'set_timer', 'open_app'],
    ),
    SupportedApp(
      id: 'chrome',
      name: 'Google Chrome',
      packageName: 'com.android.chrome',
      category: AndroidActionCategory.productivity,
      supportedActions: ['open_url', 'web_search', 'open_app'],
    ),

    // ── Protected Security Boundaries (No Autonomous Clicks / Autonomous Payments) ──
    SupportedApp(
      id: 'gpay',
      name: 'Google Pay',
      packageName: 'com.google.android.apps.nbu.paisa.user',
      category: AndroidActionCategory.protectedSecurity,
      isProtectedSecurityBoundary: true,
      supportedActions: ['safe_launch_only'],
      limitationNotice: 'AIRA strictly cannot transfer money, approve UPI payments, or enter PINs for your protection.',
    ),
    SupportedApp(
      id: 'phonepe',
      name: 'PhonePe',
      packageName: 'com.phonepe.app',
      category: AndroidActionCategory.protectedSecurity,
      isProtectedSecurityBoundary: true,
      supportedActions: ['safe_launch_only'],
      limitationNotice: 'AIRA strictly cannot execute transactions or enter UPI credentials for your security.',
    ),
    SupportedApp(
      id: 'paytm',
      name: 'Paytm',
      packageName: 'net.one97.paytm',
      category: AndroidActionCategory.protectedSecurity,
      isProtectedSecurityBoundary: true,
      supportedActions: ['safe_launch_only'],
      limitationNotice: 'Financial transactions require direct user authorization and PIN entry.',
    ),
    SupportedApp(
      id: 'banking',
      name: 'Mobile Banking Apps',
      packageName: 'generic.banking',
      category: AndroidActionCategory.protectedSecurity,
      isProtectedSecurityBoundary: true,
      supportedActions: ['safe_launch_only'],
      limitationNotice: 'Autonomous interaction with banking and credential screens is prohibited by design.',
    ),
  ];

  /// Find matching app by name or alias
  static SupportedApp? findApp(String query) {
    final lower = query.toLowerCase().trim();
    for (final app in allApps) {
      if (app.id == lower ||
          app.name.toLowerCase() == lower ||
          lower.contains(app.id) ||
          lower.contains(app.name.toLowerCase())) {
        return app;
      }
    }
    return null;
  }

  /// Check if an action target falls into a protected security boundary
  static bool isProtectedSecurityBoundary(String query) {
    final lower = query.toLowerCase();
    final securityPhrases = [
      'gpay', 'google pay', 'phonepe', 'paytm',
      'transfer money', 'send money', 'pay money', 'banking',
      'yono', 'netbanking', 'dabbulu',
      'lock screen', 'lockscreen', 'screen lock', 'bypass lock',
      'bypass pin', 'enter pin', 'upi pin', 'atm pin', 'reset pin',
      'password', 'credentials', 'credit card', 'debit card',
      'fingerprint', 'biometric',
    ];
    if (securityPhrases.any((kw) => lower.contains(kw))) {
      return true;
    }

    final wordBoundaryPatterns = [
      RegExp(r'\bupi\b'),
      RegExp(r'\bbhim\b'),
      RegExp(r'\bpin\b'),
      RegExp(r'\bbank\b'),
      RegExp(r'\bsbi\b'),
      RegExp(r'\bhdfc\b'),
      RegExp(r'\bicici\b'),
      RegExp(r'\batm\b'),
      RegExp(r'\bunlock\b'),
    ];
    return wordBoundaryPatterns.any((regex) => regex.hasMatch(lower));
  }

  /// Returns guided step-by-step instructions for tasks requiring human finish
  static List<String> getFinishSteps(String appName, String goal) {
    final lower = appName.toLowerCase();
    if (lower.contains('swiggy') || lower.contains('zomato')) {
      return [
        'I have opened $appName with "$goal" pre-filtered.',
        'Choose your favorite restaurant from the top-rated list.',
        'Select dish customizations and tap "Add to Cart".',
        'Verify your delivery address and complete checkout.',
      ];
    }
    if (lower.contains('uber') || lower.contains('ola')) {
      return [
        'I have opened $appName for your trip to "$goal".',
        'Select your preferred ride tier (Auto, Premier, or Go).',
        'Verify pickup pin location.',
        'Tap "Confirm Booking" to match with a driver.',
      ];
    }
    if (lower.contains('amazon') || lower.contains('flipkart')) {
      return [
        'I have opened $appName searching for "$goal".',
        'Compare product ratings, reviews, and delivery dates.',
        'Select color or size options and tap "Buy Now".',
        'Select payment method and confirm order.',
      ];
    }
    return [
      'I have opened $appName for "$goal".',
      'Follow on-screen prompts to review and finalize your task.',
      'Authenticate with your credentials or biometric as required.',
    ];
  }

  /// Returns explicit safety explanation when an action touches protected boundaries
  static String getSafetyBoundaryExplanation(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('lock') || lower.contains('pin') || lower.contains('unlock') || lower.contains('password')) {
      return '🛡️ **Security Guardrail Active**\n\n'
          'Lock screens, PINs, biometrics, and device authentication are protected security boundaries. '
          'AIRA will never attempt to bypass locks or capture device credentials.\n\n'
          'Please unlock or authenticate directly on your device.';
    }
    return '🛡️ **Security Guardrail Active**\n\n'
        'Financial and banking transactions, UPI payments, and monetary transfers are protected security boundaries. '
        'For your security, AIRA will never enter credentials or authorize payments autonomously.\n\n'
        'I can open the app safely for you so you can authenticate directly.';
  }
}
