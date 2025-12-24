import 'package:flutter/material.dart';

void showErrorDialog(BuildContext context, String message) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.error),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
        ),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
