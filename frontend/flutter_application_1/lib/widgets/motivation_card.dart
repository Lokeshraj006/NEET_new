import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

class MotivationCard extends StatelessWidget {
  final int streak;
  final String quote;

  const MotivationCard({super.key, required this.streak, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$streak DAY STREAK',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Keep your streak alive',
            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            quote,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1.3),
          ),
        ],
      ),
    );
  }
}
