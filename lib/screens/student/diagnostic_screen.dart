import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/diagnostic_exception.dart';
import '../../core/models/placement_result.dart';
import '../../core/models/student_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/diagnostic_provider.dart';
import '../../widgets/question_card.dart';
import 'diagnostic_results_screen.dart';

/// Diagnostic Screen for Mathalino Student App.
///
/// Presents the 20-item RMA-based diagnostic assessment, submits answers,
/// applies the IF–THEN placement rules, and shows the placement result.
/// On completion, routes the student to the Adventure Map at their
/// assigned starting level.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
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
    final authService = context.read<AuthService>();
    final diagnosticProvider = context.read<DiagnosticProvider>();
    var profile = authService.studentProfile;
    if (profile == null && authService.user != null) {
      profile = await authService.ensureProfileLoaded();
    }
    if (!mounted) return;
    final currentUserId = profile?.uid ?? authService.user?.id ?? '';

    // If the provider has questions for another user, is incomplete/malformed,
    // is already marked completed, or has no questions loaded yet, load a fresh 20-item diagnostic set.
    final needsLoad = diagnosticProvider.questions.isEmpty ||
        diagnosticProvider.questions.length != 20 ||
        diagnosticProvider.loadedUserId != currentUserId ||
        diagnosticProvider.isComplete;

    if (needsLoad) {
      await diagnosticProvider.loadDiagnosticQuestions(
        userId: currentUserId,
        gradeLevel: profile?.gradeLevel ?? 1,
        usedQuestionsHistory: profile?.usedQuestionsHistory ?? [],
      );
    }
  }

  Future<void> _handleAnswer(dynamic answer) async {
    final diagnosticProvider = context.read<DiagnosticProvider>();
    final isComplete = diagnosticProvider.answerCurrentQuestion(answer);

    if (isComplete) {
      // All questions answered — submit the diagnostic.
      await _submitDiagnostic();
    }
  }

  /// Submits the completed diagnostic and reacts to the safe, typed outcomes:
  ///  * DIAGNOSTIC_ALREADY_COMPLETED → route to Adventure Map (never fabricate a
  ///    Beginner/Level-1 result for a student whose RMA is already saved).
  ///  * DIAGNOSTIC_STATUS_UNCONFIRMED → offer a Retry; keep answers, save nothing.
  ///  * any other error → preserve the existing notice behavior.
  Future<void> _submitDiagnostic() async {
    final diagnosticProvider = context.read<DiagnosticProvider>();
    final authService = context.read<AuthService>();
    final profile = authService.studentProfile;
    final userId = profile?.uid ?? authService.user?.id ?? '';

    try {
      final placement = await diagnosticProvider.submitDiagnostic(
        userId: userId,
        currentProfile: profile ?? _placeholderProfile(userId),
      );
      if (!mounted) return;
      _showPlacementResult(placement);
    } on DiagnosticException catch (ex) {
      if (!mounted) return;
      switch (ex.code) {
        case 'DIAGNOSTIC_ALREADY_COMPLETED':
          Navigator.of(context).pushReplacementNamed(
            '/adventure_map',
            arguments: const {'showWelcomeBack': true},
          );
          break;
        case 'DIAGNOSTIC_STATUS_UNCONFIRMED':
          _showRetryDialog();
          break;
        default:
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Notice: $ex')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Notice: $e')));
    }
  }

  /// Retry affordance for an unconfirmed completion status. It intentionally
  /// does NOT clear the answered diagnostic or write anything — the student's
  /// answers stay and nothing is saved until a retry succeeds.
  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connection problem'),
        content: const Text(
          "We couldn't confirm your saved progress, so nothing was submitted. "
          'Your answers are still here — please retry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _submitDiagnostic();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Minimal fallback profile used only when a live profile is momentarily
  /// unavailable. It is never shown as a placement result: a completed student
  /// is routed away before this could produce a fabricated placement.
  StudentProfile _placeholderProfile(String userId) => StudentProfile(
        uid: userId,
        lrn: '',
        displayName: 'Student',
        role: 'student',
        gradeLevel: 1,
        assignedCategory: 'Beginner',
        currentLevel: 1,
        startingLevel: 1,
        stats: const StudentStats(),
        usedQuestionsHistory: const [],
        diagnosticCompleted: false,
        verificationCode: '',
      );

  void _showPlacementResult(PlacementResult placement) {
    final diagnosticProvider = context.read<DiagnosticProvider>();
    final authService = context.read<AuthService>();
    final profile = authService.studentProfile;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DiagnosticResultsScreen(
          placement: placement,
          correctAnswers: diagnosticProvider.correctCountSoFar,
          totalQuestions: diagnosticProvider.totalQuestions,
          studentName: profile?.displayName ?? 'Student',
        ),
        settings: const RouteSettings(name: '/diagnostic_results'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diagnosticProvider = context.watch<DiagnosticProvider>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diagnostic Assessment'),
          backgroundColor: AppColors.primary,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(child: _buildBody(diagnosticProvider)),
      ),
    );
  }

  Widget _buildBody(DiagnosticProvider provider) {
    if (provider.isLoading || provider.isSubmitting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              provider.isSubmitting
                  ? 'Analyzing results...'
                  : 'Loading questions...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(provider.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _initialize(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final question = provider.currentQuestion;
    if (question == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No diagnostic questions available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${provider.currentIndex + 1} of ${provider.totalQuestions}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  ),
                  child: child,
                ),
                child: Text(
                  'Correct: ${provider.correctCountSoFar}',
                  key: ValueKey(provider.correctCountSoFar),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            end: provider.currentIndex / provider.totalQuestions,
          ),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.accent,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        // Question card (animated slide/fade between questions)
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Padding(
              key: ValueKey('card-${provider.currentIndex}-${question.id}'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: QuestionCard(
                key: ValueKey('qc-${provider.currentIndex}-${question.id}'),
                question: question,
                onAnswerSelected: _handleAnswer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
