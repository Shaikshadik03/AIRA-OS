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
      'organize downloads', 'sort downloads',
      'take a note', 'save a note', 'write a note',
      'search on my laptop', 'search on laptop',
      'brightness on laptop', 'set brightness',
      'paste on laptop', 'copy on laptop',
      'cancel shutdown', 'abort shutdown',
      'minimize', 'maximize', 'close window',
      'what\'s my laptop', 'laptop wifi', 'laptop ip',
      'set volume', 'volume to', 'increase brightness', 'decrease brightness',
      'scroll down laptop', 'scroll up laptop',
    ];
    return laptopKeywords.any((kw) => lower.contains(kw));
  }

  /// Parse the message and return a LaptopCommand.
  static LaptopCommand? parse(String message) {
    final lower = message.toLowerCase().trim();

    // Multi-step compound Agentic Task on laptop
    final isCompound = lower.contains(' and ') ||
        lower.contains(' then ') ||
        lower.contains(' also ') ||
        lower.contains(' after that ') ||
        (lower.contains('play') && lower.contains('youtube')) ||
        (lower.contains('search') && lower.contains('note')) ||
        (lower.contains('open') && lower.contains('search'));

    if (isCompound && (lower.contains('laptop') || lower.contains('pc') || lower.contains('computer') || lower.contains('desktop'))) {
      return LaptopCommand(type: LaptopCommandType.agentTask, argument: message);
    }

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

    // Organize downloads
    if (lower.contains('organize downloads') || lower.contains('sort downloads') || lower.contains('clean downloads')) {
      return LaptopCommand(type: LaptopCommandType.organizeDownloads);
    }

    // Quick note / save note on laptop
    final noteMatch = RegExp(r'(?:take a note|save a note|write a note|create a note)\s+(?:saying\s+|that\s+)?(.+)', caseSensitive: false).firstMatch(lower);
    if (noteMatch != null) {
      final noteContent = noteMatch.group(1)?.trim() ?? '';
      if (noteContent.isNotEmpty) {
        return LaptopCommand(type: LaptopCommandType.saveNote, argument: noteContent);
      }
    }

    // Search on laptop
    final searchMatch = RegExp(r'(?:search on my laptop|search on laptop|google on laptop)\s+(?:for\s+)?(.+)', caseSensitive: false).firstMatch(lower);
    if (searchMatch != null) {
      final query = searchMatch.group(1)?.trim() ?? '';
      if (query.isNotEmpty) {
        return LaptopCommand(type: LaptopCommandType.webSearch, argument: query);
      }
    }

    // Cancel shutdown
    if (lower.contains('cancel shutdown') || lower.contains('abort shutdown') || lower.contains('cancel restart')) {
      return LaptopCommand(type: LaptopCommandType.cancelShutdown);
    }

    // Set specific brightness level
    final brightSetMatch = RegExp(r'(?:set|change|brightness to|brightness)\s*(?:to\s*)?(\d+)\s*%?', caseSensitive: false).firstMatch(lower);
    if ((lower.contains('brightness') || lower.contains('bright')) && brightSetMatch != null) {
      final level = brightSetMatch.group(1) ?? '70';
      return LaptopCommand(type: LaptopCommandType.setBrightness, argument: level);
    }

    // Increase/decrease brightness
    if (lower.contains('increase brightness') || lower.contains('brightness up')) {
      return LaptopCommand(type: LaptopCommandType.setBrightness, argument: 'up');
    }
    if (lower.contains('decrease brightness') || lower.contains('brightness down')) {
      return LaptopCommand(type: LaptopCommandType.setBrightness, argument: 'down');
    }

    // Set specific volume level
    final volSetMatch = RegExp(r'(?:set|volume to|volume)\s*(?:to\s*)?(\d+)\s*%?', caseSensitive: false).firstMatch(lower);
    if ((lower.contains('volume to') || lower.contains('set volume')) && volSetMatch != null) {
      final level = volSetMatch.group(1) ?? '50';
      return LaptopCommand(type: LaptopCommandType.setVolume, argument: level);
    }

    // Paste on laptop
    if (lower.contains('paste on laptop') || lower.contains('paste on my laptop') || lower.contains('paste on pc')) {
      return LaptopCommand(type: LaptopCommandType.paste);
    }

    // Copy selected text on laptop
    if (lower.contains('copy on laptop') || lower.contains('copy on my laptop') || lower.contains('copy on pc')) {
      return LaptopCommand(type: LaptopCommandType.copy);
    }

    // Minimize / Maximize / Close window
    if (lower.contains('minimize') && (lower.contains('laptop') || lower.contains('window') || lower.contains('pc'))) {
      return LaptopCommand(type: LaptopCommandType.minimizeWindow);
    }
    if (lower.contains('maximize') && (lower.contains('laptop') || lower.contains('window') || lower.contains('pc'))) {
      return LaptopCommand(type: LaptopCommandType.maximizeWindow);
    }
    if (lower.contains('close window') || lower.contains('close this window')) {
      return LaptopCommand(type: LaptopCommandType.closeWindow);
    }

    // Scroll on laptop
    if (lower.contains('scroll down') && (lower.contains('laptop') || lower.contains('pc'))) {
      return LaptopCommand(type: LaptopCommandType.scrollDown);
    }
    if (lower.contains('scroll up') && (lower.contains('laptop') || lower.contains('pc'))) {
      return LaptopCommand(type: LaptopCommandType.scrollUp);
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
      case LaptopCommandType.organizeDownloads:
        final count = result?['moved_count'] ?? 0;
        return '📁 **Downloads Organized!** Cleaned and sorted $count files into categorized folders (PDFs, Images, Code, Docs, Media).';
      case LaptopCommandType.saveNote:
        final path = result?['path'] ?? 'Desktop';
        return '📝 **Note Saved!** Created markdown note on your laptop Desktop: `$path`';
      case LaptopCommandType.webSearch:
        return '🌐 **Opened Browser!** Searching for "${command.argument}" on your laptop.';
      case LaptopCommandType.cancelShutdown:
        return '✅ **Shutdown cancelled!** Your laptop is safe.';
      case LaptopCommandType.setBrightness:
        final a = command.argument ?? '';
        if (a == 'up') return '☀️ **Brightness increased** on your laptop.';
        if (a == 'down') return '🌑 **Brightness decreased** on your laptop.';
        return '☀️ **Brightness set to $a%** on your laptop.';
      case LaptopCommandType.setVolume:
        return '🔊 **Volume set to ${command.argument}%** on your laptop.';
      case LaptopCommandType.paste:
        return '📋 **Pasted clipboard content** on your laptop.';
      case LaptopCommandType.copy:
        return '📋 **Copied selected text** on your laptop.';
      case LaptopCommandType.minimizeWindow:
        return '⬇️ **Window minimized** on your laptop.';
      case LaptopCommandType.maximizeWindow:
        return '⬆️ **Window maximized** on your laptop.';
      case LaptopCommandType.closeWindow:
        return '❌ **Window closed** on your laptop (Alt+F4).';
      case LaptopCommandType.scrollDown:
        return '↕️ **Scrolled down** on your laptop.';
      case LaptopCommandType.scrollUp:
        return '↕️ **Scrolled up** on your laptop.';
      case LaptopCommandType.agentTask:
        final total = result?['total_steps'] ?? 0;
        final msg = result?['message'] ?? 'Executed multi-step task';
        return '🤖 **Laptop Agent Task Executed ($total steps)**\n\n$msg';
    }
  }
}

enum LaptopCommandType {
  agentTask,
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
  organizeDownloads,
  saveNote,
  webSearch,
  cancelShutdown,
  setBrightness,
  setVolume,
  paste,
  copy,
  minimizeWindow,
  maximizeWindow,
  closeWindow,
  scrollDown,
  scrollUp,
}

class LaptopCommand {
  final LaptopCommandType type;
  final String? argument;
  const LaptopCommand({required this.type, this.argument});
}
