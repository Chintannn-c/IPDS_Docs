import 'package:flutter/material.dart';

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxContentWidth = 1200,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
