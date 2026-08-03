enum RoutineType {
  goodMorning,
  focusMode,
  headingHome,
  sleepMode,
  unknown,
}

class RoutineCommand {
  final RoutineType type;
  final String name;
  final bool isRoutineCommand;

  const RoutineCommand({
    required this.type,
    required this.name,
    required this.isRoutineCommand,
  });

  factory RoutineCommand.none() => const RoutineCommand(
        type: RoutineType.unknown,
        name: '',
        isRoutineCommand: false,
      );
}

class RoutineIntentDetector {
  static RoutineCommand detect(String input) {
    final lower = input.toLowerCase().trim();

    if (lower.contains('good morning') || lower.contains('morning routine') || lower.contains('start my day')) {
      return const RoutineCommand(
        type: RoutineType.goodMorning,
        name: 'Good Morning AIRA 🌅',
        isRoutineCommand: true,
      );
    }

    if (lower.contains('focus mode') || lower.contains('do not disturb') || lower.contains('start focus')) {
      return const RoutineCommand(
        type: RoutineType.focusMode,
        name: 'Focus Mode 🎯',
        isRoutineCommand: true,
      );
    }

    if (lower.contains('heading home') || lower.contains('going home') || lower.contains('on my way home')) {
      return const RoutineCommand(
        type: RoutineType.headingHome,
        name: 'Heading Home 🚗',
        isRoutineCommand: true,
      );
    }

    if (lower.contains('sleep mode') || lower.contains('goodnight') || lower.contains('good night') || lower.contains('going to bed')) {
      return const RoutineCommand(
        type: RoutineType.sleepMode,
        name: 'Sleep Mode 🌙',
        isRoutineCommand: true,
      );
    }

    return RoutineCommand.none();
  }
}
