import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/learn_content_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/mathalino_tokens.dart';
import '../../providers/learn_provider.dart';
import '../../providers/level_progress_provider.dart';
import '../../core/services/avatar_shop_service.dart';
import '../../widgets/logout_dialog.dart';
import 'avatar_shop_screen.dart';
import 'module_lessons_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN 1 - LEARN
// ═════════════════════════════════════════════════════════════════════════════

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
      context.read<LearnProvider>().loadPublishedModules();
    });
  }

  @override
  Widget build(BuildContext context) {
    final learn = context.watch<LearnProvider>();
    final modules = learn.publishedModules;

    return RefreshIndicator(
      onRefresh: () => learn.refreshPublishedModules(),
      color: AppTokens.primaryIndigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title row with faded mascot decoration
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Faded pencil mascot at top right (78x114, opacity 0.35, pointer-events none)
                    Positioned(
                      top: -6,
                      right: 4,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.35,
                          child: Image.asset(
                            'assets/mascots/mascot_pencil.png',
                            width: 78,
                            height: 114,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                              width: 78,
                              height: 114,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Title + Subtitle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              color: Color(0xFFD97706),
                              size: 34,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Learn',
                              style: AppTokens.baloo2(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.headingIndigo,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            'Choose a module and keep building your math skills.',
                            style: AppTokens.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.secondaryText,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Loading State ───────────────────────────────────────────
                if (learn.isLoading && modules.isEmpty) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: CircularProgressIndicator(
                        color: AppTokens.primaryIndigo,
                      ),
                    ),
                  ),
                ]
                // ── Recoverable Error State (Distinguished from empty) ────────
                else if (learn.errorMessage != null && modules.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF87171),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Color(0xFFDC2626),
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          learn.errorMessage!,
                          style: AppTokens.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF991B1B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => learn.loadPublishedModules(force: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primaryIndigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ]
                // ── Empty State: Exact required wording ───────────────────────
                else if (modules.isEmpty) ...[
                  _buildEmptyState(context, learn),
                ]
                // ── Published Teacher Modules List ───────────────────────────
                else ...[
                  for (var i = 0; i < modules.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    _buildDynamicModuleCard(
                      context: context,
                      module: modules[i],
                      index: i,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Empty state per Section 7:
  /// Exactly "Your teacher hasn't added practice lessons yet."
  Widget _buildEmptyState(BuildContext context, LearnProvider learn) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTokens.cardBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppTokens.cardBorder,
            offset: Offset(0, 6),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFFDE68A), width: 3),
            ),
            child: const Center(
              child: Icon(
                Icons.menu_book_rounded,
                color: Color(0xFFD97706),
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Your teacher hasn't added practice lessons yet.",
            style: AppTokens.baloo2(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTokens.headingIndigo,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon! When your teacher publishes new mathematics lessons and practice activities, they will appear here.',
            style: AppTokens.nunito(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppTokens.secondaryText,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => learn.refreshPublishedModules(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTokens.primaryIndigo,
              side: const BorderSide(color: AppTokens.primaryIndigo, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check for Updates'),
          ),
        ],
      ),
    );
  }

  /// Dynamic card for a teacher-published mathematics module
  Widget _buildDynamicModuleCard({
    required BuildContext context,
    required TeacherPublishedModule module,
    required int index,
  }) {
    // Dynamic palette cycling across Mathalino primary colors
    final colors = [
      (bg: AppTokens.primaryIndigo, ring: const Color(0xFF818CF8)),
      (bg: const Color(0xFF047857), ring: const Color(0xFF6EE7B7)),
      (bg: const Color(0xFFD97706), ring: const Color(0xFFFDE68A)),
      (bg: const Color(0xFF7C3AED), ring: const Color(0xFFC4B5FD)),
      (bg: const Color(0xFF0284C7), ring: const Color(0xFF7DD3FC)),
    ];
    final colorPair = colors[index % colors.length];

    final icon = _getDynamicModuleIcon(module.title);
    final count = module.publishedLessonCount;
    final chipText = '$count Practice Lesson${count == 1 ? '' : 's'}';

    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTokens.cardBorder, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppTokens.cardBorder,
            offset: Offset(0, 6),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () {
            final learnProvider = context.read<LearnProvider>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider<LearnProvider>.value(
                  value: learnProvider,
                  child: ModuleLessonsScreen(
                    publishedModule: module,
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // 56px round icon badge (4px ring)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorPair.bg,
                    border: Border.all(color: colorPair.ring, width: 4),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 14),
                // Title + chip + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            module.title,
                            style: AppTokens.baloo2(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTokens.bodyText,
                              height: 1.15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTokens.navActivePill,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              chipText,
                              style: AppTokens.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.headingIndigo,
                                height: 1.0,
                              ),
                            ),
                          ),
                          if (module.gradeLevel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                module.gradeLevel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (module.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          module.description,
                          style: AppTokens.nunito(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.secondaryText,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTokens.headingIndigo,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getDynamicModuleIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('multiplic') || lower.contains('times') || lower.contains('product')) {
      return Icons.close_rounded;
    }
    if (lower.contains('add') || lower.contains('sum') || lower.contains('plus')) {
      return Icons.add_rounded;
    }
    if (lower.contains('subtrac') || lower.contains('minus') || lower.contains('differen')) {
      return Icons.remove_rounded;
    }
    if (lower.contains('divis') || lower.contains('divide')) {
      return Icons.safety_divider_rounded;
    }
    if (lower.contains('fraction')) {
      return Icons.pie_chart_outline_rounded;
    }
    if (lower.contains('geometr') || lower.contains('shape')) {
      return Icons.category_outlined;
    }
    if (lower.contains('word') || lower.contains('problem')) {
      return Icons.psychology_rounded;
    }
    return Icons.menu_book_rounded;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN 2 - PROGRESS
// ═════════════════════════════════════════════════════════════════════════════

class AdventureProgressView extends StatelessWidget {
  final VoidCallback? onNavigateToLearn;

  const AdventureProgressView({
    super.key,
    this.onNavigateToLearn,
  });

  String _getHeadline(int completed) {
    if (completed == 0) return 'Start your math journey!';
    if (completed < 15) return 'Great start, keep going!';
    if (completed < 30) return "You're making great progress!";
    if (completed < 45) return "You're almost halfway there!";
    if (completed < 60) return "You're so close to the finish!";
    return 'Incredible! All levels completed!';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().studentProfile;
    final levels = context.watch<LevelProgressProvider>();

    final completed = List.generate(60, (index) => index + 1)
        .where((level) => levels.getLevelState(level) == LevelState.completed)
        .length;
    final levelProgress = completed / 60;
    final percentage = (levelProgress * 100).round();
    final headline = _getHeadline(completed);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title: "My Progress" (Baloo 2, 28px/800)
              Text(
                'My Progress',
                style: AppTokens.baloo2(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.bodyText,
                ),
              ),
              const SizedBox(height: 16),

              // Hero card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTokens.cardBorder, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTokens.cardBorder,
                      offset: Offset(0, 6),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: headline, green bar, label + percentage
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline,
                            style: AppTokens.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.bodyText,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Green progress bar (track #D1FAE5, fill #047857, 17px high, round)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              height: 17,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth *
                                      levelProgress.clamp(0.0, 1.0);
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: width,
                                      height: 17,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF047857),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$completed of 60 levels completed',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTokens.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTokens.secondaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$percentage%',
                                style: AppTokens.baloo2(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Thumbs-up mascot inside card, right side (~62x91, pointer-events none)
                    IgnorePointer(
                      child: Image.asset(
                        'assets/mascots/mascot_thumbs_up.png',
                        width: 62,
                        height: 91,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                          width: 62,
                          height: 91,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Three stat tiles (3-column grid, 10px gap, equal height)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.flag_outlined,
                        iconColor: AppTokens.primaryIndigo,
                        value: '${levels.currentLevel}',
                        label: 'Current level',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.check_box_outlined,
                        iconColor: const Color(0xFFD97706),
                        value: '${profile?.diagnosticScore ?? 0}/20',
                        label:
                            'Placement\nquiz · ${(profile?.diagnosticPercentage ?? 0).toStringAsFixed(0)}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatTile(
                        icon: Icons.menu_book_outlined,
                        iconColor: const Color(0xFF047857),
                        value: '0',
                        label: 'Modules\ndone',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Activity performance card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTokens.cardBorder, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTokens.cardBorder,
                      offset: Offset(0, 6),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Activity performance',
                      style: AppTokens.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.bodyText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Empty state illustration
                    const Center(
                      child: _ActivityBarChartIllustration(),
                    ),
                    const SizedBox(height: 20),

                    // Message
                    Text(
                      'Finish a Learn activity and your scores will show up here.',
                      textAlign: TextAlign.center,
                      style: AppTokens.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.secondaryText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Primary "Go to Learn" button
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTokens.primaryIndigo,
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTokens.primaryShadow,
                            offset: Offset(0, 5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(27),
                          onTap: onNavigateToLearn,
                          child: Center(
                            child: Text(
                              'Go to Learn',
                              style: AppTokens.baloo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTokens.cardBorder, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTokens.baloo2(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTokens.bodyText,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTokens.secondaryText,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom 3-bar illustration matching the design spec empty state
class _ActivityBarChartIllustration extends StatelessWidget {
  const _ActivityBarChartIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 90,
      child: CustomPaint(
        painter: _BarChartPainter(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final baseLinePaint = Paint()
      ..color = const Color(0xFFC7C3E8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final baselineY = size.height - 4;
    canvas.drawLine(
      Offset(4, baselineY),
      Offset(size.width - 4, baselineY),
      baseLinePaint,
    );

    // Bar 1: Purple outline & soft fill (h = 36)
    final bar1Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10, baselineY - 36, 22, 36),
      const Radius.circular(6),
    );
    final bar1Fill = Paint()..color = const Color(0xFFEEF2FF);
    final bar1Stroke = Paint()
      ..color = const Color(0xFF818CF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(bar1Rect, bar1Fill);
    canvas.drawRRect(bar1Rect, bar1Stroke);

    // Bar 2: Amber outline & soft fill (h = 56)
    final bar2Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(49, baselineY - 56, 22, 56),
      const Radius.circular(6),
    );
    final bar2Fill = Paint()..color = const Color(0xFFFEF3C7);
    final bar2Stroke = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(bar2Rect, bar2Fill);
    canvas.drawRRect(bar2Rect, bar2Stroke);

    // Bar 3: Green dashed outline (h = 74)
    final bar3X = 88.0;
    final bar3W = 22.0;
    final bar3H = 74.0;
    final bar3Top = baselineY - bar3H;
    final bar3Radius = 6.0;

    final path = Path()
      ..moveTo(bar3X, baselineY)
      ..lineTo(bar3X, bar3Top + bar3Radius)
      ..arcToPoint(
        Offset(bar3X + bar3Radius, bar3Top),
        radius: Radius.circular(bar3Radius),
      )
      ..lineTo(bar3X + bar3W - bar3Radius, bar3Top)
      ..arcToPoint(
        Offset(bar3X + bar3W, bar3Top + bar3Radius),
        radius: Radius.circular(bar3Radius),
      )
      ..lineTo(bar3X + bar3W, baselineY);

    final greenDashPaint = Paint()
      ..color = const Color(0xFF047857)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw dashed path
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashLength = 5.0;
      const dashGap = 4.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        final extract = metric.extractPath(
          distance,
          next > metric.length ? metric.length : next,
        );
        canvas.drawPath(extract, greenDashPaint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN 3 - PROFILE (no top header)
// ═════════════════════════════════════════════════════════════════════════════

class AdventureProfileView extends StatelessWidget {
  final VoidCallback? onNavigateToShop;
  const AdventureProfileView({super.key, this.onNavigateToShop});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthService>().studentProfile ??
        context.watch<LevelProgressProvider>().studentProfile;
    final levelProvider = context.watch<LevelProgressProvider>();

    final String displayName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : 'fettiz';
    final int currentLevel = levelProvider.currentLevel;
    final int coins = profile?.stats.coins ?? 0;
    final int stars = levelProvider.totalStars;
    final String lrn = profile?.lrn.isNotEmpty == true
        ? profile!.lrn
        : '123456789018';
    final String gradeLabel = profile?.gradeLevelLabel.isNotEmpty == true
        ? profile!.gradeLevelLabel
        : 'Grade ${profile?.gradeLevel ?? 4}';
    final String section =
        profile?.section.isNotEmpty == true ? profile!.section : 'Cute';
    final String placement = profile?.assignedCategory.isNotEmpty == true
        ? profile!.assignedCategory
        : 'Intermediate';
    final int startingLevel = profile?.startingLevel ?? 1;

    final linkedUid = profile?.linkedParentUid ?? '';
    final isLinked = profile?.isParentLinked == true || linkedUid.isNotEmpty;

    final parentEmail = profile?.parentGuardianEmail ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title "Profile" (Baloo 2, 34px/800, #3730A3)
              Text(
                'Profile',
                style: AppTokens.baloo2(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.headingIndigo,
                ),
              ),
              const SizedBox(height: 16),

              // Hero card (radius 28, 3px border, shadow 0 6px 0 #E0E7FF)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTokens.cardBorder, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTokens.cardBorder,
                      offset: Offset(0, 6),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Tappable 80px round equipped avatar with indigo border and edit badge
                        AnimatedBuilder(
                          animation: AvatarShopService.instance,
                          builder: (context, _) {
                            final equipped = AvatarShopService.instance.equippedAvatar;
                            return SizedBox(
                              width: 80,
                              height: 80,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (onNavigateToShop != null) {
                                      onNavigateToShop!();
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AvatarShopScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(40),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFE0E7FF),
                                          border: Border.all(
                                            color: AppTokens.primaryIndigo,
                                            width: 4,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: equipped.isAssetAvailable
                                                ? Image.asset(
                                                    equipped.assetPath,
                                                    width: 72,
                                                    height: 72,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        Image.asset(
                                                      'assets/mascots/mascot_thumbs_up.png',
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                                        Icons.person_rounded,
                                                        size: 40,
                                                        color: AppTokens.primaryIndigo,
                                                      ),
                                                    ),
                                                  )
                                                : Image.asset(
                                                    'assets/mascots/mascot_thumbs_up.png',
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                                      Icons.person_rounded,
                                                      size: 40,
                                                      color: AppTokens.primaryIndigo,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppTokens.primaryIndigo,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.palette_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTokens.baloo2(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppTokens.bodyText,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$gradeLabel · $section',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTokens.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTokens.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Current Level: $currentLevel',
                                maxLines: 1,
                                style: AppTokens.baloo2(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTokens.orangeText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (onNavigateToShop != null) {
                                      onNavigateToShop!();
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AvatarShopScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFC7D2FE), width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.storefront_rounded, size: 14, color: AppTokens.primaryIndigo),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Avatar Shop',
                                          style: AppTokens.baloo2(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTokens.primaryIndigo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Coins chip (white, orange border) & Stars chip (white, yellow border)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(21),
                              border: Border.all(
                                color: AppTokens.accentOrange,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  color: AppTokens.accentOrange,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$coins Coins',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTokens.baloo2(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTokens.bodyText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(21),
                              border: Border.all(
                                color: AppTokens.tileYellow,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: AppTokens.tileYellow,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$stars Stars',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTokens.baloo2(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTokens.tileYellow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // "My details" card (white, radius 24, 2px border)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTokens.cardBorder, width: 2),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My details',
                      style: AppTokens.baloo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.bodyText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Name
                    _buildDetailRow(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppTokens.primaryIndigo,
                      iconBg: const Color(0xFFEEF2FF),
                      label: 'Name',
                      valueWidget: Text(
                        displayName,
                        style: AppTokens.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.bodyText,
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 2. LRN
                    _buildDetailRow(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      label: 'LRN',
                      valueWidget: Text(
                        lrn,
                        style: AppTokens.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.bodyText,
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 3. Grade level
                    _buildDetailRow(
                      icon: Icons.school_outlined,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFD1FAE5),
                      label: 'Grade level',
                      valueWidget: Text(
                        gradeLabel,
                        style: AppTokens.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.bodyText,
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 4. Section
                    _buildDetailRow(
                      icon: Icons.people_outline_rounded,
                      iconColor: const Color(0xFFDB2777),
                      iconBg: const Color(0xFFFCE7F3),
                      label: 'Section',
                      valueWidget: Text(
                        section,
                        style: AppTokens.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.bodyText,
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 5. Placement (indigo pill)
                    _buildDetailRow(
                      icon: Icons.check_box_outlined,
                      iconColor: AppTokens.primaryIndigo,
                      iconBg: const Color(0xFFEEF2FF),
                      label: 'Placement',
                      valueWidget: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFC7C3E8),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          placement,
                          style: AppTokens.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.headingIndigo,
                          ),
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 6. Starting level
                    _buildDetailRow(
                      icon: Icons.flag_outlined,
                      iconColor: const Color(0xFF0284C7),
                      iconBg: const Color(0xFFE0F2FE),
                      label: 'Starting level',
                      valueWidget: Text(
                        'Level $startingLevel',
                        style: AppTokens.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.bodyText,
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 7. Parent linked (green pill "✓ Yes" or grey pill "No")
                    _buildDetailRow(
                      icon: Icons.link_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFD1FAE5),
                      label: 'Parent linked',
                      valueWidget: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLinked
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFE7E5F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLinked
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFC7C3E8),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          isLinked ? '✓ Yes' : 'No',
                          style: AppTokens.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isLinked
                                ? const Color(0xFF047857)
                                : const Color(0xFF5B5780),
                          ),
                        ),
                      ),
                    ),
                    _buildDivider(),

                    // 8. Parent email (14px, one line, ellipsis)
                    _buildDetailRow(
                      icon: Icons.mail_outline_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      label: 'Parent email',
                      valueWidget: Text(
                        parentEmail.isNotEmpty ? parentEmail : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTokens.bodyText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // "Log out" button: white, 3px red border, solid shadow 0 5px 0 #FECACA
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(color: const Color(0xFFDC2626), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFFECACA),
                      offset: Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => confirmAndLogout(context),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFB91C1C),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Log out',
                            style: AppTokens.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required Widget valueWidget,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // 32px rounded-square tinted icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTokens.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTokens.secondaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDivider() {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFEEF0FF),
    );
  }
}

