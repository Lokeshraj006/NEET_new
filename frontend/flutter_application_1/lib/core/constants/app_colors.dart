import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/theme_service.dart';

class AppColors {
  static const primary = Color(0xFF14532D);
  static const Color _lightPrimarySoft = Color(0xFFDCFCE7);
  static const Color _darkPrimarySoft = Color(0xFF18301F);
  static const Color _lightBackground = Color(0xFFF0FDF4);
  static const Color _darkBackground = Color(0xFF071018);
  static const Color _lightSurface = Colors.white;
  static const Color _darkSurface = Color(0xFF0B1220);
  static const Color _lightTextPrimary = Color(0xFF1F2430);
  static const Color _darkTextPrimary = Color(0xFFF8FAFC);
  static const Color _lightTextSecondary = Color(0xFF667085);
  static const Color _darkTextSecondary = Color(0xFFCBD5E1);
  static const Color _lightBorder = Color(0xFFE6EAF2);
  static const Color _darkBorder = Color(0xFF223043);

  static bool get _isDark {
    final mode = ThemeService.mode.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  static Color get primarySoft => _isDark ? _darkPrimarySoft : _lightPrimarySoft;
  static Color get background => _isDark ? _darkBackground : _lightBackground;
  static Color get surface => _isDark ? _darkSurface : _lightSurface;
  static Color get textPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
  static Color get textSecondary => _isDark ? _darkTextSecondary : _lightTextSecondary;
  static Color get border => _isDark ? _darkBorder : _lightBorder;
  static const success = Color(0xFF1F9D55);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFE5484D);
}
