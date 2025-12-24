import 'package:flutter/material.dart';

/// Represents the strength level of a password
enum PasswordStrength { weak, fair, good, strong }

/// Model class containing password validation results
class PasswordValidationResult {
  final PasswordStrength strength;
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;
  final String message;

  PasswordValidationResult({
    required this.strength,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
    required this.message,
  });

  /// Returns true if all requirements are met
  bool get isValid =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSpecialChar;

  /// Returns the number of requirements met (0-5)
  int get requirementsMet {
    int count = 0;
    if (hasMinLength) count++;
    if (hasUppercase) count++;
    if (hasLowercase) count++;
    if (hasDigit) count++;
    if (hasSpecialChar) count++;
    return count;
  }
}

/// Utility class for password validation
class PasswordValidator {
  static const int minLength = 8;

  /// Validates a password and returns a detailed result
  static PasswordValidationResult validate(String password) {
    final hasMinLength = password.length >= minLength;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    // Calculate strength based on requirements met
    int score = 0;
    if (hasMinLength) score++;
    if (hasUppercase) score++;
    if (hasLowercase) score++;
    if (hasDigit) score++;
    if (hasSpecialChar) score++;

    // Add bonus for length
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    PasswordStrength strength;
    String message;

    if (password.isEmpty) {
      strength = PasswordStrength.weak;
      message = 'Enter';
    } else if (score <= 2) {
      strength = PasswordStrength.weak;
      message = 'Weak';
    } else if (score <= 4) {
      strength = PasswordStrength.fair;
      message = 'Fair';
    } else if (score <= 5) {
      strength = PasswordStrength.good;
      message = 'Good';
    } else {
      strength = PasswordStrength.strong;
      message = 'Strong';
    }

    return PasswordValidationResult(
      strength: strength,
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigit: hasDigit,
      hasSpecialChar: hasSpecialChar,
      message: message,
    );
  }

  /// Returns a validation error message or null if valid
  static String? getValidationError(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    final result = validate(password);

    if (!result.hasMinLength) {
      return 'Password must be at least $minLength characters';
    }
    if (!result.hasUppercase) {
      return 'Password must contain an uppercase letter';
    }
    if (!result.hasLowercase) {
      return 'Password must contain a lowercase letter';
    }
    if (!result.hasDigit) {
      return 'Password must contain a number';
    }
    if (!result.hasSpecialChar) {
      return 'Password must contain a special character (!@#\$%^&*...)';
    }

    return null;
  }
}

/// A widget that displays password strength with animated progress bar and requirements
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showRequirements;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showRequirements = true,
  });

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFEF4444); // Softer red
      case PasswordStrength.fair:
        return const Color(0xFFF59E0B); // Warm amber
      case PasswordStrength.good:
        return const Color(0xFF10B981); // Teal green
      case PasswordStrength.strong:
        return const Color(0xFF059669); // Emerald
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = PasswordValidator.validate(password);
    final color = _getStrengthColor(result.strength);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Strength meter section
          Row(
            children: [
              // Animated strength icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _getStrengthIcon(result.strength),
                    key: ValueKey(result.strength),
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Progress bar and label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Password Strength',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          child: Text(result.message),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Segmented progress bar
                    Row(
                      children: List.generate(5, (index) {
                        final isActive = index < result.requirementsMet;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: Duration(
                              milliseconds: 200 + (index * 50),
                            ),
                            curve: Curves.easeOutCubic,
                            height: 6,
                            margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? color
                                  : (isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.08)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (showRequirements) ...[
            const SizedBox(height: 16),

            // Requirements as a clean list
            ...buildRequirementsList(result, theme, isDark),
          ],
        ],
      ),
    );
  }

  List<Widget> buildRequirementsList(
    PasswordValidationResult result,
    ThemeData theme,
    bool isDark,
  ) {
    final requirements = [
      _RequirementItem(
        label: 'At least 8 characters',
        isMet: result.hasMinLength,
        isDark: isDark,
      ),
      _RequirementItem(
        label: 'Uppercase letter (A-Z)',
        isMet: result.hasUppercase,
        isDark: isDark,
      ),
      _RequirementItem(
        label: 'Lowercase letter (a-z)',
        isMet: result.hasLowercase,
        isDark: isDark,
      ),
      _RequirementItem(
        label: 'Number (0-9)',
        isMet: result.hasDigit,
        isDark: isDark,
      ),
      _RequirementItem(
        label: 'Special character (!@#\$%...)',
        isMet: result.hasSpecialChar,
        isDark: isDark,
      ),
    ];

    return requirements;
  }

  IconData _getStrengthIcon(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Icons.shield_outlined;
      case PasswordStrength.fair:
        return Icons.shield_outlined;
      case PasswordStrength.good:
        return Icons.shield;
      case PasswordStrength.strong:
        return Icons.verified_user_rounded;
    }
  }
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool isMet;
  final bool isDark;

  const _RequirementItem({
    required this.label,
    required this.isMet,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final metColor = const Color(0xFF10B981);
    final unmetColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isMet ? metColor.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isMet ? metColor : unmetColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isMet
                  ? Icon(
                      Icons.check_rounded,
                      key: const ValueKey('check'),
                      size: 14,
                      color: metColor,
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isMet ? FontWeight.w500 : FontWeight.w400,
                color: isMet
                    ? (isDark
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey[800])
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
                decoration: isMet ? TextDecoration.none : TextDecoration.none,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
