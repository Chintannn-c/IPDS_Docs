import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // MINIMALISTIC COLOR PALETTE
  // ═══════════════════════════════════════════════════════════════════════════

  // Light Theme Colors
  static const Color _lightBackground = Color(0xFFF8FAFC);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightPrimary = Color(0xFF3B82F6);
  static const Color _lightSecondary = Color(0xFF64748B);
  static const Color _lightSuccess = Color(0xFF22C55E);
  static const Color _lightWarning = Color(0xFFF59E0B);
  static const Color _lightError = Color(0xFFEF4444);
  static const Color _lightTextPrimary = Color(0xFF1E293B);
  static const Color _lightTextSecondary = Color(0xFF64748B);

  // Dark Theme Colors
  static const Color _darkBackground = Color(0xFF0F172A);
  static const Color _darkSurface = Color(0xFF1E293B);
  static const Color _darkPrimary = Color(0xFF3B82F6);
  static const Color _darkSecondary = Color(0xFF64748B);
  static const Color _darkSuccess = Color(0xFF22C55E);
  static const Color _darkWarning = Color(0xFFF59E0B);
  static const Color _darkError = Color(0xFFEF4444);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextSecondary = Color(0xFF94A3B8);

  // ═══════════════════════════════════════════════════════════════════════════
  // DESIGN TOKENS
  // ═══════════════════════════════════════════════════════════════════════════

  // Border Radius Scale
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE-FIRST TOKENS
  // ═══════════════════════════════════════════════════════════════════════════

  // Touch Targets (Accessibility - minimum 48px)
  static const double touchTargetMin = 48.0;
  static const double touchTargetLarge = 56.0;

  // Spacing Scale
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC STATUS COLORS (Non-alarming, security-focused)
  // ═══════════════════════════════════════════════════════════════════════════

  static Color get statusSecure => _darkSuccess.withOpacity(0.12);
  static Color get statusSecureText => _darkSuccess;
  static Color get statusMonitoring => _darkPrimary.withOpacity(0.12);
  static Color get statusMonitoringText => _darkPrimary;
  static Color get statusAttention => _darkWarning.withOpacity(0.12);
  static Color get statusAttentionText => _darkWarning;
  static Color get statusCritical => _darkError.withOpacity(0.12);
  static Color get statusCriticalText => _darkError;

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static TextTheme _buildTextTheme(
    TextTheme base,
    Color primary,
    Color secondary,
  ) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: primary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: secondary),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: secondary),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    final base = ThemeData.light();

    return base.copyWith(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: _lightSecondary,
        surface: _lightSurface,
        error: _lightError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _lightTextPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _lightBackground,
      textTheme: _buildTextTheme(
        base.textTheme,
        _lightTextPrimary,
        _lightTextSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _lightTextPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: _lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: _lightSecondary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: _lightSecondary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _lightPrimary, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: _lightTextSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: _lightSecondary.withOpacity(0.1)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    return base.copyWith(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkSurface,
        error: _darkError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _darkTextPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: _buildTextTheme(
        base.textTheme,
        _darkTextPrimary,
        _darkTextSecondary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _darkTextPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: _darkSecondary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: _darkSecondary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: _darkPrimary, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: _darkTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: _darkTextSecondary,
        suffixIconColor: _darkTextSecondary,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: _darkSecondary.withOpacity(0.15)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC GETTERS — FIXED AND WORKING
  // ═══════════════════════════════════════════════════════════════════════════

  static Color get primaryColor => _darkPrimary;
  static Color get successColor => _darkSuccess;
  static Color get warningColor => _darkWarning;
  static Color get errorColor => _darkError;
  static Color get surfaceColor => _darkSurface;
  static Color get backgroundColor => _darkBackground;
  static Color get textPrimary => _darkTextPrimary;
  static Color get textSecondary => _darkTextSecondary;

  static get primary => null;
}
