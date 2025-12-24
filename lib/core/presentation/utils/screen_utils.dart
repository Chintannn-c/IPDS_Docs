import 'package:flutter/material.dart';

class ScreenUtils {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  // Device Type Checks
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // Screen Dimensions
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Relative Sizing (Percentage based)
  /// Returns width as percentage of screen width (0-100)
  static double w(BuildContext context, double percentage) =>
      width(context) * (percentage / 100);

  /// Returns height as percentage of screen height (0-100)
  static double h(BuildContext context, double percentage) =>
      height(context) * (percentage / 100);

  // Dynamic Spacing
  static double spacing(BuildContext context) {
    if (isDesktop(context)) return 32.0;
    if (isTablet(context)) return 24.0;
    return 16.0; // Mobile default
  }

  // Dynamic Font Sizing
  /// Scales font size based on screen width, with min/max caps
  static double fontSize(BuildContext context, double baseSize) {
    final w = width(context);
    // Scale factor: 1.0 for mobile (375px), up to 1.5 for desktop
    double scale = w / 375.0;
    if (scale < 0.8) scale = 0.8;
    if (scale > 1.2) scale = 1.2; // Cap scaling to prevent oversized text

    return baseSize * scale;
  }

  // Touch Targets
  /// Ensures minimum touch target size (48px)
  static double get touchTarget => 48.0;
}
