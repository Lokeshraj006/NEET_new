import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/widgets/info_card.dart';
import 'package:flutter_application_1/screens/subject_units_screen.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';

class QuizzesScreen extends StatelessWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quizzes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            child: Text(
              'Pick a subject and drill into chapter-wise practice in the same medical-learning style.',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SubjectTile(subject: 'Physics'),
          const SizedBox(height: 10),
          _SubjectTile(subject: 'Chemistry'),
          const SizedBox(height: 10),
          _SubjectTile(subject: 'Biology'),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String subject;
  const _SubjectTile({required this.subject});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
        ),
        title: Text(
          subject,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Start quiz mode',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubjectUnitsScreen.forSubject(
              subject,
              allowStartQuiz: true,
            ),
          ),
        ),
      ),
    );
  }
}
