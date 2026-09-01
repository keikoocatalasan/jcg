import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jcg_fitness/app/theme.dart';

enum StatusTagStyle { filled, outlined, subtle }

class StatusTag extends StatelessWidget {
  final String label;
  final StatusTagStyle style;

  const StatusTag({
    super.key,
    required this.label,
    this.style = StatusTagStyle.outlined,
  });

  const StatusTag.over({super.key, required this.label})
      : style = StatusTagStyle.filled;

  const StatusTag.ok({super.key, required this.label})
      : style = StatusTagStyle.outlined;

  const StatusTag.neutral({super.key, required this.label})
      : style = StatusTagStyle.subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border.all(
          color: _borderColor,
          width: style == StatusTagStyle.filled ? 0 : 1,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '[${label.toUpperCase()}]',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight:
              style == StatusTagStyle.filled ? FontWeight.w700 : FontWeight.w500,
          color: _textColor,
          letterSpacing: 0.04,
        ),
      ),
    );
  }

  Color get _bgColor {
    switch (style) {
      case StatusTagStyle.filled:
        return AppColors.accentPrimary;
      case StatusTagStyle.outlined:
        return Colors.transparent;
      case StatusTagStyle.subtle:
        return AppColors.accentMuted;
    }
  }

  Color get _borderColor {
    switch (style) {
      case StatusTagStyle.filled:
        return AppColors.accentPrimary;
      case StatusTagStyle.outlined:
        return AppColors.accentBorder;
      case StatusTagStyle.subtle:
        return AppColors.borderDefault;
    }
  }

  Color get _textColor {
    switch (style) {
      case StatusTagStyle.filled:
        return AppColors.textOnAccent;
      case StatusTagStyle.outlined:
        return AppColors.accentPrimary;
      case StatusTagStyle.subtle:
        return AppColors.textSecondary;
    }
  }
}
