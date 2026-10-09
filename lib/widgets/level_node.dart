import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/mathalino_tokens.dart';
import '../providers/level_progress_provider.dart';
import 'home/home_strings.dart';

/// Visual kind of a node on the level map.
enum LevelNodeKind { completed, current, unlocked, locked }

extension LevelNodeKindX on LevelNodeKind {
  /// Outer diameter of the circle (border/ring included).
  double get diameter {
    switch (this) {
      case LevelNodeKind.completed:
        return 60;
      case LevelNodeKind.current:
        return 104;
      case LevelNodeKind.unlocked:
      case LevelNodeKind.locked:
        return 64;
    }
  }
}

/// Maps the provider state to a visual kind (presentation only).
LevelNodeKind levelNodeKindFor(LevelState state, bool isCurrent) {
  if (state == LevelState.locked) return LevelNodeKind.locked;
  if (state == LevelState.completed) return LevelNodeKind.completed;
  return isCurrent ? LevelNodeKind.current : LevelNodeKind.unlocked;
}

/// Level node for the Mathalino adventure map (Home).
///
/// Behavior is unchanged: playable nodes call [onTap]; locked nodes show the
/// existing "locked" snackbar.
class LevelNode extends StatelessWidget {
  final int levelNumber;
  final LevelState state;
  final bool isHard;
  final bool isBoss;
  final bool isCurrent;
  final VoidCallback onTap;

  const LevelNode({
    super.key,
    required this.levelNumber,
    required this.state,
    this.isHard = false,
    this.isBoss = false,
    this.isCurrent = false,
    required this.onTap,
  });

  LevelNodeKind get kind => levelNodeKindFor(state, isCurrent);

  void _handleTap(BuildContext context) {
    if (state != LevelState.locked) {
      onTap();
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Level $levelNumber is locked. Complete earlier levels first!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String get _semanticLabel {
    switch (kind) {
      case LevelNodeKind.completed:
        return HomeStrings.nodeCompleted(levelNumber);
      case LevelNodeKind.current:
        return HomeStrings.nodeCurrent(levelNumber);
      case LevelNodeKind.unlocked:
        return HomeStrings.nodeUnlocked(levelNumber);
      case LevelNodeKind.locked:
        return HomeStrings.nodeLocked(levelNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = kind;
    Widget visual;
    switch (k) {
      case LevelNodeKind.completed:
        visual = _CompletedNode(level: levelNumber);
      case LevelNodeKind.current:
        visual = _CurrentNode(level: levelNumber);
      case LevelNodeKind.unlocked:
        visual = _UnlockedNode(level: levelNumber, isHard: isHard, isBoss: isBoss);
      case LevelNodeKind.locked:
        visual = _LockedNode(level: levelNumber);
    }

    // Keep numbers inside the circles when the user enlarges system text.
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.2,
      child: Semantics(
        button: true,
        enabled: true,
        label: _semanticLabel,
        onTap: () => _handleTap(context),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(context),
          child: visual,
        ),
      ),
    );
  }
}

// ─── Completed ──────────────────────────────────────────────────────────────

class _CompletedNode extends StatelessWidget {
  final int level;
  const _CompletedNode({required this.level});

  @override
  Widget build(BuildContext context) {
    const d = 60.0;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: AppTokens.successGreen,
              shape: BoxShape.circle,
              border: Border.all(color: AppTokens.completedRing, width: 4),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, color: Colors.white, size: 32),
          ),
          Positioned(
            top: d + 4,
            left: -12,
            right: -12,
            child: Text(
              '$level',
              textAlign: TextAlign.center,
              style: AppTokens.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTokens.successGreen,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Unlocked (playable, not the current level) ─────────────────────────────

class _UnlockedNode extends StatelessWidget {
  final int level;
  final bool isHard;
  final bool isBoss;
  const _UnlockedNode({
    required this.level,
    required this.isHard,
    required this.isBoss,
  });

  @override
  Widget build(BuildContext context) {
    const d = 64.0;
    final badge = isBoss
        ? Icons.workspace_premium_rounded
        : (isHard ? Icons.star_rounded : null);
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: AppTokens.currentBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: AppTokens.currentBlueDark,
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$level',
              style: AppTokens.baloo2(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppTokens.accentOrange,
                  shape: BoxShape.circle,
                ),
                child: Icon(badge, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Locked ─────────────────────────────────────────────────────────────────

class _LockedNode extends StatelessWidget {
  final int level;
  const _LockedNode({required this.level});

  @override
  Widget build(BuildContext context) {
    const d = 64.0;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: AppTokens.lockedFill,
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.lockedBorder, width: 4),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, color: AppTokens.lockedContent, size: 20),
          Text(
            '$level',
            style: AppTokens.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTokens.lockedContent,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Current (hero) ─────────────────────────────────────────────────────────

/// The pulsing, white-bordered current level with a bobbing START tag.
///
/// One controller drives both loops (7.2s = 4 pulses of 1.8s = 3 bobs of 2.4s)
/// and only transforms/opacity are animated. Disabled by the OS reduce-motion
/// setting.
class _CurrentNode extends StatefulWidget {
  final int level;
  const _CurrentNode({required this.level});

  @override
  State<_CurrentNode> createState() => _CurrentNodeState();
}

class _CurrentNodeState extends State<_CurrentNode>
    with SingleTickerProviderStateMixin {
  static const double _d = 104;
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Static, cached hero circle (does not rebuild every frame).
    final hero = RepaintBoundary(
      child: Container(
        width: _d,
        height: _d,
        decoration: BoxDecoration(
          color: AppTokens.currentBlue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: const [
            BoxShadow(
              color: AppTokens.currentBlueDark,
              offset: Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '${widget.level}',
          style: AppTokens.baloo2(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );

    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.currentBlueDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        HomeStrings.start,
        style: AppTokens.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1,
          height: 1.2,
        ),
      ),
    );

    return SizedBox(
      width: _d,
      height: _d,
      child: AnimatedBuilder(
        animation: _controller,
        child: hero,
        builder: (context, child) {
          final v = _controller.value;
          // Pulse: 1.8s loop, scale 1 -> 1.55, opacity .5 -> 0
          final pulsePhase = (v * 4) % 1.0;
          final eased = Curves.easeOut.transform(pulsePhase);
          final pulseScale = 1 + 0.55 * eased;
          final pulseOpacity = _reduceMotion ? 0.0 : 0.5 * (1 - eased);
          // Bob: 2.4s loop, 6px up and back, ease-in-out
          final bobPhase = (v * 3) % 1.0;
          final bob = _reduceMotion
              ? 0.0
              : -6 * (1 - math.cos(2 * math.pi * bobPhase)) / 2;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Transform.scale(
                  scale: pulseScale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTokens.currentBlue.withValues(alpha: pulseOpacity),
                    ),
                  ),
                ),
              ),
              child!,
              Positioned(
                top: -34,
                left: -20,
                right: -20,
                child: Transform.translate(
                  offset: Offset(0, bob),
                  child: Center(child: tag),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
