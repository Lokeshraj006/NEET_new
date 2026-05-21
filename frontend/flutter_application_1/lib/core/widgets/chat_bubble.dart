import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../../services/auth_service.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({super.key, required this.text, required this.isUser});

  static final RegExp _sectionHeading = RegExp(
    r'^(Definition|Structure|Function/Mechanism|Function|Mechanism|Key Points|Summary|Formula)\s*$',
    caseSensitive: false,
  );

  List<InlineSpan> _inlineBoldSpans(String value, TextStyle style) {
    final spans = <InlineSpan>[];
    final matches = RegExp(r'\*\*(.+?)\*\*').allMatches(value);
    var last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: value.substring(last, m.start), style: style));
      }
      final boldText = m.group(1) ?? '';
      spans.add(TextSpan(text: boldText, style: style.copyWith(fontWeight: FontWeight.w700)));
      last = m.end;
    }
    if (last < value.length) {
      spans.add(TextSpan(text: value.substring(last), style: style));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: value, style: style));
    }
    return spans;
  }

  List<InlineSpan> _messageSpans(String rawText, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final lines = rawText.replaceAll('\r\n', '\n').split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (!isUser && _sectionHeading.hasMatch(trimmed)) {
        spans.add(TextSpan(text: trimmed, style: baseStyle.copyWith(fontWeight: FontWeight.w700)));
      } else {
        spans.addAll(_inlineBoldSpans(line, baseStyle));
      }

      if (i != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? AppColors.primary : AppColors.surface;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final avatar = isUser
        ? ValueListenableBuilder<String?>(
            valueListenable: AuthService.photoNotifier,
            builder: (context, photoB64, _) {
              return _AvatarChip(
                backgroundColor: AppColors.primarySoft,
                icon: Icons.person_rounded,
                iconColor: AppColors.primary,
                imageBytes: photoB64 == null ? null : base64Decode(photoB64),
              );
            },
          )
        : const _AvatarChip(
            backgroundColor: AppColors.primarySoft,
            icon: Icons.smart_toy_rounded,
            iconColor: AppColors.primary,
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              avatar,
              const SizedBox(width: 8),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 8),
                  bottomRight: Radius.circular(isUser ? 8 : 22),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0E000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 14,
                    height: 1.45,
                  ),
                  children: _messageSpans(
                    text,
                    GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            if (isUser) ...[
              const SizedBox(width: 8),
              avatar,
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final Uint8List? imageBytes;

  const _AvatarChip({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: imageBytes != null
            ? Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
              )
            : Icon(icon, color: iconColor, size: 16),
      ),
    );
  }
}
