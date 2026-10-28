import 'package:flutter/material.dart';

import '../core/theme/mathalino_tokens.dart';

/// Child-friendly hearts display for Preparation / Moderate level attempts.
///
/// PRESENTATION ONLY — the heart count is owned by `LevelProvider`. Filled vs.
/// outlined heart SHAPES communicate remaining lives so the meaning does not
/// rely on color alone, and a [Semantics] label announces the state. A gentle
/// pop-in runs unless the platform requests reduced motion (or [animate] is
/// false), matching the existing [StarRating] conventions.
class Hearts extends StatelessWidget {
  const Hearts({
    super.key,
    required this.hearts,
    this.maxHearts = 3,
    this.iconSize = 26,
    this.gap = 6,
    this.animate = true,
  });

  final int hearts;
  final int maxHearts;
  final double iconSize;
  final double gap;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final remaining = hearts.clamp(0, maxHearts);
    final children = <Widget>[];
    for (var i = 0; i < maxHearts; i++) {
      children.add(_HeartIcon(
        index: i,
        filled: i < remaining,
        size: iconSize,
        animate: animate,
      ));
      if (i != maxHearts - 1) children.add(SizedBox(width: gap));
    }
    return Semantics(
      label: '$remaining out of $maxHearts hearts remaining',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _HeartIcon extends StatelessWidget {
  const _HeartIcon({
    required this.index,
    required this.filled,
    required this.size,
    required this.animate,
  });

  final int index;
  final bool filled;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final heart = Icon(
      // Filled vs. outline shape → readable without relying on color alone.
      filled ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
      size: size,
      color: filled
          ? AppTokens.errorRed
          : Colors.white.withValues(alpha: 0.55),
    );
    if (!animate || reduceMotion) return heart;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + index * 120),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 0.6 + 0.4 * value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: heart,
    );
  }
}
