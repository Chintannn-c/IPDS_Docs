import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MinimalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderRadius;

  const MinimalCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppTheme.radiusLarge,
        ),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppTheme.radiusLarge,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppTheme.radiusLarge,
        ),
        child: card,
      );
    }
    return card;
  }
}

// Minimal Section Header
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          if (actionText != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionText!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Minimal Status Badge
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}
