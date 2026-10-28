import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/learn_content_models.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/learn_provider.dart';
import 'lesson_detail_screen.dart';

/// Screen displaying the list of published practice lessons for a selected
/// teacher-created module, adhering to Phase 7 specifications.
class ModuleLessonsScreen extends StatefulWidget {
  final TeacherPublishedModule? publishedModule;
  final LearnModule? module;
  final int? gradeLevel;

  const ModuleLessonsScreen({
    super.key,
    this.publishedModule,
    this.module,
    this.gradeLevel,
  });

  @override
  State<ModuleLessonsScreen> createState() => _ModuleLessonsScreenState();
}

class _ModuleLessonsScreenState extends State<ModuleLessonsScreen> {
  List<PublishedLessonSummary> _dynamicLessons = const [];
  bool _isLoading = false;
  String? _errorMessage;

  String get _moduleTitle =>
      widget.publishedModule?.title ?? widget.module?.name ?? 'Practice Module';

  String get _moduleDescription =>
      widget.publishedModule?.description ??
      widget.module?.description ??
      'Teacher mathematics practice module.';

  String get _gradeLevelText {
    if (widget.publishedModule != null &&
        widget.publishedModule!.gradeLevel.isNotEmpty) {
      return widget.publishedModule!.gradeLevel;
    }
    final g = widget.gradeLevel ?? 1;
    return 'Grade $g Curriculum';
  }

  @override
  void initState() {
    super.initState();
    if (widget.publishedModule != null) {
      _loadDynamicLessons();
    }
  }

  Future<void> _loadDynamicLessons() async {
    if (widget.publishedModule == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lessons = await context
          .read<LearnProvider>()
          .fetchModuleLessons(widget.publishedModule!.id);
      if (mounted) {
        setState(() {
          _dynamicLessons = lessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ModuleLessonsScreen] load lessons error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load published lessons. Please retry.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _moduleTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _gradeLevelText,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // ── Dynamic Supabase Flow ───────────────────────────────────────────────
    if (widget.publishedModule != null) {
      if (_isLoading) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
          ),
        );
      }

      if (_errorMessage != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFF87171),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadDynamicLessons,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (_dynamicLessons.isEmpty) {
        return _buildDynamicEmptyState(context);
      }

      return RefreshIndicator(
        onRefresh: _loadDynamicLessons,
        color: AppColors.accent,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: _dynamicLessons.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildHeader(
                title: _moduleTitle,
                description: _moduleDescription,
                lessonCount: _dynamicLessons.length,
                isPublished: true,
              );
            }

            final lesson = _dynamicLessons[index - 1];
            final lessonNumber = index;

            return _buildDynamicLessonCard(context, lesson, lessonNumber);
          },
        ),
      );
    }

    // ── Legacy Module Flow (Preserved for backward test compatibility) ───────
    final legacyTopics = widget.module?.topics ?? const [];
    if (legacyTopics.isEmpty) {
      return _buildLegacyEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: legacyTopics.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(
            title: _moduleTitle,
            description: _moduleDescription,
            lessonCount: legacyTopics.length,
            isPublished: false,
          );
        }

        final topic = legacyTopics[index - 1];
        final lessonNumber = index;

        return _buildLegacyTopicCard(context, topic, lessonNumber);
      },
    );
  }

  Widget _buildHeader({
    required String title,
    required String description,
    required int lessonCount,
    bool isPublished = true,
  }) {
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
                child: Icon(_getModuleIcon(title),
                    color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPublished
                          ? '$lessonCount published lesson${lessonCount == 1 ? '' : 's'}'
                          : '$lessonCount formal lesson${lessonCount == 1 ? '' : 's'}',
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
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDynamicLessonCard(
    BuildContext context,
    PublishedLessonSummary lesson,
    int lessonNumber,
  ) {
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
          final learnProvider = context.read<LearnProvider>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<LearnProvider>.value(
                value: learnProvider,
                child: LessonDetailScreen(
                  lessonId: lesson.id,
                  lessonTitle: lesson.title,
                  gradeLevel: lesson.gradeLevel.isNotEmpty
                      ? lesson.gradeLevel
                      : _gradeLevelText,
                  moduleTitle: _moduleTitle,
                ),
              ),
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
                lesson.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    '11-Part Instructional Lesson & Exercises',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildLegacyTopicCard(
    BuildContext context,
    LearnTopic topic,
    int lessonNumber,
  ) {
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicEmptyState(BuildContext context) {
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
                Icons.menu_book_rounded,
                size: 48,
                color: Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$_moduleTitle Lessons',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No practice lessons have been published for this module yet.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
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

  Widget _buildLegacyEmptyState(BuildContext context) {
    final noteText = widget.module?.note ??
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
              '$_moduleTitle Lessons',
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
    if (lower.contains('operation') || lower.contains('multiplic')) {
      return Icons.functions;
    }
    if (lower.contains('fraction')) return Icons.pie_chart_outline;
    if (lower.contains('geometry')) return Icons.category_outlined;
    return Icons.menu_book_rounded;
  }
}
