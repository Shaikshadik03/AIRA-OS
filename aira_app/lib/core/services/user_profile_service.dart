import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// AIRA User Profile Service
/// Manages the persistent core identity of the user — who they are,
/// what they care about, and how AIRA should contextualize responses.
class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const String _profileKey = 'aira_user_profile_v2';

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> get profile => Map.unmodifiable(_profile);

  bool get isProfileSetUp =>
      _profile['name'] != null && (_profile['name'] as String).isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      _profile = Map<String, dynamic>.from(jsonDecode(raw));
    } else {
      _profile = _defaultProfile();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(_profile));
  }

  /// Update a single field
  Future<void> setField(String key, dynamic value) async {
    _profile[key] = value;
    await save();
  }

  /// Update multiple fields at once
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    _profile.addAll(updates);
    await save();
  }

  /// Get a specific field
  dynamic getField(String key) => _profile[key];

  /// Get display name
  String get displayName => _profile['name'] ?? 'there';

  /// Reset profile
  Future<void> clearProfile() async {
    _profile = _defaultProfile();
    await save();
  }

  /// Build a concise context string for LLM injection
  String toContextString() {
    final buf = StringBuffer();
    final name = _profile['name'] ?? '';
    final occupation = _profile['occupation'] ?? '';
    final college = _profile['college'] ?? '';
    final year = _profile['year'] ?? '';
    final goals = _profile['goals'] ?? '';
    final wakeTime = _profile['wake_time'] ?? '';
    final sleepTime = _profile['sleep_time'] ?? '';
    final contacts = _profile['close_contacts'] ?? '';
    final interests = _profile['interests'] ?? '';

    if (name.isNotEmpty) buf.writeln('Name: $name');
    if (occupation.isNotEmpty) buf.writeln('Occupation: $occupation');
    if (college.isNotEmpty) buf.writeln('College: $college ($year)');
    if (goals.isNotEmpty) buf.writeln('Goals: $goals');
    if (wakeTime.isNotEmpty) buf.writeln('Wake Time: $wakeTime');
    if (sleepTime.isNotEmpty) buf.writeln('Sleep Time: $sleepTime');
    if (contacts.isNotEmpty) buf.writeln('Close Contacts: $contacts');
    if (interests.isNotEmpty) buf.writeln('Interests: $interests');

    return buf.toString().trim();
  }

  Map<String, dynamic> _defaultProfile() {
    return {
      'name': '',
      'occupation': '',
      'college': '',
      'year': '',
      'goals': '',
      'wake_time': '7:00 AM',
      'sleep_time': '11:00 PM',
      'close_contacts': '',
      'interests': '',
      'dietary': '',
      'timezone': 'IST',
      'language': 'English',
    };
  }

  /// All profile fields with labels for UI rendering
  static const List<Map<String, String>> profileFields = [
    {'key': 'name', 'label': 'What should I call you?', 'hint': 'e.g. Arshan'},
    {'key': 'occupation', 'label': 'What do you do?', 'hint': 'e.g. CSE Student'},
    {'key': 'college', 'label': 'College / Company', 'hint': 'e.g. VIT University'},
    {'key': 'year', 'label': 'Year / Role', 'hint': 'e.g. 1st Year'},
    {'key': 'goals', 'label': 'Current goals', 'hint': 'e.g. Master DSA, Build projects'},
    {'key': 'wake_time', 'label': 'Usual wake-up time', 'hint': 'e.g. 7:00 AM'},
    {'key': 'sleep_time', 'label': 'Usual sleep time', 'hint': 'e.g. 11:00 PM'},
    {'key': 'close_contacts', 'label': 'Close contacts', 'hint': 'e.g. Mom, Rahul, Ayesha'},
    {'key': 'interests', 'label': 'Interests & hobbies', 'hint': 'e.g. AI, Flutter, Fitness'},
  ];
}
