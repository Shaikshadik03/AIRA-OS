import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

class DeviceStatusCard extends StatelessWidget {
  final int batteryLevel;
  final bool isCharging;
  final double storageUsedGB;
  final double storageTotalGB;
  final int volumeLevel;
  final int maxVolume;

  const DeviceStatusCard({
    super.key,
    required this.batteryLevel,
    required this.isCharging,
    required this.storageUsedGB,
    required this.storageTotalGB,
    required this.volumeLevel,
    required this.maxVolume,
  });

  @override
  Widget build(BuildContext context) {
    final storagePercent = storageTotalGB > 0 ? (storageUsedGB / storageTotalGB) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AiraColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AiraColors.electricCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phonelink_setup_rounded, color: AiraColors.electricCyan, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'System Status Dashboard',
                style: AiraTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AiraColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Battery gauge
              Expanded(
                child: _buildGauge(
                  title: 'Battery',
                  value: '$batteryLevel%',
                  subtitle: isCharging ? '⚡ Charging' : 'Discharging',
                  progress: batteryLevel / 100.0,
                  color: batteryLevel > 20 ? AiraColors.success : AiraColors.error,
                  icon: isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
                ),
              ),
              const SizedBox(width: 12),
              // Storage gauge
              Expanded(
                child: _buildGauge(
                  title: 'Storage',
                  value: '${storageUsedGB.toStringAsFixed(1)} GB',
                  subtitle: 'of ${storageTotalGB.toStringAsFixed(0)} GB',
                  progress: storagePercent,
                  color: AiraColors.purple,
                  icon: Icons.storage_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Volume bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AiraColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.volume_up_rounded, color: AiraColors.electricCyan, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Media Volume',
                  style: AiraTypography.bodySmall.copyWith(color: AiraColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '$volumeLevel / $maxVolume',
                  style: AiraTypography.caption.copyWith(color: AiraColors.electricCyan, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge({
    required String title,
    required String value,
    required String subtitle,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AiraColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AiraColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: color.withValues(alpha: 0.15),
                  color: color,
                ),
              ),
              Text(
                value,
                style: AiraTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AiraColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: AiraTypography.caption.copyWith(color: AiraColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
