import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/services/android_action_registry.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';

/// Interactive UI Card rendered in Chat for Stage K Android Actions.
/// Handles Message Drafting, Calendar Preparation, Navigation,
/// Guided Task Handoffs, and Protected Security Guardrails.
class AndroidActionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const AndroidActionCard({
    super.key,
    required this.data,
  });

  @override
  ConsumerState<AndroidActionCard> createState() => _AndroidActionCardState();
}

class _AndroidActionCardState extends ConsumerState<AndroidActionCard> {
  bool _isExecuting = false;
  String? _statusMessage;

  String get _actionType => widget.data['actionType'] ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final textColor = isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_actionType == AndroidActionType.composeMessage.name)
            _buildMessageDraftCard(textColor, mutedColor, borderColor, isDark)
          else if (_actionType == AndroidActionType.calendarEvent.name)
            _buildCalendarCard(textColor, mutedColor, borderColor, isDark)
          else if (_actionType == AndroidActionType.navigateMaps.name)
            _buildNavigationCard(textColor, mutedColor, borderColor, isDark)
          else if (_actionType == AndroidActionType.taskHandoff.name)
            _buildHandoffCard(textColor, mutedColor, borderColor, isDark)
          else if (_actionType == AndroidActionType.safetyBoundaryHalted.name)
            _buildSafetyBoundaryCard(textColor, mutedColor, borderColor, isDark)
          else
            _buildGenericActionCard(textColor, mutedColor, borderColor, isDark),

          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: GoogleFonts.sourceSerif4(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 1. Message Draft Card ──────────────────────────────────────────────────

  Widget _buildMessageDraftCard(Color textColor, Color mutedColor, Color borderColor, bool isDark) {
    final app = widget.data['app'] ?? 'WhatsApp';
    final recipient = widget.data['recipient'] ?? 'Contact';
    final body = widget.data['body'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AiraColors.claudeTerracotta.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mark_chat_unread_rounded, color: AiraColors.claudeTerracotta, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Draft Message ($app)',
                  style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  'To: $recipient',
                  style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AiraColors.claudeAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AiraColors.claudeAmber.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Authorization Required',
                style: GoogleFonts.firaCode(fontSize: 9, color: AiraColors.claudeAmber, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            '"$body"',
            style: GoogleFonts.sourceSerif4(fontSize: 13, fontStyle: FontStyle.italic, color: textColor),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isExecuting ? null : () => _handleLaunchMessageDraft(),
            icon: _isExecuting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 15, color: Colors.white),
            label: Text(
              'Open in $app & Review',
              style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AiraColors.claudeTerracotta,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. Calendar Event Card ─────────────────────────────────────────────────

  Widget _buildCalendarCard(Color textColor, Color mutedColor, Color borderColor, bool isDark) {
    final title = widget.data['title'] ?? 'Event';
    final timeFormatted = widget.data['startTimeFormatted'] ?? 'Today';
    final location = widget.data['location'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AiraColors.claudeAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_available_rounded, color: AiraColors.claudeAmber, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    timeFormatted,
                    style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (location != null && location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AiraColors.claudeAmber),
              const SizedBox(width: 4),
              Text(location, style: GoogleFonts.sourceSerif4(fontSize: 11, color: mutedColor)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isExecuting ? null : () => _handleLaunchCalendar(),
            icon: _isExecuting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.calendar_month_rounded, size: 15, color: Colors.white),
            label: Text(
              'Review in Native Calendar',
              style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AiraColors.claudeAmber,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Navigation Card ─────────────────────────────────────────────────────

  Widget _buildNavigationCard(Color textColor, Color mutedColor, Color borderColor, bool isDark) {
    final destination = widget.data['destination'] ?? 'Destination';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.navigation_rounded, color: Colors.blue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Maps Navigation',
                    style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    'To: $destination',
                    style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isExecuting ? null : () => _handleLaunchNavigation(),
            icon: _isExecuting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.directions_car_rounded, size: 15, color: Colors.white),
            label: Text(
              'Start Turn-by-Turn Directions',
              style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Guided Task Handoff Card ────────────────────────────────────────────

  Widget _buildHandoffCard(Color textColor, Color mutedColor, Color borderColor, bool isDark) {
    final targetApp = widget.data['targetApp'] ?? 'App';
    final goal = widget.data['goal'] ?? '';
    final steps = (widget.data['steps'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AiraColors.claudeTerracotta.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assistant_direction_rounded, color: AiraColors.claudeTerracotta, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guided Task Handoff ($targetApp)',
                    style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    'Goal: "$goal"',
                    style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Steps to complete in $targetApp:',
                style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.bold, color: AiraColors.claudeTerracotta),
              ),
              const SizedBox(height: 6),
              for (int i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ', style: GoogleFonts.firaCode(fontSize: 11, color: AiraColors.claudeTerracotta, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(steps[i], style: GoogleFonts.sourceSerif4(fontSize: 11, color: textColor)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isExecuting ? null : () => _handleLaunchHandoff(),
            icon: _isExecuting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.launch_rounded, size: 15, color: Colors.white),
            label: Text(
              'Open $targetApp & Finish Task',
              style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AiraColors.claudeTerracotta,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── 5. Protected Security Boundary Card ────────────────────────────────────

  Widget _buildSafetyBoundaryCard(Color textColor, Color mutedColor, Color borderColor, bool isDark) {
    final app = widget.data['targetApp'] ?? 'Banking App';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protected Security Boundary',
                    style: GoogleFonts.playfairDisplay(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    'Autonomous execution disabled by design',
                    style: GoogleFonts.sourceSerif4(fontSize: 11, color: Colors.amber),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'For your privacy and financial protection, AIRA cannot autonomously transfer funds, enter UPI credentials, or bypass lock screens.',
          style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isExecuting ? null : () => _handleSafeLaunch(app),
            icon: const Icon(Icons.lock_open_rounded, size: 15, color: Colors.amber),
            label: Text(
              'Open $app Safely (Authenticate Yourself)',
              style: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericActionCard(Color textColor, Color mutedColor, Color borderColor, bool isDark) {
    return Text('Android Action Ready', style: GoogleFonts.playfairDisplay(fontSize: 14, color: textColor));
  }

  // ── Action Handlers ────────────────────────────────────────────────────────

  Future<void> _handleLaunchMessageDraft() async {
    setState(() => _isExecuting = true);
    try {
      await ref.read(chatProvider.notifier).executeAndroidAction(widget.data);
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Opened ${widget.data['app'] ?? "App"} with pre-filled message draft';
      });
    } catch (e) {
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Error opening app: $e';
      });
    }
  }

  Future<void> _handleLaunchCalendar() async {
    setState(() => _isExecuting = true);
    try {
      await ref.read(chatProvider.notifier).executeAndroidAction(widget.data);
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Event opened in native Calendar';
      });
    } catch (e) {
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleLaunchNavigation() async {
    setState(() => _isExecuting = true);
    try {
      await ref.read(chatProvider.notifier).executeAndroidAction(widget.data);
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Navigation started in Google Maps';
      });
    } catch (e) {
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleLaunchHandoff() async {
    setState(() => _isExecuting = true);
    try {
      await ref.read(chatProvider.notifier).executeAndroidAction(widget.data);
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Opened ${widget.data['targetApp']} for task completion';
      });
    } catch (e) {
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleSafeLaunch(String appName) async {
    setState(() => _isExecuting = true);
    try {
      await ref.read(chatProvider.notifier).executeAndroidAction({
        'actionType': 'safeLaunch',
        'targetApp': appName,
      });
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Launched $appName safely';
      });
    } catch (e) {
      setState(() {
        _isExecuting = false;
        _statusMessage = 'Error launching $appName: $e';
      });
    }
  }
}
