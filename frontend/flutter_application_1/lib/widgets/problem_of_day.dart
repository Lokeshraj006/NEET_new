import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

class ProblemOfDay extends StatefulWidget {
  final Map problem;
  const ProblemOfDay({super.key, required this.problem});

  @override
  State<ProblemOfDay> createState() => _ProblemOfDayState();
}

class _ProblemOfDayState extends State<ProblemOfDay> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
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
                child: Text(widget.problem['subject'], style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Text('Problem of the Day', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(widget.problem['question'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...List.generate(widget.problem['options'].length, (i) {
            final opt = widget.problem['options'][i];
            final isSelected = selected == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => selected = i),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(opt, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: () {}, child: const Text('View Solution')),
          ),
        ],
      ),
    );
  }
}
