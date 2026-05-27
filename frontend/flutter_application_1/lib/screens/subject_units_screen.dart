import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/widgets/info_card.dart';
import 'package:flutter_application_1/screens/unit_quiz_screen.dart';
import 'package:flutter_application_1/widgets/bottom_nav.dart';

class UnitNode {
  final String title;
  final List<UnitNode> children;

  const UnitNode({required this.title, this.children = const []});

  bool get hasChildren => children.isNotEmpty;
}

class SubjectUnitsScreen extends StatelessWidget {
  final String title;
  final List<UnitNode> units;
  final bool allowStartQuiz;

  const SubjectUnitsScreen({
    super.key,
    required this.title,
    required this.units,
    this.allowStartQuiz = false,
  });

  factory SubjectUnitsScreen.forSubject(String subject, {bool allowStartQuiz = false}) {
    switch (subject) {
      case 'Physics':
        return SubjectUnitsScreen(
          title: 'Physics Units',
          units: _physicsUnits,
          allowStartQuiz: allowStartQuiz,
        );
      case 'Chemistry':
        return SubjectUnitsScreen(
          title: 'Chemistry Units',
          units: _chemistryUnits,
          allowStartQuiz: allowStartQuiz,
        );
      case 'Biology':
        return SubjectUnitsScreen(
          title: 'Biology Units',
          units: _biologyUnits,
          allowStartQuiz: allowStartQuiz,
        );
      default:
        return SubjectUnitsScreen(
          title: subject,
          units: const [],
          allowStartQuiz: allowStartQuiz,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: units.length,
        itemBuilder: (context, index) {
          final unit = units[index];
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
            child: InfoCard(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  unit.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: unit.hasChildren
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tap to open sub-topics',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : null,
                trailing: unit.hasChildren
                    ? const Icon(Icons.chevron_right_rounded)
                    : (allowStartQuiz
                        ? FilledButton.tonalIcon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UnitQuizScreen(
                                    subject: title.replaceAll(' Units', '').trim(),
                                    unitTitle: unit.title,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.quiz_rounded),
                            label: const Text('Quiz'),
                          )
                        : const Icon(Icons.chevron_right_rounded)),
                onTap: () {
                  if (unit.hasChildren) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SubjectUnitsScreen(
                          title: unit.title,
                          units: unit.children,
                          allowStartQuiz: allowStartQuiz,
                        ),
                      ),
                    );
                  } else if (allowStartQuiz) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UnitQuizScreen(
                          subject: title.replaceAll(' Units', '').trim(),
                          unitTitle: unit.title,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: 1,
        onTap: (_) => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}

const List<UnitNode> _physicsUnits = [
  UnitNode(title: 'Physics and Measurement'),
  UnitNode(title: 'Kinematics'),
  UnitNode(title: 'Laws of Motion'),
  UnitNode(title: 'Work, Energy and Power'),
  UnitNode(title: 'Rotational Motion'),
  UnitNode(title: 'Gravitation'),
  UnitNode(title: 'Properties of Solids and Liquids'),
  UnitNode(title: 'Thermodynamics'),
  UnitNode(title: 'Kinetic Theory of Gases'),
  UnitNode(title: 'Oscillations and Waves'),
  UnitNode(title: 'Electrostatics'),
  UnitNode(title: 'Current Electricity'),
  UnitNode(title: 'Magnetic Effects of Current and Magnetism'),
  UnitNode(title: 'Electromagnetic Induction and Alternating Currents'),
  UnitNode(title: 'Electromagnetic Waves'),
  UnitNode(title: 'Optics'),
  UnitNode(title: 'Dual Nature of Matter and Radiation'),
  UnitNode(title: 'Atoms and Nuclei'),
  UnitNode(title: 'Electronic Devices'),
];

const List<UnitNode> _chemistryUnits = [
  UnitNode(
    title: 'Physical Chemistry',
    children: [
      UnitNode(title: 'Some Basic Concepts in Chemistry'),
      UnitNode(title: 'Atomic Structure'),
      UnitNode(title: 'Chemical Bonding and Molecular Structure'),
      UnitNode(title: 'Chemical Thermodynamics'),
      UnitNode(title: 'Equilibrium'),
      UnitNode(title: 'Solutions'),
      UnitNode(title: 'Redox Reactions and Electrochemistry'),
      UnitNode(title: 'Chemical Kinetics'),
    ],
  ),
  UnitNode(
    title: 'Inorganic Chemistry',
    children: [
      UnitNode(title: 'Classification of Elements and Periodicity in Properties'),
      UnitNode(title: 'P-Block Elements'),
      UnitNode(title: 'd- and f-Block Elements'),
      UnitNode(title: 'Co-ordination Compounds'),
    ],
  ),
  UnitNode(
    title: 'Organic Chemistry',
    children: [
      UnitNode(title: 'Purification and Characterisation of Organic Compounds'),
      UnitNode(title: 'Some Basic Principles of Organic Chemistry'),
      UnitNode(title: 'Hydrocarbons'),
      UnitNode(title: 'Organic Compounds Containing Halogens'),
      UnitNode(title: 'Organic Compounds Containing Oxygen'),
      UnitNode(title: 'Organic Compounds Containing Nitrogen'),
      UnitNode(title: 'Biomolecules'),
      UnitNode(title: 'Principles Related to Practical Chemistry'),
    ],
  ),
];

const List<UnitNode> _biologyUnits = [
  UnitNode(title: 'Diversity in Living World'),
  UnitNode(title: 'Structural Organisation in Animals and Plants'),
  UnitNode(title: 'Cell Structure and Function'),
  UnitNode(title: 'Plant Physiology'),
  UnitNode(title: 'Human Physiology'),
  UnitNode(title: 'Reproduction'),
  UnitNode(title: 'Genetics and Evolution'),
  UnitNode(title: 'Biology and Human Welfare'),
  UnitNode(title: 'Biotechnology and Its Applications'),
  UnitNode(title: 'Ecology and Environment'),
];