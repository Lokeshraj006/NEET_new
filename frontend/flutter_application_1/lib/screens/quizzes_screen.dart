import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/screens/subject_units_screen.dart';

class QuizzesScreen extends StatelessWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quizzes', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a subject', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                          _SubjectTile(subject: 'Physics'),
                          const SizedBox(height: 10),
                          _SubjectTile(subject: 'Chemistry'),
                          const SizedBox(height: 10),
                          _SubjectTile(subject: 'Biology'),
                        ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String subject;
  const _SubjectTile({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: ListTile(
        title: Text(subject, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubjectUnitsScreen.forSubject(subject, allowStartQuiz: true))),
      ),
    );
  }
}
