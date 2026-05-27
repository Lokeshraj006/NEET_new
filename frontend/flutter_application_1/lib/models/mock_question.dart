class MockQuestion {
  final String subject;
  final String unit;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String correctAnswer;
  final String explanation;
  final String hash;
  final String? questionImageBase64;
  final int? sourcePage;
  final int? setNumber;

  const MockQuestion({
    required this.subject,
    required this.unit,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.correctAnswer,
    required this.explanation,
    required this.hash,
    this.questionImageBase64,
    this.sourcePage,
    this.setNumber,
  });

  String get topic => unit;

  static String _cleanText(dynamic value) {
    return value == null
        ? ''
        : value.toString().replaceAll('\u00a0', ' ').trim();
  }

  static String _stripQuestionNumber(String value) {
    return value
        .replaceFirst(
          RegExp(r'^\s*(?:Q\s*)?\d+[\).:-]?\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  static String _stripOptionPrefix(String value) {
    return value
        .replaceFirst(RegExp(r'^\s*(?:\(?\s*[A-Da-d1-4]\s*\)?[\).:-]\s*)'), '')
        .trim();
  }

  static String _stringFromJsonValue(dynamic value) {
    if (value is Map) {
      for (final key in const [
        'text',
        'value',
        'option',
        'label',
        'content',
        'answer',
      ]) {
        final nested = value[key];
        if (nested != null && nested.toString().trim().isNotEmpty) {
          return _cleanText(nested);
        }
      }
    }
    return _cleanText(value);
  }

  static List<String> _uniqueOptions(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final cleaned = _stripOptionPrefix(_cleanText(value));
      if (cleaned.isEmpty || !seen.add(cleaned)) {
        continue;
      }
      result.add(cleaned);
      if (result.length == 4) {
        break;
      }
    }
    return result;
  }

  static List<String> _optionsFromInlineQuestion(String question) {
    final lines = question.split(RegExp(r'\r?\n'));
    final stem = <String>[];
    final options = <String>[];
    final optionPattern = RegExp(
      r'^\s*(?:\(?\s*([A-Da-d1-4])\s*\)?[\).:-])\s*(.+)$',
    );
    StringBuffer? currentOption;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (currentOption != null) {
          currentOption.writeln();
        }
        continue;
      }

      final match = optionPattern.firstMatch(line);
      if (match != null) {
        if (currentOption != null) {
          options.add(_stripOptionPrefix(currentOption.toString()));
        }
        currentOption = StringBuffer(match.group(2) ?? '');
        continue;
      }

      if (currentOption != null) {
        if (currentOption.isNotEmpty) currentOption.write(' ');
        currentOption.write(line);
      } else {
        stem.add(line);
      }
    }

    if (currentOption != null) {
      options.add(_stripOptionPrefix(currentOption.toString()));
    }

    return _uniqueOptions(options);
  }

  static List<String> optionsFromInlineQuestion(String question) {
    return _optionsFromInlineQuestion(question);
  }

  static int _answerIndexFromJson(Map<String, dynamic> json) {
    final rawIndex = json['answer_index'];
    if (rawIndex is int) {
      return rawIndex.clamp(0, 3);
    }
    final rawLetter = (json['correct_answer'] ?? json['correctAnswer'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (rawLetter.length == 1 &&
        rawLetter.codeUnitAt(0) >= 65 &&
        rawLetter.codeUnitAt(0) <= 68) {
      return rawLetter.codeUnitAt(0) - 65;
    }
    return (int.tryParse('${rawIndex ?? 0}') ?? 0).clamp(0, 3).toInt();
  }

  static List<String> _optionsFromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    if (raw is Map) {
      final orderedKeys = const [
        'A',
        'B',
        'C',
        'D',
        'a',
        'b',
        'c',
        'd',
        '1',
        '2',
        '3',
        '4',
        'optionA',
        'optionB',
        'optionC',
        'optionD',
        'option_a',
        'option_b',
        'option_c',
        'option_d',
      ];
      final values = <String>[];
      for (final key in orderedKeys) {
        if (values.length == 4) break;
        final entry = raw[key];
        if (entry == null) continue;
        final text = _stripOptionPrefix(_stringFromJsonValue(entry));
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
      if (values.length == 4) return values;
      final fallback = raw.values
          .map(_stringFromJsonValue)
          .map(_stripOptionPrefix)
          .where((value) => value.isNotEmpty)
          .toList();
      if (fallback.length >= 4) return fallback.take(4).toList();
    }
    if (raw is List) {
      final values = _uniqueOptions(
        raw
            .map(_stringFromJsonValue)
            .map(_stripOptionPrefix)
            .where((value) => value.isNotEmpty),
      );
      if (values.length == 4) return values;

      final merged = <String>[...values];
      final inlineOptions = _optionsFromInlineQuestion(
        _cleanText(json['question']),
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
      // Preserve source order and pad only as a last resort for rendering.
      while (values.length < 4) {
        values.add('');
      }
      if (merged.length >= 4) return merged.take(4).toList(growable: false);
      return values;
    }
    final inlineOptions = _optionsFromInlineQuestion(
      _cleanText(json['question']),
    );
    if (inlineOptions.length == 4) return inlineOptions;
    return const [];
  }

  factory MockQuestion.fromJson(Map<String, dynamic> json) {
    final topic = (json['topic'] ?? json['unit'] ?? '').toString();
    final subject = (json['subject'] ?? 'NEET').toString();
    final correctAnswer =
        (json['correctAnswer'] ?? json['correct_answer'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
    final answerIndex = _answerIndexFromJson(json);
    return MockQuestion(
      subject: subject,
      unit: topic,
      question: _stripQuestionNumber(_cleanText(json['question'])),
      options: _optionsFromJson(json),
      answerIndex: answerIndex,
      correctAnswer: correctAnswer,
      explanation: (json['explanation'] ?? '').toString(),
      hash: (json['hash'] ?? '').toString(),
      questionImageBase64: _cleanText(
        json['question_image'] ?? json['page_image'] ?? json['image_base64'],
      ),
      sourcePage: int.tryParse('${json['source_page'] ?? ''}'),
      setNumber: int.tryParse(
        '${json['setNumber'] ?? json['set_number'] ?? ''}',
      ),
    );
  }
}
