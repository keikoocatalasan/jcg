import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jcg_fitness/app/theme.dart';

class SectionHeader extends StatelessWidget {
  final int number;
  final String title;

  const SectionHeader({
    super.key,
    required this.number,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final numStr = number.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        '$numStr — ${title.toLowerCase()}',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.08,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
