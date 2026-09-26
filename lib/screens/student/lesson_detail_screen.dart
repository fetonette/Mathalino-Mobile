import 'package:flutter/material.dart';
import '../../core/models/learn_content_models.dart';
import '../../core/theme/app_colors.dart';

/// Screen that renders a single textbook lesson following the 11-part
/// instructional sequence specified in LEARN_CONTENT_STRUCTURE.md (§2 & §8.4).
class LessonDetailScreen extends StatefulWidget {
  final LearnTopic topic;

  const LessonDetailScreen({
    super.key,
    required this.topic,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // Set of indices for revealed guided practice hints
  final Set<int> _revealedHints = {};

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final seq = topic.lessonSequence;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          topic.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Lesson Header ──────────────────────────────────────────
            _buildLessonHeader(topic),
            const SizedBox(height: 16),

            // ── RMA Module Mapping Note (if present) ────────────────────
            if (topic.moduleMappingNote != null &&
                topic.moduleMappingNote!.isNotEmpty) ...[
              _buildMappingNoteCard(topic.moduleMappingNote!),
              const SizedBox(height: 16),
            ],

            // ── 1. Objectives ───────────────────────────────────────────
            _buildSectionCard(
              index: 1,
              title: 'Learning Objectives',
              subtitle: 'What you will master in this lesson',
              icon: Icons.track_changes_rounded,
              iconColor: const Color(0xFF38BDF8),
              child: Column(
                children: seq.objectives
                    .map((obj) => _buildCheckItem(obj))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Introduction ─────────────────────────────────────────
            _buildSectionCard(
              index: 2,
              title: 'Introduction',
              subtitle: 'Connecting math to the real world',
              icon: Icons.lightbulb_outline_rounded,
              iconColor: const Color(0xFFFBBF24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFBBF24),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        seq.introduction,
                        style: const TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 3. Step-by-Step Explanation ─────────────────────────────
            _buildSectionCard(
              index: 3,
              title: 'Step-by-Step Explanation',
              subtitle: 'Learn the method one step at a time',
              icon: Icons.format_list_numbered_rounded,
              iconColor: const Color(0xFF60A5FA),
              child: Column(
                children: List.generate(seq.explanation.length, (idx) {
                  final text = seq.explanation[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF3B82F6),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 14.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. Key Concepts ─────────────────────────────────────────
            _buildSectionCard(
              index: 4,
              title: 'Key Concepts & Rules',
              subtitle: 'Important rules and terms to remember',
              icon: Icons.key_rounded,
              iconColor: const Color(0xFFA78BFA),
              child: Column(
                children: seq.keyConcepts.map((concept) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFA78BFA),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            concept,
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 14.5,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── 5. Worked Examples ──────────────────────────────────────
            _buildSectionCard(
              index: 5,
              title: 'Worked Examples',
              subtitle: 'Fully solved examples increasing in difficulty',
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF34D399),
              child: Column(
                children: List.generate(seq.workedExamples.length, (idx) {
                  final ex = seq.workedExamples[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Example ${idx + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ex.problem,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ex.solution,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── 6. Guided Practice ──────────────────────────────────────
            _buildSectionCard(
              index: 6,
              title: 'Guided Practice',
              subtitle: 'Practice problems with supportive hints',
              icon: Icons.psychology_rounded,
              iconColor: const Color(0xFFF472B6),
              child: Column(
                children: List.generate(seq.guidedPractice.length, (idx) {
                  final item = seq.guidedPractice[idx];
                  final isRevealed = _revealedHints.contains(idx);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${idx + 1}. ',
                              style: const TextStyle(
                                color: Color(0xFFF472B6),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.problem,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              if (isRevealed) {
                                _revealedHints.remove(idx);
                              } else {
                                _revealedHints.add(idx);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isRevealed
                                  ? const Color(0xFFF472B6)
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isRevealed
                                    ? const Color(0xFFF472B6)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isRevealed
                                      ? Icons.visibility_off_rounded
                                      : Icons.help_outline_rounded,
                                  size: 16,
                                  color: isRevealed
                                      ? const Color(0xFFF472B6)
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isRevealed ? 'Hide Hint' : 'Need a Hint?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isRevealed
                                        ? const Color(0xFFF472B6)
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isRevealed) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF472B6)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '💡 Hint: ${item.hint}',
                              style: const TextStyle(
                                color: Color(0xFFFCE7F3),
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── 7. Independent Practice ─────────────────────────────────
            _buildSectionCard(
              index: 7,
              title: 'Independent Practice',
              subtitle: 'Solve these on your own to build confidence',
              icon: Icons.edit_note_rounded,
              iconColor: const Color(0xFFFB923C),
              child: Column(
                children: List.generate(seq.independentPractice.length, (idx) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFFFB923C)
                              .withValues(alpha: 0.2),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Color(0xFFFB923C),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            seq.independentPractice[idx],
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── 8. Real-Life Application ────────────────────────────────
            _buildSectionCard(
              index: 8,
              title: 'Real-Life Application',
              subtitle: 'Why this math matters in everyday life',
              icon: Icons.public_rounded,
              iconColor: const Color(0xFF2DD4BF),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.nature_people_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        seq.realLifeApplication,
                        style: const TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 9. Check Understanding ──────────────────────────────────
            _buildSectionCard(
              index: 9,
              title: 'Check Understanding',
              subtitle: 'Quick review questions to check your mastery',
              icon: Icons.quiz_rounded,
              iconColor: const Color(0xFFE879F9),
              child: Column(
                children: List.generate(seq.checkUnderstanding.length, (idx) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.help_center_rounded,
                          color: Color(0xFFE879F9),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            seq.checkUnderstanding[idx],
                            style: const TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // ── 10. Summary ─────────────────────────────────────────────
            _buildSectionCard(
              index: 10,
              title: 'Lesson Summary',
              subtitle: 'The big takeaway of today’s lesson',
              icon: Icons.bookmark_added_rounded,
              iconColor: const Color(0xFF10B981),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  seq.summary,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 11. Challenge ───────────────────────────────────────────
            _buildSectionCard(
              index: 11,
              title: 'Math Explorer Challenge',
              subtitle: 'Higher-level practice for curious math explorers',
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFFFD700),
              child: Column(
                children: List.generate(seq.challenge.length, (idx) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700).withValues(alpha: 0.12),
                          const Color(0xFFF59E0B).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Color(0xFFFFD700),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            seq.challenge[idx],
                            style: const TextStyle(
                              color: Color(0xFFFEF3C7),
                              fontSize: 14.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonHeader(LearnTopic topic) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Grade ${topic.gradeLevel} • ${_formatModuleName(topic.module)}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'RMA Mapped',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            topic.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: topic.rmaCompetencyCodes.map((code) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.source_outlined,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Source: ${topic.rmaSource}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMappingNoteCard(String note) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF60A5FA), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                color: Color(0xFF93C5FD),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Part $index: ',
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF38BDF8),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatModuleName(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
