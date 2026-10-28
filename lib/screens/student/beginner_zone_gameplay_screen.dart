import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/student_profile.dart';
import '../../core/services/game_logic_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/mathalino_tokens.dart';
import '../../providers/level_progress_provider.dart';
import '../../providers/level_provider.dart';
import '../../widgets/difficulty_badge.dart';
import '../../widgets/hearts.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/star_row.dart';

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

class _BeginnerZoneGameplayScreenState extends State<BeginnerZoneGameplayScreen>
    with WidgetsBindingObserver {
  /// Guards against opening multiple feedback dialogs for the same answer.
  bool _feedbackDialogShowing = false;

  /// Cached provider reference so [dispose] can remove the listener without
  /// touching the (deactivated) element tree via `context`.
  LevelProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _provider?.stopAnsweringTimer();
    _provider?.removeListener(_onLevelProviderChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final provider = _provider;
    if (provider == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        provider.pauseAnsweringTimer();
        break;
      case AppLifecycleState.resumed:
        provider.resumeAnsweringTimer();
        break;
      case AppLifecycleState.detached:
        provider.stopAnsweringTimer();
        break;
    }
  }

  void _onLevelProviderChanged() {
    final provider = _provider;
    if (provider == null) return;
    if (provider.feedbackPending && !_feedbackDialogShowing) {
      // If the level or adventure is already complete, the completion screen
      // displays the combined feedback ("Correct!", score) directly, eliminating
      // the redundant popup dialog.
      if (provider.phase == PlayerPhase.levelComplete ||
          provider.phase == PlayerPhase.adventureComplete ||
          provider.phase == PlayerPhase.outOfHearts) {
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
              PlayerPhase.outOfHearts =>
                _buildOutOfHearts(context, provider),
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
        if (!provider.isLoading && provider.error == null) ...[
          // Hearts only for Preparation / Moderate levels; challenge levels
          // keep their existing remediation flow and show none.
          if (!provider.isChallengeLevel)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Hearts(
                  hearts: provider.hearts,
                  maxHearts: LevelProvider.kMaxHearts,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: DifficultyBadge(difficulty: displayDifficulty),
            ),
          ),
        ] else
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
              if (question.imagePath != null &&
                  question.imagePath!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        question.imagePath!,
                        fit: BoxFit.contain,
                        height: 130,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
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
            // Encouragement + age-appropriate hint on the last heart. Never
            // reveals the correct answer.
            if (!isCorrect &&
                !provider.isChallengeLevel &&
                provider.hearts == 1) ...[
              const SizedBox(height: 12),
              Text(
                'You have one heart left — read the question again, take your '
                "time, and think it through step by step. You've got this! \uD83D\uDCAA",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
              ),
            ],
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
    // Non-Challenge levels display the universal three-chance score (X/3);
    // Challenge levels keep their raw correct-count / attempted denominator.
    // Presentation uses the exact same values the persistence path receives,
    // so the on-screen rating always matches the stored
    // `level_progress.stars` / `student_results.stars` values.
    final score = provider.completedScore;
    final maxScore = provider.completedMax;
    final accuracyPct = StarRating.accuracyForScore(score, maxScore);
    final stars = StarRating.starsForAccuracy(accuracyPct);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTokens.indigoRing.withValues(alpha: 0.40),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTokens.successRing.withValues(alpha: 0.40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTokens.successGreen,
                  size: 62,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Level ${widget.levelNumber} Complete!',
                textAlign: TextAlign.center,
                style: AppTokens.baloo2(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.successGreen,
                ),
              ),
              const SizedBox(height: 16),
              // LATEST-ATTEMPT performance rating celebration (one-time animation).
              _LevelCompleteCelebrationStars(
                stars: stars,
                starSize: 54,
                gap: 12,
              ),
              const SizedBox(height: 10),
              Text(
                StarRating.messageForStars(stars),
                textAlign: TextAlign.center,
                style: AppTokens.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.bodyText,
                ),
              ),
              if (maxScore > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.iconBadgeFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    provider.isChallengeLevel
                        ? 'Score: $score/$maxScore'
                        : 'Chance Score: $score/$maxScore',
                    textAlign: TextAlign.center,
                    style: AppTokens.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.headingIndigo,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildRewardStrip(context, provider),
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

  /// Compact, child-friendly Coins + XP + saved-star-gain strip for the
  /// completion screens. Animated and child-friendly. It reflects ONLY genuinely
  /// persisted values from [LevelProvider.completionOutcome]:
  ///   * null (save still pending, or a fully unconfirmed/failed save) → a
  ///     neutral "Saving rewards…" state (never guessed/fictional amounts);
  ///   * rewardsPersisted → real +Coins / +XP, or a "Practice complete!" note
  ///     on a +0/+0 replay;
  ///   * starsPersisted && totalStarsGain > 0 → a "New best! +N stars" chip.
  /// It never uses `saveSucceeded` as the sole gate for XP/Coins, and never
  /// confuses the latest-attempt star rating with newly saved best stars.
  Widget _buildRewardStrip(BuildContext context, LevelProvider provider) {
    return _AnimatedRewardStrip(outcome: provider.completionOutcome);
  }

  Widget _buildAdventureComplete(
      BuildContext context, LevelProvider provider) {
    final levelProgressProvider =
        Provider.of<LevelProgressProvider>(context, listen: false);
    final score = provider.score;
    final attempted = provider.attemptedTotal;
    // Presentation-only: same counters the persistence path uses, so the on-screen
    // rating matches the stored `level_progress.stars` value.
    final accuracyPct = StarRating.accuracyForScore(score, attempted);
    final stars = StarRating.starsForAccuracy(accuracyPct);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppTokens.indigoRing.withValues(alpha: 0.40),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppTokens.accentRing.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppTokens.accentOrange,
                  size: 68,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Adventure Complete!',
                textAlign: TextAlign.center,
                style: AppTokens.baloo2(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.successGreen,
                ),
              ),
              const SizedBox(height: 16),
              _LevelCompleteCelebrationStars(
                stars: stars,
                starSize: 54,
                gap: 12,
              ),
              const SizedBox(height: 10),
              Text(
                StarRating.messageForStars(stars),
                textAlign: TextAlign.center,
                style: AppTokens.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.bodyText,
                ),
              ),
              if (attempted > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTokens.iconBadgeFill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Score: $score/$attempted',
                    textAlign: TextAlign.center,
                    style: AppTokens.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.headingIndigo,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildRewardStrip(context, provider),
              const SizedBox(height: 14),
              Text(
                "You've completed all 60 levels of the Mathalino adventure! \uD83C\uDFC6",
                textAlign: TextAlign.center,
                style: AppTokens.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.secondaryText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your mastery of mathematics is complete. Great job!',
                textAlign: TextAlign.center,
                style: AppTokens.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.secondaryText,
                  height: 1.4,
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

  /// Supportive, non-punishing screen shown when a Preparation / Moderate
  /// level runs out of hearts. Offers an in-place "Try Again" (which resets
  /// hearts/score/attempts and selects a new question WITHOUT writing to the
  /// database or granting rewards) and "Back to Adventure Map" (which simply
  /// exits — the level is NOT marked completed).
  Widget _buildOutOfHearts(BuildContext context, LevelProvider provider) {
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
              const Hearts(hearts: 0, maxHearts: 3),
              const SizedBox(height: 16),
              Image.asset(
                'assets/mascots/mascot_thumbs_up.png',
                height: 96,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.favorite_rounded,
                  size: 72,
                  color: AppTokens.accentOrange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Let's Practice Again!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTokens.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                "You've used all your hearts on Level ${widget.levelNumber}, "
                "and that's okay! Take a breath and try again — every mistake "
                "helps you learn. You can restart this level or head back to "
                "the Adventure Map.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                      height: 1.5,
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
                  onPressed: provider.restartLevelForHearts,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Back to Adventure Map'),
                ),
              ),
            ],
          ),
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

/// Compact pill showing a single awarded-reward value (Coins / XP / new-star
/// gain) inside the static MathALINO Level Complete reward strip.
// ignore: unused_element
class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.background,
    required this.foreground,
    required this.semanticsLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Color background;
  final Color foreground;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: AppTokens.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neutral, non-numeric status pill used while a save is still pending or when
/// there is genuinely nothing to award — never shows fictional rewards.
class _RewardStatusCard extends StatelessWidget {
  const _RewardStatusCard({
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.semanticsLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String message;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTokens.iconBadgeFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTokens.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Reward Collection Strip ───────────────────────────────────────

/// Compact, child-friendly animated Coins + XP + saved-star-gain strip for the
/// completion screens. It reflects ONLY genuinely persisted values from
/// [LevelProvider.completionOutcome]:
///   * null (save still pending, or a fully unconfirmed/failed save) → a
///     neutral "Saving rewards…" state (never guessed/fictional amounts);
///   * rewardsPersisted → real +Coins / +XP, or a "Practice complete!" note
///     on a +0/+0 replay;
///   * starsPersisted && totalStarsGain > 0 → a "New best! +N stars" chip.
/// It never uses `saveSucceeded` as the sole gate for XP/Coins, and never
/// confuses the latest-attempt star rating with newly saved best stars.
///
/// Runs a bounded, child-friendly one-time collection animation (~1.3s) once
/// the confirmed outcome becomes available.
class _AnimatedRewardStrip extends StatefulWidget {
  const _AnimatedRewardStrip({required this.outcome});

  final LevelCompletionOutcome? outcome;

  @override
  State<_AnimatedRewardStrip> createState() => _AnimatedRewardStripState();
}

class _AnimatedRewardStripState extends State<_AnimatedRewardStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    if (_hasConfirmedRewards(widget.outcome)) {
      _startAnimation();
    }
  }

  bool _hasConfirmedRewards(LevelCompletionOutcome? outcome) {
    if (outcome == null) return false;
    return outcome.rewardsPersisted || outcome.starsPersisted;
  }

  void _startAnimation() {
    if (_hasStarted) return;
    _hasStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_AnimatedRewardStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasStarted && _hasConfirmedRewards(widget.outcome)) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;

    if (outcome == null ||
        (!outcome.rewardsPersisted && !outcome.starsPersisted)) {
      return const _RewardStatusCard(
        icon: Icons.hourglass_top_rounded,
        iconColor: AppTokens.secondaryText,
        message: 'Saving rewards\u2026',
        semanticsLabel: 'Saving rewards, please wait',
      );
    }

    final chips = <Widget>[];

    // Evaluate rewardsPersisted
    if (outcome.rewardsPersisted) {
      final coins = outcome.coinsAwarded;
      final xp = outcome.xpAwarded;

      if (coins == 0 && xp == 0) {
        chips.add(const _RewardStatusCard(
          icon: Icons.favorite_rounded,
          iconColor: AppTokens.accentOrange,
          message: 'Practice complete!',
          semanticsLabel:
              'Practice complete. No new coins on this replay',
        ));
      } else {
        if (coins > 0) {
          final coinsAnimation = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.00, 0.65, curve: Curves.easeOutCubic),
          );
          chips.add(_AnimatedCollectChip(
            icon: Icons.monetization_on_rounded,
            iconColor: AppTokens.tileYellow,
            targetValue: coins,
            labelFormatter: (v) => '+$v Coins',
            background: AppTokens.tileYellow.withValues(alpha: 0.16),
            foreground: AppTokens.tileSymbolYellow,
            semanticsLabel: '$coins coins awarded',
            animation: coinsAnimation,
          ));
        }


      }
    }

    // Evaluate starsPersisted
    if (outcome.starsPersisted && outcome.totalStarsGain > 0) {
      final gain = outcome.totalStarsGain;
      final starsAnimation = CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.95, curve: Curves.easeOutCubic),
      );
      chips.add(_AnimatedCollectChip(
        icon: Icons.star_rounded,
        iconColor: AppTokens.accentOrange,
        targetValue: gain,
        labelFormatter: (v) => 'New best! +$v star${v == 1 ? '' : 's'}',
        background: AppTokens.accentRing.withValues(alpha: 0.50),
        foreground: AppTokens.orangeText,
        semanticsLabel: '$gain new stars saved',
        animation: starsAnimation,
      ));
    }

    if (chips.isEmpty) {
      return const _RewardStatusCard(
        icon: Icons.celebration_rounded,
        iconColor: AppTokens.successGreen,
        message: 'Level complete!',
        semanticsLabel: 'Level complete',
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: chips,
    );
  }
}

/// A single animated reward counter chip with playful particle flight toward the
/// chip icon, a gentle scale/bounce pop, and smooth numerical count-up.
class _AnimatedCollectChip extends StatelessWidget {
  const _AnimatedCollectChip({
    required this.icon,
    required this.iconColor,
    required this.targetValue,
    required this.labelFormatter,
    required this.background,
    required this.foreground,
    required this.semanticsLabel,
    required this.animation,
  });

  final IconData icon;
  final Color iconColor;
  final int targetValue;
  final String Function(int value) labelFormatter;
  final Color background;
  final Color foreground;
  final String semanticsLabel;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;

        // Counter roll: 0 -> targetValue
        final currentValue =
            (progress * targetValue).round().clamp(0, targetValue);

        // Scale pop: subtle bounce overshoot (0.75 -> 1.06 -> 1.00)
        final double scale;
        if (progress < 0.7) {
          scale = 0.75 + (0.31 * (progress / 0.7));
        } else {
          scale = 1.06 - (0.06 * ((progress - 0.7) / 0.3));
        }

        // Slide up into place
        final slideY = 10.0 * (1.0 - progress);

        // Opacity fade in
        final opacity = progress.clamp(0.0, 1.0);

        // Floating particle icon traveling toward the chip icon
        final particleProgress = (progress / 0.75).clamp(0.0, 1.0);
        final particleOpacity =
            (1.0 - (particleProgress - 0.5).abs() * 2).clamp(0.0, 1.0);
        final particleSlideY = -18.0 * (1.0 - particleProgress);

        return Semantics(
          label: semanticsLabel,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Main reward chip
              Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, slideY),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: progress > 0.25 && progress < 0.95
                            ? [
                                BoxShadow(
                                  color: iconColor.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: iconColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            labelFormatter(currentValue),
                            style: AppTokens.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Small playful particle icon flying toward the chip icon
              if (particleOpacity > 0.01 && progress < 0.9)
                Positioned(
                  left: 14,
                  top: particleSlideY,
                  child: Opacity(
                    opacity: particleOpacity,
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Level Complete Star Celebration ────────────────────────────────────────

/// Playful, one-time star entrance with an elastic pop sequence and a brief
/// 3-star confetti/sparkle burst for the Level Complete & Adventure Complete screens.
class _LevelCompleteCelebrationStars extends StatefulWidget {
  final int stars;
  final double starSize;
  final double gap;

  const _LevelCompleteCelebrationStars({
    required this.stars,
    this.starSize = 54.0,
    this.gap = 12.0,
  });

  @override
  State<_LevelCompleteCelebrationStars> createState() =>
      _LevelCompleteCelebrationStarsState();
}

class _LevelCompleteCelebrationStarsState
    extends State<_LevelCompleteCelebrationStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _LevelCompleteCelebrationStars oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bounded one-time celebration: prevent restart when LevelProvider notifies on save.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Elastic scale for star [index] with staggered 180ms delay.
  double _starScale(int index, double t, bool reduceMotion) {
    if (reduceMotion) return 1.0;
    final startT = (index * 180) / 2000.0;
    final endT = (index * 180 + 450) / 2000.0;

    if (t < startT) return 0.0;
    if (t >= endT) return 1.0;

    final progress = (t - startT) / (endT - startT);
    return Curves.elasticOut.transform(progress);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final filledStars = widget.stars.clamp(0, 3);

    return Semantics(
      label: '$filledStars of 3 stars',
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Invisible StarRating maintains compatibility with find.byType(StarRating) and semantics
          Offstage(
            offstage: true,
            child: StarRating(
              stars: widget.stars,
              starSize: widget.starSize,
              gap: widget.gap,
              animate: false,
            ),
          ),

          // 3-Star Confetti / Sparkle burst celebration (duration ~1.5s, bounded inside card)
          if (filledStars == 3 && !reduceMotion)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiCelebrationPainter(
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),

          // Star slots: empty outlines always visible; filled stars pop in sequentially
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) SizedBox(width: widget.gap),
                    SizedBox(
                      width: widget.starSize,
                      height: widget.starSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Base empty outline slot (always visible from frame 0)
                          Icon(
                            Icons.star_outline_rounded,
                            size: widget.starSize,
                            color: AppTokens.accentRing,
                          ),
                          // Popping filled star with gentle elastic bounce
                          if (i < filledStars)
                            Transform.scale(
                              scale: _starScale(i, t, reduceMotion),
                              child: Icon(
                                Icons.star_rounded,
                                size: widget.starSize,
                                color: AppTokens.accentOrange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParticleData {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isSparkle;
  final double rotationMultiplier;

  const _ParticleData({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isSparkle,
    required this.rotationMultiplier,
  });
}

class _ConfettiCelebrationPainter extends CustomPainter {
  final double progress;

  _ConfettiCelebrationPainter({required this.progress});

  static const List<_ParticleData> _particles = [
    _ParticleData(
      angle: -1.4,
      speed: 70,
      size: 5,
      color: AppTokens.tileYellow,
      isSparkle: true,
      rotationMultiplier: 2.0,
    ),
    _ParticleData(
      angle: -1.1,
      speed: 85,
      size: 6,
      color: AppTokens.accentOrange,
      isSparkle: false,
      rotationMultiplier: 3.5,
    ),
    _ParticleData(
      angle: -0.8,
      speed: 60,
      size: 4,
      color: AppTokens.tileMint,
      isSparkle: false,
      rotationMultiplier: -2.5,
    ),
    _ParticleData(
      angle: -0.5,
      speed: 90,
      size: 5,
      color: AppTokens.tileSky,
      isSparkle: true,
      rotationMultiplier: 4.0,
    ),
    _ParticleData(
      angle: -0.2,
      speed: 75,
      size: 6,
      color: AppTokens.tilePeriwinkle,
      isSparkle: false,
      rotationMultiplier: -3.0,
    ),
    _ParticleData(
      angle: 0.2,
      speed: 65,
      size: 4,
      color: AppTokens.primaryIndigo,
      isSparkle: false,
      rotationMultiplier: 2.5,
    ),
    _ParticleData(
      angle: 0.5,
      speed: 85,
      size: 5,
      color: AppTokens.tileYellow,
      isSparkle: true,
      rotationMultiplier: -4.0,
    ),
    _ParticleData(
      angle: 0.8,
      speed: 70,
      size: 6,
      color: AppTokens.accentOrange,
      isSparkle: false,
      rotationMultiplier: 3.0,
    ),
    _ParticleData(
      angle: 1.1,
      speed: 60,
      size: 4,
      color: AppTokens.tileMint,
      isSparkle: false,
      rotationMultiplier: -2.0,
    ),
    _ParticleData(
      angle: 1.4,
      speed: 80,
      size: 5,
      color: AppTokens.tileSky,
      isSparkle: true,
      rotationMultiplier: 3.5,
    ),
    _ParticleData(
      angle: 1.7,
      speed: 65,
      size: 6,
      color: AppTokens.tilePeriwinkle,
      isSparkle: false,
      rotationMultiplier: -3.5,
    ),
    _ParticleData(
      angle: 2.0,
      speed: 90,
      size: 5,
      color: AppTokens.tileYellow,
      isSparkle: true,
      rotationMultiplier: 4.0,
    ),
    _ParticleData(
      angle: 2.3,
      speed: 60,
      size: 4,
      color: AppTokens.accentOrange,
      isSparkle: false,
      rotationMultiplier: -2.5,
    ),
    _ParticleData(
      angle: 2.6,
      speed: 75,
      size: 6,
      color: AppTokens.tileMint,
      isSparkle: false,
      rotationMultiplier: 3.0,
    ),
    _ParticleData(
      angle: 2.9,
      speed: 70,
      size: 5,
      color: AppTokens.tileSky,
      isSparkle: true,
      rotationMultiplier: -4.0,
    ),
    _ParticleData(
      angle: 3.2,
      speed: 85,
      size: 6,
      color: AppTokens.tilePeriwinkle,
      isSparkle: false,
      rotationMultiplier: 2.0,
    ),
    _ParticleData(
      angle: 3.5,
      speed: 60,
      size: 4,
      color: AppTokens.primaryIndigo,
      isSparkle: false,
      rotationMultiplier: -3.0,
    ),
    _ParticleData(
      angle: 3.8,
      speed: 80,
      size: 5,
      color: AppTokens.tileYellow,
      isSparkle: true,
      rotationMultiplier: 3.5,
    ),
    _ParticleData(
      angle: 4.1,
      speed: 65,
      size: 6,
      color: AppTokens.accentOrange,
      isSparkle: false,
      rotationMultiplier: -2.0,
    ),
    _ParticleData(
      angle: 4.4,
      speed: 85,
      size: 5,
      color: AppTokens.tileMint,
      isSparkle: true,
      rotationMultiplier: 4.5,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.25 || progress >= 1.0) return;

    final p = ((progress - 0.25) / 0.75).clamp(0.0, 1.0);
    final easedP = Curves.easeOutCubic.transform(p);
    final alpha = p < 0.55 ? 1.0 : (1.0 - (p - 0.55) / 0.45).clamp(0.0, 1.0);

    if (alpha <= 0.001) return;

    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in _particles) {
      final dist = easedP * particle.speed;
      final x = center.dx + math.cos(particle.angle) * dist;
      final y =
          center.dy + math.sin(particle.angle) * dist * 0.75 + (p * p * 22.0);

      canvas.save();
      canvas.translate(x, y);

      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.color.a * alpha)
        ..style = PaintingStyle.fill;

      if (particle.isSparkle) {
        final sparklePath = StarPainter.buildSparklePath(
          Offset.zero,
          particle.size * (1.0 - 0.3 * p),
        );
        canvas.drawPath(sparklePath, paint);
      } else {
        canvas.rotate(p * particle.rotationMultiplier * math.pi);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: particle.size * 1.3,
          height: particle.size * 0.75,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1.5));
        canvas.drawRRect(rrect, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiCelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}