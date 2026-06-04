import 'package:flutter/material.dart';

class SafetyBanner extends StatefulWidget {
  final String verdict;

  const SafetyBanner({
    Key? key,
    required this.verdict,
  }) : super(key: key);

  @override
  State<SafetyBanner> createState() => _SafetyBannerState();
}

class _SafetyBannerState extends State<SafetyBanner> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = widget.verdict == "DANGER";
    
    final Color bannerColor = isDanger ? const Color(0xFFFF3B30) : const Color(0xFF30D158);
    final Color shadowColor = bannerColor.withOpacity(0.4);
    
    final String labelText = isDanger ? "STOP! VEHICLE APPROACHING" : "SAFE TO CROSS";
    final IconData icon = isDanger ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bannerColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          )
        ),
        padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32.0,
            ),
            const SizedBox(width: 12.0),
            Text(
              labelText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
