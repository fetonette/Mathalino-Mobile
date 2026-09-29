import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final profile = authService.studentProfile;

    if (diagnosticProvider.questions.isEmpty) {
      await diagnosticProvider.loadDiagnosticQuestions(
        userId: profile?.uid ?? '',
        gradeLevel: profile?.gradeLevel ?? 1,
        usedQuestionsHistory: profile?.usedQuestionsHistory ?? [],
      );
    }
  }

  Future<void> _handleAnswer(dynamic answer) async {
    final diagnosticProvider = context.read<DiagnosticProvider>();
    final authService = context.read<AuthService>();
    final profile = authService.studentProfile;
    final userId = profile?.uid ?? authService.user?.id ?? '';

    final isComplete = diagnosticProvider.answerCurrentQuestion(answer);

    if (isComplete) {
      // All questions answered — submit the diagnostic instantly.
      try {
        final fallbackProfile =
            profile ??
            StudentProfile(
              uid: userId,
              lrn: '000000000000',
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

        final placement = await diagnosticProvider.submitDiagnostic(
          userId: userId,
          currentProfile: fallbackProfile,
        );
        if (!mounted) return;
        _showPlacementResult(placement);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Notice: $e')));
      }
    }
  }

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Assessment'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(child: _buildBody(diagnosticProvider)),
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
      return const Center(child: Text('No diagnostic questions available'));
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
              key: ValueKey('card-${question.id}'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: QuestionCard(
                key: ValueKey(question.id),
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
