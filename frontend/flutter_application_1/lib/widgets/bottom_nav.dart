import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/widgets/bottom_nav_bar.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNav({super.key, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavBar(
      selectedIndex: selectedIndex,
      onTap: (index) {
        if (index == 1) {
          Navigator.of(context).pushNamed('/mock-test/start');
          return;
        }
        if (index == 2) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
          return;
        }
        if (index == 3) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          return;
        }
        onTap(index);
      },
    );
  }
}
