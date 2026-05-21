import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

class SubjectMastery extends StatelessWidget {
  final List subjects;
  final void Function(String subjectTitle)? onSubjectTap;

  const SubjectMastery({
    super.key,
    required this.subjects,
    this.onSubjectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: subjects.map((s) {
        final title = s['title'] as String;
        final color = switch (title) {
          'Physics' => AppColors.primary,
          'Chemistry' => AppColors.warning,
          'Biology' => AppColors.success,
          _ => AppColors.primary,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: onSubjectTap == null ? null : () => onSubjectTap!(title),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Color(0x0E000000), blurRadius: 18, offset: Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
