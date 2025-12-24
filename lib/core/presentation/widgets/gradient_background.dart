import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020617), // Deep Navy
            Color.fromARGB(255, 0, 0, 0), // Slate 900
            Color.fromARGB(255, 0, 0, 0), // Deep Indigo
          ],
        ),
      ),
      child: child,
    );
  }
}
