import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/learn_content_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/learn_provider.dart';
import '../../providers/level_progress_provider.dart';
import 'module_lessons_screen.dart';

class AdventureLearnView extends StatefulWidget {
  const AdventureLearnView({super.key});

  @override
  State<AdventureLearnView> createState() => _AdventureLearnViewState();
}

class _AdventureLearnViewState extends State<AdventureLearnView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<AuthService>().studentProfile;
      context.read<LearnProvider>().loadForStudent(profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().studentProfile;
    final learn = context.watch<LearnProvider>();
    final content = learn.currentGradeContent;
    final gradeLevel = content?.gradeLevel ?? (profile?.gradeLevel ?? 1);

    // Auto-trigger load if profile loaded later
    if (content == null && !learn.isLoading && profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LearnProvider>().loadForStudent(profile);
      });
    }

    const moduleDefs = [
      (
        key: 'number_sense',
        title: 'Number Sense',
        description: 'Build confidence with numbers and place value.',
        icon: Icons.calculate_outlined,
      ),
      (
        key: 'operations',
        title: 'Operations',
        description: 'Practice addition, subtraction, multiplication, and division.',
        icon: Icons.functions,
      ),
      (
        key: 'fractions',
        title: 'Fractions',
        description: 'Explore parts, wholes, and equivalent fractions.',
        icon: Icons.pie_chart_outline,
      ),
      (
        key: 'geometry',
        title: 'Geometry',
        description: 'Learn shapes, space, measurement, and patterns.',
        icon: Icons.category_outlined,
      ),
    ];

    return _SectionPage(
      title: 'Learn',
      subtitle: 'Choose a module and keep building your math skills.',
      icon: Icons.menu_book_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grade 6 unsupported banner (§8.5)
          if (content != null && !content.isSupported) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFBBF24), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Grade 6 Content Coming Soon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content.note ??
                              'Grade 6 assessment-mapped lessons are being prepared according to the RMA instrument.',
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (learn.isLoading && content == null) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
          ] else if (learn.errorMessage != null && content == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    learn.errorMessage!,
                    style: const TextStyle(color: Color(0xFFFCA5A5)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => learn.loadForStudent(profile),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: columns == 2 ? 2.1 : 2.5,
                  ),
                  itemCount: moduleDefs.length,
                  itemBuilder: (context, index) {
                    final def = moduleDefs[index];
                    final module = content?.getModule(def.key);
                    final topicCount = module?.topics.length ?? 0;

                    final badgeText = content == null
                        ? null
                        : (!content.isSupported || topicCount == 0
                            ? 'Coming Soon'
                            : '$topicCount Lesson${topicCount == 1 ? '' : 's'}');

                    return _ModuleCard(
                      title: def.title,
                      description: module?.description.isNotEmpty == true
                          ? module!.description
                          : def.description,
                      icon: def.icon,
                      badgeText: badgeText,
                      onTap: () {
                        if (module != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ModuleLessonsScreen(
                                module: module,
                                gradeLevel: gradeLevel,
                              ),
                            ),
                          );
                        } else {
                          // Fallback placeholder module
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ModuleLessonsScreen(
                                module: LearnModule(
                                  id: 'grade_${gradeLevel}_${def.key}',
                                  name: def.title,
                                  description: def.description,
                                  note: 'Content is being prepared.',
                                  topics: const [],
                                ),
                                gradeLevel: gradeLevel,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class AdventureProgressView extends StatelessWidget {
  const AdventureProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().studentProfile;
    final levels = context.watch<LevelProgressProvider>();
    final completed = List.generate(60, (index) => index + 1)
        .where((level) => levels.getLevelState(level) == LevelState.completed)
        .length;
    final levelProgress = completed / 60;

    return _SectionPage(
      title: 'Progress',
      subtitle: 'See how your learning is growing across Mathalino.',
      icon: Icons.insights_rounded,
      child: Column(
        children: [
          _ProgressCard(
            title: 'Overall learning progress',
            value: levelProgress,
            label: '$completed of 60 levels completed',
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _StatGrid(
            items: [
              _StatItem(
                'Current level',
                '${levels.currentLevel}',
                Icons.flag_outlined,
              ),
              _StatItem(
                'Assessment score',
                '${profile?.diagnosticScore ?? 0}/20',
                Icons.assignment_turned_in_outlined,
              ),
              _StatItem(
                'Assessment result',
                '${(profile?.diagnosticPercentage ?? 0).toStringAsFixed(0)}%',
                Icons.analytics_outlined,
              ),
              _StatItem('Modules completed', '0', Icons.task_alt_outlined),
            ],
          ),
          const SizedBox(height: 16),
          _InfoPanel(
            title: 'Activity performance',
            icon: Icons.bar_chart_rounded,
            message:
                'Complete Learn modules and activities to see your scores and strengths here.',
          ),
        ],
      ),
    );
  }
}

class AdventureProfileView extends StatelessWidget {
  const AdventureProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().studentProfile ??
        context.watch<LevelProgressProvider>().studentProfile;
    final rows = <_ProfileRow>[

      _ProfileRow(
        'Name',
        profile?.displayName.isNotEmpty == true ? profile!.displayName : '—',
      ),
      _ProfileRow(
        'LRN',
        profile?.lrn.isNotEmpty == true ? profile!.lrn : 'Not available',
      ),
      _ProfileRow(
        'Grade level',
        profile?.gradeLevelLabel.isNotEmpty == true
            ? profile!.gradeLevelLabel
            : 'Grade ${profile?.gradeLevel ?? 1}',
      ),
      _ProfileRow(
        'Section',
        profile?.section.isNotEmpty == true ? profile!.section : '—',
      ),
      _ProfileRow('Placement', profile?.assignedCategory ?? 'Not assessed'),
      _ProfileRow('Starting level', 'Level ${profile?.startingLevel ?? 1}'),
    ];

    // Status is only shown when the teacher has explicitly set it to non-active.
    final status = profile?.studentStatus;
    if (status != null && status.isNotEmpty && status != 'active') {
      rows.add(_ProfileRow('Status', status));
    }

    // Parent/guardian block — shown when a parent is linked OR when the
    // teacher has provided parent contact details.
    final linkedUid = profile?.linkedParentUid ?? '';
    final isLinked = profile?.isParentLinked == true || linkedUid.isNotEmpty;
    if (isLinked) {
      rows.add(_ProfileRow('Parent Linked', 'Yes'));
    }
    final parentName = profile?.parentGuardianName ?? '';
    if (parentName.isNotEmpty) {
      rows.add(_ProfileRow('Parent/Guardian', parentName));
    }
    if ((profile?.parentGuardianEmail ?? '').isNotEmpty) {
      rows.add(_ProfileRow('Parent email', profile!.parentGuardianEmail));
    }
    if ((profile?.parentGuardianPhone ?? '').isNotEmpty) {
      rows.add(_ProfileRow('Parent phone', profile!.parentGuardianPhone));
    }

    return _SectionPage(
      title: 'Profile',
      subtitle: 'Your Mathalino account information.',
      icon: Icons.account_circle_rounded,
      child: _InfoPanel(
        title: profile?.displayName ?? 'Student',
        icon: Icons.person_outline_rounded,
        rows: rows,
      ),
    );
  }
}

class _SectionPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.accent, size: 30),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badgeText;

  const _ModuleCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accent.withValues(alpha: .18),
                child: Icon(icon, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeText == 'Coming Soon'
                                  ? const Color(0xFFFBBF24)
                                      .withValues(alpha: 0.15)
                                  : AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                color: badgeText == 'Coming Soon'
                                    ? const Color(0xFFFBBF24)
                                    : AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final double value;
  final String label;
  final Color color;

  const _ProgressCard({
    required this.title,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: value,
            minHeight: 10,
            color: color,
            backgroundColor: color.withValues(alpha: .15),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem(this.label, this.value, this.icon);
}

class _StatGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650 ? 4 : 2;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: items
            .map(
              (item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? message;
  final List<_ProfileRow>? rows;
  const _InfoPanel({
    required this.title,
    required this.icon,
    this.message,
    this.rows,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (rows != null) ...[
            const SizedBox(height: 12),
            ...rows!.map(
              (row) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  row.label,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Text(
                  row.value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProfileRow {
  final String label;
  final String value;
  const _ProfileRow(this.label, this.value);
}
