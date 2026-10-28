import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/learn_content_models.dart';
import '../../providers/learn_provider.dart';

/// Interactive Mathematics Practice Screen for published teacher lessons.
///
/// Implements Phase 8 specifications:
/// - 5 teacher-approved practice MCQs.
/// - Secure server-side answer checking via Supabase RPC.
/// - Age-appropriate hints and immediate constructive feedback.
/// - Unlimited retries with zero lives/hearts penalties.
/// - Friendly completion view without formal examination grading or reward modifications.
class PracticeScreen extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final String moduleTitle;

  const PracticeScreen({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    this.moduleTitle = 'Practice Module',
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LearnProvider>().loadPracticeForLesson(widget.lessonId);
    });
  }

  Future<bool> _onWillPop() async {
    final provider = context.read<LearnProvider>();
    if (provider.isPracticeCompleted ||
        (provider.currentPracticeQuestions?.isEmpty ?? true)) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Practice?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You are currently practicing this lesson. Your attempts are saved, but you can finish anytime!',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () async {
              if (await _onWillPop() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.lessonTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.moduleTitle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        body: Consumer<LearnProvider>(
          builder: (context, provider, _) {
            if (provider.isPracticeLoading) {
              return _buildLoadingState();
            }

            if (provider.practiceError != null) {
              return _buildErrorState(provider.practiceError!, () {
                provider.loadPracticeForLesson(widget.lessonId);
              });
            }

            final questions = provider.currentPracticeQuestions;
            if (questions == null || questions.isEmpty) {
              return _buildEmptyState();
            }

            if (provider.isPracticeCompleted) {
              return _buildCompletionView(context, provider);
            }

            return _buildPracticeBody(context, provider, questions);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
          ),
          SizedBox(height: 16),
          Text(
            'Preparing your practice questions...',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFE11D48),
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to Load Practice',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                color: Color(0xFFFBBF24),
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                'No Practice Questions Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your teacher hasn\'t published practice questions for this lesson yet. Check back soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Lesson'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeBody(
    BuildContext context,
    LearnProvider provider,
    List<StudentPracticeQuestion> questions,
  ) {
    final currentQ = provider.currentQuestion;
    if (currentQ == null) return const SizedBox.shrink();

    final currentIndex = provider.currentQuestionIndex;
    final totalCount = questions.length;
    final lastResult = provider.lastAnswerResult;
    final isCorrect = lastResult?.isCorrect ?? false;
    final isIncorrect = lastResult != null && !isCorrect;

    return Column(
      children: [
        // ── Progress Bar ────────────────────────────────────────────────
        LinearProgressIndicator(
          value: (currentIndex + (isCorrect ? 1 : 0)) / totalCount,
          backgroundColor: const Color(0xFF1E293B),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
          minHeight: 6,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header: Question Counter & Difficulty ─────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Question ${currentIndex + 1} of $totalCount',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildDifficultyChip(currentQ.difficulty),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Question Card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    currentQ.question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Options (A, B, C, D) ───────────────────────────────────
                ...['A', 'B', 'C', 'D'].map((optKey) {
                  final optText = currentQ.options[optKey] ?? '';
                  if (optText.isEmpty) return const SizedBox.shrink();

                  final isSelected = provider.selectedOption == optKey;
                  return _buildOptionTile(
                    optionKey: optKey,
                    optionText: optText,
                    isSelected: isSelected,
                    isCorrect: isCorrect,
                    isIncorrect: isIncorrect,
                    onTap: () => provider.selectOption(optKey),
                  );
                }),
                const SizedBox(height: 14),

                // ── Hint Section ───────────────────────────────────────────
                if (currentQ.hint != null && currentQ.hint!.trim().isNotEmpty) ...[
                  _buildHintSection(provider, currentQ.hint!),
                  const SizedBox(height: 14),
                ],

                // ── Feedback Banner (Correct / Incorrect) ──────────────────
                if (lastResult != null) ...[
                  _buildFeedbackBanner(lastResult),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),

        // ── Bottom Action Bar ─────────────────────────────────────────────
        _buildBottomActionBar(context, provider, isCorrect, isIncorrect, currentIndex, totalCount),
      ],
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color chipColor;
    String label;

    switch (difficulty.toLowerCase()) {
      case 'easy':
        chipColor = const Color(0xFF10B981);
        label = 'Easy';
        break;
      case 'challenge':
        chipColor = const Color(0xFFFFD700);
        label = 'Challenge';
        break;
      case 'standard':
      default:
        chipColor = const Color(0xFF38BDF8);
        label = 'Standard';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String optionKey,
    required String optionText,
    required bool isSelected,
    required bool isCorrect,
    required bool isIncorrect,
    required VoidCallback onTap,
  }) {
    Color borderColor = const Color(0xFF334155);
    Color backgroundColor = const Color(0xFF1E293B);
    Color letterBg = const Color(0xFF334155);
    Color letterColor = Colors.white70;

    if (isSelected) {
      if (isCorrect) {
        borderColor = const Color(0xFF10B981);
        backgroundColor = const Color(0xFF10B981).withValues(alpha: 0.15);
        letterBg = const Color(0xFF10B981);
        letterColor = Colors.white;
      } else if (isIncorrect) {
        borderColor = const Color(0xFFF43F5E);
        backgroundColor = const Color(0xFFF43F5E).withValues(alpha: 0.12);
        letterBg = const Color(0xFFF43F5E);
        letterColor = Colors.white;
      } else {
        borderColor = const Color(0xFF38BDF8);
        backgroundColor = const Color(0xFF38BDF8).withValues(alpha: 0.15);
        letterBg = const Color(0xFF38BDF8);
        letterColor = const Color(0xFF0F172A);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isCorrect ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: letterBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    optionKey,
                    style: TextStyle(
                      color: letterColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    optionText,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                if (isSelected && isCorrect) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                ] else if (isSelected && isIncorrect) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.refresh_rounded, color: Color(0xFFF43F5E), size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHintSection(LearnProvider provider, String hintText) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => provider.toggleHint(),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFFBBF24),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    provider.isHintRevealed ? 'Hide Hint' : 'Show Hint',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    provider.isHintRevealed
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFFBBF24),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (provider.isHintRevealed) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                hintText,
                style: const TextStyle(
                  color: Color(0xFFFEF3C7),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner(StudentPracticeAnswerResult result) {
    final isCorrect = result.isCorrect;
    final bannerColor = isCorrect ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final icon = isCorrect ? Icons.celebration_rounded : Icons.info_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: bannerColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.feedback,
                  style: TextStyle(
                    color: bannerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (result.explanation != null && result.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              result.explanation!,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    LearnProvider provider,
    bool isCorrect,
    bool isIncorrect,
    int currentIndex,
    int totalCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (isIncorrect) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => provider.retryCurrentQuestion(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ] else if (isCorrect) ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => provider.nextQuestion(widget.lessonId),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    currentIndex == totalCount - 1 ? 'Complete Practice' : 'Next Question',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    disabledBackgroundColor: const Color(0xFF334155),
                    disabledForegroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (provider.selectedOption == null || provider.isCheckingAnswer)
                      ? null
                      : () => provider.submitAnswer(widget.lessonId),
                  child: provider.isCheckingAnswer
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                          ),
                        )
                      : const Text(
                          'Check Answer',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, LearnProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFF10B981),
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Practice Complete! Great Effort!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You have completed all 5 practice questions for this lesson! Keep exploring mathematics to master more concepts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Action 1: Review Lesson ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.menu_book_rounded, size: 20),
                  label: const Text('Review Lesson', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),

              // ── Action 2: Practice Again ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    side: const BorderSide(color: Color(0xFF34D399)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => provider.resetPracticeSession(),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Practice Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),

              // ── Action 3: Back to Modules ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    // Pop practice screen and lesson detail screen to return to module/lessons list
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.dashboard_rounded, size: 18),
                  label: const Text('Back to Modules', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
