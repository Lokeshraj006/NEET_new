import 'package:flutter/material.dart';

const Color kBackground = Color(0xFFF5F5F5);
const Color kPrimaryGreen = Color(0xFF3E4F4F);

ThemeData buildAppTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: kBackground,
    colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryGreen, primary: kPrimaryGreen),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 2,
      foregroundColor: Colors.black87,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textTheme: base.textTheme.copyWith(
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyLarge: const TextStyle(fontSize: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryGreen,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: Colors.grey),
    ),
  );
}
