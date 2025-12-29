import 'dart:math' as math;
import 'package:flutter/material.dart';

class AILoadingAnimation extends StatefulWidget {
  const AILoadingAnimation({super.key});

  @override
  State<AILoadingAnimation> createState() => _AILoadingAnimationState();
}

class _AILoadingAnimationState extends State<AILoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _textController;

  final List<String> _statusMessages = [
    'READING YOUR DOCUMENT...',
    'UNDERSTANDING THE CONTENT...',
    'IDENTIFYING KEY INFORMATION...',
    'ANALYZING DOCUMENT STRUCTURE...',
    'CHECKING FOR SECURITY RISKS...',
    'EXTRACTING IMPORTANT POINTS...',
    'CREATING YOUR SUMMARY...',
    'ALMOST DONE...',
  ];

  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _textController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _messageIndex = (_messageIndex + 1) % _statusMessages.length;
              });
              _textController.forward(from: 0);
            }
          });
    _textController.forward();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 140 + (20 * _pulseController.value),
                    height: 140 + (20 * _pulseController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(
                            0.15 * (1 - _pulseController.value),
                          ),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Custom Painter for Rings
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(200, 200),
                    painter: AIRingPainter(
                      rotation: _rotationController.value,
                      color: colorScheme.primary,
                      pulse: _pulseController.value,
                    ),
                  );
                },
              ),

              // Inner Document Icon with Scanning Line
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.description_rounded,
                    size: 60,
                    color: colorScheme.primary.withOpacity(0.8),
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Positioned(
                        top: 40 + (40 * _pulseController.value),
                        child: Container(
                          width: 40,
                          height: 2,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // Dynamic Status Text
        FadeTransition(
          opacity: _textController.drive(
            TweenSequence([
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
            ]),
          ),
          child: Text(
            _statusMessages[_messageIndex],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: colorScheme.primary,
              shadows: [
                Shadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "ENCRYPTED NEURAL PROCESSING ACTIVE",
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: colorScheme.onSurface.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class AIRingPainter extends CustomPainter {
  final double rotation;
  final Color color;
  final double pulse;

  AIRingPainter({
    required this.rotation,
    required this.color,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer Thin Orbit
    paint.color = color.withOpacity(0.1);
    canvas.drawCircle(center, 90, paint);

    // Main Rotating Arc 1
    paint.color = color.withOpacity(0.6);
    paint.strokeWidth = 3.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 80),
      rotation * 2 * math.pi,
      math.pi * 0.4,
      false,
      paint,
    );

    // Inner Rotating Arc 2 (Opposite direction)
    paint.color = color.withOpacity(0.4);
    paint.strokeWidth = 2.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 65),
      -rotation * 4 * math.pi,
      math.pi * 0.6,
      false,
      paint,
    );

    // Hexagon Shape
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = color.withOpacity(0.2 + (0.2 * pulse));

    final hexPath = Path();
    final hexRadius = 50.0 + (5.0 * pulse);
    for (int i = 0; i < 6; i++) {
      double angle = (2 * math.pi / 6) * i + (rotation * math.pi);
      double x = center.dx + hexRadius * math.cos(angle);
      double y = center.dy + hexRadius * math.sin(angle);
      if (i == 0)
        hexPath.moveTo(x, y);
      else
        hexPath.lineTo(x, y);
    }
    hexPath.close();
    canvas.drawPath(hexPath, paint);

    // Decorative Nodes on the path
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      double angle = (2 * math.pi / 6) * i + (rotation * math.pi);
      double x = center.dx + hexRadius * math.cos(angle);
      double y = center.dy + hexRadius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AIRingPainter oldDelegate) => true;
}
