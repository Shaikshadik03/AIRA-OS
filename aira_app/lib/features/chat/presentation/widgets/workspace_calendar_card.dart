import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

enum CalendarCardType {
  agenda,
  nextMeeting,
  freeTime,
}

class WorkspaceCalendarCard extends StatelessWidget {
  final CalendarCardType type;
  final String title;
  final List<Map<String, dynamic>> events;
  final List<String> freeSlots;
  final VoidCallback? onPrepTap;

  const WorkspaceCalendarCard({
    super.key,
    required this.type,
    required this.title,
    this.events = const [],
    this.freeSlots = const [],
    this.onPrepTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1B1A17) : const Color(0xFFF9F7F3);
    final borderColor = isDark ? const Color(0xFF33312B) : const Color(0xFFE2DDD5);
    final textColor = isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == CalendarCardType.freeTime ? Icons.schedule_rounded : Icons.calendar_today_rounded,
                  color: AiraColors.claudeTerracotta,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'GOOGLE CALENDAR',
                  style: GoogleFonts.firaCode(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content according to type
          if (type == CalendarCardType.agenda) ...[
            if (events.isEmpty)
              Text(
                'No events scheduled for today. Enjoy your day!',
                style: GoogleFonts.sourceSerif4(color: mutedColor, fontSize: 13),
              )
            else
              ...events.map((e) => _buildAgendaItem(e, isDark, textColor, mutedColor)),
          ] else if (type == CalendarCardType.nextMeeting) ...[
            if (events.isEmpty)
              Text(
                'No upcoming meetings for the rest of today.',
                style: GoogleFonts.sourceSerif4(color: mutedColor, fontSize: 13),
              )
            else
              _buildNextMeetingHighlight(events.first, isDark, textColor, mutedColor),
          ] else if (type == CalendarCardType.freeTime) ...[
            if (freeSlots.isEmpty)
              Text(
                'Your schedule is packed today without 30+ min open slots.',
                style: GoogleFonts.sourceSerif4(color: mutedColor, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: freeSlots.map((slot) => _buildFreeSlotPill(slot, isDark)).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgendaItem(
    Map<String, dynamic> ev,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    final title = ev['title'] ?? 'Meeting';
    final start = _formatTimeStr(ev['start']);
    final end = _formatTimeStr(ev['end']);
    final location = ev['location'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131210) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: AiraColors.claudeTerracotta,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$start - $end',
                      style: GoogleFonts.firaCode(fontSize: 11, color: AiraColors.claudeTerracotta),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: mutedColor, fontSize: 11)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.sourceSerif4(fontSize: 11.5, color: mutedColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMeetingHighlight(
    Map<String, dynamic> ev,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    final title = ev['title'] ?? 'Next Meeting';
    final start = _formatTimeStr(ev['start']);
    final end = _formatTimeStr(ev['end']);
    final location = ev['location'] as String? ?? '';
    final desc = ev['description'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141310) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AiraColors.claudeTerracotta.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  start,
                  style: GoogleFonts.firaCode(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AiraColors.claudeTerracotta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Time: $start - $end',
            style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: Colors.blue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.sourceSerif4(fontSize: 12, color: Colors.blue.shade300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              desc,
              style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (onPrepTap != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPrepTap,
                icon: const Icon(Icons.psychology_outlined, size: 14),
                label: const Text('Prepare for this meeting'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AiraColors.claudeTerracotta,
                  side: BorderSide(color: AiraColors.claudeTerracotta.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFreeSlotPill(String slot, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 13, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            slot,
            style: GoogleFonts.firaCode(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade400,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimeStr(dynamic dtVal) {
    if (dtVal == null) return '';
    final dt = DateTime.tryParse(dtVal.toString());
    if (dt == null) return dtVal.toString();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
