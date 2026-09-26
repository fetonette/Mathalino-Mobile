import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/question.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/daily_challenge_service.dart';
import '../../widgets/question_card.dart';

/// Daily Challenge screen for Mathalino Student App.
///
/// Fetches today's curated challenge from `daily_challenges/{yyyy-MM-dd}`,
/// presents each question using the existing [QuestionCard], scores answers
/// with [DailyChallengeService], and displays rewards after completion.
///
/// Replay is prevented by [DailyChallengeService.hasCompletedToday] and the
/// atomic anti-replay check inside [DailyChallengeService.completeChallenge].
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

enum _DailyChallengePhase { loading, ready, submitting, completed, error }

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  final DailyChallengeService _service = DailyChallengeService();

  _DailyChallengePhase _phase = _DailyChallengePhase.loading;
  List<Question> _questions = [];
  final List<dynamic> _answers = [];
  int _currentIndex = 0;
  String _errorMessage = '';
  DailyChallengeResult? _result;

  @override
  void initState() {
    super.initState();
    _loadChallenge();
  }

  Future<void> _loadChallenge() async {
    setState(() {
      _phase = _DailyChallengePhase.loading;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      final userId = authService.user?.uid ?? authService.studentProfile?.uid;

      if (userId == null || userId.isEmpty) {
        setState(() {
          _phase = _DailyChallengePhase.error;
          _errorMessage = 'You must be signed in to take the daily challenge.';
        });
        return;
      }

      // Replay prevention before fetching questions.
      final alreadyCompleted = await _service.hasCompletedToday(userId);
      if (alreadyCompleted) {
        setState(() {
          _phase = _DailyChallengePhase.completed;
        });
        return;
      }

      final questions = await _service.fetchTodayChallenge();
      setState(() {
        _questions = questions;
        _answers.clear();
        _currentIndex = 0;
        _phase = _DailyChallengePhase.ready;
      });
    } on DailyChallengeNotFoundException {
      setState(() {
        _phase = _DailyChallengePhase.error;
        _errorMessage = 'No daily challenge is available today. Check back tomorrow!';
      });
    } catch (e) {
      setState(() {
        _phase = _DailyChallengePhase.error;
        _errorMessage = 'Failed to load the daily challenge: $e';
      });
    }
  }

  Future<void> _handleAnswer(dynamic answer) async {
    if (_currentIndex >= _questions.length) return;

    // Store the answer for the current question.
    if (_answers.length <= _currentIndex) {
      _answers.add(answer);
    } else {
      _answers[_currentIndex] = answer;
    }

    // Move to the next question, or submit if this was the last one.
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
      });
    } else {
      await _submitAll();
    }
  }

  Future<void> _submitAll() async {
    setState(() {
      _phase = _DailyChallengePhase.submitting;
      _errorMessage = '';
    });

    try {
      final authService = context.read<AuthService>();
      final userId = authService.user?.uid ?? authService.studentProfile?.uid;

      if (userId == null || userId.isEmpty) {
        setState(() {
          _phase = _DailyChallengePhase.error;
          _errorMessage = 'You must be signed in to complete the daily challenge.';
        });
        return;
      }

      final result = await _service.completeChallenge(
        userId: userId,
        questions: _questions,
        answers: _answers,
      );

      setState(() {
        _result = result;
        _phase = _DailyChallengePhase.completed;
      });
    } on DailyChallengeAlreadyCompletedException {
      setState(() {
        _phase = _DailyChallengePhase.completed;
        _errorMessage = 'You already completed today\'s challenge.';
      });
    } catch (e) {
      setState(() {
        _phase = _DailyChallengePhase.error;
        _errorMessage = 'Failed to submit the daily challenge: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Challenge'),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _DailyChallengePhase.loading:
        return const Center(child: CircularProgressIndicator());

      case _DailyChallengePhase.error:
        return _ErrorView(
          message: _errorMessage,
          onRetry: _loadChallenge,
        );

      case _DailyChallengePhase.ready:
        return _buildQuestionView();

      case _DailyChallengePhase.submitting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Submitting your answers...'),
            ],
          ),
        );

      case _DailyChallengePhase.completed:
        return _CompletedView(
          result: _result,
          message: _errorMessage.isNotEmpty ? _errorMessage : null,
          onDone: () => Navigator.of(context).pop(),
        );
    }
  }

  Widget _buildQuestionView() {
    final question = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              LinearProgressIndicator(
                value: (_currentIndex) / _questions.length,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
              ),
            ],
          ),
        ),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedView extends StatelessWidget {
  final DailyChallengeResult? result;
  final String? message;
  final VoidCallback onDone;

  const _CompletedView({
    required this.result,
    required this.message,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 72),
                const SizedBox(height: 16),
                Text(
                  'Daily Challenge Complete!',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
                if (result != null) ...[
                  const SizedBox(height: 24),
                  _ResultRow(
                    icon: Icons.check_circle,
                    label: 'Correct Answers',
                    value: '${result!.correctCount}/${result!.totalQuestions}',
                  ),
                  _ResultRow(
                    icon: Icons.stars,
                    label: 'Points',
                    value: '${result!.pointsEarned}/${result!.maxPoints}',
                  ),
                  _ResultRow(
                    icon: Icons.bolt,
                    label: 'XP',
                    value: '+${result!.xpAwarded}',
                  ),
                  _ResultRow(
                    icon: Icons.monetization_on,
                    label: 'Coins',
                    value: '+${result!.coinsAwarded}',
                  ),
                  _ResultRow(
                    icon: Icons.local_fire_department,
                    label: 'Streak',
                    value: '${result!.streakDays} days',
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}
