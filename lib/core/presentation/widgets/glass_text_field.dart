import 'package:flutter/material.dart';

class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final IconData? prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const GlassTextField({
    super.key,
    this.controller,
    required this.label,
    this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onChanged,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Focus(
      onFocusChange: (focus) => setState(() => _isFocused = focus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused
                ? colorScheme.primary
                : (isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1)),
            width: _isFocused ? 1.5 : 1.0,
          ),
          boxShadow: [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _isFocused
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: _isFocused
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.6),
                  )
                : null,
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
            fillColor: Colors.transparent,
            filled: true,
          ),
        ),
      ),
    );
  }
}
