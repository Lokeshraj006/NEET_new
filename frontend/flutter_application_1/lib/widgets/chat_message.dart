import 'dart:convert';

import 'package:flutter/material.dart';

class ChatMessageModel {
  final String text;
  final bool isUser;
  ChatMessageModel({required this.text, required this.isUser});
}

class ChatMessageWidget extends StatelessWidget {
  final ChatMessageModel message;
  const ChatMessageWidget({super.key, required this.message});

  String _normalizeHeading(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'key point' ||
        normalized == 'key points' ||
        normalized == 'key poin') {
      return 'Key Points';
    }
    if (normalized == 'function' ||
        normalized == 'mechanism' ||
        normalized == 'function/mechanism') {
      return 'Function/Mechanism';
    }
    if (normalized == 'definition') {
      return 'Definition';
    }
    if (normalized == 'structure') {
      return 'Structure';
    }
    if (normalized == 'summary') {
      return 'Summary';
    }
    if (normalized == 'formula') {
      return 'Formula';
    }
    return value;
  }

  bool _isHeading(String value) {
    return RegExp(
      r'^(Definition|Structure|Function/Mechanism|Function|Mechanism|Key Points|Key Point|Key Poin|Summary|Formula)$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  List<_ChatLine> _removeEmptyHeadingBlocks(List<_ChatLine> input) {
    final output = <_ChatLine>[];
    for (var i = 0; i < input.length; i++) {
      final line = input[i];
      if (line.type != _ChatLineType.heading) {
        output.add(line);
        continue;
      }

      var j = i + 1;
      while (j < input.length && input[j].type == _ChatLineType.blank) {
        j++;
      }

      final isDangling =
          j >= input.length || input[j].type == _ChatLineType.heading;
      if (!isDangling) {
        output.add(line);
      }
    }
    return output;
  }

  List<_ChatLine> _parseLines(String text) {
    final lines = <_ChatLine>[];
    final rawLines = text.replaceAll('\r\n', '\n').split('\n');
    String? lastHeading;

    bool isHeadingLabel(String value) {
      return _isHeading(value);
    }

    String cleanBulletBody(String value) {
      return value.replaceFirst(RegExp(r'^[•\-*â€¢€¢¢.\s]+'), '').trim();
    }

    for (final raw in rawLines) {
      final line = raw.trim();
      if (line.isEmpty) {
        lines.add(const _ChatLine.blank());
        continue;
      }

      if (isHeadingLabel(line)) {
        final heading = _normalizeHeading(line);
        if (lastHeading?.toLowerCase() != heading.toLowerCase()) {
          lastHeading = heading;
          lines.add(_ChatLine.heading(heading));
        }
        continue;
      }

      final headingMatch = RegExp(
        r'^(Definition|Structure|Function/Mechanism|Function|Mechanism|Key Points|Key Point|Key Poin|Summary|Formula)\s*:\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (headingMatch != null) {
        final heading = _normalizeHeading(headingMatch.group(1) ?? '');
        if (lastHeading?.toLowerCase() == heading.toLowerCase()) {
          continue;
        }
        lastHeading = heading;
        lines.add(_ChatLine.heading(heading));
        continue;
      }

      final headingInlineMatch = RegExp(
        r'^(Definition|Structure|Function/Mechanism|Function|Mechanism|Key Points|Key Point|Key Poin|Summary|Formula)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (headingInlineMatch != null) {
        final heading = _normalizeHeading(headingInlineMatch.group(1) ?? '');
        final body = (headingInlineMatch.group(2) ?? '').trim();
        if (lastHeading?.toLowerCase() != heading.toLowerCase()) {
          lines.add(_ChatLine.heading(heading));
        }
        lastHeading = heading;
        if (body.isNotEmpty && body.toLowerCase() != heading.toLowerCase()) {
          lines.add(_ChatLine.body(body));
        }
        continue;
      }

      final bulletMatch = RegExp(
        r'^(?:[.·]\s*)?[•\-*â€¢€¢¢]\s*(.+)$',
      ).firstMatch(line);
      if (bulletMatch != null) {
        final body = cleanBulletBody(bulletMatch.group(1) ?? '');
        if (body.isNotEmpty) {
          lines.add(_ChatLine.bullet(body));
        }
        continue;
      }

      final currentHeading = lastHeading;
      if (currentHeading != null &&
          line.toLowerCase() == currentHeading.toLowerCase()) {
        continue;
      }

      lines.add(_ChatLine.body(line));
    }

    return _removeEmptyHeadingBlocks(lines);
  }

  String _repairMojibake(String input) {
    try {
      final repaired = utf8.decode(latin1.encode(input), allowMalformed: true);
      final repairedBad = '\uFFFD'.allMatches(repaired).length;
      final originalBad = '\uFFFD'.allMatches(input).length;
      if (repairedBad <= originalBad) {
        return repaired;
      }
    } catch (_) {
      // Keep the original text when conversion fails.
    }
    return input;
  }

  String _cleanText(String input) {
    final repaired = _repairMojibake(input);
    return repaired
        .replaceAll('â€¢', '•')
        .replaceAll('€¢', '•')
        .replaceAll('ï¿¢', '•')
        .replaceAll('â€“', '-')
        .replaceAll('â€”', '-')
        .replaceAll('â€™', "'")
        .replaceAll('â€˜', "'")
        .replaceAll('â€²', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('Â', '')
        .replaceAll('Î¸', 'theta')
        .replaceAll('θ', 'theta')
        .replaceAll('₁', '1')
        .replaceAll('₂', '2')
        .replaceAll('\uFFFD', '')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'__(.+?)__'), r'$1')
        .replaceAll(RegExp(r'`([^`]*)`'), r'$1');
  }

  List<InlineSpan> _buildSpans(BuildContext context, List<_ChatLine> lines) {
    final bodyStyle = TextStyle(
      color: message.isUser ? Colors.white : Colors.black87,
      height: 1.35,
      fontSize: 15,
    );
    final headingStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
    final filtered = lines.where((l) => l.type != _ChatLineType.blank).toList();
    final spans = <InlineSpan>[];

    for (var i = 0; i < filtered.length; i++) {
      final line = filtered[i];
      final isLast = i == filtered.length - 1;
      final nextIsHeading = !isLast && filtered[i + 1].type == _ChatLineType.heading;

      String ensurePeriod(String t) {
        if (t.isEmpty) return t;
        final last = t[t.length - 1];
        if (RegExp(r'[.!?:,;]').hasMatch(last)) return t;
        return '$t.';
      }

      switch (line.type) {
        case _ChatLineType.heading:
          if (i != 0) spans.add(const TextSpan(text: '\n\n'));
          spans.add(TextSpan(text: line.text, style: headingStyle));
          spans.add(const TextSpan(text: '\n'));
          break;
        case _ChatLineType.bullet:
          final t = message.isUser ? line.text : ensurePeriod(line.text);
          spans.add(TextSpan(text: '\u2022 $t', style: bodyStyle));
          if (!isLast && !nextIsHeading) spans.add(const TextSpan(text: '\n'));
          break;
        case _ChatLineType.body:
          final t = message.isUser ? line.text : ensurePeriod(line.text);
          spans.add(TextSpan(text: t, style: bodyStyle));
          if (!isLast && !nextIsHeading) spans.add(const TextSpan(text: '\n'));
          break;
        case _ChatLineType.blank:
          break;
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final color = message.isUser
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    final textColor = message.isUser ? Colors.white : Colors.black87;
    final cleanedText = _cleanText(message.text);
    final parsedLines = _parseLines(cleanedText);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Card(
                color: color,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: textColor),
                      children: _buildSpans(context, parsedLines) ,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChatLineType { heading, body, bullet, blank }

class _ChatLine {
  final _ChatLineType type;
  final String text;

  const _ChatLine._(this.type, this.text);

  const _ChatLine.heading(String text) : this._(_ChatLineType.heading, text);
  const _ChatLine.body(String text) : this._(_ChatLineType.body, text);
  const _ChatLine.bullet(String text) : this._(_ChatLineType.bullet, text);
  const _ChatLine.blank() : this._(_ChatLineType.blank, '');
}
