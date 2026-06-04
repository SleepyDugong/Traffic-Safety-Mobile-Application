import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color borderGradientStart;
  final Color borderGradientEnd;
  final Color bgGradientStart;
  final Color bgGradientEnd;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    Key? key,
    required this.child,
    this.borderRadius = 20.0,
    this.blur = 15.0,
    this.borderGradientStart = const Color(0x33FFFFFF),
    this.borderGradientEnd = const Color(0x0DFFFFFF),
    this.bgGradientStart = const Color(0x1AFFFFFF),
    this.bgGradientEnd = const Color(0x08FFFFFF),
    this.padding = const EdgeInsets.all(16.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgGradientStart, bgGradientEnd],
            ),
            border: Border.all(
              width: 1.5,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
