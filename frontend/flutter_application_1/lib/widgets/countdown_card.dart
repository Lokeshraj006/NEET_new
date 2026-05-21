import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

class CountdownCard extends StatelessWidget {
  final int daysLeft;
  final double progress;

  const CountdownCard({super.key, required this.daysLeft, required this.progress});

  @override
  Widget build(BuildContext context) {
    final isExamDay = daysLeft == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isExamDay ? AppColors.warning.withValues(alpha: 0.12) : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isExamDay ? Icons.emoji_events_rounded : Icons.calendar_month_rounded,
              color: isExamDay ? AppColors.warning : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEET Exam Countdown', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  isExamDay ? 'Exam day is here' : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isExamDay ? AppColors.warning : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text('NEET Exam: July 14, 2026', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF0FDF4),
                    valueColor: AlwaysStoppedAnimation(isExamDay ? AppColors.warning : AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
