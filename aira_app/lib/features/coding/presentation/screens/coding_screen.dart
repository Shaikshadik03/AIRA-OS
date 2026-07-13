import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/features/coding/presentation/providers/coding_provider.dart';

class CodingScreen extends ConsumerStatefulWidget {
  const CodingScreen({super.key});

  @override
  ConsumerState<CodingScreen> createState() => _CodingScreenState();
}

class _CodingScreenState extends ConsumerState<CodingScreen> {
  final _codeController = TextEditingController();
  String _selectedLanguage = 'python';

  final List<String> _languages = ['python', 'dart', 'javascript', 'cpp', 'html', 'css'];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(codingProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: AiraColors.electricCyan, size: 24),
            const SizedBox(width: 8),
            Text('Coding Assistant', style: AiraTypography.h4),
          ],
        ),
        actions: [
          if (state.result != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AiraColors.textSecondary),
              tooltip: 'Reset',
              onPressed: () {
                _codeController.clear();
                ref.read(codingProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Language selector & Header
            Row(
              children: [
                Text('Language:', style: AiraTypography.bodySmall),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AiraColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AiraColors.glassBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: AiraColors.cardDark,
                      value: _selectedLanguage,
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang.toUpperCase(), style: AiraTypography.caption.copyWith(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLanguage = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Work area: Editor or Result output
            Expanded(
              child: state.result == null
                  ? _buildEditor()
                  : _buildResultView(state.result!),
            ),
            const SizedBox(height: 16),
            // Operation buttons
            if (state.result == null) ...[
              Row(
                children: [
                  Expanded(
                    child: AiraButton(
                      label: 'Explain Code',
                      onPressed: () {
                        if (_codeController.text.trim().isEmpty) return;
                        ref.read(codingProvider.notifier).explainCode(
                              _codeController.text.trim(),
                              _selectedLanguage,
                            );
                      },
                      isLoading: state.isLoading,
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AiraButton(
                      label: 'Debug Code',
                      onPressed: () {
                        if (_codeController.text.trim().isEmpty) return;
                        ref.read(codingProvider.notifier).debugCode(
                              _codeController.text.trim(),
                              _selectedLanguage,
                            );
                      },
                      isLoading: state.isLoading,
                    ),
                  ),
                ],
              ),
            ] else
              AiraButton(
                label: 'Back to Editor',
                onPressed: () => ref.read(codingProvider.notifier).clear(),
                isFullWidth: true,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AiraColors.glassBorder),
      ),
      child: TextField(
        controller: _codeController,
        maxLines: null,
        minLines: 15,
        keyboardType: TextInputType.multiline,
        style: AiraTypography.bodySmall.copyWith(
          fontFamily: 'monospace',
          color: AiraColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '// Paste your code snippet here...',
          hintStyle: AiraTypography.bodySmall.copyWith(
            fontFamily: 'monospace',
            color: AiraColors.textMuted,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildResultView(String mdResult) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: Markdown(
        data: mdResult,
        styleSheet: MarkdownStyleSheet(
          p: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary, height: 1.5),
          h1: AiraTypography.h4.copyWith(color: AiraColors.textPrimary),
          h2: AiraTypography.h5.copyWith(color: AiraColors.textPrimary),
          h3: AiraTypography.h6.copyWith(color: AiraColors.textPrimary),
          code: AiraTypography.bodySmall.copyWith(
            color: AiraColors.electricCyan,
            backgroundColor: AiraColors.scaffoldDark,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: AiraColors.scaffoldDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AiraColors.glassBorder),
          ),
          codeblockPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
