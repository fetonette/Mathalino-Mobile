import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/mathalino_tokens.dart';

/// CustomPainter for rendering individual stars, star badges, and sparkle bursts.
///
/// Can be used as a standalone [CustomPainter] or via static drawing methods.
class StarPainter extends CustomPainter {
  final bool isFilled;
  final double size;
  final double cornerRadiusFactor;
  final double opacity;
  final double sparkleProgress;

  const StarPainter({
    this.isFilled = true,
    this.size = AppTokens.starSize,
    this.cornerRadiusFactor = AppTokens.starCornerRadiusFactor,
    this.opacity = 1.0,
    this.sparkleProgress = 0.0,
  });

  /// Builds a rounded 5-pointed star path with smooth corner fillets.
  static Path buildStarPath(
    double starSize, [
    double cornerRadiusFactor = AppTokens.starCornerRadiusFactor,
  ]) {
    final path = Path();
    final rOuter = starSize / 2.0;
    // Child-friendly plump proportions (0.46 ratio)
    final rInner = rOuter * 0.46;
    final cornerRadius = starSize * cornerRadiusFactor;

    // 10 alternating outer/inner vertices
    final points = <Offset>[];
    for (int i = 0; i < 5; i++) {
      // Outer tip (pointing straight up at i=0)
      final angleOuter = -math.pi / 2 + (i * 2 * math.pi / 5);
      points.add(
        Offset(rOuter * math.cos(angleOuter), rOuter * math.sin(angleOuter)),
      );

      // Inner valley
      final angleInner = angleOuter + (math.pi / 5);
      points.add(
        Offset(rInner * math.cos(angleInner), rInner * math.sin(angleInner)),
      );
    }

    final n = points.length;
    final entryPoints = <Offset>[];
    final exitPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final prev = points[(i - 1 + n) % n];
      final curr = points[i];
      final next = points[(i + 1) % n];

      final d1 = prev - curr;
      final d2 = next - curr;
      final len1 = d1.distance;
      final len2 = d2.distance;

      final u1 = Offset(d1.dx / len1, d1.dy / len1);
      final u2 = Offset(d2.dx / len2, d2.dy / len2);

      final dot = (u1.dx * u2.dx + u1.dy * u2.dy).clamp(-1.0, 1.0);
      final halfAngle = math.acos(dot) / 2.0;
      final tanHalf = math.tan(halfAngle);

      double t = tanHalf > 0.001 ? (cornerRadius / tanHalf) : 0.0;
      final maxT = math.min(len1, len2) * 0.40;
      if (t > maxT) t = maxT;

      entryPoints.add(curr + u1 * t);
      exitPoints.add(curr + u2 * t);
    }

    // Connect with straight lines and quadratic bezier corner curves
    path.moveTo(exitPoints[n - 1].dx, exitPoints[n - 1].dy);
    for (int i = 0; i < n; i++) {
      path.lineTo(entryPoints[i].dx, entryPoints[i].dy);
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        exitPoints[i].dx,
        exitPoints[i].dy,
      );
    }
    path.close();
    return path;
  }

  /// Builds a 4-pointed diamond sparkle path centered at [center].
  static Path buildSparklePath(Offset center, double radius) {
    final path = Path();
    final r = radius;
    final pinch = r * 0.22;
    path.moveTo(center.dx, center.dy - r);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + pinch, center.dy);
    path.lineTo(center.dx + r, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + pinch);
    path.lineTo(center.dx, center.dy + r);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - pinch, center.dy);
    path.lineTo(center.dx - r, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - pinch);
    path.close();
    return path;
  }

  /// Draws a single rounded star (filled or empty) with outline, highlight/shadow, and sparkles.
  static void drawStar(
    Canvas canvas,
    Offset center,
    double starSize, {
    required bool isFilled,
    double angleRad = 0.0,
    double opacity = 1.0,
    double scale = 1.0,
    double sparkleProgress = 0.0,
    bool drawShadow = true,
  }) {
    if (scale <= 0.001 || opacity <= 0.001) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (angleRad != 0.0) canvas.rotate(angleRad);
    if (scale != 1.0) canvas.scale(scale, scale);

    final path = buildStarPath(starSize);

    // 1. Soft drop shadow under the star: offset (0, 2), blur 3, 20% black
    if (drawShadow) {
      final shadowPaint = Paint()
        ..color = AppTokens.starDropShadow.withValues(
          alpha: AppTokens.starDropShadow.a * opacity,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
    }

    if (isFilled) {
      // 2. Filled star vertical gradient (#FFD54A to #FFA000)
      final bounds = path.getBounds();
      final fillPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, bounds.top),
          Offset(bounds.left, bounds.bottom),
          [
            AppTokens.starGoldLight.withValues(
              alpha: AppTokens.starGoldLight.a * opacity,
            ),
            AppTokens.starGoldDark.withValues(
              alpha: AppTokens.starGoldDark.a * opacity,
            ),
          ],
        );
      canvas.drawPath(path, fillPaint);

      // 3. Small white glossy highlight on the upper left arm (white at 60% opacity)
      final r = starSize / 2.0;
      final highlightPaint = Paint()
        ..color = AppTokens.starGlossHighlight.withValues(
          alpha: AppTokens.starGlossHighlight.a * opacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, starSize * 0.08)
        ..strokeCap = StrokeCap.round;

      final highlightPath = Path()
        ..moveTo(-r * 0.22, -r * 0.58)
        ..quadraticBezierTo(-r * 0.44, -r * 0.48, -r * 0.65, -r * 0.28);
      canvas.drawPath(highlightPath, highlightPaint);

      // 4. Darker 2px outline (#C77700) with round join
      final outlinePaint = Paint()
        ..color = AppTokens.starGoldOutline.withValues(
          alpha: AppTokens.starGoldOutline.a * opacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTokens.starOutlineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, outlinePaint);
    } else {
      // Empty star: flat #E6DCCB fill with #CDBFA8 outline and faint inner shadow
      canvas.save();
      canvas.clipPath(path);

      // Flat fill
      final emptyFillPaint = Paint()
        ..color = AppTokens.starEmptyFill.withValues(
          alpha: AppTokens.starEmptyFill.a * opacity,
        );
      canvas.drawPath(path, emptyFillPaint);

      // Faint inner shadow from top edge
      final innerShadowPaint = Paint()
        ..color = AppTokens.starEmptyInnerShadow.withValues(
          alpha: AppTokens.starEmptyInnerShadow.a * opacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.save();
      canvas.translate(0, 1.5);
      canvas.drawPath(path, innerShadowPaint);
      canvas.restore();

      canvas.restore();

      // Empty outline
      final outlinePaint = Paint()
        ..color = AppTokens.starEmptyOutline.withValues(
          alpha: AppTokens.starEmptyOutline.a * opacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTokens.starOutlineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, outlinePaint);
    }

    // 5. Short sparkle burst (4 tiny 4-point sparkles that fade out in 400ms)
    if (sparkleProgress > 0.0 && sparkleProgress < 1.0) {
      final r = starSize / 2.0;
      final sparkleAlpha = (1.0 - sparkleProgress).clamp(0.0, 1.0);
      final sparkleDist = r * (0.95 + 0.35 * sparkleProgress);
      final sparkleRadius = math.max(1.0, 4.0 * (1.0 - 0.4 * sparkleProgress));

      final sparklePaint = Paint()
        ..color = AppTokens.starSparkle.withValues(alpha: sparkleAlpha)
        ..style = PaintingStyle.fill;

      const angles = [
        math.pi / 4,
        3 * math.pi / 4,
        5 * math.pi / 4,
        7 * math.pi / 4,
      ];
      for (final a in angles) {
        final sx = sparkleDist * math.cos(a);
        final sy = sparkleDist * math.sin(a);
        final spPath = buildSparklePath(Offset(sx, sy), sparkleRadius);
        canvas.drawPath(spPath, sparklePaint);
      }
    }

    canvas.restore();
  }

  /// Draws the complete 3-star curved badge row with shadows, glow, and overlapping stars.
  static void drawStarRow(
    Canvas canvas,
    Size size, {
    required int earnedStars,
    required double baseStarSize,
    double opacity = 1.0,
    List<double> scales = const [1.0, 1.0, 1.0],
    List<double> sparkleProgresses = const [0.0, 0.0, 0.0],
  }) {
    final center = Offset(
      size.width / 2,
      size.height / 2 + AppTokens.starMiddleLift / 2,
    );
    final midSize = baseStarSize * AppTokens.starMiddleScale;
    final centerOffset =
        (baseStarSize / 2) + (midSize / 2) + AppTokens.starOverlapGap;

    final positions = [
      Offset(center.dx - centerOffset, center.dy),
      Offset(center.dx, center.dy - AppTokens.starMiddleLift),
      Offset(center.dx + centerOffset, center.dy),
    ];
    final sizes = [baseStarSize, midSize, baseStarSize];
    final angles = [
      -AppTokens.starTiltAngleRad,
      0.0,
      AppTokens.starTiltAngleRad,
    ];

    // Subtle golden glow behind the row (radial gradient, #FFB400 at 25% opacity) for 3 stars
    if (earnedStars >= 3 && opacity > 0) {
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          positions[1],
          midSize * 1.6,
          [
            AppTokens.starGlow.withValues(
              alpha: AppTokens.starGlow.a * opacity,
            ),
            AppTokens.starGlow.withValues(alpha: 0.0),
          ],
        );
      canvas.drawCircle(positions[1], midSize * 1.6, glowPaint);
    }

    // Step 1: Draw base slot stars (empty or resting filled)
    // Left star
    drawStar(
      canvas,
      positions[0],
      sizes[0],
      isFilled: earnedStars > 0 && scales[0] >= 1.0,
      angleRad: angles[0],
      opacity: opacity,
      scale: earnedStars > 0 ? (scales[0] >= 1.0 ? scales[0] : 1.0) : 1.0,
      sparkleProgress: earnedStars > 0 ? sparkleProgresses[0] : 0.0,
    );

    // Right star
    drawStar(
      canvas,
      positions[2],
      sizes[2],
      isFilled: earnedStars > 2 && scales[2] >= 1.0,
      angleRad: angles[2],
      opacity: opacity,
      scale: earnedStars > 2 ? (scales[2] >= 1.0 ? scales[2] : 1.0) : 1.0,
      sparkleProgress: earnedStars > 2 ? sparkleProgresses[2] : 0.0,
    );

    // Middle star (rendered on top of side stars for cohesive trophy layering)
    drawStar(
      canvas,
      positions[1],
      sizes[1],
      isFilled: earnedStars > 1 && scales[1] >= 1.0,
      angleRad: angles[1],
      opacity: opacity,
      scale: earnedStars > 1 ? (scales[1] >= 1.0 ? scales[1] : 1.0) : 1.0,
      sparkleProgress: earnedStars > 1 ? sparkleProgresses[1] : 0.0,
    );

    // Step 2: If animating, draw active pop-in star on top with its scale and sparkles
    for (int i = 0; i < 3; i++) {
      if (i < earnedStars && scales[i] > 0.0 && scales[i] != 1.0) {
        drawStar(
          canvas,
          positions[i],
          sizes[i],
          isFilled: true,
          angleRad: angles[i],
          opacity: opacity,
          scale: scales[i],
          sparkleProgress: sparkleProgresses[i],
          drawShadow: false,
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    drawStar(
      canvas,
      Offset(canvasSize.width / 2, canvasSize.height / 2),
      size,
      isFilled: isFilled,
      opacity: opacity,
      sparkleProgress: sparkleProgress,
    );
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.isFilled != isFilled ||
        oldDelegate.size != size ||
        oldDelegate.cornerRadiusFactor != cornerRadiusFactor ||
        oldDelegate.opacity != opacity ||
        oldDelegate.sparkleProgress != sparkleProgress;
  }
}

/// A rewarding, playful trophy-style 3-star rating badge for level nodes.
///
/// Features:
/// - Three rounded 5-point stars arranged in a gentle curved arc.
/// - Middle star is 6px higher and ~10% larger than side stars (-10° / +10° tilt).
/// - -2px overlap so the stars feel like a single cohesive badge.
/// - Rich visual styling: gold gradient, round outline, glossy highlight, drop shadow.
/// - Empty star slots with subtle inner shadow.
/// - Radial golden aura for 3-star perfect scores.
/// - Staggered elastic pop-in and sparkle bursts for newly earned ratings.
/// - Accessibility: Semantics label "X of 3 stars" with child elements excluded.
class StarRow extends StatefulWidget {
  final int stars;
  final double size;
  final bool animateNew;
  final double opacity;

  const StarRow({
    super.key,
    required this.stars,
    this.size = AppTokens.starSize,
    this.animateNew = false,
    this.opacity = 1.0,
  });

  @override
  State<StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<StarRow> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  final Set<int> _triggeredHaptics = {};

  @override
  void initState() {
    super.initState();
    _initAnimationIfNeeded();
  }

  void _initAnimationIfNeeded() {
    final earned = widget.stars.clamp(0, 3);
    if (widget.animateNew && earned > 0) {
      final totalMs =
          (earned - 1) * AppTokens.starStaggerDelay.inMilliseconds +
          AppTokens.starPopDuration.inMilliseconds +
          200;
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: totalMs),
      );
      _controller!.addListener(_handleAnimationTick);
      _controller!.forward();
    }
  }

  void _handleAnimationTick() {
    if (!mounted || _controller == null) return;
    final totalMs = _controller!.duration!.inMilliseconds;
    final elapsedMs = _controller!.value * totalMs;
    final earned = widget.stars.clamp(0, 3);

    for (int i = 0; i < earned; i++) {
      final startMs = i * AppTokens.starStaggerDelay.inMilliseconds;
      final relMs = elapsedMs - startMs;
      // Star lands at ~150ms into elastic bounce
      if (relMs >= 150 && !_triggeredHaptics.contains(i)) {
        _triggeredHaptics.add(i);
        HapticFeedback.lightImpact();
      }
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant StarRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stars != widget.stars ||
        oldWidget.animateNew != widget.animateNew) {
      _controller?.removeListener(_handleAnimationTick);
      _controller?.dispose();
      _controller = null;
      _triggeredHaptics.clear();
      _initAnimationIfNeeded();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleAnimationTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earned = widget.stars.clamp(0, 3);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isAnimating =
        widget.animateNew &&
        !disableAnimations &&
        _controller != null &&
        _controller!.isAnimating;

    final scales = <double>[1.0, 1.0, 1.0];
    final sparkleProgresses = <double>[0.0, 0.0, 0.0];

    if (isAnimating) {
      final totalMs = _controller!.duration!.inMilliseconds;
      final elapsedMs = _controller!.value * totalMs;
      final popDurationMs = AppTokens.starPopDuration.inMilliseconds;
      final sparkleDurationMs = AppTokens.starSparkleDuration.inMilliseconds;

      for (int i = 0; i < earned; i++) {
        final startMs = i * AppTokens.starStaggerDelay.inMilliseconds;
        final relMs = elapsedMs - startMs;
        if (relMs < 0) {
          scales[i] = 0.0;
        } else {
          final p = (relMs / popDurationMs).clamp(0.0, 1.0);
          scales[i] = Curves.elasticOut.transform(p);

          // Sparkle burst starts on landing (~150ms) and lasts 400ms
          final sparkleRelMs = relMs - 150;
          if (sparkleRelMs >= 0) {
            sparkleProgresses[i] = (sparkleRelMs / sparkleDurationMs).clamp(
              0.0,
              1.0,
            );
          }
        }
      }
    }

    return Semantics(
      label: '$earned of 3 stars',
      child: ExcludeSemantics(
        child: SizedBox(
          width: AppTokens.starRowWidth,
          height: AppTokens.starRowHeight,
          child: CustomPaint(
            painter: _StarRowPainter(
              earnedStars: earned,
              baseStarSize: widget.size,
              opacity: widget.opacity,
              scales: scales,
              sparkleProgresses: sparkleProgresses,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRowPainter extends CustomPainter {
  final int earnedStars;
  final double baseStarSize;
  final double opacity;
  final List<double> scales;
  final List<double> sparkleProgresses;

  _StarRowPainter({
    required this.earnedStars,
    required this.baseStarSize,
    required this.opacity,
    required this.scales,
    required this.sparkleProgresses,
  });

  @override
  void paint(Canvas canvas, Size size) {
    StarPainter.drawStarRow(
      canvas,
      size,
      earnedStars: earnedStars,
      baseStarSize: baseStarSize,
      opacity: opacity,
      scales: scales,
      sparkleProgresses: sparkleProgresses,
    );
  }

  @override
  bool shouldRepaint(covariant _StarRowPainter oldDelegate) {
    return oldDelegate.earnedStars != earnedStars ||
        oldDelegate.baseStarSize != baseStarSize ||
        oldDelegate.opacity != opacity ||
        oldDelegate.scales != scales ||
        oldDelegate.sparkleProgresses != sparkleProgresses;
  }
}
