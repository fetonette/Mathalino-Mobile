import 'package:flutter/material.dart';

import '../core/theme/mathalino_tokens.dart';

/// Child-friendly 1–3 star rating display for level/adventure completion.
///
/// PRESENTATION ONLY — it never writes to the database. The star count is
/// derived with the exact same thresholds that
/// `SupabaseService.saveLevelCompletion` already persists
/// (accuracy >= 90 → 3 stars, >= 60 → 2 stars, otherwise 1 star), so the
/// on-screen rating always matches the stored `level_progress.stars` /
/// `student_results.stars` value. Use [StarRating.starsForScore] with the same
/// `score` / `attempted` session counters that feed the persistence path.
///
/// Accessibility: filled vs. outlined star SHAPES communicate the rating so it
/// does not rely on color alone, and a [Semantics] label announces the result.
/// A gentle pop-in animation is used unless the platform requests reduced
/// motion (or [animate] is false).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.stars,
    this.maxStars = 3,
    this.starSize = 44,
    this.gap = 8,
    this.animate = true,
  });

  final int stars;
  final int maxStars;
  final double starSize;
  final double gap;
  final bool animate;

  /// Accuracy percentage computed exactly the way the provider computes the
  /// persisted value (rounded to one decimal). Defensive for a zero/negative
  /// [attempted] so the display never divides by zero.
  static double accuracyForScore(int score, int attempted) {
    if (attempted <= 0) return 0.0;
    return double.parse((score / attempted * 100).toStringAsFixed(1));
  }

  /// Pure star-count helper reusing the single canonical threshold rule
  /// (>= 90 → 3, >= 60 → 2, else 1) so gameplay UI and persistence agree.
  static int starsForAccuracy(double accuracyPct) {
    if (accuracyPct >= 90) return 3;
    if (accuracyPct >= 60) return 2;
    return 1;
  }

  /// Convenience wrapper: derives stars directly from the raw counters using
  /// the same path the persistence layer uses.
  static int starsForScore(int score, int attempted) =>
      starsForAccuracy(accuracyForScore(score, attempted));

  /// Encouraging, child-friendly caption for the achieved rating.
  static String messageForStars(int stars) {
    switch (stars) {
      case 3:
        return 'Perfect! You got it right away!';
      case 2:
        return 'Great work! Keep it up!';
      default:
        return 'You did it! Practice makes perfect!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = stars.clamp(0, maxStars);
    final children = <Widget>[];
    for (var i = 0; i < maxStars; i++) {
      children.add(_StarIcon(
        index: i,
        filled: i < filled,
        size: starSize,
        animate: animate,
      ));
      if (i != maxStars - 1) children.add(SizedBox(width: gap));
    }
    return Semantics(
      label: '$filled out of $maxStars stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _StarIcon extends StatelessWidget {
  const _StarIcon({
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
    final star = Icon(
      // Filled vs. outline shape → readable without relying on color alone.
      filled ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size,
      color: filled ? AppTokens.accentOrange : AppTokens.accentRing,
    );
    if (!animate || reduceMotion) return star;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + index * 140),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 0.5 + 0.5 * value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: star,
    );
  }
}
