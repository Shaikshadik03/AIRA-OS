class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String timezone;
  final String preferredLanguage;
  final String aiPersonality;
  final bool onboardingComplete;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.timezone = 'Asia/Kolkata',
    this.preferredLanguage = 'en',
    this.aiPersonality = 'mentor',
    this.onboardingComplete = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      aiPersonality: json['ai_personality'] as String? ?? 'mentor',
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'timezone': timezone,
      'preferred_language': preferredLanguage,
      'ai_personality': aiPersonality,
      'onboarding_complete': onboardingComplete,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? avatarUrl,
    String? timezone,
    String? preferredLanguage,
    String? aiPersonality,
    bool? onboardingComplete,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timezone: timezone ?? this.timezone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      aiPersonality: aiPersonality ?? this.aiPersonality,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
    );
  }
}
