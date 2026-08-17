/// AI intent detector for laptop control commands.
/// Parses natural language chat messages and translates them into laptop control actions.
class LaptopIntentDetector {
  /// Returns true if the message seems laptop-related.
  static bool isLaptopCommand(String message) {
    final lower = message.toLowerCase();
    final laptopKeywords = [
      'laptop', 'pc', 'computer', 'desktop', 'windows',
      'open chrome', 'open vs code', 'open spotify',
      'take a screenshot', 'screenshot of my laptop',
      'lock my laptop', 'lock the laptop',
      'mute my laptop', 'volume up', 'volume down',
      'shut down', 'restart my laptop', 'sleep my laptop',
      'type on my laptop', 'click on my laptop',
      'run on my laptop', 'terminal command',
      'close chrome', 'close spotify',
      'files on my laptop', 'open file',
      'clipboard', 'copy to laptop',
    ];
    return laptopKeywords.any((kw) => lower.contains(kw));
  }

  /// Parse the message and return a LaptopCommand.
  static LaptopCommand? parse(String message) {
    final lower = message.toLowerCase().trim();

    // Screenshot
    if (lower.contains('screenshot') || lower.contains('screen of my laptop') || lower.contains('what\'s on my laptop')) {
      return LaptopCommand(type: LaptopCommandType.screenshot);
    }

    // Lock
    if (lower.contains('lock my laptop') || lower.contains('lock the laptop') || lower.contains('lock screen')) {
      return LaptopCommand(type: LaptopCommandType.lock);
    }

    // Sleep
    if (lower.contains('sleep') && (lower.contains('laptop') || lower.contains('pc'))) {
      return LaptopCommand(type: LaptopCommandType.sleep);
    }

    // Shutdown
    if ((lower.contains('shut down') || lower.contains('shutdown') || lower.contains('turn off')) &&
        (lower.contains('laptop') || lower.contains('pc') || lower.contains('computer'))) {
      return LaptopCommand(type: LaptopCommandType.shutdown);
    }

    // Restart
    if (lower.contains('restart') && (lower.contains('laptop') || lower.contains('pc'))) {
      return LaptopCommand(type: LaptopCommandType.restart);
    }

    // Mute
    if (lower.contains('mute') && (lower.contains('laptop') || lower.contains('pc') || lower.contains('volume'))) {
      return LaptopCommand(type: LaptopCommandType.mute);
    }

    // Volume up
    if (lower.contains('volume up') || (lower.contains('increase') && lower.contains('volume'))) {
      return LaptopCommand(type: LaptopCommandType.volumeUp);
    }

    // Volume down
    if (lower.contains('volume down') || (lower.contains('decrease') && lower.contains('volume'))) {
      return LaptopCommand(type: LaptopCommandType.volumeDown);
    }

    // Open app
    final openMatch = RegExp(r'open\s+([a-zA-Z\s]+?)(?:\s+on my laptop|\s+on my pc|\s+on my computer|$)').firstMatch(lower);
    if (openMatch != null) {
      final appName = openMatch.group(1)?.trim() ?? '';
      if (appName.isNotEmpty && !appName.contains('laptop') && !appName.contains('file')) {
        return LaptopCommand(type: LaptopCommandType.openApp, argument: appName);
      }
    }

    // Close app
    final closeMatch = RegExp(r'close\s+([a-zA-Z\s]+?)(?:\s+on my laptop|$)').firstMatch(lower);
    if (closeMatch != null) {
      final appName = closeMatch.group(1)?.trim() ?? '';
      if (appName.isNotEmpty) {
        return LaptopCommand(type: LaptopCommandType.closeApp, argument: appName);
      }
    }

    // Type text
    final typeMatch = RegExp(r'type\s+["""](.+?)["""]').firstMatch(lower);
    if (typeMatch != null) {
      return LaptopCommand(type: LaptopCommandType.type, argument: typeMatch.group(1) ?? '');
    }

    // Run terminal command
    final runMatch = RegExp(r'run\s+["`](.+?)["`]').firstMatch(lower);
    if (runMatch != null) {
      return LaptopCommand(type: LaptopCommandType.terminal, argument: runMatch.group(1) ?? '');
    }

    // System stats
    if (lower.contains('cpu') || lower.contains('ram') || lower.contains('battery') ||
        (lower.contains('stats') && lower.contains('laptop'))) {
      return LaptopCommand(type: LaptopCommandType.systemStats);
    }

    return null;
  }

  /// Generate a user-friendly response for a completed laptop command.
  static String getResponse(LaptopCommand command, Map<String, dynamic>? result) {
    switch (command.type) {
      case LaptopCommandType.screenshot:
        return result != null
            ? '📸 **Screenshot captured!** Here\'s what\'s currently on your laptop screen.'
            : '❌ Could not capture screenshot. Make sure AIRA Desktop Agent is running.';
      case LaptopCommandType.lock:
        return '🔒 **Laptop locked!** Your Windows screen is now locked.';
      case LaptopCommandType.sleep:
        return '😴 **Laptop sleeping.** Your laptop is going to sleep.';
      case LaptopCommandType.shutdown:
        return '🔴 **Shutting down...** Your laptop will turn off in 10 seconds. Type "cancel shutdown" to abort.';
      case LaptopCommandType.restart:
        return '🔄 **Restarting...** Your laptop will restart in 10 seconds.';
      case LaptopCommandType.mute:
        return '🔇 **Laptop muted!** System audio is now muted.';
      case LaptopCommandType.volumeUp:
        return '🔊 **Volume increased** on your laptop.';
      case LaptopCommandType.volumeDown:
        return '🔉 **Volume decreased** on your laptop.';
      case LaptopCommandType.openApp:
        final success = result?['success'] == true;
        return success
            ? '🚀 **Opened ${command.argument}** on your laptop!'
            : '❌ Could not open "${command.argument}". Is it installed on your laptop?';
      case LaptopCommandType.closeApp:
        return '✅ **Closed ${command.argument}** on your laptop.';
      case LaptopCommandType.type:
        return '⌨️ **Typed** "${command.argument}" on your laptop keyboard.';
      case LaptopCommandType.terminal:
        final stdout = result?['stdout'] as String? ?? '';
        final stderr = result?['stderr'] as String? ?? '';
        return '💻 **Terminal output:**\n```\n${stdout.isNotEmpty ? stdout : stderr.isNotEmpty ? stderr : "(no output)"}\n```';
      case LaptopCommandType.systemStats:
        if (result == null) return '❌ Could not fetch laptop stats.';
        return '📊 **Laptop Stats:**\n'
            '- 🖥️ CPU: ${result['cpu_percent']}%\n'
            '- 💾 RAM: ${result['ram_used_gb']}GB / ${result['ram_total_gb']}GB (${result['ram_percent']}%)\n'
            '- 💿 Disk: ${result['disk_used_gb']}GB / ${result['disk_total_gb']}GB\n'
            '- 🔋 Battery: ${result['battery_percent'] ?? "N/A"}%${result['is_charging'] == true ? " ⚡ Charging" : ""}';
    }
  }
}

enum LaptopCommandType {
  screenshot,
  lock,
  sleep,
  shutdown,
  restart,
  mute,
  volumeUp,
  volumeDown,
  openApp,
  closeApp,
  type,
  terminal,
  systemStats,
}

class LaptopCommand {
  final LaptopCommandType type;
  final String? argument;
  const LaptopCommand({required this.type, this.argument});
}
