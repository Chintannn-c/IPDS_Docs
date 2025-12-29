import 'package:flutter/material.dart';

class NoteSummarizingAnimation extends StatefulWidget {
  const NoteSummarizingAnimation({super.key});

  @override
  State<NoteSummarizingAnimation> createState() =>
      _NoteSummarizingAnimationState();
}

class _NoteSummarizingAnimationState extends State<NoteSummarizingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentStep = 0;
  final List<String> _steps = [
    'Reading your note...',
    'Analyzing patterns...',
    'Identifying key points...',
    'Crafting summary...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Cycle through steps
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        setState(() {
          _currentStep = (_currentStep + 1) % _steps.length;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        decoration: BoxDecoration(
          color: const Color(
            0xFF1E293B,
          ).withOpacity(0.95), // Premium Slate Navy
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing AI Sparkles Icon (Matched to image)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF3B82F6,
                        ).withOpacity(0.4 * _controller.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Main Status Text (Blue shade from image)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _steps[_currentStep],
                key: ValueKey(_currentStep),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF60A5FA), // Light blue text
                  letterSpacing: 0.2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Minimalist Progress Bar
            SizedBox(
              width: 140,
              height: 4,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 40 + (100 * _controller.value),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer Text
            const Text(
              'AI is summarizing your note',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
