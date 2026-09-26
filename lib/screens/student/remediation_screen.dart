import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/game_rules.dart';
import '../../core/models/student_profile.dart';
import '../../providers/remediation_provider.dart';
import '../../widgets/question_card.dart';

/// Remediation Screen for Mathalino Student App.
///
/// Drives the Failure & Remediation Engine UI:
/// - Preparation phase: student answers questions from the preparation range
///   (levels below the failed target level) filtered to the failed question's
///   competency code.
/// - Challenge phase: once mastery is achieved, a NEW question for the target
///   level is presented.
/// - On success: remediation completes and the next level is unlocked.
/// - On repeat failure: the remediation loops back to preparation.
class RemediationScreen extends StatefulWidget {
  final StudentProfile user;
  final List<String> contentPool;
  final int failedLevel;

  const RemediationScreen({
    super.key,
    required this.user,
    required this.contentPool,
    required this.failedLevel,
  });

  @override
  State<RemediationScreen> createState() => _RemediationScreenState();
}

class _RemediationScreenState extends State<RemediationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initialize();
      }
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    final provider = context.read<RemediationProvider>();
    await provider.loadRemediation(widget.user.uid);

    if (provider.isRemediationActive) {
      await provider.loadPreparationQuestions(
        userId: widget.user.uid,
        contentPool: widget.contentPool,
        usedQuestionsHistory: widget.user.usedQuestionsHistory,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RemediationProvider>();

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remediation')),
        body: Center(
          child: Text(
            'Error: ${provider.errorMessage}',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // No active remediation - show info screen.
    if (!provider.isRemediationActive) {
      return _buildNoRemediationScreen(context);
    }

    // Check if teacher support is flagged:
    if (provider.needsTeacherSupport || provider.remediation.needsTeacherSupport) {
      return _buildNeedsTeacherSupportScreen(context, provider);
    }

    // Switch on the current phase.
    switch (provider.phase) {
      case RemediationPhase.preparation:
        return _buildPreparationScreen(context, provider);
      case RemediationPhase.challenge:
        return _buildChallengeScreen(context, provider);
      case RemediationPhase.completed:
        return _buildCompletionScreen(context);
      case RemediationPhase.repeatFailure:
        return _buildRepeatFailureScreen(context, provider);
      case RemediationPhase.needsTeacherSupport:
        return _buildNeedsTeacherSupportScreen(context, provider);
      case RemediationPhase.none:
        return _buildNoRemediationScreen(context);
    }
  }

  // --- Preparation Phase ---

  Widget _buildPreparationScreen(BuildContext context, RemediationProvider provider) {
    final question = provider.currentPreparationQuestion;

    if (question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remediation')),
        body: const Center(child: Text('No preparation questions available')),
      );
    }

    final remediation = provider.remediation;
    final masteryPercent = (provider.masteryScore * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remediation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Mastery: $masteryPercent%',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preparation range banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Preparing for Level ${remediation.targetLevel} — '
                      'Reviewing Levels ${remediation.preparationStart}-${remediation.preparationEnd}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mastery progress bar
            LinearProgressIndicator(
              value: provider.masteryScore.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              'Attempts: ${provider.attemptsInRange} / $kMaxPrepAttempts',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Question card
            Expanded(
              child: QuestionCard(
                question: question,
                onAnswerSelected: (selectedAnswer) async {
                  final achievedMastery = await provider.answerPreparationQuestion(
                    userId: widget.user.uid,
                    selectedAnswer: selectedAnswer,
                  );

                  if (!mounted) return;

                  if (achievedMastery) {
                    // Load the challenge question.
                    await provider.loadChallengeQuestion(
                      userId: widget.user.uid,
                      contentPool: widget.contentPool,
                      usedQuestionsHistory: widget.user.usedQuestionsHistory,
                    );
                  } else if (provider.phase == RemediationPhase.repeatFailure) {
                    // Reload a fresh batch of preparation questions.
                    await provider.loadPreparationQuestions(
                      userId: widget.user.uid,
                      contentPool: widget.contentPool,
                      usedQuestionsHistory: widget.user.usedQuestionsHistory,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Challenge Phase ---

  Widget _buildChallengeScreen(BuildContext context, RemediationProvider provider) {
    final question = provider.challengeQuestion;

    if (question == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Remediation Challenge')),
        body: const Center(child: Text('No challenge question available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remediation Challenge'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Challenge banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'ve mastered the preparation! '
                      'Now answer this challenge question for Level ${provider.remediation.targetLevel}.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Challenge question
            Expanded(
              child: QuestionCard(
                question: question,
                onAnswerSelected: (selectedAnswer) async {
                  final passed = await provider.answerChallengeQuestion(
                    userId: widget.user.uid,
                    selectedAnswer: selectedAnswer,
                  );

                  if (!mounted) return;

                  if (!passed && provider.phase == RemediationPhase.repeatFailure) {
                    // Reload a fresh batch of preparation questions.
                    await provider.loadPreparationQuestions(
                      userId: widget.user.uid,
                      contentPool: widget.contentPool,
                      usedQuestionsHistory: widget.user.usedQuestionsHistory,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Completion / Repeat Failure / No Remediation ---

  Widget _buildCompletionScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              Text(
                'Remediation Complete!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You\'ve mastered the skills and unlocked the next level!',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatFailureScreen(BuildContext context, RemediationProvider provider) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remediation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, color: Colors.orange, size: 80),
              const SizedBox(height: 24),
              Text(
                'Let\'s Try Again!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You\'re close! Let\'s review the preparation levels once more '
                'before attempting Level ${provider.remediation.targetLevel} again.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await provider.loadPreparationQuestions(
                    userId: widget.user.uid,
                    contentPool: widget.contentPool,
                    usedQuestionsHistory: widget.user.usedQuestionsHistory,
                  );
                },
                child: const Text('Continue Preparation'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedsTeacherSupportScreen(
    BuildContext context,
    RemediationProvider provider,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Support'),
      ),
      body: Center(
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
                  'Level ${provider.remediation.targetLevel} Review',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "You've shown great effort working through Level ${provider.remediation.targetLevel}! "
                "Your teacher has been notified and will provide extra guidance on these topics. "
                "You can ask your teacher or parent for assistance before retrying this challenge.",
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
      ),
    );
  }

  Widget _buildNoRemediationScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remediation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 80),
              const SizedBox(height: 24),
              Text(
                'No Active Remediation',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'There is no active remediation session for this student.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}