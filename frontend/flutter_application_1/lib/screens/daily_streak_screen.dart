import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/widgets/custom_button.dart';
import 'package:flutter_application_1/core/widgets/info_card.dart';
import 'package:flutter_application_1/core/widgets/question_option_tile.dart';
import 'package:flutter_application_1/models/home_model.dart';
import 'package:flutter_application_1/services/streak_service.dart';

class DailyStreakScreen extends StatefulWidget {
  const DailyStreakScreen({super.key});

  @override
  State<DailyStreakScreen> createState() => _DailyStreakScreenState();
}

class _DailyStreakScreenState extends State<DailyStreakScreen> {
  final StreakService _service = StreakService();
  DailyStreakChallenge? _challenge;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _resultMessage;
  final Map<int, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    try {
      final challenge = await _service.fetchToday();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _error = null;
        _resultMessage = challenge.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    final challenge = _challenge;
    if (challenge == null || challenge.questions.isEmpty) return;
    if (_answers.length != challenge.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer all 3 questions before submitting.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.submitToday(
        answers: List<int?>.generate(challenge.questions.length, (index) => _answers[index]),
      );
      if (!mounted) return;
      setState(() {
        _challenge = result;
        _resultMessage = result.message;
      });
      context.read<HomeModel>().applyDailyChallenge(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _selectAnswer(int questionIndex, int optionIndex) {
    final challenge = _challenge;
    if (challenge == null || challenge.submitted) return;
    setState(() {
      _answers[questionIndex] = optionIndex;
    });
    if (!_submitting && _answers.length == challenge.questions.length) {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Daily Streak Arena', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6FBF6), Color(0xFFE8FFF4), Color(0xFFF7FBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -20,
                child: _GlowDot(color: AppColors.primary.withValues(alpha: 0.16), size: 130),
              ),
              Positioned(
                top: 140,
                left: -30,
                child: _GlowDot(color: const Color(0xFF0EA5E9).withValues(alpha: 0.12), size: 90),
              ),
              _buildBody(challenge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DailyStreakChallenge? challenge) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: InfoCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, size: 42, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  'Daily streak unavailable',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                CustomButton(label: 'Try again', onPressed: _loadChallenge),
              ],
            ),
          ),
        ),
      );
    }

    if (challenge == null) {
      return const Center(child: Text('No streak challenge found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadChallenge,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroBanner(challenge: challenge),
            const SizedBox(height: 16),
            _StatusStrip(
              streakDays: challenge.streakDays,
              bestStreak: challenge.bestStreak,
              score: challenge.score,
              totalQuestions: challenge.totalQuestions,
              submitted: challenge.submitted,
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < challenge.questions.length; index++) ...[
              _QuestionArenaCard(
                questionNumber: index + 1,
                question: challenge.questions[index],
                selectedIndex: _answers[index],
                locked: challenge.submitted,
                onSelect: (value) => _selectAnswer(index, value),
              ),
              const SizedBox(height: 14),
            ],
            if (_resultMessage != null) ...[
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.submitted ? 'Result' : 'Daily mission',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _resultMessage!,
                      style: GoogleFonts.poppins(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            CustomButton(
              label: challenge.submitted ? 'Back to dashboard' : (_submitting ? 'Submitting...' : 'Lock the flame'),
              loading: _submitting,
              onPressed: challenge.submitted
                  ? () => Navigator.of(context).pop()
                  : _submit,
            ),
            if (!challenge.submitted) ...[
              const SizedBox(height: 12),
              Text(
                'One chance per day. Solve all 3 to maintain and grow the streak.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final DailyStreakChallenge challenge;

  const _HeroBanner({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x2A000000), blurRadius: 24, offset: Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.submitted ? 'Daily flame secured' : 'Battle for today\'s streak',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Physics + Chemistry + Biology. One perfect run to climb the streak.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniMetric(label: 'Current', value: challenge.streakDays.toString(), suffix: 'days'),
              const SizedBox(width: 10),
              _MiniMetric(label: 'Best', value: challenge.bestStreak.toString(), suffix: 'days'),
              const SizedBox(width: 10),
              _MiniMetric(label: 'Questions', value: challenge.totalQuestions.toString(), suffix: 'today'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final int streakDays;
  final int bestStreak;
  final int score;
  final int totalQuestions;
  final bool submitted;

  const _StatusStrip({
    required this.streakDays,
    required this.bestStreak,
    required this.score,
    required this.totalQuestions,
    required this.submitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoundedPill(
            label: 'Streak',
            value: streakDays.toString(),
            icon: Icons.local_fire_department_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoundedPill(
            label: 'Best',
            value: bestStreak.toString(),
            icon: Icons.emoji_events_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoundedPill(
            label: submitted ? 'Result' : 'Live',
            value: submitted ? '$score/$totalQuestions' : '$score/$totalQuestions',
            icon: submitted ? Icons.verified_rounded : Icons.sports_esports_rounded,
          ),
        ),
      ],
    );
  }
}

class _QuestionArenaCard extends StatelessWidget {
  final int questionNumber;
  final DailyStreakQuestion question;
  final int? selectedIndex;
  final bool locked;
  final ValueChanged<int> onSelect;

  const _QuestionArenaCard({
    required this.questionNumber,
    required this.question,
    required this.selectedIndex,
    required this.locked,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final revealed = locked && question.answerIndex != null;
    return InfoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${question.subject} quest $questionNumber',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (locked && question.isCorrect != null)
                Icon(
                  question.isCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: question.isCorrect == true ? Colors.green : Colors.redAccent,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question.question,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.unit,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          IgnorePointer(
            ignoring: locked,
            child: Column(
              children: [
                for (var optionIndex = 0; optionIndex < question.options.length; optionIndex++) ...[
                  QuestionOptionTile(
                    label: String.fromCharCode(65 + optionIndex),
                    text: question.options[optionIndex],
                    selected: selectedIndex == optionIndex,
                    onTap: () => onSelect(optionIndex),
                  ),
                  if (optionIndex != question.options.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (revealed) ...[
            const SizedBox(height: 12),
            _RevealRow(
              label: 'Correct answer',
              value: String.fromCharCode(65 + (question.answerIndex ?? 0)),
              highlight: true,
            ),
            if (question.explanation != null && question.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                question.explanation!,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;

  const _MiniMetric({required this.label, required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  suffix,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundedPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RoundedPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RevealRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _RevealRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 10),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}