import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated Mathalino Logo Widget
/// Features floating animation and glow effect
class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool showGlow;

  const AnimatedLogo({
    super.key,
    this.size = 120,
    this.showGlow = true,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _floatAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
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
        final floatOffset = math.sin(_floatAnimation.value * math.pi * 2) * 10;
        
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: _glowAnimation.value * 0.5),
                  Colors.white.withValues(alpha: _glowAnimation.value * 0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          ),
        );
      },
      child: _buildLogoContent(),
    );
  }

  Widget _buildLogoContent() {
    return Image.asset(
      'image/MLOGO.png',
      width: widget.size * 0.8,
      height: widget.size * 0.8,
      fit: BoxFit.contain,
    );
  }
}
