import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TouchCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final bool showBorder;
  final bool elevated;

  const TouchCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.showBorder = true,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTheme.radiusLarge;
    final bgColor = backgroundColor ?? AppTheme.surfaceColor;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: AppTheme.primaryColor.withOpacity(0.08),
          highlightColor: AppTheme.primaryColor.withOpacity(0.04),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTheme.touchTargetMin,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: showBorder
                  ? Border.all(color: AppTheme.textSecondary.withOpacity(0.1))
                  : null,
              boxShadow: elevated ? AppTheme.cardShadow : null,
            ),
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingM),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A touch-optimized list tile with consistent sizing.
class TouchListTile extends StatelessWidget {
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Color? textColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const TouchListTile({
    super.key,
    this.leading,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.textColor,
    this.trailing,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine leading widget: either passed directly or built from icon
    Widget? leadingWidget = leading;
    if (leadingWidget == null && icon != null) {
      final color = iconColor ?? AppTheme.textSecondary;
      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          splashColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.02),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leadingWidget != null) ...[
                  leadingWidget!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColor ?? AppTheme.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary.withOpacity(0.7),
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  trailing!,
                ] else if (onTap != null) ...[
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: leadingWidget != null ? 64 : 16,
            endIndent: 16,
            color: AppTheme.textSecondary.withOpacity(0.06),
          ),
      ],
    );
  }
}

/// A primary action button with proper touch target.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: AppTheme.touchTargetLarge,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppTheme.spacingS),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A secondary/outline button with proper touch target.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppTheme.primaryColor;

    return SizedBox(
      height: AppTheme.touchTargetLarge,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppTheme.spacingS),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
