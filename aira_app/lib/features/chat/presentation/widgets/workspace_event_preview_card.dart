import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

class WorkspaceEventPreviewCard extends StatefulWidget {
  final String title;
  final String date;
  final String startTime;
  final String endTime;
  final String timezone;
  final List<String> attendees;
  final String? description;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const WorkspaceEventPreviewCard({
    super.key,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.timezone = 'Asia/Kolkata (IST)',
    this.attendees = const [],
    this.description,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<WorkspaceEventPreviewCard> createState() => _WorkspaceEventPreviewCardState();
}

class _WorkspaceEventPreviewCardState extends State<WorkspaceEventPreviewCard> {
  bool _isConfirmed = false;
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1A16) : const Color(0xFFFFF9F5);
    final borderColor = isDark ? const Color(0xFF5A3622) : const Color(0xFFE2A888);
    final textColor = isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVIEW • GOOGLE CALENDAR EVENT',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Colors.blue.shade400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Event Details Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141310) : const Color(0xFFF3EFEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Date',
                  value: widget.date,
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                const Divider(height: 14, thickness: 0.5),
                _buildDetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: '${widget.startTime} - ${widget.endTime} (${widget.timezone})',
                  isDark: isDark,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                if (widget.attendees.isNotEmpty) ...[
                  const Divider(height: 14, thickness: 0.5),
                  _buildDetailRow(
                    icon: Icons.people_outline_rounded,
                    label: 'Attendees',
                    value: widget.attendees.join(', '),
                    isDark: isDark,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
                if (widget.description != null && widget.description!.isNotEmpty) ...[
                  const Divider(height: 14, thickness: 0.5),
                  _buildDetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: widget.description!,
                    isDark: isDark,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          if (!_isConfirmed && !_isCancelled)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _isConfirmed = true);
                      widget.onConfirm();
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Confirm & Add to Calendar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _isCancelled = true);
                    widget.onCancel();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isConfirmed
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConfirmed ? Icons.check_circle : Icons.cancel,
                    color: _isConfirmed ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConfirmed ? 'Event Confirmed & Added to Calendar' : 'Event Proposal Cancelled',
                    style: GoogleFonts.sourceSerif4(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: _isConfirmed ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AiraColors.claudeTerracotta),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.sourceSerif4(fontSize: 12.5, color: textColor),
          ),
        ),
      ],
    );
  }
}
