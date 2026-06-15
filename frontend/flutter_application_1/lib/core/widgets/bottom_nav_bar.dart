import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({super.key, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF071426) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: background,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: background,
            indicatorColor: isDark ? AppColors.primarySoft : AppColors.primarySoft,
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
              return TextStyle(
                fontSize: 12,
                height: 1.0,
                color: states.contains(WidgetState.selected)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onTap,
            backgroundColor: background,
            indicatorColor: AppColors.primarySoft,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, size: 22),
                selectedIcon: Icon(Icons.dashboard_rounded, size: 22),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined, size: 22),
                selectedIcon: Icon(Icons.checklist_rounded, size: 22),
                label: 'Mock Test',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline, size: 22),
                selectedIcon: Icon(Icons.chat_bubble_rounded, size: 22),
                label: 'AI Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, size: 22),
                selectedIcon: Icon(Icons.person_rounded, size: 22),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
