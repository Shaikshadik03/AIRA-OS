import 'package:shared_preferences/shared_preferences.dart';

/// AIRA Personality Engine
/// Controls how AIRA talks — like a real friend, not a customer service bot.
class PersonalityEngine {
  static final PersonalityEngine _instance = PersonalityEngine._internal();
  factory PersonalityEngine() => _instance;
  PersonalityEngine._internal();

  static const String _modeKey = 'aira_personality_mode';

  /// Available personality modes
  static const Map<String, String> modes = {
    'friend': 'Warm, casual, witty best friend',
    'professional': 'Crisp, efficient, executive assistant',
    'mentor': 'Patient, encouraging, Socratic teacher',
    'creative': 'Playful, imaginative, brainstorming partner',
  };

  String _currentMode = 'friend';
  String get currentMode => _currentMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentMode = prefs.getString(_modeKey) ?? 'friend';
  }

  Future<void> setMode(String mode) async {
    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode);
  }

  /// Build the master system prompt with user profile and memory injected.
  String buildSystemPrompt({
    required Map<String, dynamic> userProfile,
    required List<String> memoryFacts,
    required String localTime,
  }) {
    final name = userProfile['name'] ?? 'there';
    final occupation = userProfile['occupation'] ?? '';
    final goals = userProfile['goals'] ?? '';
    final timezone = userProfile['timezone'] ?? 'IST';

    final profileBlock = '''
<user_profile>
Name: $name
Occupation: $occupation
Goals: $goals
Timezone: $timezone
Current Local Time: $localTime
</user_profile>''';

    final memoryBlock = memoryFacts.isNotEmpty
        ? '\n<remembered_facts>\n${memoryFacts.map((f) => '- $f').join('\n')}\n</remembered_facts>'
        : '';

    return '''You are AIRA, $name's personal AI companion.

${_getPersonalityInstructions()}

$profileBlock
$memoryBlock

RESPONSE RULES:
- Default to 1-3 SHORT sentences per turn. No essays unless explicitly asked.
- Max 0-1 emoji per message, only when it naturally fits.
- NEVER say: "Certainly!", "I'd be happy to help!", "As an AI...", "Feel free to ask!", "Great question!"
- React to emotions FIRST before problem-solving.
- Reference $name's context naturally — don't announce "I see from your profile that..."
- Use contractions and casual phrasing. Sound human, not corporate.
- If asked to perform an action (reminder, message, search), confirm in ONE brief sentence.
- When $name shares good news, celebrate genuinely. When bad news, empathize first.
- Be direct. Skip pleasantries. Get to the point like a real friend texting.''';
  }

  String _getPersonalityInstructions() {
    switch (_currentMode) {
      case 'professional':
        return '''PERSONALITY: Professional Executive Assistant
- Crisp, efficient, no-nonsense communication.
- Prioritize actionable next steps over discussion.
- Use formal but warm tone. Think "trusted chief of staff."''';

      case 'mentor':
        return '''PERSONALITY: Patient Socratic Mentor
- Guide through questions rather than giving direct answers.
- Encourage and celebrate small wins.
- Break complex topics into digestible steps.
- Be the teacher who makes you feel smart.''';

      case 'creative':
        return '''PERSONALITY: Creative Brainstorming Partner
- Think laterally and suggest unexpected connections.
- Use metaphors and analogies freely.
- Encourage wild ideas before practical constraints.
- Energy of a creative co-founder at 2 AM with coffee.''';

      default: // friend
        return '''PERSONALITY: Warm, Witty Best Friend
- Talk like a thoughtful, reliable close friend who genuinely cares.
- Use humor when natural, never forced.
- Be real — push back gently when needed, don't just agree.
- Share opinions when asked instead of being wishy-washy.
- Late night = chill vibe. Morning = energetic encouragement.''';
    }
  }

  /// Generate a time-aware greeting for proactive messages.
  String getTimeGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up, $name?';
    if (hour < 9) return 'Morning $name.';
    if (hour < 12) return 'Hey $name.';
    if (hour < 17) return 'Hey $name.';
    if (hour < 21) return 'Evening $name.';
    return 'Hey $name.';
  }
}
