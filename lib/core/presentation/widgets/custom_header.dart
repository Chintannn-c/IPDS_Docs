import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const CustomHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 4,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.textSecondary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          if (showBackButton)
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.textPrimary,
                size: 20,
              ),
              onPressed: onBack ?? () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),

          // Title
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),

          // Actions or spacer
          if (actions != null && actions!.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: actions!)
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
