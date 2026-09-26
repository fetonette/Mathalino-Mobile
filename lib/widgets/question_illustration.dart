// Animated competency-aware illustration banner shown above each question.
//
// The scene is chosen purely from the Question's Firestore metadata
// (contentDomain / competency / prompt keywords) and painted with
// CustomPainter - no answers are rendered and nothing is hardcoded per
// question, so Firestore stays the single source of content.
//
// Animation: gentle vertical float + twinkling sparkles engage young
// learners without distracting from the question itself.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models/question.dart';
import 'question_scene_painter.dart';

/// Animated, topic-aware illustration for a [Question].
class QuestionIllustration extends StatefulWidget {
  final Question question;
  final double height;
  final bool showLabel;

  const QuestionIllustration({
    super.key,
    required this.question,
    this.height = 118,
    this.showLabel = true,
  });

  @override
  State<QuestionIllustration> createState() => _QuestionIllustrationState();
}

class _QuestionIllustrationState extends State<QuestionIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Offset> _sparkleSpots;
  late final List<double> _sparkleSizes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // Deterministic sparkle layout per question id (stable across rebuilds).
    final rng = math.Random(_seed);
    _sparkleSpots = List.generate(
      3,
      (i) => Offset(
        18.0 + rng.nextDouble() * 220,
        10.0 + rng.nextDouble() * (widget.height * 0.45),
      ),
    );
    _sparkleSizes = List.generate(3, (_) => 10.0 + rng.nextDouble() * 10.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _seed {
    var h = 7;
    for (final cu in widget.question.id.codeUnits) {
      h = (h * 31 + cu) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final scene = detectQuestionScene(widget.question);
    final palette = scenePalettes[scene]!;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.light.withValues(alpha: 0.9), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value;
          final dy = -5.0 * math.sin(2 * math.pi * phase);
          final twinkle = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
          return Stack(
            children: [
              Positioned(
                top: -18,
                right: -14,
                child: _blob(palette.accent, 52),
              ),
              Positioned(
                bottom: -24,
                left: -16,
                child: _blob(palette.dark, 60),
              ),
              Positioned.fill(
                bottom: widget.showLabel ? 26 : 8,
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: CustomPaint(
                    painter: QuestionScenePainter(
                      scene: scene,
                      palette: palette,
                      seed: _seed,
                      twinkle: twinkle,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < _sparkleSpots.length; i++)
                Positioned(
                  left: _sparkleSpots[i].dx,
                  top: _sparkleSpots[i].dy,
                  child: Opacity(
                    opacity:
                        0.30 +
                        0.60 *
                            (0.5 -
                                0.5 *
                                    math.cos(2 * math.pi * (phase + i * 0.33))),
                    child: Icon(
                      Icons.auto_awesome,
                      size: _sparkleSizes[i],
                      color: palette.dark.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              if (widget.showLabel)
                Positioned(left: 12, bottom: 8, child: _chip(scene, palette)),
            ],
          );
        },
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      shape: BoxShape.circle,
    ),
  );

  Widget _chip(QuestionSceneKind scene, ScenePalette palette) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 12, color: palette.dark),
        const SizedBox(width: 4),
        Text(
          sceneLabel(scene),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.dark,
          ),
        ),
      ],
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Metadata-driven scene detection
// ────────────────────────────────────────────────────────────────────────────

/// Picks an illustration scene from question metadata + prompt keywords.
QuestionSceneKind detectQuestionScene(Question q) {
  final h =
      '${q.contentDomain} ${q.competencyCode} ${q.competencyText} '
              '${q.questionText}'
          .toLowerCase();

  bool any(List<String> keys) {
    for (final k in keys) {
      if (h.contains(k)) return true;
    }
    return false;
  }

  if (h.contains('mass')) return QuestionSceneKind.mass;
  if (any(['length', 'centimeter', 'ruler', 'kilogram', 'liter', ' gram'])) {
    return QuestionSceneKind.measurement;
  }
  if (any(['time', 'clock', 'minute', 'hour', 'a.m', 'p.m'])) {
    return QuestionSceneKind.time;
  }
  if (h.contains('fraction')) return QuestionSceneKind.fraction;
  if (any(['probability', 'data', 'chance', 'coin', 'marble'])) {
    return QuestionSceneKind.dataProbability;
  }
  if (any(['algebra', 'equation', 'expression', 'evaluate'])) {
    return QuestionSceneKind.algebra;
  }
  if (h.contains('pattern')) return QuestionSceneKind.pattern;
  if (any(['peso', '₱', 'total cost'])) return QuestionSceneKind.money;
  if (any(['multiplication', 'multiply', 'groups of'])) {
    return QuestionSceneKind.multiplication;
  }
  if (any(['division', 'divide', 'shared equally', 'per basket'])) {
    return QuestionSceneKind.division;
  }
  if (any([
    'geometry',
    'shape',
    'triangle',
    'circle',
    'square',
    'rectangle',
    'angle',
  ])) {
    return QuestionSceneKind.geometry;
  }
  if (any([
    'decimal',
    'place value',
    'discrimination',
    'identification',
    'greatest',
    'digit',
    'counting',
  ])) {
    return QuestionSceneKind.number;
  }
  if (any(['addition', 'sum', 'more than'])) {
    return QuestionSceneKind.addition;
  }
  if (any(['subtraction', 'subtract', 'minus', 'take away', 'remain'])) {
    return QuestionSceneKind.subtraction;
  }
  if (any(['measurement', 'meter'])) return QuestionSceneKind.measurement;
  return QuestionSceneKind.symbols;
}
