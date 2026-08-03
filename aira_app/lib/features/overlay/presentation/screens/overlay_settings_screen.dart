import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/services/overlay_service.dart';

class OverlaySettingsScreen extends StatefulWidget {
  const OverlaySettingsScreen({super.key});

  @override
  State<OverlaySettingsScreen> createState() => _OverlaySettingsScreenState();
}

class _OverlaySettingsScreenState extends State<OverlaySettingsScreen> {
  final OverlayService _service = OverlayService();
  bool _isOverlayActive = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await _service.canDrawOverlays();
    setState(() {
      _hasPermission = granted;
    });
  }

  Future<void> _toggleOverlay(bool enable) async {
    if (enable) {
      if (!_hasPermission) {
        await _service.requestOverlayPermission();
        await Future.delayed(const Duration(seconds: 1));
        await _checkPermission();
      }
      final started = await _service.startOverlay();
      setState(() {
        _isOverlayActive = started;
      });
    } else {
      await _service.stopOverlay();
      setState(() {
        _isOverlayActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AIRA Everywhere',
          style: AiraTypography.h4.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AiraColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isOverlayActive ? AiraColors.electricCyan : AiraColors.glassBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isOverlayActive ? AiraColors.electricCyan : Colors.transparent).withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AiraColors.cyanPurpleGradient,
                    ),
                    child: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floating Assistant Bubble',
                          style: AiraTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AiraColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isOverlayActive ? 'ACTIVE OVER ALL APPS' : 'DISABLED',
                          style: AiraTypography.caption.copyWith(
                            color: _isOverlayActive ? AiraColors.electricCyan : AiraColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOverlayActive,
                    activeThumbColor: AiraColors.electricCyan,
                    onChanged: _toggleOverlay,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Permission Status',
              style: AiraTypography.overline.copyWith(color: AiraColors.textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AiraColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AiraColors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasPermission ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: _hasPermission ? AiraColors.success : AiraColors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display Over Other Apps',
                          style: AiraTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AiraColors.textPrimary,
                          ),
                        ),
                        Text(
                          _hasPermission ? 'Permission granted ✓' : 'Tap button to grant overlay permission',
                          style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (!_hasPermission)
                    TextButton(
                      onPressed: () async {
                        await _service.requestOverlayPermission();
                        await _checkPermission();
                      },
                      child: const Text('Grant'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'How to Use',
              style: AiraTypography.overline.copyWith(color: AiraColors.textMuted),
            ),
            const SizedBox(height: 12),
            _buildInfoTile('1. Enable the toggle above to start the AIRA bubble.'),
            _buildInfoTile('2. Drag the bubble anywhere on your screen over any app.'),
            _buildInfoTile('3. Tap the bubble anytime to open AIRA OS immediately.'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AiraColors.surfaceDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AiraTypography.caption.copyWith(color: AiraColors.textSecondary, height: 1.4),
      ),
    );
  }
}
