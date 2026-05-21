import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../screens/chat_screen.dart';

class AIStarterCard extends StatelessWidget {
  const AIStarterCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: _CardText(),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
            child: const Text('Ask AI'),
          ),
        ],
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const _CardText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medical AI Assistant', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Get instant NEET explanations, concept breakdowns, and quick doubts solved.',
          style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}
