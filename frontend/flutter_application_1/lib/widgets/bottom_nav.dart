import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:flutter_application_1/screens/mock_test_flow.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const BottomNav({super.key, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
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
          // Open profile editing directly from bottom nav
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          return;
        }
        onTap(index);
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.check_box_outlined), label: 'Mock Test'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'AI Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}
