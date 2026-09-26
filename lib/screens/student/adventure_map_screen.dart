import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/student_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/level_progress_provider.dart';
import '../../providers/remediation_provider.dart';
import '../../widgets/level_node.dart';
import '../../widgets/zone_banner.dart';
import 'remediation_screen.dart';
import 'adventure_sections.dart';
import 'beginner_zone_gameplay_screen.dart';

/// Adventure Map Screen for Mathalino Student App
/// Displays 60 levels grouped into 3 Zone Sections with serpentine path layout.
class AdventureMapScreen extends StatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  State<AdventureMapScreen> createState() => _AdventureMapScreenState();
}

class _AdventureMapScreenState extends State<AdventureMapScreen> {
  final ScrollController _scrollController = ScrollController();
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = context.read<AuthService>();
      final levelProvider = context.read<LevelProgressProvider>();
      final remediationProvider = context.read<RemediationProvider>();

      if (authService.user != null) {
        await levelProvider.fetchProgress(authService.user!.uid);
        if (mounted) {
          remediationProvider.loadRemediation(authService.user!.uid);
          levelProvider.subscribeToProfile(authService.user!.uid);
          await authService.ensureProfileLoaded();
        }
      } else {
        levelProvider.initLocal(currentLevel: 1, startingLevel: 1);
      }

      if (mounted) {
        _scrollToCurrentLevel(levelProvider.currentLevel);

        // ── One-time Welcome Modal ─────────────────────────────────────
        // Show once per UID (both new students from diagnostic and existing
        // students opening the map for the first time on this device).
        final uid = authService.user?.uid;
        if (uid != null) {
          await _checkAndShowWelcomeModal(
            uid: uid,
            authService: authService,
            levelProvider: levelProvider,
          );
        }
      }
    });
  }

  // ─── SharedPreferences key ────────────────────────────────────────────────
  static String _welcomeKey(String uid) => 'adventure_welcome_shown_$uid';

  /// Shows the Welcome Modal the first time a student opens the Adventure Map.
  /// Uses SharedPreferences so it persists across app restarts.
  /// Accepts placement data from route arguments (set by DiagnosticResultsScreen)
  /// as well as from the loaded student profile for existing students.
  Future<void> _checkAndShowWelcomeModal({
    required String uid,
    required AuthService authService,
    required LevelProgressProvider levelProvider,
  }) async {
    try {
      // Prefer route arguments (fresh from diagnostic) captured before async gap
      final routeArgs = ModalRoute.of(context)?.settings.arguments;

      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_welcomeKey(uid)) ?? false;
      if (alreadyShown || !mounted) return;

      // Mark as shown immediately so double-triggers can't show it twice.
      await prefs.setBool(_welcomeKey(uid), true);
      if (!mounted) return;

      final args = routeArgs is Map ? routeArgs : <String, dynamic>{};

      final studentName = (args['studentName'] as String?)?.isNotEmpty == true
          ? args['studentName'] as String
          : (authService.studentProfile?.displayName.isNotEmpty == true
                ? authService.studentProfile!.displayName
                : 'Student');

      final placementCategory = (args['placementCategory'] as String?)?.isNotEmpty == true
          ? args['placementCategory'] as String
          : (authService.studentProfile?.assignedCategory.isNotEmpty == true
                ? authService.studentProfile!.assignedCategory
                : 'Beginner');

      final startingLevel = (args['startingLevel'] as int?) ??
          levelProvider.startingLevel;

      if (mounted) {
        await _showWelcomeModal(
          studentName: studentName,
          placementCategory: placementCategory,
          startingLevel: startingLevel,
        );
      }
    } catch (e) {
      debugPrint('[AdventureMapScreen] Welcome modal error: $e');
    }
  }

  /// Premium gamified Welcome Modal shown once per student account.
  Future<void> _showWelcomeModal({
    required String studentName,
    required String placementCategory,
    required int startingLevel,
  }) {
    // Category-specific colour & emoji
    final Color categoryColor;
    final String categoryEmoji;
    final String categoryLabel;
    switch (placementCategory.toLowerCase()) {
      case 'advanced':
      case 'mastery':
        categoryColor = const Color(0xFF3B82F6);
        categoryEmoji = '🏆';
        categoryLabel = placementCategory;
        break;
      case 'intermediate':
        categoryColor = const Color(0xFF10B981);
        categoryEmoji = '⭐';
        categoryLabel = placementCategory;
        break;
      default:
        categoryColor = const Color(0xFFF59E0B);
        categoryEmoji = '🌱';
        categoryLabel = placementCategory.isEmpty ? 'Beginner' : placementCategory;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: categoryColor.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sparkle header
                Text(
                  categoryEmoji,
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome, $studentName!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your adventure is about to begin!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Placement badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: categoryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        categoryLabel.toUpperCase(),
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Starting level chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Starting at Level $startingLevel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor,
                          categoryColor.withValues(alpha: 0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withValues(alpha: 0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Start Adventure!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
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
        ),
      ),
    );
  }

  void _scrollToCurrentLevel(int targetLevel) {
    if (!mounted || targetLevel <= 1 || !_scrollController.hasClients) return;

    // Approximate node height + padding = ~76px, with zone header offsets
    final double targetOffset =
        (targetLevel - 1) * 76.0 +
        (targetLevel > 20 ? 120.0 : 0.0) +
        (targetLevel > 40 ? 120.0 : 0.0);

    final maxScroll = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of Mathalino?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
  }

  void _navigateToGameplay(int levelNumber) {
    final authService = context.read<AuthService>();
    final profile = authService.studentProfile;
    final remediationProvider = context.read<RemediationProvider>();

    // If a remediation session is active, route to the remediation screen
    // instead of normal gameplay.
    if (remediationProvider.isRemediationActive) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RemediationScreen(
            user:
                profile ??
                StudentProfile(
                  uid: authService.user?.uid ?? '',
                  lrn: '',
                  displayName: 'Student',
                  gradeLevel: 1,
                  assignedCategory: 'Beginner',
                  currentLevel: levelNumber,
                  startingLevel: 1,
                  stats: const StudentStats(),
                  usedQuestionsHistory: [],
                  diagnosticCompleted: false,
                  verificationCode: '',
                ),
            contentPool: profile?.assignedCategory.isNotEmpty == true
                ? [profile!.assignedCategory]
                : const [],
            failedLevel: remediationProvider.remediation.targetLevel,
          ),
          settings: RouteSettings(name: '/remediation/$levelNumber'),
        ),
      );
      return;
    }

    // All levels 1–60 use BeginnerZoneGameplayScreen (backed by LevelProvider +
    // GameLogicService + QuestionBankService). Zone 2 (21–40) has no
    // remediation gates; Zone 3 (41–60) restores gates at 45/50/55/60 and
    // Level 60 surfaces the "Adventure Complete" state.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BeginnerZoneGameplayScreen(
          levelNumber: levelNumber,
          user:
              profile ??
              StudentProfile(
                uid: authService.user?.uid ?? '',
                lrn: '',
                displayName: 'Student',
                gradeLevel: 1,
                assignedCategory: 'Beginner',
                currentLevel: levelNumber,
                startingLevel: 1,
                stats: const StudentStats(),
                usedQuestionsHistory: [],
                diagnosticCompleted: false,
                verificationCode: '',
              ),
        ),
        settings: RouteSettings(name: '/beginner-zone/$levelNumber'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final levelProvider = context.watch<LevelProgressProvider>();
    final profile = authService.studentProfile;

    final String displayName = profile?.displayName ?? 'Student';
    final int totalXp = profile?.stats.totalXp ?? 0;
    final int coins = profile?.stats.coins ?? 0;
    final int currentLevel = levelProvider.currentLevel;

    final sections = <Widget>[
      _buildMapBody(context, levelProvider),
      const AdventureLearnView(),
      const AdventureProgressView(),
      const AdventureProfileView(),
    ];

    return Scaffold(
      backgroundColor: const Color(
        0xFF0F172A,
      ), // Slate Dark Background for Gamified Contrast
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Current Level: $currentLevel',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Coins Indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // XP Indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 4),
                Text(
                  '$totalXp XP',
                  style: const TextStyle(
                    color: Color(0xFF818CF8),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _confirmLogout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: levelProvider.isLoading && _selectedSection == 0
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : sections[_selectedSection],
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 700
            ? NavigationBar(
                selectedIndex: _selectedSection,
                onDestinationSelected: _selectSection,
                destinations: _navigationDestinations(),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildMapBody(
    BuildContext context,
    LevelProgressProvider levelProvider,
  ) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          // ZONE 1: Levels 1-20
          _buildZoneSection(
            context: context,
            zoneNumber: 1,
            startLevel: 1,
            endLevel: 20,
            provider: levelProvider,
            banner: ZoneBanner.zone1(
              completedCount: _getCompletedCount(levelProvider, 1, 20),
            ),
          ),

          // ZONE 2: Levels 21-40
          _buildZoneSection(
            context: context,
            zoneNumber: 2,
            startLevel: 21,
            endLevel: 40,
            provider: levelProvider,
            banner: ZoneBanner.zone2(
              completedCount: _getCompletedCount(levelProvider, 21, 40),
            ),
          ),

          // ZONE 3: Levels 41-60
          _buildZoneSection(
            context: context,
            zoneNumber: 3,
            startLevel: 41,
            endLevel: 60,
            provider: levelProvider,
            banner: ZoneBanner.zone3(
              completedCount: _getCompletedCount(levelProvider, 41, 60),
            ),
          ),
        ],
      ),
    );
  }

  List<NavigationDestination> _navigationDestinations() {
    return const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: 'Learn',
      ),
      NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights),
        label: 'Progress',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  void _selectSection(int index) {
    setState(() => _selectedSection = index);
    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentLevel(
          context.read<LevelProgressProvider>().currentLevel,
        );
      });
    }
  }

  int _getCompletedCount(LevelProgressProvider provider, int start, int end) {
    int count = 0;
    for (int i = start; i <= end; i++) {
      if (provider.getLevelState(i) == LevelState.completed) {
        count++;
      }
    }
    return count;
  }

  Widget _buildZoneSection({
    required BuildContext context,
    required int zoneNumber,
    required int startLevel,
    required int endLevel,
    required LevelProgressProvider provider,
    required Widget banner,
  }) {
    final List<int> levels = List.generate(
      endLevel - startLevel + 1,
      (i) => startLevel + i,
    );

    return Column(
      children: [
        banner,
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: levels.length,
          itemBuilder: (context, index) {
            final levelNum = levels[index];
            final state = provider.getLevelState(levelNum);
            final bool isHard = LevelProgressProvider.isHardLevel(levelNum);
            final bool isBoss = LevelProgressProvider.isBossLevel(levelNum);
            final bool isCurrent = levelNum == provider.currentLevel;

            // Serpentine horizontal offset pattern: Left, Center, Right, Center, Left
            final int posPattern = index % 4;
            Alignment alignment = Alignment.center;
            if (posPattern == 0) alignment = const Alignment(-0.6, 0.0);
            if (posPattern == 1) alignment = Alignment.center;
            if (posPattern == 2) alignment = const Alignment(0.6, 0.0);
            if (posPattern == 3) alignment = Alignment.center;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Align(
                alignment: alignment,
                child: LevelNode(
                  levelNumber: levelNum,
                  state: state,
                  isHard: isHard,
                  isBoss: isBoss,
                  isCurrent: isCurrent,
                  onTap: () => _navigateToGameplay(levelNum),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
