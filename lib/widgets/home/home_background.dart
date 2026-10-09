import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/mathalino_tokens.dart';

/// Fixed, non-interactive decoration layer behind the level map:
/// cream background + 3 faded mascots + 12 floating vector stickers.
///
/// - Positions are stored as fractions of the 390x844 reference screen so they
///   scale with the device.
/// - Ignores pointer events and is hidden from screen readers.
/// - One single [Ticker] drives every sticker; each sticker is rasterised once
///   (RepaintBoundary) and only a [Transform.translate] is animated.
/// - Honors the OS "reduce motion" setting (everything static).
class HomeBackground extends StatefulWidget {
  const HomeBackground({super.key});

  @override
  State<HomeBackground> createState() => _HomeBackgroundState();
}

class _HomeBackgroundState extends State<HomeBackground>
    with SingleTickerProviderStateMixin {
  static const double _refW = 390;
  static const double _refH = 844;

  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds.value = elapsed.inMicroseconds / 1000000.0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_ticker.isActive) _ticker.stop();
      _seconds.value = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;
    // Size scale: follows width but is kept within a sane range.
    final scale = (w / _refW).clamp(0.8, 1.3);

    Widget mascot(String asset, double left, double top, double bw, double bh) {
      return Positioned(
        left: left / _refW * w,
        top: top / _refH * h,
        width: bw * scale,
        height: bh * scale,
        child: Opacity(
          opacity: 0.35,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
    }

    final stickers = <Widget>[
      for (final s in _stickers)
        Positioned(
          left: s.x / _refW * w,
          top: s.y / _refH * h,
          width: s.size * scale,
          height: s.size * scale,
          child: _FloatingSticker(
            seconds: _seconds,
            amount: s.amount,
            duration: s.duration,
            delay: s.delay,
            kind: s.kind,
          ),
        ),
    ];

    return ExcludeSemantics(
      child: IgnorePointer(
        child: ColoredBox(
          color: AppTokens.background,
          child: SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                mascot('assets/mascots/mascot_thumbs_up.png', 244, 209, 55, 70),
                mascot('assets/mascots/mascot_thinking.png', 1, 424, 112, 176),
                mascot('assets/mascots/mascot_lightbulb.png', 299, 591, 78, 101),
                ...stickers,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sticker placement table (reference px at 390x844) ──────────────────────

class _StickerSpec {
  final StickerKind kind;
  final double x, y, size, amount, duration, delay;
  const _StickerSpec(
    this.kind,
    this.x,
    this.y,
    this.size,
    this.amount,
    this.duration,
    this.delay,
  );
}

const List<_StickerSpec> _stickers = [
  _StickerSpec(StickerKind.star, 314, 218, 38, 6, 3.2, 0.3),
  _StickerSpec(StickerKind.plus, 10, 314, 28, 8, 2.4, 1.1),
  _StickerSpec(StickerKind.triangle, 126, 310, 34, 6, 3.6, 0.7),
  _StickerSpec(StickerKind.circle, 330, 303, 35, 8, 2.8, 1.6),
  _StickerSpec(StickerKind.times, 319, 377, 30, 6, 2.6, 0.2),
  _StickerSpec(StickerKind.hexagon, 340, 442, 38, 8, 3.4, 1.3),
  _StickerSpec(StickerKind.roundedSquare, 138, 526, 38, 6, 2.9, 0.9),
  _StickerSpec(StickerKind.minus, 342, 516, 24, 8, 3.8, 0.5),
  _StickerSpec(StickerKind.cylinder, 24, 622, 38, 6, 3.1, 1.8),
  _StickerSpec(StickerKind.cube, 214, 628, 38, 8, 2.5, 0.4),
  _StickerSpec(StickerKind.divide, 80, 636, 38, 6, 3.7, 1.2),
  _StickerSpec(StickerKind.equals, 11, 362, 34, 8, 2.3, 1.7),
];

class _FloatingSticker extends StatelessWidget {
  final ValueNotifier<double> seconds;
  final double amount;
  final double duration;
  final double delay;
  final StickerKind kind;

  const _FloatingSticker({
    required this.seconds,
    required this.amount,
    required this.duration,
    required this.delay,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    // Built (and rasterised) once; only the translate changes per frame.
    final cached = RepaintBoundary(
      child: Opacity(
        opacity: 0.55,
        child: CustomPaint(painter: StickerPainter(kind), isComplex: true),
      ),
    );

    return ValueListenableBuilder<double>(
      valueListenable: seconds,
      child: cached,
      builder: (context, t, child) {
        double dy = 0;
        if (t > delay) {
          final phase = ((t - delay) / duration) % 1.0;
          // ease-in-out up and back down (cosine easing)
          dy = -amount * (1 - math.cos(2 * math.pi * phase)) / 2;
        }
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
    );
  }
}

// ─── Sticker vector art ─────────────────────────────────────────────────────

enum StickerKind {
  star,
  triangle,
  circle,
  roundedSquare,
  hexagon,
  cylinder,
  cube,
  plus,
  minus,
  times,
  divide,
  equals,
}

/// Draws a flat sticker on a 0..100 viewBox, scaled to the paint size.
class StickerPainter extends CustomPainter {
  final StickerKind kind;
  const StickerPainter(this.kind);

  static const Color _navy = Color(0xFF33408F);
  static const Color _opOutline = Color(0xFF0B4FA8);
  static const Color _opTop = Color(0xFF2B7FE8);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (kind) {
      case StickerKind.star:
        _shape(canvas, _poly(const [
          [50, 18], [58.5, 40.3], [82.3, 41.5], [63.75, 56.5], [70, 79.5],
          [50, 66.5], [30, 79.5], [36.25, 56.5], [17.7, 41.5], [41.5, 40.3],
        ]), const Color(0xFFFDE68A));
      case StickerKind.triangle:
        _shape(canvas, _poly(const [[50, 18], [84, 80], [16, 80]]),
            const Color(0xFFBAE6FD));
      case StickerKind.circle:
        _shape(canvas, Path()..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 32)),
            const Color(0xFFBAE6FD));
      case StickerKind.roundedSquare:
        _shape(
            canvas,
            Path()..addRRect(RRect.fromLTRBR(20, 20, 80, 80, const Radius.circular(14))),
            const Color(0xFFFED7AA));
      case StickerKind.hexagon:
        _shape(canvas, _poly(const [
          [50, 17], [78.6, 33.5], [78.6, 66.5], [50, 83], [21.4, 66.5], [21.4, 33.5],
        ]), const Color(0xFFBBF7D0));
      case StickerKind.cylinder:
        final p = Path()
          ..moveTo(28, 30)
          ..arcToPoint(const Offset(72, 30),
              radius: const Radius.elliptical(22, 9), clockwise: true)
          ..lineTo(72, 70)
          ..arcToPoint(const Offset(28, 70),
              radius: const Radius.elliptical(22, 9), clockwise: true)
          ..close();
        _shape(canvas, p, const Color(0xFFFBCFE8));
      case StickerKind.cube:
        _cube(canvas);
      case StickerKind.plus:
        _op(canvas, _lines(const [[50, 22, 50, 78], [22, 50, 78, 50]]));
      case StickerKind.minus:
        _op(canvas, _lines(const [[22, 50, 78, 50]]));
      case StickerKind.times:
        _op(canvas, _lines(const [[28, 28, 72, 72], [72, 28, 28, 72]]));
      case StickerKind.divide:
        _op(canvas, _lines(const [[22, 50, 78, 50]]),
            dots: const [Offset(50, 24), Offset(50, 76)]);
      case StickerKind.equals:
        _op(canvas, _lines(const [[22, 36, 78, 36], [22, 64, 78, 64]]));
    }
    canvas.restore();
  }

  Path _poly(List<List<double>> pts) {
    final p = Path()..moveTo(pts.first[0], pts.first[1]);
    for (final pt in pts.skip(1)) {
      p.lineTo(pt[0], pt[1]);
    }
    return p..close();
  }

  Path _lines(List<List<double>> segs) {
    final p = Path();
    for (final s in segs) {
      p
        ..moveTo(s[0], s[1])
        ..lineTo(s[2], s[3]);
    }
    return p;
  }

  Paint _fill(Color c) => Paint()
    ..style = PaintingStyle.fill
    ..color = c
    ..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = c
    ..isAntiAlias = true;

  /// Three stacked layers using the same geometry.
  void _shape(Canvas canvas, Path p, Color fill) {
    // 1) soft white sticker border
    canvas.drawPath(p, _fill(Colors.white));
    canvas.drawPath(p, _stroke(Colors.white, 16));
    // 2) navy ring
    canvas.drawPath(p, _stroke(_navy, 8));
    // 3) flat fill with same-colored stroke
    canvas.drawPath(p, _fill(fill));
    canvas.drawPath(p, _stroke(fill, 3));
  }

  void _cube(Canvas canvas) {
    final border = _poly(const [
      [50, 16], [82, 34], [82, 68], [50, 86], [18, 68], [18, 34],
    ]);
    canvas.drawPath(border, _fill(Colors.white));
    canvas.drawPath(border, _stroke(Colors.white, 12));

    void face(List<List<double>> pts, Color c) {
      final p = _poly(pts);
      canvas.drawPath(p, _fill(c));
      canvas.drawPath(p, _stroke(_navy, 2.5));
    }

    face(const [[50, 16], [82, 34], [50, 52], [18, 34]], const Color(0xFFC4B5FD));
    face(const [[18, 34], [50, 52], [50, 86], [18, 68]], const Color(0xFFA78BFA));
    face(const [[50, 52], [82, 34], [82, 68], [50, 86]], const Color(0xFF8B5CF6));
  }

  void _op(Canvas canvas, Path p, {List<Offset> dots = const []}) {
    canvas.drawPath(p, _stroke(_opOutline, 22));
    for (final d in dots) {
      canvas.drawCircle(d, 11, _fill(_opOutline));
    }
    canvas.drawPath(p, _stroke(_opTop, 16));
    for (final d in dots) {
      canvas.drawCircle(d, 8, _fill(_opTop));
    }
  }

  @override
  bool shouldRepaint(covariant StickerPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
