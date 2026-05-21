import 'dart:async';
// ignore_for_file: prefer_final_fields, dead_code, dead_null_aware_expression, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application_1/services/mock_test_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// This screen now drives a real unit quiz: it accepts questions and session id.
class QuizInProgress extends StatefulWidget {
  final int durationMinutes;
  final String title;
  final String? sessionId;
  final List<MockQuestion>? questions;
  const QuizInProgress({super.key, required this.durationMinutes, required this.title, this.sessionId, this.questions});

  @override
  State<QuizInProgress> createState() => _QuizInProgressState();
}

class _QuizInProgressState extends State<QuizInProgress> {
  late int _remainingSeconds;
  Timer? _timer;
  int _currentIndex = 0;
  late List<int?> _answers;
  Set<int> _marked = {};
  bool _submitting = false;
  bool _submitted = false;
  Map<String, dynamic>? _submitResult;
  static const String _progressPrefix = 'unit_quiz_progress_';
  static const int _progressExpirySeconds = 24 * 3600; // 24 hours
  static const int _autoSubmitNoticeSeconds = 5; // show undo 5s before auto-submit
  bool _autoNoticeShown = false;
  bool _autoCancelled = false;
  Timer? _autoSubmitCountdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationMinutes * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds -= 1;
          if (_remainingSeconds == 0 && !_submitted && !_submitting) {
            // time's up -> auto-submit
            _autoSubmit();
          } else if (_remainingSeconds == _autoSubmitNoticeSeconds && !_autoNoticeShown && !_submitted && !_submitting) {
            _showAutoSubmitNotice();
          }
        }
      });
    });
    final qlen = widget.questions?.length ?? 0;
    _answers = List<int?>.filled(qlen, null);
    // attempt to restore saved progress for this session
    if (widget.sessionId != null) {
      _loadProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Row(children: [Expanded(child: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis))]),
      ),
      body: widget.questions == null || widget.sessionId == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('No quiz loaded', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(12)), child: Text('$minutes:$seconds', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800))),
                const SizedBox(height: 16),
                Text('Failed to load questions.', style: GoogleFonts.poppins(color: Colors.black54), textAlign: TextAlign.center),
              ]),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _submitted ? _buildResultsView() : Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(widget.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(8)), child: Text('$minutes:$seconds', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)))]),
                const SizedBox(height: 12),
                Expanded(child: _buildQuestionArea()),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  ElevatedButton(onPressed: _prev, child: const Text('PREV')),
                  ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.black), child: _submitting ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)) : const Text('SUBMIT')),
                  ElevatedButton(onPressed: _next, child: const Text('NEXT')),
                ])
              ]),
            ),
    );
  }

  Widget _buildResultsView() {
    final result = _submitResult ?? {};
    final questions = widget.questions ?? [];
    final answerKey = List<int>.from(result['answer_key'] ?? []);
    final userAnswers = _answers;
    return Column(children: [
      Text('Results', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('Score: ${result['score'] ?? '-'} / ${result['max_score'] ?? '-'}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Expanded(
        child: ListView.builder(
          itemCount: questions.length,
          itemBuilder: (context, idx) {
            final q = questions[idx];
            final correct = (idx < answerKey.length) ? answerKey[idx] : (q.answerIndex ?? 0);
            final selected = userAnswers[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Q${idx + 1}. ${q.question}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...List.generate(q.options.length, (optIdx) {
                    final isCorrect = optIdx == correct;
                    final isSelected = selected == optIdx;
                    Color? bg;
                    if (isCorrect) bg = Colors.green.withOpacity(0.12);
                    if (!isCorrect && isSelected) bg = Colors.red.withOpacity(0.12);
                    return Container(
                      color: bg,
                      child: ListTile(
                        title: Text(q.options[optIdx]),
                        leading: Icon(isCorrect ? Icons.check_circle : Icons.circle, color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey)),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text('Explanation: ${q.explanation}', style: GoogleFonts.poppins(color: Colors.black54)),
                ]),
              ),
            );
          },
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: Text('DONE', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      )
    ]);
  }

  Widget _buildQuestionArea() {
    final questions = widget.questions!;
    if (_currentIndex < 0 || _currentIndex >= questions.length) return const SizedBox();
    final q = questions[_currentIndex];
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Q${_currentIndex + 1}. ${q.question}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
            ...List.generate(q.options.length, (idx) {
              final selected = _answers[_currentIndex] == idx;
              return ListTile(
                title: Text(q.options[idx]),
                leading: Radio<int?>(value: idx, groupValue: _answers[_currentIndex], onChanged: (v) => setState(() { _answers[_currentIndex] = v; _saveProgress(); })),
                tileColor: selected ? Colors.black12 : null,
              );
            }),
        const SizedBox(height: 8),
      ]),
    );
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex -= 1);
      _saveProgress();
    }
  }

  void _next() {
    if (_currentIndex < (widget.questions?.length ?? 0) - 1) {
      setState(() => _currentIndex += 1);
      _saveProgress();
    }
  }

  Future<void> _submit() async {
    if (_submitted || _submitting) return;
    _submitting = true;
    setState(() {});
    final sessionId = widget.sessionId!;
    try {
      final svc = MockTestService();
      final result = await svc.submitUnitQuiz(sessionId: sessionId, answers: _answers, marked: _marked);
      if (!mounted) return;
      _submitted = true;
      _submitResult = result;
      _submitting = false;
      setState(() {});
      // clear saved progress
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = '$_progressPrefix$sessionId';
        await prefs.remove(key);
      } catch (_) {}
    } catch (e) {
      _submitting = false;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit quiz: $e')));
    }
  }

  void _autoSubmit() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    await _submit();
  }

  void _showAutoSubmitNotice() {
    if (!mounted) return;
    _autoNoticeShown = true;
    _autoCancelled = false;
    // start a countdown timer; if it reaches zero, submit
    _autoSubmitCountdownTimer = Timer(Duration(seconds: _autoSubmitNoticeSeconds), () {
      if (!_autoCancelled && !_submitted && !_submitting) {
        _autoSubmit();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Auto-submitting in ${_autoSubmitNoticeSeconds}s — tap CANCEL to stop'),
      duration: Duration(seconds: _autoSubmitNoticeSeconds),
      action: SnackBarAction(label: 'CANCEL', onPressed: () {
        _autoCancelled = true;
        _autoSubmitCountdownTimer?.cancel();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // give user a small buffer by restoring a few seconds
        setState(() {
          _remainingSeconds = 3; // small buffer
        });
      }),
    ));
  }

  Future<void> _saveProgress() async {
    if (widget.sessionId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_progressPrefix${widget.sessionId}';
      final payload = jsonEncode({
        'answers': _answers,
        'currentIndex': _currentIndex,
        'remainingSeconds': _remainingSeconds,
        'updated': DateTime.now().toIso8601String(),
      });
      await prefs.setString(key, payload);
    } catch (_) {}
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_progressPrefix${widget.sessionId}';
      final raw = prefs.getString(key);
      if (raw == null) return;
      final Map<String, dynamic> obj = jsonDecode(raw);
      // check expiry
      final String? updatedRaw = obj['updated'] as String?;
      if (updatedRaw != null) {
        try {
          final saved = DateTime.parse(updatedRaw).toUtc();
          final age = DateTime.now().toUtc().difference(saved).inSeconds;
          if (age > _progressExpirySeconds) {
            // expired
            await prefs.remove(key);
            return;
          }
        } catch (_) {}
      }
      final List<dynamic>? answersRaw = obj['answers'] as List<dynamic>?;
      if (answersRaw != null && answersRaw.length == _answers.length) {
        for (var i = 0; i < answersRaw.length; i++) {
          _answers[i] = answersRaw[i] == null ? null : int.tryParse(answersRaw[i].toString());
        }
      }
      final int? idx = int.tryParse(obj['currentIndex']?.toString() ?? '0');
      if (idx != null && idx >= 0 && idx < _answers.length) _currentIndex = idx;
      final int? rem = int.tryParse(obj['remainingSeconds']?.toString() ?? '');
      if (rem != null && rem > 0) _remainingSeconds = rem;
      setState(() {});
    } catch (_) {}
  }

}
