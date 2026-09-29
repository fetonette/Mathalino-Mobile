import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/student_profile.dart';
import '../../core/services/game_logic_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/level_progress_provider.dart';
import '../../providers/level_provider.dart';
import '../../widgets/difficulty_badge.dart';

/// Zone gameplay screen for Levels 1–60 (all three zones), powered by the new
/// [LevelProvider] which uses [QuestionBankService] + [GameLogicService].
///
/// Behaviour per zone:
///   * Beginner (1–20): Hard/Super-Hardcore gates at 5/10/15/20 drive the
///     remediation loop (preparation-range mastery → new challenge).
///   * Intermediate (21–40): NO gates — every level unlocks in a straight
///     line; a wrong answer simply repeats the same question with standard
///     retry feedback ('Moderate' / 'Moderate (Multi-Step)' badge treatment,
///     no boss iconography).
///   * Advanced (41–60): gates return at 45/50/55, plus the final-boss Level
///     60. Passing Level 60 completes the whole game → the provider surfaces
///     [PlayerPhase.adventureComplete] and this screen shows the
///     "Adventure Complete" state instead of routing to a Level 61.
class BeginnerZoneGameplayScreen extends StatefulWidget {
  final int levelNumber;
  final StudentProfile user;
  final List<String> usedHistory;

  const BeginnerZoneGameplayScreen({
    super.key,
    required this.levelNumber,
    required this.user,
    this.usedHistory = const [],
  });

  @override
  State<BeginnerZoneGameplayScreen> createState() =>
      _BeginnerZoneGameplayScreenState();
}

class _BeginnerZoneGameplayScreenState extends State<BeginnerZoneGameplayScreen> {
  /// Guards against opening multiple feedback dialogs for the same answer.
  bool _feedbackDialogShowing = false;

  /// Cached provider reference so [dispose] can remove the listener without
  /// touching the (deactivated) element tree via `context`.
  LevelProvider? _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<LevelProvider>();
    // When an answer is submitted, the provider flags `feedbackPending`; we
    // listen for that transition and surface the result as a modal dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _provider == null) return;
      _provider!.addListener(_onLevelProviderChanged);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final levelProvider = _provider!;
      // LevelProvider now persists to Supabase automatically (no attach needed).
      levelProvider.startLevel(
            userId: widget.user.uid,
            lrn: widget.user.lrn,
            level: widget.levelNumber,
            usedHistory: widget.usedHistory.isNotEmpty
                ? widget.usedHistory
                : widget.user.usedQuestionsHistory,
          );
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onLevelProviderChanged);
    super.dispose();
  }

  void _onLevelProviderChanged() {
    final provider = _provider;
    if (provider == null) return;
    if (provider.feedbackPending && !_feedbackDialogShowing) {
      // If the level or adventure is already complete, the completion screen
      // displays the combined feedback ("Correct!", score) directly, eliminating
      // the redundant popup dialog.
      if (provider.phase == PlayerPhase.levelComplete ||
          provider.phase == PlayerPhase.adventureComplete) {
        return;
      }
      _feedbackDialogShowing = true;
      _showFeedbackDialog(context, provider);
    }
  }

    Future<void> _submit(dynamic selected) async {
    try {
      await context.read<LevelProvider>().submitAnswer(selected);
    } catch (e, st) {
      debugPrint('[BeginnerZoneGameplayScreen] submitAnswer error: $e\n$st');
            if (mounted) {
        context.read<LevelProvider>().setError('An error occurred: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LevelProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildHeader(context, provider),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            // Keeps the question card comfortably sized on tablets / web
            // while filling the width on phones.
            constraints: const BoxConstraints(maxWidth: 640),
            child: switch (provider.phase) {
              PlayerPhase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
              PlayerPhase.levelComplete =>
                _buildLevelComplete(context, provider),
              PlayerPhase.adventureComplete =>
                _buildAdventureComplete(context, provider),
              PlayerPhase.needsTeacherSupport =>
                _buildNeedsTeacherSupport(context, provider),
              PlayerPhase.levelFailed => _buildFailed(context, provider),
              PlayerPhase.idle => _buildIdle(context, provider),
              _ => _buildQuestion(context, provider),
            },
          ),
        ),
      ),
    );
  }

  /// Rounded primary header: back button (left) · dynamic title (center) ·
  /// difficulty badge (right). Every piece is driven by the live
  /// [LevelProvider] state — no hard-coded content.
  PreferredSizeWidget _buildHeader(
    BuildContext context,
    LevelProvider provider,
  ) {
    final displayLevel = (provider.phase == PlayerPhase.remediationPrep &&
            provider.currentQuestion != null &&
            provider.currentQuestion!.level > 0)
        ? provider.currentQuestion!.level
        : widget.levelNumber;
    final displayDifficulty = (provider.phase == PlayerPhase.remediationPrep &&
            provider.currentQuestion != null)
        ? provider.currentQuestion!.difficulty
        : provider.difficulty;

    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 76,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Level $displayLevel — $displayDifficulty',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      actions: [
        if (!provider.isLoading && provider.error == null)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: DifficultyBadge(difficulty: displayDifficulty),
            ),
          )
        else
          // Keeps the centered title balanced while loading.
          const SizedBox(width: 68),
      ],
    );
  }

  Widget _buildIdle(BuildContext context, LevelProvider provider) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Ready to begin.'),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, LevelProvider provider) {
    final question = provider.currentQuestion;
    if (question == null) {
      return const Center(child: Text('No question available.'));
    }

    // Status label: shows the current question's level (e.g. Level 1)
    final currentLevelNumber = (provider.phase == PlayerPhase.remediationPrep &&
            question.level > 0)
        ? question.level
        : widget.levelNumber;
    final String phaseLabel = 'Level $currentLevelNumber';

    // Present choices in A, B, C, D visual display order.
    // The underlying choice content and answer key are randomized via
    // Fisher-Yates shuffle upon question selection.
    final choices = question.choices.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // White rounded card that fills the remaining screen (scrollable when a
    // long question/choice set overflows), matching the reference layout.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                phaseLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                question.questionText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      fontSize: 19,
                    ),
              ),
              const SizedBox(height: 24),
              ...choices.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildChoiceButton(context, entry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One large, rounded, tap-friendly answer container with a circular
  /// A/B/C/D indicator on the left — sized for small hands on phones.
  Widget _buildChoiceButton(
    BuildContext context,
    MapEntry<String, String> entry,
  ) {
    return OutlinedButton(
      onPressed: () => _submit(entry.key),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.cardBackground,
        side: const BorderSide(color: AppColors.primaryLight, width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        minimumSize: const Size.fromHeight(68),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              entry.key,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entry.value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedbackDialog(
      BuildContext context,
      LevelProvider provider,
  ) async {
    final isCorrect = provider.lastCorrect ?? false;
    final score = provider.score;
    final attempted = provider.attemptedTotal;


    await showDialog<void>(
      context: context,
      barrierDismissible: false, // force the student to acknowledge the result
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Center(
          child: Text(
            'Answer Feedback',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: isCorrect ? Colors.green : Colors.red,
              size: 76,
            ),
            const SizedBox(height: 16),
            Text(
              isCorrect ? 'Correct!' : 'Incorrect',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: $score/$attempted',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding:
            const EdgeInsets.only(left: 24, right: 24, bottom: 28, top: 12),
        actions: [
          SizedBox(
            width: 180,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () {
                provider.dismissFeedback();
                _feedbackDialogShowing = false;
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                isCorrect ? 'Next' : 'Try Again',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelComplete(BuildContext context, LevelProvider provider) {
    final levelProgressProvider =
        Provider.of<LevelProgressProvider>(context, listen: false);
    final score = provider.score;
    final attempted = provider.attemptedTotal;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              Text(
                'Correct!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Level ${widget.levelNumber} Complete!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
              ),
              if (attempted > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Score: $score/$attempted',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () async {
                    provider.dismissFeedback();
                    final navigator = Navigator.of(context);
                    final nextLevel = widget.levelNumber + 1;
                    try {
                      await levelProgressProvider.completeLevel(
                        widget.user.uid,
                        widget.levelNumber,
                        lrn: widget.user.lrn,
                      );
                    } catch (e) {
                      debugPrint(
                        '[BeginnerZoneGameplayScreen] completeLevel error: $e',
                      );
                    }
                    if (!mounted) return;
                    // Straight-line progression across all three zones (1–60).
                    // Passing Level 60 routes through `adventureComplete` (handled
                    // by _buildAdventureComplete), so this advances only up to a
                    // next level ≤ 60 before returning to the Adventure Map.
                    if (nextLevel <= 60) {
                      // Advance straight to the next level (replace this screen).
                      navigator.pushReplacement(
                        MaterialPageRoute(
                          settings:
                              RouteSettings(name: '/beginner-zone/$nextLevel'),
                          builder: (_) => BeginnerZoneGameplayScreen(
                            levelNumber: nextLevel,
                            user: widget.user,
                            usedHistory: widget.usedHistory,
                          ),
                        ),
                      );
                    } else {
                      // Past the built zones → return to the Adventure Map.
                      navigator.popUntil((route) => route.isFirst);
                    }
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdventureComplete(
      BuildContext context, LevelProvider provider) {
    final levelProgressProvider =
        Provider.of<LevelProgressProvider>(context, listen: false);
    final score = provider.score;
    final attempted = provider.attemptedTotal;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 96),
              const SizedBox(height: 16),
              Text(
                'Correct!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Adventure Complete!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
              ),
              if (attempted > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Score: $score/$attempted',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                "You've completed all 60 levels of the Mathalino adventure! 🏆",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your mastery of mathematics is complete. Great job!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () async {
                    provider.dismissFeedback();
                    final navigator = Navigator.of(context);
                    // Record the final-boss completion with the shared progress
                    // provider (same as _buildLevelComplete for regular levels) so
                    // the Adventure Map marks Level 60 as completed — both in the
                    // in-memory status map and in Firestore (/users/{uid}).
                    try {
                      await levelProgressProvider.completeLevel(
                        widget.user.uid,
                        kFinalBossLevel,
                        lrn: widget.user.lrn,
                      );
                    } catch (e) {
                      debugPrint(
                        '[BeginnerZoneGameplayScreen] completeLevel(60) error: $e',
                      );
                    }
                    if (!mounted) return;
                    // This is the end of the 60-level game — return to the map.
                    navigator.popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.map_rounded),
                  label: const Text(
                    'Back to Map',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildFailed(BuildContext context, LevelProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(provider.error ?? 'Could not load this level.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Map'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedsTeacherSupport(BuildContext context, LevelProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.support_agent_rounded,
                color: Colors.amber.shade800,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Teacher Support Requested',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Level ${widget.levelNumber} Remediation',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You've worked hard practicing Level ${widget.levelNumber}! "
              "Your teacher has been notified and will provide helpful guidance on these topics. "
              "You can ask your teacher or parent for assistance before trying again.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Back to Map'),
            ),
          ],
        ),
      ),
    );
  }
}