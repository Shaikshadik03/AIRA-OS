import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  int _selectedPersonality = 0;

  final List<_PersonalityOption> _personalities = [
    _PersonalityOption(
      icon: Icons.school_rounded,
      title: 'Mentor',
      subtitle: 'Professional & guiding',
    ),
    _PersonalityOption(
      icon: Icons.emoji_emotions_rounded,
      title: 'Casual',
      subtitle: 'Friendly & relaxed',
    ),
    _PersonalityOption(
      icon: Icons.business_center_rounded,
      title: 'Professional',
      subtitle: 'Formal & efficient',
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        title: const Text('Set Up Your Profile'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AiraColors.surfaceDark,
                        child: const Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AiraColors.textMuted,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AiraColors.electricCyan,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: AiraColors.scaffoldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Name field
              AiraTextField(
                controller: _nameController,
                hintText: 'Your display name',
                prefixIcon: Icons.person_outlined,
              ),
              const SizedBox(height: 16),
              // Timezone
              Text(
                '📍 Timezone: Asia/Kolkata (auto-detected)',
                style: AiraTypography.bodySmall.copyWith(
                  color: AiraColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              // AI Personality
              Text('Choose AI Personality', style: AiraTypography.h5),
              const SizedBox(height: 16),
              Row(
                children: List.generate(
                  _personalities.length,
                  (index) {
                    final isSelected = _selectedPersonality == index;
                    final personality = _personalities[index];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPersonality = index),
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < _personalities.length - 1 ? 10 : 0,
                          ),
                          child: GlassmorphicContainer(
                            borderColor: isSelected
                                ? AiraColors.electricCyan
                                : AiraColors.glassBorder,
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Icon(
                                  personality.icon,
                                  size: 28,
                                  color: isSelected
                                      ? AiraColors.electricCyan
                                      : AiraColors.textMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  personality.title,
                                  style: AiraTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AiraColors.textPrimary
                                        : AiraColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  personality.subtitle,
                                  style: AiraTypography.overline.copyWith(
                                    letterSpacing: 0,
                                    color: AiraColors.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              // Complete button
              AiraButton(
                label: 'Complete Setup',
                onPressed: () => context.go('/dashboard'),
                isFullWidth: true,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/dashboard'),
                  child: Text(
                    'Skip for now',
                    style: AiraTypography.bodySmall.copyWith(
                      color: AiraColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalityOption {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PersonalityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
