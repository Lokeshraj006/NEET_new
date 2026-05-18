import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/screens/quizzes_screen.dart';
import 'package:flutter_application_1/services/mock_test_service.dart';

const Color _kPrimary = Color(0xFF4F46B5);
const Color _kPrimarySoft = Color(0xFFF0EDFF);
const Color _kBackground = Color(0xFFEAF4FF);
const Color _kSurface = Colors.white;
const String _draftKey = 'mock_test_active_draft_v2';
const String _resultKey = 'mock_test_last_result_v2';

class MockTestResultArgs {
  final MockTestBundle bundle;
  final List<int?> answers;
  final Set<int> marked;
  final Duration elapsed;
  final Map<String, dynamic> result;

  const MockTestResultArgs({
    required this.bundle,
    required this.answers,
    required this.marked,
    required this.elapsed,
    required this.result,
  });
}

class _MockTestDraft {
  final MockTestBundle bundle;
  final List<int?> answers;
  final Set<int> marked;
  final int currentIndex;
  final DateTime startedAt;
  final Duration duration;
  final bool isPaused;

  const _MockTestDraft({
    required this.bundle,
    required this.answers,
    required this.marked,
    required this.currentIndex,
    required this.startedAt,
    required this.duration,
    this.isPaused = false,
  });

  int get remainingSeconds => math.max(
    0,
    duration.inSeconds - DateTime.now().difference(startedAt).inSeconds,
  );
  Duration get elapsed => Duration(
    seconds: math.min(
      duration.inSeconds,
      DateTime.now().difference(startedAt).inSeconds,
    ),
  );

  Map<String, dynamic> toJson() => {
    'bundle': {
      'sessionId': bundle.sessionId,
      'attempt': bundle.attempt,
      'attemptsAllowed': bundle.attemptsAllowed,
      'questions': bundle.questions
          .map(
            (q) => {
              'subject': q.subject,
              'unit': q.unit,
              'question': q.question,
              'options': q.options,
              'answerIndex': q.answerIndex,
              'explanation': q.explanation,
              'hash': q.hash,
            },
          )
          .toList(),
    },
    'answers': answers.map((value) => value).toList(),
    'marked': marked.toList(),
    'currentIndex': currentIndex,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'isPaused': isPaused,
  };

  static _MockTestDraft? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final bundleJson = Map<String, dynamic>.from(
      (json['bundle'] as Map?) ?? const {},
    );
    final questionList = (bundleJson['questions'] as List? ?? const []);
    final questions = questionList
        .map(
          (entry) =>
              MockQuestion.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    final bundle = MockTestBundle(
      sessionId: (bundleJson['sessionId'] ?? '').toString(),
      questions: questions,
      attempt: int.tryParse('${bundleJson['attempt'] ?? 1}') ?? 1,
      attemptsAllowed:
          int.tryParse('${bundleJson['attemptsAllowed'] ?? 5}') ?? 5,
    );
    final rawAnswers = (json['answers'] as List? ?? const []);
    final answers = rawAnswers.map<int?>((entry) {
      if (entry == null) return null;
      return int.tryParse(entry.toString());
    }).toList();
    while (answers.length < questions.length) {
      answers.add(null);
    }
    final marked = ((json['marked'] as List? ?? const []))
        .map((entry) => int.tryParse(entry.toString()))
        .whereType<int>()
        .toSet();
    final currentIndex = math.max(
      0,
      int.tryParse('${json['currentIndex'] ?? 0}') ?? 0,
    );
    final startedAt =
        DateTime.tryParse((json['startedAt'] ?? '').toString()) ??
        DateTime.now();
    final durationSeconds =
        int.tryParse('${json['durationSeconds'] ?? 3 * 60 * 60}') ??
        3 * 60 * 60;
    final isPaused = json['isPaused'] == true;
    return _MockTestDraft(
      bundle: bundle,
      answers: answers,
      marked: marked,
      currentIndex: currentIndex.clamp(0, math.max(0, questions.length - 1)),
      startedAt: startedAt,
      duration: Duration(seconds: durationSeconds),
      isPaused: isPaused,
    );
  }
}

class MockTestPracticeScreen extends StatefulWidget {
  const MockTestPracticeScreen({super.key});

  @override
  State<MockTestPracticeScreen> createState() => _MockTestPracticeScreenState();
}

class _MockTestPracticeScreenState extends State<MockTestPracticeScreen> {
  _MockTestDraft? _draft;
  bool _loadingDraft = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    if (mounted) {
      setState(() => _loadingDraft = false);
    }
  }

  Future<void> _startTest() async {
    setState(() => _starting = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MockTestSetPickerScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start mock test: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    if (!mounted) return;
    setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF09111F) : _kBackground;
    if (_loadingDraft) {
      return Scaffold(
        backgroundColor: background,
        body: const _MockTestSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _PracticeHeroCard(onStart: _startTest, loading: _starting),
              const SizedBox(height: 16),
              const _ExamPatternCard(),
              const SizedBox(height: 16),
              const _QuizzesCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class MockTestSetPickerScreen extends StatelessWidget {
  const MockTestSetPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sets = List.generate(6, (index) => index + 1);
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        title: Text(
          'Full Mock Tests',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: GridView.builder(
          itemCount: sets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            // allow slightly taller tiles on very narrow screens to avoid vertical overflow
            childAspectRatio: MediaQuery.of(context).size.width < 360
                ? 0.95
                : 1.05,
          ),
          shrinkWrap: false,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final setId = sets[index];
            return _SetCard(
              setId: setId,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MockTestSetRulesScreen(setId: setId),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final int setId;
  final VoidCallback onTap;

  const _SetCard({required this.setId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kPrimarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$setId',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 16, color: _kPrimary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mock Test Set $setId',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.fade,
            ),
            const SizedBox(height: 6),
            // allow small text to shrink/wrap to avoid overflow on tiny devices
            Flexible(
              child: Text(
                'Open rules, then start instantly.',
                style: GoogleFonts.poppins(color: Colors.black54, fontSize: 12),
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MockTestSetRulesScreen extends StatefulWidget {
  final int setId;

  const MockTestSetRulesScreen({super.key, required this.setId});

  @override
  State<MockTestSetRulesScreen> createState() => _MockTestSetRulesScreenState();
}

class _MockTestSetRulesScreenState extends State<MockTestSetRulesScreen> {
  final MockTestService _service = MockTestService();
  bool _loading = true;
  bool _starting = false;
  Object? _error;
  MockTestBundle? _bundle;

  @override
  void initState() {
    super.initState();
    _loadBundle();
  }

  Future<void> _loadBundle() async {
    try {
      final bundle = await _service.loadFixedSetBundle(widget.setId);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _startTest() async {
    final bundle = _bundle;
    if (bundle == null) return;
    setState(() => _starting = true);
    try {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MockTestScreen(bundle: bundle)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start mock test: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      appBar: AppBar(
        title: Text(
          'Set ${widget.setId} Rules',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rules and Regulations',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _RuleTile('Set ${widget.setId} contains the full fixed paper.'),
              const _RuleTile('Use the same NEET pattern and scoring.'),
              const _RuleTile(
                'Marks: +4 for correct, -1 for wrong, 0 for unattempted.',
              ),
              const _RuleTile('Pause Test and Resume Test are available.'),
              const _RuleTile(
                'Mark for Review, Previous, and Save & Next are available.',
              ),
              const _RuleTile('Submit only after reviewing the whole paper.'),
              const SizedBox(height: 18),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Failed to load set ${widget.setId}. Check the extracted PDF text.',
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_starting || _loading || _bundle == null)
                      ? null
                      : _startTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _starting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _loading ? 'Loading Set...' : 'Start Test',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final String text;

  const _RuleTile(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.check_circle, color: _kPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MockTestScreen extends StatefulWidget {
  final MockTestBundle bundle;
  final _MockTestDraft? draft;
  final Future<void> Function()? onDraftCleared;

  const MockTestScreen({
    super.key,
    required this.bundle,
    this.draft,
    this.onDraftCleared,
  });

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  late List<int?> _answers;
  late Set<int> _marked;
  late int _currentIndex;
  late DateTime _startedAt;
  late Duration _duration;
  bool _isPaused = false;
  Timer? _timer;
  bool _submitting = false;
  bool _autoSubmitted = false;

  int get _answered => _answers.where((answer) => answer != null).length;
  int get _remaining => _answers.length - _answered;
  int get _markedCount => _marked.length;
  int get _remainingSeconds => math.max(
    0,
    _duration.inSeconds - DateTime.now().difference(_startedAt).inSeconds,
  );
  double get _progress => _answers.isEmpty ? 0 : _answered / _answers.length;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _answers = List<int?>.filled(widget.bundle.questions.length, null);
    _marked = <int>{};
    _currentIndex = 0;
    _startedAt = DateTime.now();
    _duration = const Duration(hours: 3);
    if (draft != null) {
      _answers = List<int?>.from(draft.answers);
      _marked = {...draft.marked};
      _currentIndex = draft.currentIndex.clamp(
        0,
        math.max(0, widget.bundle.questions.length - 1),
      );
      _startedAt = draft.startedAt;
      _duration = draft.duration;
      _isPaused = draft.isPaused;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPaused) {
        setState(() {});
        return;
      }
      final remaining = _remainingSeconds;
      setState(() {});
      if (remaining <= 0 && !_autoSubmitted && !_submitting) {
        _autoSubmitted = true;
        _submit(auto: true);
      }
    });
    _saveDraft();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = _MockTestDraft(
      bundle: widget.bundle,
      answers: _answers,
      marked: _marked,
      currentIndex: _currentIndex,
      startedAt: _startedAt,
      duration: _duration,
      isPaused: _isPaused,
    );
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _saveResult(
    Map<String, dynamic> result,
    Duration elapsed,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _resultKey,
      jsonEncode({
        'bundle': {
          'sessionId': widget.bundle.sessionId,
          'attempt': widget.bundle.attempt,
          'attemptsAllowed': widget.bundle.attemptsAllowed,
          'questions': widget.bundle.questions
              .map(
                (q) => {
                  'subject': q.subject,
                  'unit': q.unit,
                  'question': q.question,
                  'options': q.options,
                  'answerIndex': q.answerIndex,
                  'explanation': q.explanation,
                  'hash': q.hash,
                },
              )
              .toList(),
        },
        'answers': _answers.map((value) => value).toList(),
        'marked': _marked.toList(),
        'elapsedSeconds': elapsed.inSeconds,
        'result': result,
      }),
    );
  }

  void _selectOption(int index) {
    setState(() {
      _answers[_currentIndex] = index;
    });
    _saveDraft();
  }

  void _toggleMark() {
    setState(() {
      if (_marked.contains(_currentIndex)) {
        _marked.remove(_currentIndex);
      } else {
        _marked.add(_currentIndex);
      }
    });
    _saveDraft();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    _saveDraft();
  }

  void _prev() {
    if (_currentIndex == 0) return;
    setState(() => _currentIndex -= 1);
    _saveDraft();
  }

  void _next({bool submitIfLast = false}) {
    if (_currentIndex < _answers.length - 1) {
      setState(() => _currentIndex += 1);
      _saveDraft();
      return;
    }
    if (submitIfLast) {
      _submit();
    }
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    if (!auto) {
      final shouldSubmit = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (_) => SubmitModal(
          answered: _answered,
          unanswered: _remaining,
          marked: _markedCount,
          total: _answers.length,
        ),
      );
      if (shouldSubmit != true || !mounted) return;
    }

    setState(() => _submitting = true);
    final elapsed = _duration - Duration(seconds: _remainingSeconds);
    Map<String, dynamic> result = {};
    try {
      if (widget.bundle.sessionId.startsWith('fixed_set_')) {
        result = {'status': 'ok', 'mode': 'fixed_set'};
      } else {
        result = await MockTestService().submitAnswers(
          sessionId: widget.bundle.sessionId,
          answers: _answers,
          marked: _marked,
        );
      }
    } catch (error) {
      result = {'error': error.toString()};
    }

    await _saveResult(result, elapsed);
    await _clearDraft();
    if (!mounted) return;
    setState(() => _submitting = false);

    Navigator.of(context).pushReplacementNamed(
      '/mock-test/result',
      arguments: MockTestResultArgs(
        bundle: widget.bundle,
        answers: _answers,
        marked: _marked,
        elapsed: elapsed,
        result: result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0A1220) : _kBackground;
    final currentQuestion = widget.bundle.questions[_currentIndex];
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const _PreviousIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const _NextIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA): const _PickOptionIntent(
          0,
        ),
        const SingleActivator(LogicalKeyboardKey.keyB): const _PickOptionIntent(
          1,
        ),
        const SingleActivator(LogicalKeyboardKey.keyC): const _PickOptionIntent(
          2,
        ),
        const SingleActivator(LogicalKeyboardKey.keyD): const _PickOptionIntent(
          3,
        ),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PreviousIntent: CallbackAction<_PreviousIntent>(
            onInvoke: (_) {
              _prev();
              return null;
            },
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) {
              _next();
              return null;
            },
          ),
          _PickOptionIntent: CallbackAction<_PickOptionIntent>(
            onInvoke: (intent) {
              if (intent != null) {
                _selectOption(intent.index);
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: background,
            body: SafeArea(
              child: Column(
                children: [
                  TestHeader(
                    timerText: '$minutes:$seconds',
                    answered: _answered,
                    total: _answers.length,
                    subject: currentQuestion.subject,
                    currentIndex: _currentIndex,
                    onEndTest: _submit,
                    isPaused: _isPaused,
                    onPauseToggle: _togglePause,
                    progress: _progress,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 1100) {
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    16,
                                    12,
                                    18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ProgressHeader(
                                        title: 'NEET Mock Test - Full Syllabus',
                                        subtitle:
                                            'Section: ${currentQuestion.subject} • Question ${_currentIndex + 1} of ${_answers.length}',
                                        progress: _progress,
                                        answered: _answered,
                                        total: _answers.length,
                                      ),
                                      const SizedBox(height: 16),
                                      QuestionCard(
                                        question: currentQuestion,
                                        selectedIndex: _answers[_currentIndex],
                                        currentIndex: _currentIndex,
                                        onSelect: _selectOption,
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 16),
                                      BottomControls(
                                        answered: _answered,
                                        remaining: _remaining,
                                        marked: _markedCount,
                                        onPrevious: _prev,
                                        onToggleMark: _toggleMark,
                                        onSaveNext: () =>
                                            _next(submitIfLast: true),
                                        isMarked: _marked.contains(
                                          _currentIndex,
                                        ),
                                        isLast:
                                            _currentIndex ==
                                            _answers.length - 1,
                                      ),
                                      const SizedBox(height: 16),
                                      SummaryBar(
                                        answered: _answered,
                                        remaining: _remaining,
                                        marked: _markedCount,
                                        total: _answers.length,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 380,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    16,
                                    18,
                                    18,
                                  ),
                                  child: QuestionPalette(
                                    currentIndex: _currentIndex,
                                    answers: _answers,
                                    marked: _marked,
                                    onTap: (index) {
                                      setState(() => _currentIndex = index);
                                      _saveDraft();
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ProgressHeader(
                                title: 'NEET Mock Test - Full Syllabus',
                                subtitle:
                                    'Section: ${currentQuestion.subject} • Question ${_currentIndex + 1} of ${_answers.length}',
                                progress: _progress,
                                answered: _answered,
                                total: _answers.length,
                              ),
                              const SizedBox(height: 14),
                              QuestionCard(
                                question: currentQuestion,
                                selectedIndex: _answers[_currentIndex],
                                currentIndex: _currentIndex,
                                onSelect: _selectOption,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              QuestionPalette(
                                currentIndex: _currentIndex,
                                answers: _answers,
                                marked: _marked,
                                onTap: (index) {
                                  setState(() => _currentIndex = index);
                                  _saveDraft();
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(height: 14),
                              BottomControls(
                                answered: _answered,
                                remaining: _remaining,
                                marked: _markedCount,
                                onPrevious: _prev,
                                onToggleMark: _toggleMark,
                                onSaveNext: () => _next(submitIfLast: true),
                                isMarked: _marked.contains(_currentIndex),
                                isLast: _currentIndex == _answers.length - 1,
                              ),
                              const SizedBox(height: 14),
                              SummaryBar(
                                answered: _answered,
                                remaining: _remaining,
                                marked: _markedCount,
                                total: _answers.length,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isPaused)
                    Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.38),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Test paused',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_submitting)
                    Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MockTestResultsScreen extends StatefulWidget {
  final MockTestResultArgs? args;

  const MockTestResultsScreen({super.key, this.args});

  @override
  State<MockTestResultsScreen> createState() => _MockTestResultsScreenState();
}

class _MockTestResultsScreenState extends State<MockTestResultsScreen> {
  MockTestResultArgs? _args;

  @override
  void initState() {
    super.initState();
    _args = widget.args;
    if (_args == null) {
      _restoreFromPrefs();
    }
  }

  Future<void> _restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_resultKey);
    if (raw == null || raw.trim().isEmpty) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final bundleJson = Map<String, dynamic>.from(
      (data['bundle'] as Map?) ?? const {},
    );
    final questions = (bundleJson['questions'] as List? ?? const [])
        .map(
          (entry) =>
              MockQuestion.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    final bundle = MockTestBundle(
      sessionId: (bundleJson['sessionId'] ?? '').toString(),
      questions: questions,
      attempt: int.tryParse('${bundleJson['attempt'] ?? 1}') ?? 1,
      attemptsAllowed:
          int.tryParse('${bundleJson['attemptsAllowed'] ?? 5}') ?? 5,
    );
    final answers = ((data['answers'] as List? ?? const []))
        .map<int?>(
          (entry) => entry == null ? null : int.tryParse(entry.toString()),
        )
        .toList();
    while (answers.length < bundle.questions.length) {
      answers.add(null);
    }
    final marked = ((data['marked'] as List? ?? const []))
        .map((entry) => int.tryParse(entry.toString()))
        .whereType<int>()
        .toSet();
    final elapsed = Duration(
      seconds: int.tryParse('${data['elapsedSeconds'] ?? 0}') ?? 0,
    );
    final result = Map<String, dynamic>.from(
      (data['result'] as Map?) ?? const {},
    );
    if (mounted) {
      setState(
        () => _args = MockTestResultArgs(
          bundle: bundle,
          answers: answers,
          marked: marked,
          elapsed: elapsed,
          result: result,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null) {
      return Scaffold(
        backgroundColor: _kBackground,
        body: const _MockTestSkeleton(message: 'Loading result analytics...'),
      );
    }
    return ResultAnalyticsPage(args: args);
  }
}

class ResultAnalyticsPage extends StatelessWidget {
  final MockTestResultArgs args;

  const ResultAnalyticsPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final metrics = _buildMetrics(
      args.bundle,
      args.answers,
      args.marked,
      args.elapsed,
    );
    final background = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF09111F)
        : const Color(0xFFEAF4FF);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          'Mock Test Result',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultHero(metrics: metrics),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1000) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _StatsGrid(metrics: metrics)),
                      const SizedBox(width: 16),
                      Expanded(child: _ChartsPanel(metrics: metrics)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _StatsGrid(metrics: metrics),
                    const SizedBox(height: 16),
                    _ChartsPanel(metrics: metrics),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _SubjectAnalysis(metrics: metrics),
            const SizedBox(height: 16),
            _AdditionalAnalytics(metrics: metrics),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/mock-test/start', (route) => false),
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  'Back to Mock Tests',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockTestMetrics {
  final int score;
  final int maxScore;
  final int correct;
  final int wrong;
  final int skipped;
  final int marked;
  final int answered;
  final double accuracy;
  final double percentile;
  final int rankEstimate;
  final Duration elapsed;
  final Map<String, Map<String, int>> subjectStats;

  const _MockTestMetrics({
    required this.score,
    required this.maxScore,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.marked,
    required this.answered,
    required this.accuracy,
    required this.percentile,
    required this.rankEstimate,
    required this.elapsed,
    required this.subjectStats,
  });
}

_MockTestMetrics _buildMetrics(
  MockTestBundle bundle,
  List<int?> answers,
  Set<int> marked,
  Duration elapsed,
) {
  int score = 0;
  int correct = 0;
  int wrong = 0;
  int skipped = 0;
  final subjectStats = <String, Map<String, int>>{};
  for (var index = 0; index < bundle.questions.length; index += 1) {
    final question = bundle.questions[index];
    final selected = index < answers.length ? answers[index] : null;
    final subject = question.subject.isEmpty ? 'NEET' : question.subject;
    subjectStats.putIfAbsent(
      subject,
      () => {'correct': 0, 'wrong': 0, 'skipped': 0, 'score': 0, 'total': 0},
    );
    subjectStats[subject]!['total'] =
        (subjectStats[subject]!['total'] ?? 0) + 1;
    if (selected == null) {
      skipped += 1;
      subjectStats[subject]!['skipped'] =
          (subjectStats[subject]!['skipped'] ?? 0) + 1;
      continue;
    }
    if (selected == question.answerIndex) {
      correct += 1;
      score += 4;
      subjectStats[subject]!['correct'] =
          (subjectStats[subject]!['correct'] ?? 0) + 1;
      subjectStats[subject]!['score'] =
          (subjectStats[subject]!['score'] ?? 0) + 4;
    } else {
      wrong += 1;
      score -= 1;
      subjectStats[subject]!['wrong'] =
          (subjectStats[subject]!['wrong'] ?? 0) + 1;
      subjectStats[subject]!['score'] =
          (subjectStats[subject]!['score'] ?? 0) - 1;
    }
  }

  final answered = correct + wrong;
  final maxScore = bundle.questions.length * 4;
  final accuracy = answered == 0 ? 0.0 : (correct / answered) * 100;
  final normalized = maxScore == 0
      ? 0.0
      : (score.clamp(0, maxScore) / maxScore).toDouble();
  final percentile = 40 + normalized * 58;
  final rankEstimate = math.max(1, ((100 - percentile) * 1800).round());

  return _MockTestMetrics(
    score: score,
    maxScore: maxScore,
    correct: correct,
    wrong: wrong,
    skipped: skipped,
    marked: marked.length,
    answered: answered,
    accuracy: accuracy,
    percentile: percentile.clamp(0, 99.9),
    rankEstimate: rankEstimate,
    elapsed: elapsed,
    subjectStats: subjectStats,
  );
}

class TestHeader extends StatelessWidget {
  final String timerText;
  final int answered;
  final int total;
  final String subject;
  final int currentIndex;
  final VoidCallback onEndTest;
  final bool isPaused;
  final VoidCallback onPauseToggle;
  final double progress;

  const TestHeader({
    super.key,
    required this.timerText,
    required this.answered,
    required this.total,
    required this.subject,
    required this.currentIndex,
    required this.onEndTest,
    required this.isPaused,
    required this.onPauseToggle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive header: use Expanded/Flexible to avoid overflow on narrow screens.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          // Title and subtitle take remaining space and can wrap.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANEET PREP',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Subject: $subject • Question ${currentIndex + 1} / $total',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Timer - shrink if necessary
          Flexible(
            fit: FlexFit.loose,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kPrimarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: _kPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timerText,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: _kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Pause and End buttons wrapped to fit smaller screens
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  FilledButton(
                    onPressed: onPauseToggle,
                    style: FilledButton.styleFrom(
                      backgroundColor: isPaused
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      isPaused ? 'Resume' : 'Pause',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onEndTest,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'End',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final int answered;
  final int total;

  const ProgressHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.answered,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _kPrimarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${(progress * 100).round()}% completed',
                  style: GoogleFonts.poppins(
                    color: _kPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE9E7F3),
              valueColor: const AlwaysStoppedAnimation(_kPrimary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Answered $answered',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Remaining ${total - answered}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final MockQuestion question;
  final int? selectedIndex;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool isDark;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedIndex,
    required this.currentIndex,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF111A2A) : _kSurface;
    final border = isDark ? const Color(0xFF223047) : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SubjectBadge(subject: question.subject),
              _TinyBadge(
                text: 'Q${currentIndex + 1}',
                color: _kPrimarySoft,
                textColor: _kPrimary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: isDark ? Colors.white : Colors.black87,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 18),
          ...List.generate(
            question.options.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OptionButton(
                label: String.fromCharCode(65 + index),
                text: question.options[index],
                selected: selectedIndex == index,
                borderColor: border,
                onTap: () => onSelect(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OptionButton extends StatelessWidget {
  final String label;
  final String text;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  const OptionButton({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F3FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _kPrimary : borderColor,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? _kPrimary : const Color(0xFFF2F3F7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: selected ? _kPrimary : Colors.black87,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _kPrimary : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class QuestionPalette extends StatelessWidget {
  final int currentIndex;
  final List<int?> answers;
  final Set<int> marked;
  final ValueChanged<int> onTap;
  final bool isDark;

  const QuestionPalette({
    super.key,
    required this.currentIndex,
    required this.answers,
    required this.marked,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF111A2A) : _kSurface;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question Palette',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${answers.length} Questions',
                style: GoogleFonts.poppins(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 320 ? 6 : 5;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: answers.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final isCurrent = index == currentIndex;
                  final isAnswered = answers[index] != null;
                  final isMarked = marked.contains(index);
                  Color bg = isDark ? const Color(0xFF0F172A) : Colors.white;
                  Color border = isDark
                      ? const Color(0xFF2B3750)
                      : const Color(0xFFD4D4DD);
                  Color text = isDark ? Colors.white : Colors.black87;
                  if (isAnswered) {
                    bg = const Color(0xFF4F46B5);
                    border = const Color(0xFF4F46B5);
                    text = Colors.white;
                  }
                  if (isMarked) {
                    bg = const Color(0xFFF59E0B);
                    border = const Color(0xFFF59E0B);
                    text = Colors.white;
                  }
                  if (isCurrent) {
                    bg = _kPrimarySoft;
                    border = _kPrimary;
                    text = _kPrimary;
                  }
                  return InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border, width: 1.2),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: const [
              _LegendChip(color: Color(0xFF4F46B5), label: 'Answered'),
              _LegendChip(color: Color(0xFFF59E0B), label: 'Marked'),
              _LegendChip(color: Color(0xFFF0EDFF), label: 'Current'),
              _LegendChip(color: Color(0xFFD4D4DD), label: 'Unanswered'),
            ],
          ),
        ],
      ),
    );
  }
}

class BottomControls extends StatelessWidget {
  final int answered;
  final int remaining;
  final int marked;
  final VoidCallback onPrevious;
  final VoidCallback onToggleMark;
  final VoidCallback onSaveNext;
  final bool isMarked;
  final bool isLast;

  const BottomControls({
    super.key,
    required this.answered,
    required this.remaining,
    required this.marked,
    required this.onPrevious,
    required this.onToggleMark,
    required this.onSaveNext,
    required this.isMarked,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final controls = [
            SizedBox(
              width: compact ? double.infinity : null,
              child: OutlinedButton(
                onPressed: onPrevious,
                child: const Text('Previous'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : null,
              child: OutlinedButton.icon(
                onPressed: onToggleMark,
                icon: Icon(
                  isMarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(
                  isMarked ? 'Unmark' : 'Mark for Review',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : null,
              child: ElevatedButton(
                onPressed: onSaveNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isLast ? 'Submit Test' : 'Save & Next',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                controls[0],
                const SizedBox(height: 10),
                controls[1],
                const SizedBox(height: 10),
                controls[2],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: controls[0]),
              const SizedBox(width: 10),
              Expanded(child: controls[1]),
              const SizedBox(width: 10),
              Expanded(child: controls[2]),
            ],
          );
        },
      ),
    );
  }
}

class SummaryBar extends StatelessWidget {
  final int answered;
  final int remaining;
  final int marked;
  final int total;

  const SummaryBar({
    super.key,
    required this.answered,
    required this.remaining,
    required this.marked,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 480;
          final metrics = [
            _MetricChip(
              label: 'Answered',
              value: '$answered',
              color: _kPrimary,
            ),
            _MetricChip(
              label: 'Remaining',
              value: '$remaining',
              color: Colors.orange,
            ),
            _MetricChip(
              label: 'Marked',
              value: '$marked',
              color: const Color(0xFFF59E0B),
            ),
          ];

          if (compact) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...metrics,
                Text(
                  '$total Questions',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              metrics[0],
              const SizedBox(width: 12),
              metrics[1],
              const SizedBox(width: 12),
              metrics[2],
              const Spacer(),
              Text(
                '$total Questions',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SubmitModal extends StatelessWidget {
  final int answered;
  final int unanswered;
  final int marked;
  final int total;

  const SubmitModal({
    super.key,
    required this.answered,
    required this.unanswered,
    required this.marked,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.help_outline_rounded,
                color: _kPrimary,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Submit Test?',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Review the count below before final submission.',
                style: GoogleFonts.poppins(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _DialogStatRow(
                label: 'Answered',
                value: answered,
                color: _kPrimary,
              ),
              _DialogStatRow(
                label: 'Unanswered',
                value: unanswered,
                color: Colors.red,
              ),
              _DialogStatRow(
                label: 'Marked for Review',
                value: marked,
                color: const Color(0xFFF59E0B),
              ),
              _DialogStatRow(
                label: 'Total Questions',
                value: total,
                color: Colors.black87,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$unanswered questions left unanswered.',
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kPrimary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Review Answers',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Submit Test',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultAnalytics extends StatelessWidget {
  final _MockTestMetrics metrics;

  const ResultAnalytics({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCardGrid(metrics: metrics),
        const SizedBox(height: 16),
        _ChartsPanel(metrics: metrics),
      ],
    );
  }
}

class _ResultHero extends StatelessWidget {
  final _MockTestMetrics metrics;

  const _ResultHero({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final performance = metrics.maxScore == 0
        ? 0.0
        : (metrics.score.clamp(0, metrics.maxScore) / metrics.maxScore);
    final title = metrics.score >= metrics.maxScore * 0.75
        ? 'Excellent Performance!'
        : metrics.score >= metrics.maxScore * 0.5
        ? 'Good Effort!'
        : 'Keep Practicing!';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 78,
            lineWidth: 12,
            percent: performance.clamp(0.0, 1.0),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${metrics.score}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '/ ${metrics.maxScore}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            progressColor: _kPrimary,
            backgroundColor: const Color(0xFFE5E7EB),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You answered ${metrics.correct} correctly and ${metrics.wrong} incorrectly in ${_formatDuration(metrics.elapsed)}.',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TinyBadge(
                      text:
                          'Percentile ${metrics.percentile.toStringAsFixed(1)}',
                      color: _kPrimarySoft,
                      textColor: _kPrimary,
                    ),
                    _TinyBadge(
                      text: 'Accuracy ${metrics.accuracy.toStringAsFixed(0)}%',
                      color: const Color(0xFFE9F8EE),
                      textColor: const Color(0xFF0F766E),
                    ),
                    _TinyBadge(
                      text: 'Rank est. ~${metrics.rankEstimate}',
                      color: const Color(0xFFFFF4E5),
                      textColor: const Color(0xFFB45309),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final _MockTestMetrics metrics;

  const _StatsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 720 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            StatCard(
              label: 'Percentile',
              value: '${metrics.percentile.toStringAsFixed(1)}%',
              color: _kPrimary,
            ),
            StatCard(
              label: 'Accuracy',
              value: '${metrics.accuracy.toStringAsFixed(0)}%',
              color: const Color(0xFF0F766E),
            ),
            StatCard(
              label: 'Rank Estimate',
              value: '~${metrics.rankEstimate}',
              color: const Color(0xFFB45309),
            ),
            StatCard(
              label: 'Time Taken',
              value: _formatDuration(metrics.elapsed),
              color: Colors.black87,
            ),
          ],
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardGrid extends StatelessWidget {
  final _MockTestMetrics metrics;

  const _StatCardGrid({required this.metrics});

  @override
  Widget build(BuildContext context) => _StatsGrid(metrics: metrics);
}

class _ChartsPanel extends StatelessWidget {
  final _MockTestMetrics metrics;

  const _ChartsPanel({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final pieSections = [
      PieChartSectionData(
        value: metrics.correct.toDouble(),
        color: const Color(0xFF22C55E),
        radius: 54,
        title: 'Correct',
      ),
      PieChartSectionData(
        value: metrics.wrong.toDouble(),
        color: const Color(0xFFEF4444),
        radius: 54,
        title: 'Wrong',
      ),
      PieChartSectionData(
        value: metrics.skipped.toDouble(),
        color: const Color(0xFFF59E0B),
        radius: 54,
        title: 'Skipped',
      ),
    ];
    final subjectEntries = metrics.subjectStats.entries.toList();
    final barGroups = <BarChartGroupData>[];
    for (var index = 0; index < subjectEntries.length; index += 1) {
      final entry = subjectEntries[index];
      final total = entry.value['total'] ?? 0;
      final score = entry.value['score'] ?? 0;
      final normalized = total == 0
          ? 0.0
          : (score.clamp(0, total * 4) / (total * 4)).toDouble();
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: normalized * 100,
              width: 18,
              borderRadius: BorderRadius.circular(12),
              color: _kPrimary,
            ),
          ],
        ),
      );
    }
    final timeBars = subjectEntries.asMap().entries.map((entry) {
      final total = entry.value.value['total'] ?? 0;
      final totalQuestions = metrics.subjectStats.values.fold<double>(
        0,
        (sum, item) => sum + ((item['total'] ?? 0).toDouble()),
      );
      final estimate = totalQuestions == 0
          ? 0.0
          : metrics.elapsed.inSeconds * (total / totalQuestions);
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: estimate,
            width: 18,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF59E0B),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Charts',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 840) {
                return Row(
                  children: [
                    Expanded(
                      child: _ChartCard(
                        title: 'Accuracy Split',
                        child: PieChart(
                          PieChartData(
                            sections: pieSections,
                            centerSpaceRadius: 44,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ChartCard(
                        title: 'Subject-wise Performance',
                        child: BarChart(
                          BarChartData(
                            barGroups: barGroups,
                            titlesData: _axisTitles(
                              subjectEntries.map((e) => e.key).toList(),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barTouchData: BarTouchData(enabled: false),
                            maxY: 100,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _ChartCard(
                    title: 'Accuracy Split',
                    child: PieChart(
                      PieChartData(
                        sections: pieSections,
                        centerSpaceRadius: 44,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ChartCard(
                    title: 'Subject-wise Performance',
                    child: BarChart(
                      BarChartData(
                        barGroups: barGroups,
                        titlesData: _axisTitles(
                          subjectEntries.map((e) => e.key).toList(),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(enabled: false),
                        maxY: 100,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'Estimated Time Distribution',
            child: BarChart(
              BarChartData(
                barGroups: timeBars,
                titlesData: _axisTitles(
                  subjectEntries.map((e) => e.key).toList(),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _axisTitles(List<String> labels) {
    return FlTitlesData(
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 34),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= labels.length)
              return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                labels[index].split(' ').first,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: child),
        ],
      ),
    );
  }
}

class _SubjectAnalysis extends StatelessWidget {
  final _MockTestMetrics metrics;

  const _SubjectAnalysis({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final entries = metrics.subjectStats.entries.toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Analysis',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...entries.map((entry) {
            final total = entry.value['total'] ?? 0;
            final score = entry.value['score'] ?? 0;
            final percent = total == 0
                ? 0.0
                : (score.clamp(0, total * 4) / (total * 4)).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$score / ${total * 4}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFE9E7F8),
                      valueColor: const AlwaysStoppedAnimation(_kPrimary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Correct ${entry.value['correct'] ?? 0} • Wrong ${entry.value['wrong'] ?? 0} • Skipped ${entry.value['skipped'] ?? 0}',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AdditionalAnalytics extends StatelessWidget {
  final _MockTestMetrics metrics;

  const _AdditionalAnalytics({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Analytics',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatCard(
                label: 'Correct',
                value: '${metrics.correct}',
                color: const Color(0xFF22C55E),
              ),
              StatCard(
                label: 'Incorrect',
                value: '${metrics.wrong}',
                color: const Color(0xFFEF4444),
              ),
              StatCard(
                label: 'Skipped',
                value: '${metrics.skipped}',
                color: const Color(0xFFF59E0B),
              ),
              StatCard(
                label: 'Negative Marks',
                value: '-${metrics.wrong}',
                color: const Color(0xFF6B7280),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectBadge extends StatelessWidget {
  final String subject;

  const _SubjectBadge({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kPrimarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        subject,
        style: GoogleFonts.poppins(
          color: _kPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _TinyBadge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      ],
    );
  }
}

class _DialogStatRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _DialogStatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PracticeHeroCard extends StatelessWidget {
  final VoidCallback onStart;
  final bool loading;

  const _PracticeHeroCard({required this.onStart, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFEFF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Start Full Mock Test',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '180 questions • 3 hours • full NEET syllabus • AI-generated from your backend token',
            style: GoogleFonts.poppins(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'START FULL MOCK TEST',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamPatternCard extends StatelessWidget {
  const _ExamPatternCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEET Mock Test Structure',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _PatternRow(label: 'Physics', value: '45 Questions'),
          const Divider(height: 1),
          _PatternRow(label: 'Chemistry', value: '45 Questions'),
          const Divider(height: 1),
          _PatternRow(label: 'Biology', value: '90 Questions'),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _TinyBadge(
                text: '180 Questions',
                color: _kPrimary,
                textColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatternRow extends StatelessWidget {
  final String label;
  final String value;

  const _PatternRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MockTestInfoCard extends StatelessWidget {
  const _MockTestInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coverage Notes',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The backend generates AI-based questions across all Physics, Chemistry, and Biology syllabus units and avoids repeats across attempts.',
            style: GoogleFonts.poppins(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _MockTestSkeleton extends StatelessWidget {
  final String message;

  const _MockTestSkeleton({this.message = 'Loading mock test...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _kPrimary),
              const SizedBox(height: 18),
              Text(
                message,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizzesCard extends StatelessWidget {
  const _QuizzesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kPrimarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: _kPrimary,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Topic-wise Quizzes',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The quiz module stays separate from mock tests.',
            style: GoogleFonts.poppins(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const QuizzesScreen())),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'EXPLORE QUIZZES',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  color: _kPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PickOptionIntent extends Intent {
  final int index;
  const _PickOptionIntent(this.index);
}
