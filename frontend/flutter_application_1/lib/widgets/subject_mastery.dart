import 'package:flutter/material.dart';

class SubjectMastery extends StatelessWidget {
  final List subjects;
  final void Function(String subjectTitle)? onSubjectTap;

  const SubjectMastery({
    super.key,
    required this.subjects,
    this.onSubjectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: subjects.map((s) {
        final title = s['title'] as String;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onSubjectTap == null ? null : () => onSubjectTap!(title),
          ),
        );
      }).toList(),
    );
  }
}
