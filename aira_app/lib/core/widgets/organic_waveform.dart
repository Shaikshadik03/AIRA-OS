import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

/// Gemini Live / Siri-Style Organic Fluid Audio Waveform.
class OrganicVoiceVisualizer extends StatefulWidget {
  final bool isActive;
  final double height;
  final Color? primaryColor;

  const OrganicVoiceVisualizer({
    super.key,
    required this.isActive,
    this.height = 48,
    this.primaryColor,
  });

  @override
  State<OrganicVoiceVisualizer> createState() => _OrganicVoiceVisualizerState();
}

class _OrganicVoiceVisualizerState extends State<OrganicVoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(OrganicVoiceVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.primaryColor ?? AiraColors.claudeTerracotta;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(14, (index) {
              final progress = _controller.value * 2 * pi;
              final phase = (index / 14) * 2 * pi;
              final sineValue = sin(progress + phase).abs();

              final barHeight = widget.isActive
                  ? (widget.height * 0.2) + (widget.height * 0.75 * sineValue)
                  : (widget.height * 0.15);

              return Container(
                width: 3.5,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? activeColor.withValues(alpha: 0.4 + (0.6 * sineValue))
                      : activeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.5 * sineValue),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
