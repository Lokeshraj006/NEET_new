// ignore_for_file: unused_element, unused_field, unnecessary_null_comparison, unused_local_variable, unnecessary_brace_in_string_interps, curly_braces_in_flow_control_structures, private_type_in_public_api, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';
import 'package:flutter_application_1/screens/quizzes_screen.dart';
import 'package:flutter_application_1/services/mock_test_service.dart';

const Color _kPrimary = AppColors.primary;
const Color _kPrimarySoft = AppColors.primarySoft;
const Color _kBackground = AppColors.background;
const Color _kSurface = AppColors.surface;
const String _draftKey = 'mock_test_active_draft_v2';
const String _resultKey = 'mock_test_last_result_v2';

class _MockTestSection {
  final String name;
  final int startIndex;
  final int endIndex;

  const _MockTestSection({
    required this.name,
    required this.startIndex,
    required this.endIndex,
  });

  int get count => endIndex >= startIndex ? endIndex - startIndex + 1 : 0;

  bool contains(int index) => index >= startIndex && index <= endIndex;

  int localNumber(int index) => contains(index) ? index - startIndex + 1 : 0;
}

class MockTestResultArgs {
  final MockTestBundle bundle;
  final List<int?> answers;
  final Set<int> marked;
  final Map<String, dynamic> result;
  final Duration elapsed;

  const MockTestResultArgs({
    required this.bundle,
    required this.answers,
    required this.marked,
    required this.result,
    required this.elapsed,
  });
}

class MockTestLandingScreen extends StatelessWidget {
  const MockTestLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Mock Test',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Text(
            'Practice like the real NEET exam with topic-wise quizzes and a full timed mock test.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const _QuizzesCard(),
          const SizedBox(height: 14),
          _CombinedMockCard(
            loading: false,
            onStart: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MockTestSetPickerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}

class MockTestSetPickerScreen extends StatelessWidget {
  const MockTestSetPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final papers = const [
      _MockPaperOption(
        setId: 1,
        title: 'Mock Test Set 1',
        subtitle: 'Full NEET-style paper',
        accent: Color(0xFF14532D),
        accentSoft: Color(0xFFD1FAE5),
        icon: Icons.library_books_rounded,
      ),
      _MockPaperOption(
        setId: 2,
        title: 'Mock Test Set 2',
        subtitle: 'Full NEET-style paper',
        accent: Color(0xFF0F766E),
        accentSoft: Color(0xFFCFFAFE),
        icon: Icons.library_books_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Choose Mock Test Set',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;
                  return GridView.builder(
                    itemCount: papers.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 2 : 1,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: isWide ? 1.85 : 2.25,
                    ),
                    itemBuilder: (context, index) {
                      final paper = papers[index];
                      return _MockPaperCard(
                        paper: paper,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MockTestSetRulesScreen(setId: paper.setId),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}

class _MockPaperCard extends StatelessWidget {
  final _MockPaperOption paper;
  final VoidCallback onTap;

  const _MockPaperCard({required this.paper, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [Colors.white, paper.accentSoft.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: paper.accent.withValues(alpha: 0.10)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: paper.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(paper.icon, color: paper.accent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    paper.title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    paper.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PaperChip(label: '180 questions', color: paper.accent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: paper.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PaperChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MockPaperOption {
  final int setId;
  final String title;
  final String subtitle;
  final Color accent;
  final Color accentSoft;
  final IconData icon;

  const _MockPaperOption({
    required this.setId,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentSoft,
    required this.icon,
  });
}

class _MockTestDraft {
  final MockTestBundle bundle;
  final List<int?> answers;
  final Set<int> marked;
  final int currentIndex;
  final Duration duration;
  final bool isPaused;
  final int? remainingSeconds;

  const _MockTestDraft({
    required this.bundle,
    required this.answers,
    required this.marked,
    required this.currentIndex,
    required this.duration,
    required this.isPaused,
    required this.remainingSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'bundle': {
        'sessionId': bundle.sessionId,
        'attempt': bundle.attempt,
        'attemptsAllowed': bundle.attemptsAllowed,
        'questions': bundle.questions
            .map(
              (question) => {
                'subject': question.subject,
                'unit': question.unit,
                'question': question.question,
                'options': question.options,
                'answerIndex': question.answerIndex,
                'explanation': question.explanation,
                'hash': question.hash,
                'questionImageBase64': question.questionImageBase64,
                'sourcePage': question.sourcePage,
              },
            )
            .toList(),
      },
      'answers': answers.map((answer) => answer).toList(),
      'marked': marked.toList(),
      'currentIndex': currentIndex,
      'durationSeconds': duration.inSeconds,
      'isPaused': isPaused,
      'remainingSeconds': remainingSeconds,
    };
  }

  factory _MockTestDraft.fromJson(Map<String, dynamic> json) {
    final bundleJson = Map<String, dynamic>.from(
      (json['bundle'] as Map?) ?? const {},
    );
    final questions = (bundleJson['questions'] as List? ?? const [])
        .map(
          (entry) =>
              MockQuestion.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    final answers = ((json['answers'] as List? ?? const []))
        .map<int?>(
          (entry) => entry == null ? null : int.tryParse(entry.toString()),
        )
        .toList();
    final marked = ((json['marked'] as List? ?? const []))
        .map((entry) => int.tryParse(entry.toString()))
        .whereType<int>()
        .toSet();

    return _MockTestDraft(
      bundle: MockTestBundle(
        sessionId: (bundleJson['sessionId'] ?? '').toString(),
        questions: questions,
        attempt: int.tryParse('${bundleJson['attempt'] ?? 1}') ?? 1,
        attemptsAllowed:
            int.tryParse('${bundleJson['attemptsAllowed'] ?? 5}') ?? 5,
      ),
      answers: answers,
      marked: marked,
      currentIndex: int.tryParse('${json['currentIndex'] ?? 0}') ?? 0,
      duration: Duration(
        seconds: int.tryParse('${json['durationSeconds'] ?? 0}') ?? 0,
      ),
      isPaused: json['isPaused'] == true,
      remainingSeconds: int.tryParse('${json['remainingSeconds'] ?? ''}'),
    );
  }
}

class MockTestLaunchScreen extends StatefulWidget {
  final int setId;

  const MockTestLaunchScreen({super.key, required this.setId});

  @override
  State<MockTestLaunchScreen> createState() => _MockTestLaunchScreenState();
}

class _MockTestLaunchScreenState extends State<MockTestLaunchScreen> {
  final MockTestService _service = MockTestService();
  Object? _error;

  @override
  void initState() {
    super.initState();
    _openPaper();
  }

  Future<void> _openPaper() async {
    try {
      final bundle = await _service.loadFixedSetBundle(widget.setId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MockTestScreen(bundle: bundle)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: Text(
          'Opening Paper ${widget.setId}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _kPrimary),
              const SizedBox(height: 16),
              Text(
                _error == null
                    ? 'Loading questions and options...'
                    : 'Failed to open paper: $_error',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _openPaper,
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
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
              'Set $setId',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.fade,
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
  static const int _loadingCountdownStart = 15;
  int _loadingCountdown = _loadingCountdownStart;
  Timer? _loadingTicker;
  Object? _error;
  MockTestBundle? _bundle;

  @override
  void initState() {
    super.initState();
    _loadingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_loading) return;
      if (_loadingCountdown > 0) {
        setState(() => _loadingCountdown -= 1);
      }
    });
    _loadBundle();
  }

  @override
  void dispose() {
    _loadingTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadBundle() async {
    try {
      final bundle = await _service.loadFixedSetBundle(widget.setId);
      // If a stale draft exists for a different session, clear it so old
      // options/structure do not persist in SharedPreferences.
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_draftKey);
        if (raw != null && raw.trim().isNotEmpty) {
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final bundleJson = Map<String, dynamic>.from(
              (data['bundle'] as Map?) ?? {},
            );
            final savedSession = (bundleJson['sessionId'] ?? '').toString();
            if (savedSession.isNotEmpty && savedSession != bundle.sessionId) {
              await prefs.remove(_draftKey);
              debugPrint(
                'Cleared stale mock test draft (saved=$savedSession, new=${bundle.sessionId})',
              );
            }
          } catch (_) {
            // ignore malformed draft; remove it to be safe
            await prefs.remove(_draftKey);
            debugPrint('Removed malformed mock test draft');
          }
        }
      } catch (e) {
        debugPrint('Failed to inspect/clear draft: $e');
      }
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
        _loadingCountdown = _loadingCountdownStart;
      });
      _loadingTicker?.cancel();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingCountdown = _loadingCountdownStart;
      });
      _loadingTicker?.cancel();
    }
  }

  String _loadingButtonLabel() {
    if (!_loading) return 'Start Test';
    if (_loadingCountdown > 0) {
      return 'The paper will load in $_loadingCountdown seconds...';
    }
    return 'Almost there, loading your paper...';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Paper ${widget.setId}',
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
                const _RuleTile('NEET scoring pattern is followed strictly.'),
                const _RuleTile(
                  '4 sections are included: Physics, Chemistry, Botany, and Zoology.',
                ),
                const _RuleTile('Each section has 45 questions (total 180 questions).'),
                const _RuleTile(
                  'Marks: +4 for correct, -1 for wrong, 0 for unattempted.',
                ),
                const _RuleTile('Total duration is 3 hours, like NEET exam mode.'),
                const _RuleTile(
                  'Mark for Review, Previous, and Save & Next are available.',
                ),
                const _RuleTile('Submit only after reviewing the whole paper.'),
                const _RuleTile(
                  'When the mock test starts, full-screen mode is enabled: you will not be able to use app navigation or the bottom navigation bar until you end or submit the test. Normal app navigation resumes only after the test is ended.',
                ),
                const SizedBox(height: 18),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Failed to load set ${widget.setId}: $_error',
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
                            _loadingButtonLabel(),
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
        bottomNavigationBar: BottomNav(
          selectedIndex: 1,
          onTap: (_) {},
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
  static const int _sectionPageSize = 10;
  static const int _fullMockQuestionLimit = 180;

  late MockTestBundle _bundle;
  late List<_MockTestSection> _sections;
  late List<int?> _answers;
  late Set<int> _marked;
  late int _currentIndex;
  late Duration _duration;
  late int _remainingSeconds;
  int _activeSectionIndex = 0;
  int _sectionPage = 0;
  bool _isPaused = false;
  Timer? _timer;
  bool _submitting = false;
  bool _autoSubmitted = false;

  int get _answered => _answers.where((answer) => answer != null).length;
  int get _remaining => _answers.length - _answered;
  int get _markedCount => _marked.length;
  double get _progress => _answers.isEmpty ? 0 : _answered / _answers.length;
  MockQuestion get _currentQuestion => _bundle.questions[_currentIndex];
  _MockTestSection get _activeSection => _sections[_activeSectionIndex];

  List<_MockTestSection> _buildSections(List<MockQuestion> questions) {
    if (questions.isEmpty) return const [];
    final sections = <_MockTestSection>[];
    var sectionStart = 0;
    var sectionName = questions.first.subject.trim().isEmpty
        ? 'Section 1'
        : questions.first.subject.trim();

    for (var index = 1; index < questions.length; index += 1) {
      final currentName = questions[index].subject.trim().isEmpty
          ? 'Section ${sections.length + 2}'
          : questions[index].subject.trim();
      if (currentName == sectionName) {
        continue;
      }
      sections.add(
        _MockTestSection(
          name: sectionName,
          startIndex: sectionStart,
          endIndex: index - 1,
        ),
      );
      sectionStart = index;
      sectionName = currentName;
    }

    sections.add(
      _MockTestSection(
        name: sectionName,
        startIndex: sectionStart,
        endIndex: questions.length - 1,
      ),
    );
    return sections;
  }

  MockTestBundle _trimBundle(MockTestBundle bundle) {
    final questions = bundle.questions
        .take(_fullMockQuestionLimit)
        .toList(growable: false);
    return MockTestBundle(
      sessionId: bundle.sessionId,
      questions: questions,
      attempt: bundle.attempt,
      attemptsAllowed: bundle.attemptsAllowed,
    );
  }

  List<String> _normalizeOptions(Iterable<String> options) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final option in options) {
      final cleaned = option.replaceAll('\u00a0', ' ').trim();
      if (cleaned.isEmpty || !seen.add(cleaned)) {
        continue;
      }
      normalized.add(cleaned);
      if (normalized.length == 4) {
        break;
      }
    }
    return normalized;
  }

  List<String> _repairOptions(MockQuestion question) {
    final merged = _normalizeOptions(question.options);
    final inlineOptions = _normalizeOptions(
      MockQuestion.optionsFromInlineQuestion(question.question),
    );

    for (final option in inlineOptions) {
      if (merged.length == 4) {
        break;
      }
      if (merged.contains(option)) {
        continue;
      }
      merged.add(option);
    }

    while (merged.length < 4) {
      merged.add('—');
    }

    return merged.take(4).toList(growable: false);
  }

  MockTestBundle _sanitizeBundle(MockTestBundle bundle) {
    final sanitized = <MockQuestion>[];
    for (var i = 0; i < bundle.questions.length; i++) {
      final q = bundle.questions[i];
      final repaired = _repairOptions(q);
      var ai = q.answerIndex;
      if (ai < 0 || ai >= repaired.length) ai = 0;
      if (!listEquals(repaired, q.options)) {
        debugPrint(
          'MockTest sanitize q#${i + 1}: original=${q.options} -> sanitized=$repaired',
        );
      }
      sanitized.add(
        MockQuestion(
          subject: q.subject,
          unit: q.unit,
          question: q.question,
          options: repaired,
          answerIndex: ai,
          explanation: q.explanation,
          hash: q.hash,
          questionImageBase64: q.questionImageBase64,
          sourcePage: q.sourcePage,
        ),
      );
    }
    return MockTestBundle(
      sessionId: bundle.sessionId,
      questions: sanitized,
      attempt: bundle.attempt,
      attemptsAllowed: bundle.attemptsAllowed,
    );
  }

  void _syncSectionForIndex(int index) {
    if (_sections.isEmpty) return;
    final sectionIndex = _sections.indexWhere(
      (section) => section.contains(index),
    );
    if (sectionIndex < 0) return;
    _activeSectionIndex = sectionIndex;
    final section = _sections[sectionIndex];
    _sectionPage = math.max(
      0,
      (index - section.startIndex) ~/ _sectionPageSize,
    );
  }

  void _jumpToQuestion(int index) {
    if (index < 0 || index >= _answers.length) return;
    setState(() {
      _currentIndex = index;
      _syncSectionForIndex(index);
    });
    _saveDraft();
  }

  void _switchSection(int sectionIndex) {
    if (sectionIndex < 0 || sectionIndex >= _sections.length) return;
    setState(() {
      _activeSectionIndex = sectionIndex;
      _sectionPage = 0;
      _currentIndex = _sections[sectionIndex].startIndex;
    });
    _saveDraft();
  }

  List<int> _visibleQuestionIndexes() {
    if (_sections.isEmpty) return const [];
    final section = _sections[_activeSectionIndex];
    final start = section.startIndex + (_sectionPage * _sectionPageSize);
    final end = math.min(section.endIndex, start + _sectionPageSize - 1);
    if (start > end) return const [];
    return [for (var index = start; index <= end; index++) index];
  }

  int get _sectionQuestionNumber => _activeSection.localNumber(_currentIndex);
  int get _sectionPageCount => _activeSection.count == 0
      ? 1
      : ((_activeSection.count - 1) ~/ _sectionPageSize) + 1;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _bundle = _trimBundle(draft?.bundle ?? widget.bundle);
    // Sanitize options early to avoid duplicate/missing option rendering
    _bundle = _sanitizeBundle(_bundle);
    _sections = _buildSections(_bundle.questions);
    _answers = List<int?>.filled(_bundle.questions.length, null);
    _marked = <int>{};
    _currentIndex = 0;
    _duration = const Duration(hours: 3);
    _remainingSeconds = _duration.inSeconds;
    if (draft != null) {
      _answers = List<int?>.from(draft.answers);
      while (_answers.length < _bundle.questions.length) {
        _answers.add(null);
      }
      if (_answers.length > _bundle.questions.length) {
        _answers = _answers
            .take(_bundle.questions.length)
            .toList(growable: false);
      }
      _marked = {...draft.marked};
      _currentIndex = draft.currentIndex.clamp(
        0,
        math.max(0, _bundle.questions.length - 1),
      );
      _duration = draft.duration;
      _remainingSeconds = (draft.remainingSeconds ?? _duration.inSeconds).clamp(
        0,
        _duration.inSeconds,
      );
      _isPaused = draft.isPaused;
    }
    _sections = _buildSections(_bundle.questions);
    _syncSectionForIndex(_currentIndex);
    if (!_isPaused) {
      _startTimer();
      _enterImmersiveMode();
    }
    _saveDraft();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _exitImmersiveMode();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused || _submitting) {
        return;
      }
      if (_remainingSeconds <= 0) {
        if (!_autoSubmitted) {
          _autoSubmitted = true;
          _submit(auto: true);
        }
        return;
      }
      setState(() {
        _remainingSeconds = math.max(0, _remainingSeconds - 1);
      });
      if (_remainingSeconds <= 0 && !_autoSubmitted && !_submitting) {
        _autoSubmitted = true;
        _submit(auto: true);
      }
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = _MockTestDraft(
      bundle: _bundle,
      answers: _answers,
      marked: _marked,
      currentIndex: _currentIndex,
      duration: _duration,
      isPaused: _isPaused,
      remainingSeconds: _remainingSeconds,
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
          'sessionId': _bundle.sessionId,
          'attempt': _bundle.attempt,
          'attemptsAllowed': _bundle.attemptsAllowed,
          'questions': _bundle.questions
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
    if (_isPaused) {
      _timer?.cancel();
      _timer = null;
    } else {
      _startTimer();
    }
    _saveDraft();
  }

  void _prev() {
    if (_currentIndex == 0) return;
    _jumpToQuestion(_currentIndex - 1);
  }

  void _next({bool submitIfLast = false}) {
    if (_currentIndex < _answers.length - 1) {
      _jumpToQuestion(_currentIndex + 1);
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
    _timer?.cancel();
    _timer = null;
    final elapsedSeconds = _duration.inSeconds - _remainingSeconds;
    final elapsed = Duration(seconds: math.max(0, elapsedSeconds));
    Map<String, dynamic> result = {};
    try {
      if (_bundle.sessionId.startsWith('db_set_')) {
        result = {'status': 'ok', 'mode': 'db_set'};
      } else {
        result = await MockTestService().submitAnswers(
          sessionId: _bundle.sessionId,
          answers: _answers,
          marked: _marked,
        );
      }
    } catch (error) {
      result = {'error': error.toString()};
    }

    await _saveResult(result, elapsed);
    await _clearDraft();
    // Restore system UI before leaving the mock test
    _exitImmersiveMode();
    if (!mounted) return;
    setState(() => _submitting = false);

    Navigator.of(context).pushReplacementNamed(
      '/mock-test/result',
      arguments: MockTestResultArgs(
        bundle: _bundle,
        answers: _answers,
        marked: _marked,
        elapsed: elapsed,
        result: result,
      ),
    );
  }

  Future<void> _enterImmersiveMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {
      // ignore errors on platforms where immersive mode not supported
    }
  }

  Future<void> _exitImmersiveMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0A1220) : _kBackground;
    final currentQuestion = _currentQuestion;
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              TestHeader(
                onBack: null,
                timerText: '$minutes:$seconds',
                answered: _answered,
                total: _answers.length,
                currentIndex: _currentIndex,
                onEndTest: _submit,
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
                              padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: List.generate(_sections.length, (index) {
                                      final section = _sections[index];
                                      final isSelected = index == _activeSectionIndex;
                                      return ChoiceChip(
                                        selected: isSelected,
                                        label: Text(
                                          '${section.name} • ${section.count}',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                        ),
                                        onSelected: (_) => _switchSection(index),
                                        selectedColor: _kPrimary,
                                        backgroundColor: Colors.white,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 16),
                                  ProgressHeader(
                                    title: 'NEET Mock Test - Full Syllabus',
                                    subtitle:
                                        '${_activeSection.name} • Question ${_sectionQuestionNumber} of ${_activeSection.count}',
                                    progress: _progress,
                                    answered: _answered,
                                    total: _answers.length,
                                  ),
                                  const SizedBox(height: 16),
                                  QuestionCard(
                                    question: currentQuestion,
                                    sectionName: _activeSection.name,
                                    questionNumber: _sectionQuestionNumber,
                                    sectionCount: _activeSection.count,
                                    selectedIndex: _answers[_currentIndex],
                                    currentIndex: _currentIndex,
                                    isMarked: _marked.contains(_currentIndex),
                                    onToggleMark: _toggleMark,
                                    onSelect: _selectOption,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  BottomControls(
                                    answered: _answered,
                                    remaining: _remaining,
                                    marked: _markedCount,
                                    onPrevious: _prev,
                                    onSaveNext: () => _next(submitIfLast: true),
                                    isLast: _currentIndex == _answers.length - 1,
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
                              padding: const EdgeInsets.fromLTRB(0, 16, 18, 18),
                              child: QuestionPalette(
                                sections: _sections,
                                activeSectionIndex: _activeSectionIndex,
                                sectionPage: _sectionPage,
                                currentIndex: _currentIndex,
                                answers: _answers,
                                marked: _marked,
                                onTap: _jumpToQuestion,
                                onSectionTap: _switchSection,
                                onPreviousPage: _sectionPage == 0
                                    ? null
                                    : () {
                                        setState(() {
                                          _sectionPage = math.max(0, _sectionPage - 1);
                                        });
                                        _saveDraft();
                                      },
                                onNextPage: _sectionPage >= _sectionPageCount - 1
                                    ? null
                                    : () {
                                        setState(() {
                                          _sectionPage = math.min(_sectionPageCount - 1, _sectionPage + 1);
                                        });
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
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(_sections.length, (index) {
                              final section = _sections[index];
                              final isSelected = index == _activeSectionIndex;
                              return ChoiceChip(
                                selected: isSelected,
                                label: Text(
                                  '${section.name} • ${section.count}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                ),
                                onSelected: (_) => _switchSection(index),
                                selectedColor: _kPrimary,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 14),
                          ProgressHeader(
                            title: 'NEET Mock Test - Full Syllabus',
                            subtitle:
                                '${_activeSection.name} • Question ${_sectionQuestionNumber} of ${_activeSection.count}',
                            progress: _progress,
                            answered: _answered,
                            total: _answers.length,
                          ),
                          const SizedBox(height: 14),
                          QuestionCard(
                            question: currentQuestion,
                            sectionName: _activeSection.name,
                            questionNumber: _sectionQuestionNumber,
                            sectionCount: _activeSection.count,
                            selectedIndex: _answers[_currentIndex],
                            currentIndex: _currentIndex,
                            isMarked: _marked.contains(_currentIndex),
                            onToggleMark: _toggleMark,
                            onSelect: _selectOption,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          QuestionPalette(
                            sections: _sections,
                            activeSectionIndex: _activeSectionIndex,
                            sectionPage: _sectionPage,
                            currentIndex: _currentIndex,
                            answers: _answers,
                            marked: _marked,
                            onTap: _jumpToQuestion,
                            onSectionTap: _switchSection,
                            onPreviousPage: _sectionPage == 0
                                ? null
                                : () {
                                    setState(() {
                                      _sectionPage = math.max(0, _sectionPage - 1);
                                    });
                                    _saveDraft();
                                  },
                            onNextPage: _sectionPage >= _sectionPageCount - 1
                                ? null
                                : () {
                                    setState(() {
                                      _sectionPage = math.min(_sectionPageCount - 1, _sectionPage + 1);
                                    });
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
                            onSaveNext: () => _next(submitIfLast: true),
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
              const SizedBox(height: 12),
              if (_isPaused)
                Container(
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.38),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Text('Test paused', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: _kPrimary)),
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
        : const Color(0xFFF0FDF4);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
                onPressed: () => Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == '/mock-test/start' ||
                      route.isFirst,
                ),
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
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
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
  final VoidCallback? onBack;
  final String timerText;
  final int answered;
  final int total;
  final int currentIndex;
  final VoidCallback onEndTest;
  final double progress;

  const TestHeader({
    super.key,
    required this.onBack,
    required this.timerText,
    required this.answered,
    required this.total,
    required this.currentIndex,
    required this.onEndTest,
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
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: onBack == null ? 'Back disabled' : 'Back',
          ),
          const SizedBox(width: 8),
          // Timer placed on the left side as requested
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kPrimarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: _kPrimary, size: 16),
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
          const Spacer(),
          // End button on the right in red
          ElevatedButton(
            onPressed: onEndTest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(0, 0),
            ),
            child: Text(
              'End',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
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
              backgroundColor: const Color(0xFFDCFCE7),
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
  final String sectionName;
  final int questionNumber;
  final int sectionCount;
  final int? selectedIndex;
  final int currentIndex;
  final bool isMarked;
  final VoidCallback onToggleMark;
  final ValueChanged<int> onSelect;
  final bool isDark;

  const QuestionCard({
    super.key,
    required this.question,
    required this.sectionName,
    required this.questionNumber,
    required this.sectionCount,
    required this.selectedIndex,
    required this.currentIndex,
    required this.isMarked,
    required this.onToggleMark,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF111A2A) : _kSurface;
    final border = isDark ? const Color(0xFF223047) : const Color(0xFFE5E7EB);
    final questionImageBase64 = question.questionImageBase64?.trim();
    final hasQuestionImage = questionImageBase64?.isNotEmpty ?? false;
    Uint8List? questionImageBytes;
    if (hasQuestionImage) {
      final encodedImage = questionImageBase64!.contains(',')
          ? questionImageBase64.split(',').last
          : questionImageBase64;
      questionImageBytes = base64Decode(encodedImage);
    }
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
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SubjectBadge(subject: sectionName),
                    _TinyBadge(
                      text: 'Q$questionNumber / $sectionCount',
                      color: _kPrimarySoft,
                      textColor: _kPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onToggleMark,
                icon: Icon(
                  isMarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(
                  isMarked ? 'Marked' : 'Mark for Review',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasQuestionImage) ...[
            if (questionImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(10),
                  child: Image.memory(
                    questionImageBytes,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
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
          color: selected ? const Color(0xFFF0FDF4) : Colors.transparent,
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
  final List<_MockTestSection> sections;
  final int activeSectionIndex;
  final int sectionPage;
  final int currentIndex;
  final List<int?> answers;
  final Set<int> marked;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onSectionTap;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final bool isDark;

  const QuestionPalette({
    super.key,
    required this.sections,
    required this.activeSectionIndex,
    required this.sectionPage,
    required this.currentIndex,
    required this.answers,
    required this.marked,
    required this.onTap,
    required this.onSectionTap,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF111A2A) : _kSurface;
    final activeSection = sections[activeSectionIndex];
    final visibleStart = activeSection.startIndex + (sectionPage * 10);
    final visibleEnd = math.min(activeSection.endIndex, visibleStart + 9);
    final visibleIndexes = visibleStart <= visibleEnd
        ? [for (var index = visibleStart; index <= visibleEnd; index++) index]
        : <int>[];
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question Palette',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${activeSection.name} • ${visibleStart - activeSection.startIndex + 1}-${visibleEnd - activeSection.startIndex + 1} of ${activeSection.count}',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  IconButton(
                    onPressed: onPreviousPage,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous 10',
                  ),
                  IconButton(
                    onPressed: onNextPage,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next 10',
                  ),
                ],
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
                itemCount: visibleIndexes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final questionIndex = visibleIndexes[index];
                  final isCurrent = questionIndex == currentIndex;
                  final isAnswered = answers[questionIndex] != null;
                  final isMarked = marked.contains(questionIndex);
                  Color bg = isDark ? const Color(0xFF0F172A) : Colors.white;
                  Color border = isDark
                      ? const Color(0xFF2B3750)
                      : const Color(0xFFD4D4DD);
                  Color text = isDark ? Colors.white : Colors.black87;
                  if (isAnswered) {
                    bg = const Color(0xFF14532D);
                    border = const Color(0xFF14532D);
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
                    onTap: () => onTap(questionIndex),
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
                        '${activeSection.localNumber(questionIndex)}',
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
              _LegendChip(color: Color(0xFF14532D), label: 'Answered'),
              _LegendChip(color: Color(0xFFF59E0B), label: 'Marked'),
              _LegendChip(color: Color(0xFFDCFCE7), label: 'Current'),
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
  final VoidCallback onSaveNext;
  final bool isLast;

  const BottomControls({
    super.key,
    required this.answered,
    required this.remaining,
    required this.marked,
    required this.onPrevious,
    required this.onSaveNext,
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
              children: [controls[0], const SizedBox(height: 10), controls[1]],
            );
          }

          return Row(
            children: [
              Expanded(child: controls[0]),
              const SizedBox(width: 10),
              Expanded(child: controls[1]),
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
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 120),
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
          colors: [Color(0xFFDCFCE7), Colors.white],
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
        final crossAxisCount = constraints.maxWidth > 720 ? 3 : 2;
        final mainAxisExtent = constraints.maxWidth > 720 ? 132.0 : 122.0;
        final cards = [
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
            label: 'Time Taken',
            value: _formatDuration(metrics.elapsed),
            color: Colors.black87,
          ),
        ];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) => cards[index],
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        showTitle: false,
      ),
      PieChartSectionData(
        value: metrics.wrong.toDouble(),
        color: const Color(0xFFEF4444),
        radius: 54,
        showTitle: false,
      ),
      PieChartSectionData(
        value: metrics.skipped.toDouble(),
        color: const Color(0xFF3B82F6),
        radius: 54,
        showTitle: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
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
          const SizedBox(height: 18),
          _ChartCard(
            title: 'Accuracy Split',
            child: Column(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      centerSpaceRadius: 44,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(const Color(0xFF22C55E), 'Correct'),
                    const SizedBox(width: 16),
                    _buildLegendItem(const Color(0xFFEF4444), 'Wrong'),
                    const SizedBox(width: 16),
                    _buildLegendItem(const Color(0xFF3B82F6), 'Skipped'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
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
                      backgroundColor: const Color(0xFFDCFCE7),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 720 ? 4 : 2;
              final mainAxisExtent = constraints.maxWidth > 720 ? 132.0 : 122.0;
              final cards = [
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
                  color: const Color(0xFF3B82F6),
                ),
                StatCard(
                  label: 'Negative Marks',
                  value: '-${metrics.wrong}',
                  color: const Color(0xFFB91C1C),
                ),
              ];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: mainAxisExtent,
                ),
                itemBuilder: (context, index) => cards[index],
              );
            },
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
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
          colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF4)],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Full Mock Test',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Attempt a full NEET-style mock test covering all subjects.',
                      style: GoogleFonts.poppins(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
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
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'NEET Mock Test Structure',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const _PatternRow(label: 'Physics', value: '45 Questions'),
          const Divider(height: 1),
          const _PatternRow(label: 'Chemistry', value: '45 Questions'),
          const Divider(height: 1),
          const _PatternRow(label: 'Biology', value: '90 Questions'),
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
            'Attempt quizzes for separate units and practice topic by topic.',
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

class _CombinedMockCard extends StatelessWidget {
  final VoidCallback onStart;
  final bool loading;

  const _CombinedMockCard({required this.onStart, required this.loading});

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Full NEET Mock Test',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take the complete NEET-style paper with Physics, Chemistry, and Biology in exam conditions.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: loading ? null : onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
