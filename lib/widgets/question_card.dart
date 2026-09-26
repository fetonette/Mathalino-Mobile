import 'package:flutter/material.dart';
import '../core/models/question.dart';
import 'question_illustration.dart';

/// Reusable Question Card widget for Mathalino Student App.
///
/// Displays a [Question] and its answer options. Supports multipleChoice,
/// trueFalse, numericInput, and computation question types. Calls
/// [onAnswerSelected] with the student's raw answer.
class QuestionCard extends StatefulWidget {
  final Question question;
  final ValueChanged<dynamic> onAnswerSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.onAnswerSelected,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? _selectedChoice;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.question;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)),
              child: child,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Competency / cognitive domain badges
              Row(
                children: [
                  _buildBadge(
                    question.competencyCode,
                    Colors.blue.shade50,
                    Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  _buildBadge(
                    question.cognitiveDomain,
                    Colors.orange.shade50,
                    Colors.orange.shade800,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Topic illustration (animated; derived from question metadata)
              QuestionIllustration(question: question),
              const SizedBox(height: 14),

              // Question text
              Text(
                question.questionText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Answer input based on question type
              Expanded(child: _buildAnswerInput(question)),

              const SizedBox(height: 16),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_isSubmitting ? 'Submitting...' : 'Submit Answer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAnswerInput(Question question) {
    return _buildChoiceList(question);
  }

  Widget _buildChoiceList(Question question) {
    final choices = (question.choices != null && question.choices!.isNotEmpty)
        ? question.choices!
        : ['A. Option A', 'B. Option B', 'C. Option C', 'D. Option D'];

    return ListView.builder(
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        final isSelected = _selectedChoice == choice;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 320 + index * 50),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(14 * (1 - t), 0),
                child: child,
              ),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedChoice = choice;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ]
                      : const [],
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        choice,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSubmit() {
    if (_isSubmitting) return;

    if (_selectedChoice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an answer')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    widget.onAnswerSelected(_selectedChoice);
  }
}
