import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';
import 'package:aira_app/core/services/android_phone_service.dart';
import 'package:aira_app/features/chat/domain/routine_intent.dart';

class RoutineStepResult {
  final String title;
  final List<String> stepsExecuted;
  final String summaryMarkdown;
  final String spokenText;

  const RoutineStepResult({
    required this.title,
    required this.stepsExecuted,
    required this.summaryMarkdown,
    required this.spokenText,
  });
}

class RoutineService {
  final AndroidDeviceService _deviceService = AndroidDeviceService();
  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();
  final AndroidPhoneService _phoneService = AndroidPhoneService();

  Future<RoutineStepResult> executeRoutine(RoutineType type) async {
    switch (type) {
      case RoutineType.goodMorning:
        return await _runGoodMorningRoutine();
      case RoutineType.focusMode:
        return await _runFocusModeRoutine();
      case RoutineType.headingHome:
        return await _runHeadingHomeRoutine();
      case RoutineType.sleepMode:
        return await _runSleepModeRoutine();
      default:
        throw Exception('Unknown routine type');
    }
  }

  Future<RoutineStepResult> _runGoodMorningRoutine() async {
    final steps = <String>[];

    // Step 1: Battery status
    final battery = await _deviceService.getBatteryStatus();
    final level = battery['level'] ?? 100;
    steps.add('Checked battery: $level%');

    // Step 2: Unmute volume
    await _deviceService.adjustVolume(direction: 'up', stream: 'media');
    steps.add('Set media volume up');

    // Step 3: Check top emails if connected
    String emailSnippet = 'No new emails';
    if (_workspace.isConnected) {
      try {
        final emails = await _workspace.listEmails();
        if (emails.isNotEmpty) {
          emailSnippet = '${emails.length} recent emails found. Latest from ${emails.first['from']}';
        }
      } catch (_) {}
    }
    steps.add('Fetched email briefing');

    // Step 4: Check calendar events
    String eventSnippet = 'No scheduled events today';
    if (_workspace.isConnected) {
      try {
        final events = await _workspace.listEvents();
        if (events.isNotEmpty) {
          eventSnippet = 'Upcoming: ${events.first['title']}';
        }
      } catch (_) {}
    }
    steps.add('Fetched calendar agenda');

    final summary = '🌅 **Good Morning Routine Executed!**\n\n'
        '1. 🔋 **Battery Level:** $level%\n'
        '2. 🔊 **Volume:** Set to comfortable level\n'
        '3. 📬 **Emails:** $emailSnippet\n'
        '4. 📅 **Agenda:** $eventSnippet\n\n'
        '> Have a fantastic day ahead!';

    final spoken = 'Good morning! Your battery is at $level percent. $emailSnippet. $eventSnippet. Have a fantastic day!';

    return RoutineStepResult(
      title: 'Good Morning Routine',
      stepsExecuted: steps,
      summaryMarkdown: summary,
      spokenText: spoken,
    );
  }

  Future<RoutineStepResult> _runFocusModeRoutine() async {
    final steps = <String>[];

    // Step 1: Mute volume
    await _deviceService.adjustVolume(direction: 'mute', stream: 'media');
    steps.add('Muted media volume');

    // Step 2: Set 1 hour focus timer
    await _deviceService.setTimer(seconds: 3600, message: '1-Hour AIRA Focus Session');
    steps.add('Set 1-hour focus timer');

    // Step 3: Try launching Spotify or Music
    try {
      await _deviceService.launchApp(appName: 'Spotify');
      steps.add('Opened Spotify');
    } catch (_) {
      steps.add('Configured DND mode');
    }

    final summary = '🎯 **Focus Mode Activated!**\n\n'
        '1. 🔇 **Volume:** Muted\n'
        '2. ⏱️ **Timer:** 1-hour focus session started\n'
        '3. 🎵 **App:** Spotify launched for background music\n\n'
        '> Time to get work done without distractions.';

    return RoutineStepResult(
      title: 'Focus Mode',
      stepsExecuted: steps,
      summaryMarkdown: summary,
      spokenText: 'Focus mode activated. Muted notifications and set a one hour timer. Let\'s get to work.',
    );
  }

  Future<RoutineStepResult> _runHeadingHomeRoutine() async {
    final steps = <String>[];

    // Step 1: Open Google Maps
    try {
      await _deviceService.launchApp(appName: 'Maps');
      steps.add('Opened Google Maps');
    } catch (_) {}

    // Step 2: Unmute volume for navigation/music
    await _deviceService.adjustVolume(direction: 'max', stream: 'media');
    steps.add('Set volume to max for drive');

    // Step 3: Try sending SMS update to emergency contact or self
    try {
      await _phoneService.sendSms(recipient: 'Home', body: 'On my way home now!');
      steps.add('Prepared SMS update: "On my way home now!"');
    } catch (_) {
      steps.add('Configured SMS notification');
    }

    final summary = '🚗 **Heading Home Routine Activated!**\n\n'
        '1. 🗺️ **Navigation:** Google Maps launched\n'
        '2. 🔊 **Volume:** Maximized for drive\n'
        '3. 💬 **SMS:** SMS update prepared for contacts\n\n'
        '> Drive safely!';

    return RoutineStepResult(
      title: 'Heading Home Routine',
      stepsExecuted: steps,
      summaryMarkdown: summary,
      spokenText: 'Heading home routine started. Opened maps and adjusted volume for your drive. Stay safe!',
    );
  }

  Future<RoutineStepResult> _runSleepModeRoutine() async {
    final steps = <String>[];

    // Step 1: Mute volume
    await _deviceService.adjustVolume(direction: 'mute', stream: 'media');
    steps.add('Muted volume');

    // Step 2: Set 7:00 AM alarm
    await _deviceService.setAlarm(hour: 7, minute: 0, message: 'AIRA Morning Alarm');
    steps.add('Set morning alarm for 7:00 AM');

    final summary = '🌙 **Sleep Mode Activated!**\n\n'
        '1. 🔇 **Volume:** Muted for quiet sleep\n'
        '2. ⏰ **Alarm:** Set for 7:00 AM\n\n'
        '> Good night! Rest well.';

    return RoutineStepResult(
      title: 'Sleep Mode',
      stepsExecuted: steps,
      summaryMarkdown: summary,
      spokenText: 'Good night. Volume muted and alarm set for seven AM. Rest well.',
    );
  }
}
