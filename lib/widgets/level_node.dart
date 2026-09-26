import 'package:flutter/material.dart';
import '../providers/level_progress_provider.dart';

/// Level Node Widget for Mathalino Adventure Map
/// Represents a single level button in one of 4 states: locked, unlocked, completed, or challenge.
class LevelNode extends StatefulWidget {
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

  @override
  State<LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<LevelNode> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isCurrent) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlayable = widget.state != LevelState.locked;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isCurrent ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (isPlayable) {
            widget.onTap();
          } else {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Level ${widget.levelNumber} is locked. Complete earlier levels first!'),
                  ],
                ),
                backgroundColor: Colors.grey[800],
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        child: Container(
          width: widget.isBoss ? 76 : 64,
          height: widget.isBoss ? 76 : 64,
          decoration: _buildNodeDecoration(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main content (number & primary icon)
              _buildNodeContent(),

              // Badge overlay for completed or challenge
              if (widget.state == LevelState.completed)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),

              if (widget.state == LevelState.challenge && !widget.isBoss)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildNodeDecoration() {
    switch (widget.state) {
      case LevelState.locked:
        return BoxDecoration(
          color: const Color(0xFFE5E7EB),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF9CA3AF), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );

      case LevelState.completed:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34D399), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF059669), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        );

      case LevelState.challenge:
        if (widget.isBoss) {
          return BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF59E0B), width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          );
        }
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD97706), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        );

      case LevelState.unlocked:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isCurrent ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
            width: widget.isCurrent ? 4 : 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.isCurrent ? const Color(0xFFF59E0B) : const Color(0xFF4F46E5)).withValues(alpha: 0.5),
              blurRadius: widget.isCurrent ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  Widget _buildNodeContent() {
    if (widget.state == LevelState.locked) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, color: Color(0xFF6B7280), size: 20),
          const SizedBox(height: 2),
          Text(
            '${widget.levelNumber}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (widget.isBoss) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.workspace_premium, color: Color(0xFFFCD34D), size: 24),
          Text(
            'L${widget.levelNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isHard && widget.state != LevelState.completed)
          const Icon(Icons.star, color: Colors.white, size: 16),
        Text(
          '${widget.levelNumber}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: widget.isHard ? 14 : 16,
          ),
        ),
      ],
    );
  }
}
