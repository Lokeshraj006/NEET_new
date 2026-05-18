import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/home_model.dart';
import 'package:flutter_application_1/widgets/header.dart';
import 'package:flutter_application_1/widgets/motivation_card.dart';
import 'package:flutter_application_1/widgets/countdown_card.dart';
import 'package:flutter_application_1/widgets/subject_mastery.dart';
import 'package:flutter_application_1/widgets/ai_card.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
import 'package:flutter_application_1/screens/subject_units_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HomeModel>();
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: const SafeArea(child: Header()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MotivationCard(
              streak: model.streakDays,
              quote: model.quote,
            ),
            const SizedBox(height: 12),
            CountdownCard(daysLeft: model.daysLeft, progress: model.progress),
            const SizedBox(height: 12),
            const Text('Subject Mastery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SubjectMastery(
              subjects: model.subjects,
              onSubjectTap: (subject) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubjectUnitsScreen.forSubject(subject),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            AIStarterCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(selectedIndex: model.selectedIndex, onTap: model.setIndex),
    );
  }
}
