import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../core/constants/app_colors.dart';

class PerformanceSection extends StatelessWidget {
  final double performance;
  final double average;

  const PerformanceSection({super.key, required this.performance, required this.average});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Performance Score',
            child: CircularPercentIndicator(
              radius: 54,
              lineWidth: 10,
              percent: performance,
              center: Text(
                '${(performance * 100).toInt()}%',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20),
              ),
              progressColor: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Average Score',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      '${(average * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Weekly progress',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _MetricCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
