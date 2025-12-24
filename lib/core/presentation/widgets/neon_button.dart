import 'package:flutter/material.dart';

class NeonButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final btnColor = color ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: btnColor.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.black, // Contrast text
          shadowColor: Colors.transparent, // Handled by Container
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : child,
      ),
    );
  }
}
