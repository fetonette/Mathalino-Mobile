import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Gamified Loading Spinner
/// Features playful animation with math symbols
class GamifiedLoadingSpinner extends StatefulWidget {
  final double size;
  final Color? color;

  const GamifiedLoadingSpinner({
    super.key,
    this.size = 50,
    this.color,
  });

  @override
  State<GamifiedLoadingSpinner> createState() => _GamifiedLoadingSpinnerState();
}

class _GamifiedLoadingSpinnerState extends State<GamifiedLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF4F46E5);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _SpinnerPainter(color: color),
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final Color color;

  _SpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw math symbols in a circle
    final symbols = ['+', '-', '×', '÷', '=', '√'];
    final symbolCount = symbols.length;
    final angleStep = 2 * math.pi / symbolCount;

    for (int i = 0; i < symbolCount; i++) {
      final angle = i * angleStep;
      final symbolRadius = radius * 0.7;
      final x = center.dx + symbolRadius * math.cos(angle);
      final y = center.dy + symbolRadius * math.sin(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: symbols[i],
          style: TextStyle(
            color: color,
            fontSize: size.width * 0.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw central circle
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.3, paint);

    // Draw outer ring
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius * 0.9, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
