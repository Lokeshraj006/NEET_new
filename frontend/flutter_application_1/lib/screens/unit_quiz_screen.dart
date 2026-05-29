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
  static const int _countdownStart = 15;
  static const int _maxGenerateSeconds = 120;
  bool _startingQuiz = false;
  bool _countdownRunning = false;
  int _secondsLeft = _countdownStart;
  Timer? _countdownTimer;
  Completer<void>? _countdownCompleter;
  int _flowToken = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownCompleter = Completer<void>();
    setState(() {
      _countdownRunning = true;
      _secondsLeft = _countdownStart;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        if (_countdownCompleter != null && !_countdownCompleter!.isCompleted) {
          _countdownCompleter!.complete();
        }
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _countdownRunning = false;
        });
        if (_countdownCompleter != null && !_countdownCompleter!.isCompleted) {
          _countdownCompleter!.complete();
        }
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
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
                    const SizedBox(height: 14),
                    InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quiz Rules', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 12),
                          _buildRuleItem('📚', 'Practice unit-wise quizzes focused on this chapter'),
                          _buildRuleItem('🔁', 'Each unit allows up to 5 attempts'),
                          _buildRuleItem('📝', 'Each attempt has 10 questions, 10 minutes, and 1 mark per question'),
                          _buildRuleItem('✅', 'Answer all questions and tap Submit before time ends'),
                          _buildRuleItem('📊', 'After submit, your result with explanations will appear'),
                          _buildRuleItem('🎯', 'Questions will not repeat across any attempt for this unit'),
                          _buildRuleItem('🤖', 'Each attempt generates 10 fresh MCQs for this topic (4 options each)'),
                          _buildRuleItem('⏱️', 'Tap START QUIZ — a 15-second countdown runs, then your quiz opens when questions are ready'),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 8),
                      child: CustomButton(
                        label: _buttonLabel(),
                        loading: _startingQuiz && !_countdownRunning,
                        onPressed: _startingQuiz ? () {} : _onStartPressed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }

  String _buttonLabel() {
    if (!_startingQuiz) return 'START QUIZ';
    if (_countdownRunning && _secondsLeft > 0) {
      return 'STARTING IN $_secondsLeft';
    }
    return 'GENERATING 10 QUESTIONS...';
  }

  Future<void> _waitForCountdown() async {
    final completer = _countdownCompleter;
    if (completer == null) return;
    await completer.future;
  }

  void _onStartPressed() {
    if (_startingQuiz || _countdownRunning) return;
    final token = ++_flowToken;
    _countdownTimer?.cancel();
    setState(() {
      _startingQuiz = true;
      _countdownRunning = true;
      _secondsLeft = _countdownStart;
    });
    _startCountdown();
    _startQuizRequest(token);
  }

  void _startQuizRequest(int token) async {
    Object? error;
    MockTestBundle? bundle;
    try {
      bundle = await MockTestService().generateUnitQuiz(
        subject: widget.subject,
        topic: widget.unitTitle,
        timeout: const Duration(seconds: _maxGenerateSeconds),
      );
    } catch (e) {
      error = e;
    }

    await _waitForCountdown();
    if (!mounted || token != _flowToken) return;

    _countdownTimer?.cancel();
    if (error != null) {
      setState(() {
        _startingQuiz = false;
        _countdownRunning = false;
        _secondsLeft = _countdownStart;
        _countdownCompleter = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyStartError(error!))),
      );
      return;
    }

    setState(() {
      _startingQuiz = false;
      _countdownRunning = false;
      _secondsLeft = _countdownStart;
      _countdownCompleter = null;
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizInProgress(
          durationMinutes: _fixedMinutes,
          title: widget.unitTitle,
          sessionId: bundle!.sessionId,
          questions: bundle.questions,
        ),
      ),
    );
  }
  

  String _friendlyStartError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = message.toLowerCase();

    if (normalized.contains('maximum quizzes reached for this topic') ||
        normalized.contains('maximum attempt reached') ||
        normalized.contains('maximum attempts')) {
      return 'Maximum attempts reached for this topic. Please try another unit or come back later.';
    }

    if (normalized.contains('cannot reach mock test api') ||
        normalized.contains('cannot reach mock-test server') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('socketexception') ||
        normalized.contains('clientexception')) {
      return 'Cannot reach server. Start the backend and check your network URL, then try again.';
    }

    if (normalized.contains('mistral api key')) {
      return 'Mistral API key is missing on the server. Contact support or try again later.';
    }

    if (normalized.contains('within 60 seconds') ||
        normalized.contains('using mistral') ||
        normalized.contains('unable to generate enough unique unit-quiz questions') ||
        normalized.contains('unable to generate 10 unique')) {
      return 'Mistral could not generate 10 topic questions in time. Please try again.';
    }

    if (normalized.contains('server error')) {
      return message.isNotEmpty ? message : 'Server error while starting quiz. Please try again.';
    }

    if (normalized.contains('forbidden') || normalized.contains('403')) {
      return 'Maximum attempts reached for this topic. Please try another unit or come back later.';
    }

    if (message.isEmpty) {
      return 'Unable to start quiz right now. Please try again.';
    }

    return 'Unable to start quiz right now. Please try again.';
  }
}
