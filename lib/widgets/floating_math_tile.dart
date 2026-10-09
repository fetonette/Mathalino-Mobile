import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/mathalino_tokens.dart';

/// Floating Math Tile Decoration
/// Rounded square tile with a math symbol that floats gently up and down
class FloatingMathTile extends StatefulWidget {
  final double size;
  final double radius;
  final String symbol;
  final double symbolSize;
  final Color backgroundColor;
  final Color symbolColor;
  final double angleInDegrees;
  final Duration delay;

  const FloatingMathTile({
    super.key,
    this.size = 46.0,
    this.radius = 15.0,
    required this.symbol,
    this.symbolSize = 30.0,
    required this.backgroundColor,
    required this.symbolColor,
    this.angleInDegrees = 0.0,
    this.delay = Duration.zero,
  });

  @override
  State<FloatingMathTile> createState() => _FloatingMathTileState();
}

class _FloatingMathTileState extends State<FloatingMathTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.delay != Duration.zero) {
      Future.delayed(widget.delay, () {
        if (!_disposed && mounted) {
          _controller.repeat(reverse: true);
        }
      });
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final dy = reduceMotion ? 0.0 : _animation.value;
          return Transform.translate(
            offset: Offset(0, dy),
            child: child,
          );
        },
        child: Transform.rotate(
          angle: widget.angleInDegrees * math.pi / 180,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.symbol,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTokens.fontBaloo2,
                fontSize: widget.symbolSize,
                fontWeight: FontWeight.w800,
                color: widget.symbolColor,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny 4-point decorative star
class FourPointStar extends StatelessWidget {
  final double size;
  final Color color;

  const FourPointStar({
    super.key,
    this.size = 14.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size),
        painter: _FourPointStarPainter(color: color),
      ),
    );
  }
}

class _FourPointStarPainter extends CustomPainter {
  final Color color;
  _FourPointStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width / 2;
    final rInner = rOuter * 0.28;

    for (int i = 0; i < 4; i++) {
      final angleOuter = (i * 90 - 90) * math.pi / 180;
      final angleInner = (i * 90 + 45 - 90) * math.pi / 180;

      final ox = cx + rOuter * math.cos(angleOuter);
      final oy = cy + rOuter * math.sin(angleOuter);

      final ix = cx + rInner * math.cos(angleInner);
      final iy = cy + rInner * math.sin(angleInner);

      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FourPointStarPainter oldDelegate) =>
      oldDelegate.color != color;
}
