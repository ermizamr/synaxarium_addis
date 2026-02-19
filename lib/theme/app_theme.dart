import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    cardTheme: _cardTheme,
    filledButtonTheme: _filledButtonTheme,
    outlinedButtonTheme: _outlinedButtonTheme,
    inputDecorationTheme: _inputDecorationTheme,
  );

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: Color(0xFF7C3AED), // Purple
    primaryContainer: Color(0xFFF5F3FF), // Light Purple
    secondary: Color(0xFF3B82F6), // Blue
    secondaryContainer: Color(0xFFEFF6FF), // Light Blue
    tertiary: Color(0xFF10B981), // Green
    tertiaryContainer: Color(0xFFECFDF5), // Light Green
    error: Color(0xFFEF4444),
    surface: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFFF9FAFB),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Color(0xFF1F2937),
    onSurfaceVariant: Color(0xFF6B7280),
  );

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );

  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 4,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  static const InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      );
}

class TierColors {
  static const List<Color> demoGradient = [
    Color(0xFF9CA3AF),
    Color(0xFF6B7280),
  ]; // Gray
  static const List<Color> normalGradient = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
  ]; // Blue to Purple
  static const List<Color> vipGradient = [
    Color(0xFFFBBF24),
    Color(0xFFF97316),
  ]; // Yellow to Orange
  static const List<Color> lockedGradient = [
    Color(0xFFF97316),
    Color(0xFFFBBF24),
  ]; // Orange to Yellow
}
