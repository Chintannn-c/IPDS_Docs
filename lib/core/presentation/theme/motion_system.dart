import 'package:flutter/material.dart';

/// Premium Motion Design System
/// Unified animation curves, durations, and reusable animated widgets

// ==================== ANIMATION DURATIONS ====================
class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration pageTransition = Duration(milliseconds: 300);
}

// ==================== ANIMATION CURVES ====================
class AppCurves {
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve bounce = Curves.bounceOut;
  static const Curve elastic = Curves.elasticOut;
  static const Curve overshoot = Curves.easeOutBack;

  // Material Design motion curves
  static const Curve standardEasing = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedEasing = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
}

// ==================== THEME EXTENSION ====================
class MotionTheme extends ThemeExtension<MotionTheme> {
  final Duration fastDuration;
  final Duration mediumDuration;
  final Duration slowDuration;
  final Curve defaultCurve;

  const MotionTheme({
    this.fastDuration = const Duration(milliseconds: 150),
    this.mediumDuration = const Duration(milliseconds: 250),
    this.slowDuration = const Duration(milliseconds: 400),
    this.defaultCurve = Curves.easeOutCubic,
  });

  @override
  MotionTheme copyWith({
    Duration? fastDuration,
    Duration? mediumDuration,
    Duration? slowDuration,
    Curve? defaultCurve,
  }) {
    return MotionTheme(
      fastDuration: fastDuration ?? this.fastDuration,
      mediumDuration: mediumDuration ?? this.mediumDuration,
      slowDuration: slowDuration ?? this.slowDuration,
      defaultCurve: defaultCurve ?? this.defaultCurve,
    );
  }

  @override
  MotionTheme lerp(ThemeExtension<MotionTheme>? other, double t) {
    if (other is! MotionTheme) return this;
    return this;
  }
}

// ==================== ANIMATED SCALE BUTTON ====================
class AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const AnimatedScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: AppCurves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ==================== ANIMATED CARD ====================
class AnimatedPressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? color;
  final double elevation;

  const AnimatedPressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.color,
    this.elevation = 2,
  });

  @override
  State<AnimatedPressableCard> createState() => _AnimatedPressableCardState();
}

class _AnimatedPressableCardState extends State<AnimatedPressableCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.color ?? theme.cardColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.easeOut,
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.98 : (_isHovered ? 1.01 : 1.0)),
          decoration: BoxDecoration(
            color: _isHovered ? baseColor.withOpacity(0.95) : baseColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  _isPressed ? 0.05 : (_isHovered ? 0.12 : 0.08),
                ),
                blurRadius: _isPressed ? 4 : (_isHovered ? 16 : 8),
                offset: Offset(0, _isPressed ? 2 : (_isHovered ? 6 : 4)),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ==================== SHIMMER LOADING ====================
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: isDark
                  ? [Colors.grey[800]!, Colors.grey[700]!, Colors.grey[800]!]
                  : [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
            ),
          ),
        );
      },
    );
  }
}

// ==================== STAGGERED ANIMATION ====================
class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayPerItem;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.delayPerItem = const Duration(milliseconds: 50),
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.medium,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: AppCurves.easeOutCubic),
        );

    // Staggered delay
    Future.delayed(widget.delayPerItem * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// ==================== ANIMATED COUNTER ====================
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: AppCurves.easeOutCubic,
      builder: (context, val, child) {
        return Text('${prefix ?? ''}$val${suffix ?? ''}', style: style);
      },
    );
  }
}

// ==================== GLASSMORPHISM CARD ====================
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.color,
    this.borderRadius,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color:
              color ??
              (isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.7)),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          border:
              border ??
              Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.5),
              ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

// ==================== PULSE ANIMATION ====================
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.animate = true,
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

// ==================== FADE IN ANIMATION ====================
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset? slideOffset;

  const FadeInAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
    this.slideOffset,
  });

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AppCurves.easeOut));

    _slideAnimation =
        Tween<Offset>(
          begin: widget.slideOffset ?? const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: AppCurves.easeOutCubic),
        );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

// ==================== PAGE ROUTE TRANSITIONS ====================
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: AppDurations.pageTransition,
        reverseTransitionDuration: AppDurations.medium,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: AppCurves.easeOut),
          );
          final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: AppCurves.easeOutCubic),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          );
        },
      );
}

class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: AppDurations.pageTransition,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideAnimation =
              Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: AppCurves.easeOutCubic,
                ),
              );

          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: AppCurves.easeOut),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
      );
}

// ==================== ANIMATED GRADIENT BACKGROUND ====================
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    required this.colors,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
              stops: [
                0.0,
                _controller.value,
                1.0,
              ].take(widget.colors.length).toList(),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
