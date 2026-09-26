// Vector scenes for Mathalino question illustrations (CustomPainter).
// Scenes derive ONLY from question metadata resolved by
// question_illustration.dart - never answer keys - so Firestore stays the
// single source of question content.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kind of visual scene rendered for a question.
enum QuestionSceneKind {
  number,
  addition,
  subtraction,
  multiplication,
  division,
  fraction,
  geometry,
  pattern,
  time,
  measurement,
  mass,
  money,
  dataProbability,
  algebra,
  symbols,
}

/// Cheerful {light, dark, accent} palette per scene.
class ScenePalette {
  final Color light;
  final Color dark;
  final Color accent;
  const ScenePalette(this.light, this.dark, this.accent);
}

const Map<QuestionSceneKind, ScenePalette> scenePalettes = {
  QuestionSceneKind.number: ScenePalette(
    Color(0xFFC7D2FE),
    Color(0xFF4F46E5),
    Color(0xFFF59E0B),
  ),
  QuestionSceneKind.addition: ScenePalette(
    Color(0xFFA7F3D0),
    Color(0xFF047857),
    Color(0xFFFB7185),
  ),
  QuestionSceneKind.subtraction: ScenePalette(
    Color(0xFFFED7AA),
    Color(0xFFC2410C),
    Color(0xFF3B82F6),
  ),
  QuestionSceneKind.multiplication: ScenePalette(
    Color(0xFFFBCFE8),
    Color(0xFFBE185D),
    Color(0xFF8B5CF6),
  ),
  QuestionSceneKind.division: ScenePalette(
    Color(0xFFFDE68A),
    Color(0xFFB45309),
    Color(0xFF10B981),
  ),
  QuestionSceneKind.fraction: ScenePalette(
    Color(0xFFFFE4C7),
    Color(0xFFEA580C),
    Color(0xFF6366F1),
  ),
  QuestionSceneKind.geometry: ScenePalette(
    Color(0xFFBFDBFE),
    Color(0xFF1D4ED8),
    Color(0xFFF97316),
  ),
  QuestionSceneKind.pattern: ScenePalette(
    Color(0xFFDDD6FE),
    Color(0xFF6D28D9),
    Color(0xFFEC4899),
  ),
  QuestionSceneKind.time: ScenePalette(
    Color(0xFFA5F3FC),
    Color(0xFF0891B2),
    Color(0xFFF59E0B),
  ),
  QuestionSceneKind.measurement: ScenePalette(
    Color(0xFF99F6E4),
    Color(0xFF0F766E),
    Color(0xFF0EA5E9),
  ),
  QuestionSceneKind.mass: ScenePalette(
    Color(0xFFFDE68A),
    Color(0xFF92400E),
    Color(0xFF10B981),
  ),
  QuestionSceneKind.money: ScenePalette(
    Color(0xFFBBF7D0),
    Color(0xFF047857),
    Color(0xFFF59E0B),
  ),
  QuestionSceneKind.dataProbability: ScenePalette(
    Color(0xFFE9D5FF),
    Color(0xFF7E22CE),
    Color(0xFFF43F5E),
  ),
  QuestionSceneKind.algebra: ScenePalette(
    Color(0xFFC7D2FE),
    Color(0xFF4338CA),
    Color(0xFF10B981),
  ),
  QuestionSceneKind.symbols: ScenePalette(
    Color(0xFFCBD5E1),
    Color(0xFF334155),
    Color(0xFFF59E0B),
  ),
};

/// Human-friendly topic label shown on the illustration chip.
String sceneLabel(QuestionSceneKind scene) {
  switch (scene) {
    case QuestionSceneKind.number:
      return 'Identify Numbers';
    case QuestionSceneKind.addition:
      return 'Addition';
    case QuestionSceneKind.subtraction:
      return 'Subtraction';
    case QuestionSceneKind.multiplication:
      return 'Multiplication';
    case QuestionSceneKind.division:
      return 'Division';
    case QuestionSceneKind.fraction:
      return 'Fractions';
    case QuestionSceneKind.geometry:
      return 'Geometry';
    case QuestionSceneKind.pattern:
      return 'Patterns';
    case QuestionSceneKind.time:
      return 'Time';
    case QuestionSceneKind.measurement:
      return 'Measurement';
    case QuestionSceneKind.mass:
      return 'Mass';
    case QuestionSceneKind.money:
      return 'Money';
    case QuestionSceneKind.dataProbability:
      return 'Data & Chance';
    case QuestionSceneKind.algebra:
      return 'Algebra';
    case QuestionSceneKind.symbols:
      return 'Math';
  }
}

/// Paints the central artwork for a [QuestionSceneKind].
class QuestionScenePainter extends CustomPainter {
  final QuestionSceneKind scene;
  final ScenePalette palette;
  final int seed;
  final double twinkle; // 0..1 drives subtle pulsing highlights

  QuestionScenePainter({
    required this.scene,
    required this.palette,
    required this.seed,
    required this.twinkle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2 + s * 0.02);

    // Soft white badge behind the artwork so it pops on the gradient.
    canvas.drawCircle(
      c,
      s * 0.34,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    switch (scene) {
      case QuestionSceneKind.number:
        _numbers(canvas, c, s);
      case QuestionSceneKind.addition:
        _addSub(canvas, c, s, true);
      case QuestionSceneKind.subtraction:
        _addSub(canvas, c, s, false);
      case QuestionSceneKind.multiplication:
        _grid(canvas, c, s);
      case QuestionSceneKind.division:
        _groups(canvas, c, s);
      case QuestionSceneKind.fraction:
        _fraction(canvas, c, s);
      case QuestionSceneKind.geometry:
        _shapes(canvas, c, s);
      case QuestionSceneKind.pattern:
        _pattern(canvas, c, s);
      case QuestionSceneKind.time:
        _clock(canvas, c, s);
      case QuestionSceneKind.measurement:
        _ruler(canvas, c, s);
      case QuestionSceneKind.mass:
        _scale(canvas, c, s, false);
      case QuestionSceneKind.algebra:
        _scale(canvas, c, s, true);
      case QuestionSceneKind.money:
        _money(canvas, c, s);
      case QuestionSceneKind.dataProbability:
        _jar(canvas, c, s);
      case QuestionSceneKind.symbols:
        _symbols(canvas, c, s);
    }
  }

  // ── shared helpers ──────────────────────────────────────────────────────
  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _dot(Canvas canvas, Offset o, double r, Color c) =>
      canvas.drawCircle(o, r, _fill(c));

  void _box(
    Canvas canvas,
    Rect r,
    double radius,
    Color fill,
    Color stroke,
    double sw,
  ) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, _fill(fill));
    canvas.drawRRect(rr, _stroke(stroke, sw));
  }

  void _text(
    Canvas canvas,
    String t,
    Offset center,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w900,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  // Small cluster of counters centred on [center].
  void _cluster(
    Canvas canvas,
    Offset center,
    int count,
    double s,
    Color color,
  ) {
    const cols = 2;
    final gap = s * 0.14;
    for (var i = 0; i < count; i++) {
      _dot(
        canvas,
        center + Offset((i % cols - 0.5) * gap, (i ~/ cols - 0.5) * gap),
        s * 0.048,
        color,
      );
    }
  }

  // ── scenes ──────────────────────────────────────────────────────────────
  void _numbers(Canvas canvas, Offset c, double s) {
    final rng = math.Random(seed);
    _text(
      canvas,
      '${1 + rng.nextInt(9)}',
      c + Offset(-s * 0.20, -s * 0.02),
      s * 0.26,
      palette.dark,
    );
    _text(
      canvas,
      '${1 + rng.nextInt(9)}',
      c + Offset(s * 0.20, -s * 0.02),
      s * 0.26,
      palette.dark,
    );
    for (var i = 0; i < 3; i++) {
      final o = c + Offset((i - 1) * s * 0.13, s * 0.19);
      _box(
        canvas,
        Rect.fromCenter(center: o, width: s * 0.09, height: s * 0.09),
        3,
        palette.accent,
        palette.dark,
        1.5,
      );
    }
  }

  void _addSub(Canvas canvas, Offset c, double s, bool isAdd) {
    final rng = math.Random(seed);
    final left = 2 + rng.nextInt(2);
    final right = 2 + rng.nextInt(3);
    final col = palette.dark.withValues(alpha: 0.75);
    _cluster(canvas, c + Offset(-s * 0.30, -s * 0.05), left, s, col);
    _cluster(canvas, c + Offset(s * 0.30, -s * 0.05), right, s, col);
    _text(canvas, isAdd ? '+' : '−', c, s * 0.28, palette.dark);
  }

  void _grid(Canvas canvas, Offset c, double s) {
    const rows = 3, cols = 4;
    final gap = s * 0.15;
    for (var r = 0; r < rows; r++) {
      for (var col = 0; col < cols; col++) {
        _dot(
          canvas,
          c + Offset((col - (cols - 1) / 2) * gap, (r - (rows - 1) / 2) * gap),
          s * 0.042,
          palette.accent,
        );
      }
    }
    _text(
      canvas,
      '= ?',
      c + Offset(0, s * 0.26),
      s * 0.11,
      palette.dark,
      weight: FontWeight.w800,
    );
  }

  void _groups(Canvas canvas, Offset c, double s) {
    // Two equal baskets sharing a set -> division.
    for (final side in [-1.0, 1.0]) {
      final r = Rect.fromCenter(
        center: c + Offset(side * s * 0.24, s * 0.07),
        width: s * 0.27,
        height: s * 0.19,
      );
      _box(canvas, r, 6, Colors.white, palette.dark, 3);
      for (var i = 0; i < 3; i++) {
        _dot(
          canvas,
          Offset(r.left + r.width * (0.25 + i * 0.25), r.center.dy),
          s * 0.034,
          palette.accent,
        );
      }
    }
    _text(canvas, '÷', c - Offset(0, s * 0.20), s * 0.16, palette.dark);
  }

  void _fraction(Canvas canvas, Offset c, double s) {
    final rng = math.Random(seed);
    final parts = 2 + rng.nextInt(6);
    final shaded = 1 + rng.nextInt(parts - 1);
    final r = s * 0.25;
    canvas.drawCircle(c, r, _fill(Colors.white));
    final start = -math.pi / 2;
    final sweep = 2 * math.pi / parts;
    for (var i = 0; i < parts; i++) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(
          Rect.fromCircle(center: c, radius: r),
          start + i * sweep,
          sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, _fill(i < shaded ? palette.dark : palette.light));
    }
    canvas.drawCircle(c, r, _stroke(palette.dark, 3));
    _text(
      canvas,
      '$shaded/$parts',
      c + Offset(0, s * 0.33),
      s * 0.12,
      palette.dark,
      weight: FontWeight.w800,
    );
  }

  void _shapes(Canvas canvas, Offset c, double s) {
    final t = s * 0.24;
    final tri = Path()
      ..moveTo(c.dx - t, c.dy + t * 0.8)
      ..lineTo(c.dx, c.dy - t)
      ..lineTo(c.dx + t, c.dy + t * 0.8)
      ..close();
    canvas.drawPath(tri, _fill(palette.accent.withValues(alpha: 0.85)));
    canvas.drawPath(tri, _stroke(palette.dark, 3));
    _box(
      canvas,
      Rect.fromCenter(
        center: c + Offset(s * 0.06, s * 0.29),
        width: s * 0.15,
        height: s * 0.15,
      ),
      4,
      palette.light,
      palette.dark,
      3,
    );
    _dot(canvas, c + Offset(-s * 0.26, -s * 0.12), s * 0.078, palette.dark);
  }

  void _pattern(Canvas canvas, Offset c, double s) {
    const total = 4;
    final gap = s * 0.17;
    final startX = c.dx - ((total - 1) / 2) * gap - gap * 0.55;
    for (var i = 0; i < total; i++) {
      final o = Offset(startX + i * gap, c.dy);
      if (i.isEven) {
        _dot(canvas, o, s * 0.056, palette.dark);
      } else {
        final tri = Path()
          ..moveTo(o.dx, o.dy - s * 0.066)
          ..lineTo(o.dx - s * 0.056, o.dy + s * 0.048)
          ..lineTo(o.dx + s * 0.056, o.dy + s * 0.048)
          ..close();
        canvas.drawPath(tri, _fill(palette.accent));
      }
    }
    // Mystery next-slot pulses with the twinkle phase.
    final q = Offset(startX + total * gap, c.dy);
    _box(
      canvas,
      Rect.fromCenter(center: q, width: s * 0.11, height: s * 0.11),
      4,
      Color.lerp(palette.light, Colors.white, twinkle) ?? palette.light,
      palette.dark,
      2.5,
    );
    _text(canvas, '?', q, s * 0.085, palette.dark, weight: FontWeight.w800);
  }

  void _clock(Canvas canvas, Offset c, double s) {
    final r = s * 0.25;
    canvas.drawCircle(c, r, _fill(Colors.white));
    canvas.drawCircle(c, r, _stroke(palette.dark, 3));
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * math.pi;
      canvas.drawLine(
        Offset(
          c.dx + math.cos(a) * (r - s * 0.04),
          c.dy + math.sin(a) * (r - s * 0.04),
        ),
        Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
        _stroke(palette.dark, 2),
      );
    }
    final rng = math.Random(seed);
    final hourAng = rng.nextInt(12) / 12 * 2 * math.pi - math.pi / 2;
    final minAng = rng.nextInt(4) * 15 / 60 * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
      c,
      Offset(
        c.dx + math.cos(hourAng) * r * 0.5,
        c.dy + math.sin(hourAng) * r * 0.5,
      ),
      _stroke(palette.dark, 4),
    );
    canvas.drawLine(
      c,
      Offset(
        c.dx + math.cos(minAng) * r * 0.72,
        c.dy + math.sin(minAng) * r * 0.72,
      ),
      _stroke(palette.accent, 3),
    );
    _dot(canvas, c, s * 0.02, palette.dark);
  }

  void _ruler(Canvas canvas, Offset c, double s) {
    final rect = Rect.fromCenter(center: c, width: s * 0.6, height: s * 0.21);
    _box(canvas, rect, 8, Colors.white, palette.dark, 3);
    for (var i = 1; i < 8; i++) {
      final x = rect.left + rect.width * i / 8;
      final tall = i.isEven ? rect.height * 0.42 : rect.height * 0.24;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.top + tall),
        _stroke(palette.dark, 2),
      );
    }
    _box(
      canvas,
      Rect.fromCenter(
        center: c + Offset(rect.width * 0.22, rect.height * 0.62),
        width: s * 0.19,
        height: s * 0.08,
      ),
      4,
      palette.accent,
      palette.dark,
      2,
    );
  }

  void _scale(Canvas canvas, Offset c, double s, bool algebra) {
    final beam = Paint()
      ..color = palette.dark
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final pivot = c + Offset(0, -s * 0.20);
    final half = s * 0.27;
    canvas.drawLine(
      Offset(pivot.dx - half, pivot.dy),
      Offset(pivot.dx + half, pivot.dy),
      beam,
    );
    canvas.drawLine(pivot, pivot + Offset(0, s * 0.12), beam);
    _dot(canvas, pivot, s * 0.022, palette.dark);

    for (final side in [-1.0, 1.0]) {
      final top = pivot + Offset(side * half, 0);
      final pan = top + Offset(0, s * 0.21);
      canvas.drawLine(top, pan, beam);
      final boxR = Rect.fromCenter(
        center: pan + Offset(0, -s * 0.02),
        width: s * 0.14,
        height: s * 0.14,
      );
      final isLeft = side < 0;
      final fill = algebra && isLeft ? palette.accent : palette.light;
      _box(canvas, boxR, 4, fill, palette.dark, 2.5);
      if (algebra) {
        _text(
          canvas,
          isLeft ? 'x' : '?',
          boxR.center,
          s * 0.10,
          isLeft ? Colors.white : palette.dark,
        );
      } else if (!isLeft) {
        _text(canvas, '?', boxR.center, s * 0.10, palette.dark);
      } else {
        _dot(canvas, boxR.center, s * 0.032, palette.dark);
      }
    }
  }

  void _money(Canvas canvas, Offset c, double s) {
    final coins = c + Offset(-s * 0.22, s * 0.05);
    for (var i = 1; i >= 0; i--) {
      final o = coins + Offset(0, i * s * 0.055);
      canvas.drawCircle(o, s * 0.085, _fill(Colors.white));
      canvas.drawCircle(o, s * 0.085, _stroke(palette.accent, 2.5));
    }
    final note = Rect.fromCenter(
      center: c + Offset(s * 0.20, 0),
      width: s * 0.34,
      height: s * 0.20,
    );
    _box(canvas, note, 8, palette.light, palette.dark, 2.5);
    _text(
      canvas,
      '₱',
      note.center,
      s * 0.14,
      palette.dark,
      weight: FontWeight.w800,
    );
  }

  void _jar(Canvas canvas, Offset c, double s) {
    final jar = Rect.fromCenter(
      center: c + Offset(-s * 0.20, 0),
      width: s * 0.27,
      height: s * 0.31,
    );
    _box(canvas, jar, 12, Colors.white, palette.dark, 2.5);
    final colors = [
      palette.accent,
      palette.dark,
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
    ];
    for (var i = 0; i < 6; i++) {
      _dot(
        canvas,
        Offset(
          jar.left + jar.width * (0.25 + (i % 3) * 0.25),
          jar.top + jar.height * (0.30 + (i ~/ 3) * 0.38),
        ),
        s * 0.03,
        colors[i % colors.length],
      );
    }
    final die = Rect.fromCenter(
      center: c + Offset(s * 0.27, s * 0.08),
      width: s * 0.17,
      height: s * 0.17,
    );
    _box(canvas, die, 6, palette.light, palette.dark, 2.5);
    _dot(
      canvas,
      die.center + Offset(-s * 0.033, -s * 0.033),
      s * 0.015,
      palette.dark,
    );
    _dot(
      canvas,
      die.center + Offset(s * 0.033, s * 0.033),
      s * 0.015,
      palette.dark,
    );
  }

  void _symbols(Canvas canvas, Offset c, double s) {
    _text(canvas, '+ − × ÷', c, s * 0.22, palette.dark);
  }

  @override
  bool shouldRepaint(covariant QuestionScenePainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.seed != seed ||
      oldDelegate.twinkle != twinkle;
}
