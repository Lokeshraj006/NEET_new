import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/widgets/custom_button.dart';
import 'package:flutter_application_1/core/widgets/info_card.dart';
import 'package:flutter_application_1/screens/quiz_in_progress.dart';
import 'package:flutter_application_1/services/mock_test_service.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';

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
  
  bool _isLoading = false;
  int _countdown = 15;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isLoading = true;
      _countdown = 15;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildRuleItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.unitTitle,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiz for ${widget.unitTitle}',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Focused NEET practice for ${widget.subject}.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_attempt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Attempt $_attempt of ${_attemptsAllowed ?? 5}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoCard(
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duration',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_fixedMinutes minutes',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 14),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quiz Rules', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    _buildRuleItem('📚', 'Subject-wise practice for ${widget.subject}'),
                    _buildRuleItem('🤖', 'AI is generating unique questions for this topic'),
                    _buildRuleItem('🔄', 'Questions are fresh and will not be repeated'),
                    _buildRuleItem('🎯', 'Maximum 5 attempts allowed per topic'),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Text(
                      _countdown > 0 
                        ? 'The quiz will generate in $_countdown seconds...'
                        : 'Almost there, finalizing your quiz...',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const Spacer(),
              CustomButton(
                label: 'START QUIZ',
                onPressed: _startQuiz,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }

  void _startQuiz() async {
    _startCountdown();
    try {
      final svc = MockTestService();
      final bundle = await svc.generateUnitQuiz(subject: widget.subject, topic: widget.unitTitle);
      if (!mounted) return;
      _stopCountdown();
      setState(() {
        _attempt = bundle.attempt;
        _attemptsAllowed = bundle.attemptsAllowed;
      });
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizInProgress(durationMinutes: _fixedMinutes, title: '${widget.unitTitle} • Attempt ${bundle.attempt}/${bundle.attemptsAllowed}', sessionId: bundle.sessionId, questions: bundle.questions)));
    } catch (e) {
      if (!mounted) return;
      _stopCountdown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start quiz: $e')));
    }
  }
}
