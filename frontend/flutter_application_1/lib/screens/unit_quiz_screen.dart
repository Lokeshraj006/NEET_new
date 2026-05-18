import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/screens/quiz_in_progress.dart';
import 'package:flutter_application_1/services/mock_test_service.dart';

class UnitQuizScreen extends StatefulWidget {
  final String subject;
  final String unitTitle;
  const UnitQuizScreen({super.key, required this.subject, required this.unitTitle});

  @override
  State<UnitQuizScreen> createState() => _UnitQuizScreenState();
}

class _UnitQuizScreenState extends State<UnitQuizScreen> {
  static const int _fixedMinutes = 10;
  int? _attempt;
  int? _attemptsAllowed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.unitTitle, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quiz for ${widget.unitTitle}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (_attempt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Attempt $_attempt of ${_attemptsAllowed ?? 5}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Duration', style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 4),
              Text('$_fixedMinutes minutes', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startQuiz,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text('START QUIZ', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  void _startQuiz() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final svc = MockTestService();
      final bundle = await svc.generateUnitQuiz(subject: widget.subject, topic: widget.unitTitle);
      if (!mounted) return;
      Navigator.of(context).pop(); // remove loader
      setState(() {
        _attempt = bundle.attempt;
        _attemptsAllowed = bundle.attemptsAllowed;
      });
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizInProgress(durationMinutes: _fixedMinutes, title: '${widget.unitTitle} • Attempt ${bundle.attempt}/${bundle.attemptsAllowed}', sessionId: bundle.sessionId, questions: bundle.questions)));
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start quiz: $e')));
    }
  }
}
