import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Security-focused status indicator with reassuring language.
///
/// Uses calm colors and non-alarming text to convey security status
/// without causing unnecessary anxiety for users.
enum SecurityStatus {
  secure, // Green - "System Secure"
  monitoring, // Blue - "Monitoring Active"
  attention, // Amber - "Review Recommended"
  critical, // Red - "Action Required"
}

class StatusIndicator extends StatelessWidget {
  final SecurityStatus status;
  final bool compact;
  final bool showIcon;
  final bool showPulse;

  const StatusIndicator({
    super.key,
    required this.status,
    this.compact = false,
    this.showIcon = true,
    this.showPulse = false,
  });

  Color get _backgroundColor {
    switch (status) {
      case SecurityStatus.secure:
        return AppTheme.statusSecure;
      case SecurityStatus.monitoring:
        return AppTheme.statusMonitoring;
      case SecurityStatus.attention:
        return AppTheme.statusAttention;
      case SecurityStatus.critical:
        return AppTheme.statusCritical;
    }
  }

  Color get _textColor {
    switch (status) {
      case SecurityStatus.secure:
        return AppTheme.statusSecureText;
      case SecurityStatus.monitoring:
        return AppTheme.statusMonitoringText;
      case SecurityStatus.attention:
        return AppTheme.statusAttentionText;
      case SecurityStatus.critical:
        return AppTheme.statusCriticalText;
    }
  }

  IconData get _icon {
    switch (status) {
      case SecurityStatus.secure:
        return Icons.check_circle_rounded;
      case SecurityStatus.monitoring:
        return Icons.visibility_rounded;
      case SecurityStatus.attention:
        return Icons.info_rounded;
      case SecurityStatus.critical:
        return Icons.warning_rounded;
    }
  }

  String get _label {
    switch (status) {
      case SecurityStatus.secure:
        return 'System Secure';
      case SecurityStatus.monitoring:
        return 'Monitoring Active';
      case SecurityStatus.attention:
        return 'Review Recommended';
      case SecurityStatus.critical:
        return 'Action Required';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppTheme.spacingS : AppTheme.spacingM,
        vertical: compact ? AppTheme.spacingXS : AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(
          compact ? AppTheme.radiusSmall : AppTheme.radiusMedium,
        ),
        border: Border.all(color: _textColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            if (showPulse)
              _PulsingIcon(icon: _icon, color: _textColor)
            else
              Icon(_icon, size: compact ? 14 : 18, color: _textColor),
            SizedBox(width: compact ? 4 : 8),
          ],
          Text(
            _label,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Icon(widget.icon, size: 18, color: widget.color),
        );
      },
    );
  }
}

/// A status banner for the top of screens.
class StatusBanner extends StatelessWidget {
  final SecurityStatus status;
  final String? customMessage;
  final VoidCallback? onTap;

  const StatusBanner({
    super.key,
    required this.status,
    this.customMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          children: [
            Icon(_getIcon(), size: 20, color: _getTextColor()),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTitle(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getTextColor(),
                    ),
                  ),
                  if (customMessage != null)
                    Text(
                      customMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTextColor().withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _getTextColor().withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case SecurityStatus.secure:
        return AppTheme.statusSecure;
      case SecurityStatus.monitoring:
        return AppTheme.statusMonitoring;
      case SecurityStatus.attention:
        return AppTheme.statusAttention;
      case SecurityStatus.critical:
        return AppTheme.statusCritical;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case SecurityStatus.secure:
        return AppTheme.statusSecureText;
      case SecurityStatus.monitoring:
        return AppTheme.statusMonitoringText;
      case SecurityStatus.attention:
        return AppTheme.statusAttentionText;
      case SecurityStatus.critical:
        return AppTheme.statusCriticalText;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case SecurityStatus.secure:
        return Icons.verified_user_rounded;
      case SecurityStatus.monitoring:
        return Icons.shield_rounded;
      case SecurityStatus.attention:
        return Icons.info_outline_rounded;
      case SecurityStatus.critical:
        return Icons.warning_amber_rounded;
    }
  }

  String _getTitle() {
    switch (status) {
      case SecurityStatus.secure:
        return 'All Systems Secure';
      case SecurityStatus.monitoring:
        return 'Monitoring in Real Time';
      case SecurityStatus.attention:
        return 'Review Recommended';
      case SecurityStatus.critical:
        return 'Action Required';
    }
  }
}

/// Section divider with optional label.
class SectionDivider extends StatelessWidget {
  final String? label;
  final EdgeInsetsGeometry? margin;

  const SectionDivider({super.key, this.label, this.margin});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding:
            margin ?? const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        child: Divider(
          height: 1,
          color: AppTheme.textSecondary.withOpacity(0.1),
        ),
      );
    }

    return Padding(
      padding:
          margin ?? const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: AppTheme.textSecondary.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: AppTheme.textSecondary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
