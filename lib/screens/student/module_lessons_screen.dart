import 'package:flutter/material.dart';
import '../../core/models/learn_content_models.dart';
import '../../core/theme/app_colors.dart';
import 'lesson_detail_screen.dart';

/// Screen displaying the list of topics/lessons for a selected Learn module,
/// adhering to LEARN_CONTENT_STRUCTURE.md (§8.3).
class ModuleLessonsScreen extends StatelessWidget {
  final LearnModule module;
  final int gradeLevel;

  const ModuleLessonsScreen({
    super.key,
    required this.module,
    required this.gradeLevel,
  });

  @override
  Widget build(BuildContext context) {
    final hasTopics = module.topics.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              module.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Grade $gradeLevel Curriculum',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: hasTopics
          ? _buildTopicList(context)
          : _buildEmptyState(context),
    );
  }

  Widget _buildTopicList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: module.topics.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader();
        }

        final topic = module.topics[index - 1];
        final lessonNumber = index;

        return _buildTopicCard(context, topic, lessonNumber);
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                child: Icon(_getModuleIcon(module.name),
                    color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${module.topics.length} formal lesson${module.topics.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            module.description,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
      BuildContext context, LearnTopic topic, int lessonNumber) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonDetailScreen(topic: topic),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lesson $lessonNumber',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.white60),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: topic.rmaCompetencyCodes.map((code) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
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
                  const Icon(Icons.book_outlined,
                      size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      topic.rmaSource,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empty state per LEARN_CONTENT_STRUCTURE.md §8.3 & §8.5:
  /// Surfacing module.note as a friendly "content coming soon" state.
  Widget _buildEmptyState(BuildContext context) {
    final noteText = module.note ??
        'Lessons for this module are currently being developed and will be available soon.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 48,
                color: Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${module.name} Lessons',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                noteText,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Learn Modules'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModuleIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('number')) return Icons.calculate_outlined;
    if (lower.contains('operation')) return Icons.functions;
    if (lower.contains('fraction')) return Icons.pie_chart_outline;
    if (lower.contains('geometry')) return Icons.category_outlined;
    return Icons.menu_book_rounded;
  }
}
