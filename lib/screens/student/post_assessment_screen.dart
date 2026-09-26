import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/post_assessment_provider.dart';
import '../../widgets/post_assessment_reward_dialog.dart';
import '../../widgets/question_card.dart';
import 'adventure_map_screen.dart';

/// Screen presenting the milestone Post-Assessment (10–20 items)
/// following Zone 1 (L20), Zone 2 (L40), or Final Boss (L60).
class PostAssessmentScreen extends StatefulWidget {
  final int levelMilestone;

  const PostAssessmentScreen({
    super.key,
    required this.levelMilestone,
  });

  @override
  State<PostAssessmentScreen> createState() => _PostAssessmentScreenState();
}

class _PostAssessmentScreenState extends State<PostAssessmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _init();
      }
    });
  }

  Future<void> _init() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    final postAssessmentProvider = context.read<PostAssessmentProvider>();
    final profile = authService.studentProfile;

    if (profile == null) return;

    await postAssessmentProvider.initializePostAssessment(
      profile: profile,
      levelMilestone: widget.levelMilestone,
    );
  }

  Future<void> _handleAnswer(dynamic answer) async {
    final provider = context.read<PostAssessmentProvider>();
    final authService = context.read<AuthService>();
    final profile = authService.studentProfile;

    if (profile == null) return;

    final isDone = provider.answerQuestion(answer);

    if (isDone) {
      try {
        final result = await provider.submitPostAssessment(
          studentId: profile.uid,
          profile: profile,
        );

        if (!mounted) return;

        await PostAssessmentRewardDialog.show(
          context,
          result: result,
          onContinue: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const AdventureMapScreen(),
                settings: const RouteSettings(name: '/adventure_map'),
              ),
              (route) => false,
            );
          },
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit post-assessment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostAssessmentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Zone ${widget.levelMilestone ~/ 20} Post-Assessment'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(PostAssessmentProvider provider) {
    if (provider.isLoading || provider.isSubmitting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              provider.isSubmitting
                  ? 'Calculating growth and finalizing profile...'
                  : 'Preparing post-assessment items...',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
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
                onPressed: _init,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final question = provider.currentQuestion;
    if (question == null) {
      return const Center(child: Text('No post-assessment questions available'));
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.contentDomain.isNotEmpty
                      ? question.contentDomain
                      : 'Numeracy',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: provider.totalQuestions > 0
              ? (provider.currentIndex) / provider.totalQuestions
              : 0.0,
          backgroundColor: Colors.grey.shade200,
          color: AppColors.primary,
          minHeight: 8,
        ),
        const SizedBox(height: 8),

        // Question card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: QuestionCard(
              key: ValueKey(question.id),
              question: question,
              onAnswerSelected: _handleAnswer,
            ),
          ),
        ),
      ],
    );
  }
}
