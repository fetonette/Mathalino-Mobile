import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/student_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/mathalino_tokens.dart';
import '../../providers/level_progress_provider.dart';
import '../../providers/remediation_provider.dart';
import '../../widgets/chunky_3d_button.dart';
import '../../widgets/home/home_background.dart';
import '../../widgets/home/home_strings.dart';
import '../../widgets/home/home_widgets.dart';
import '../../widgets/home/level_map.dart';
import '../../widgets/level_node.dart';
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

class _AdventureMapScreenState extends State<AdventureMapScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  int _selectedSection = 0;

  // ── Home presentation state (UI only) ────────────────────────────────────
  /// Zone whose levels are currently in view (drives the pinned zone card).
  final ValueNotifier<int> _zoneInView = ValueNotifier<int>(1);
  LevelMapLayout? _layout;
  double _viewportHeight = 0;
  bool _dataReady = false;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authService = context.read<AuthService>();
      final levelProvider = context.read<LevelProgressProvider>();
      final remediationProvider = context.read<RemediationProvider>();

      if (authService.user != null) {
        await levelProvider.fetchProgress(authService.user!.id);
        if (mounted) {
          remediationProvider.loadRemediation(authService.user!.id);
          levelProvider.subscribeToProfile(authService.user!.id);
          await authService.ensureProfileLoaded();
        }
      } else {
        levelProvider.initLocal(currentLevel: 1, startingLevel: 1);
      }

      if (mounted) {
        // Data is loaded: let the map jump to the current level once built.
        setState(() => _dataReady = true);

        // ── One-time Welcome Modal ─────────────────────────────────────
        // Show once per UID (both new students from diagnostic and existing
        // students opening the map for the first time on this device).
        final uid = authService.user?.id;
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

  // ─── Map scrolling ───────────────────────────────────────────────────────

  /// Scrolls so the current level sits in the upper-middle of the map area.
  void _scrollToCurrentLevel(int targetLevel, {bool animate = false}) {
    final layout = _layout;
    if (!mounted || layout == null || !_scrollController.hasClients) return;
    if (layout.entries.isEmpty) return;

    final h = _viewportHeight;
    final localY = math.min(math.max(0.40 * h, 175.0), math.max(h - 125.0, 0.0));
    final index = (targetLevel - 1).clamp(0, layout.entries.length - 1);
    final offset = layout
        .offsetFor(index, localY)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
    _updateZoneInView(offset);
  }

  void _updateZoneInView(double pixels) {
    final layout = _layout;
    if (layout == null || layout.centers.isEmpty) return;
    final probe = pixels + _viewportHeight * 0.35;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < layout.centers.length; i++) {
      final d = (layout.centers[i].dy - probe).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    final zone = HomeZone.forLevel(layout.entries[best].level).number;
    if (_zoneInView.value != zone) _zoneInView.value = zone;
  }

  bool _onMapScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical) _updateZoneInView(n.metrics.pixels);
    return false;
  }

  @override
  void dispose() {
    _zoneInView.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Starts a level. Same navigation as before.
  void _startLevel(int levelNumber) {
    _navigateToGameplay(levelNumber);
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
                  uid: authService.user?.id ?? '',
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
                uid: authService.user?.id ?? '',
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

    if (_selectedSection == 0) {
      return _buildHome(
        levelProvider: levelProvider,
        name: displayName,
        coins: coins,
        xp: totalXp,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTokens.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_selectedSection == 1 || _selectedSection == 2)
                HomeHeader(
                  name: displayName,
                  level: currentLevel,
                  coins: coins,
                  xp: totalXp,
                ),
              Expanded(
                child: _selectedSection == 1
                    ? const AdventureLearnView()
                    : _selectedSection == 2
                        ? AdventureProgressView(
                            onNavigateToLearn: () => _selectSection(1),
                          )
                        : const AdventureProfileView(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 700
          ? HomeBottomNav(
              selectedIndex: _selectedSection,
              onSelected: _selectSection,
            )
          : const SizedBox.shrink(),
    );
  }

  // ─── Home / level map ────────────────────────────────────────────────────

  Widget _buildHome({
    required LevelProgressProvider levelProvider,
    required String name,
    required int coins,
    required int xp,
  }) {
    final currentLevel = levelProvider.currentLevel;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppTokens.background,
        body: Stack(
          children: [
            // Fixed background layer (does not scroll, never takes taps).
            const Positioned.fill(child: HomeBackground()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  HomeHeader(
                    name: name,
                    level: currentLevel,
                    coins: coins,
                    xp: xp,
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _zoneInView,
                    builder: (context, zoneNumber, _) {
                      final zone = HomeZone.all[zoneNumber - 1];
                      return ZoneCard(
                        zone: zone,
                        completed: _completedIn(levelProvider, zone),
                      );
                    },
                  ),
                  Expanded(
                    child: levelProvider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          )
                        : _buildMapArea(levelProvider),
                  ),
                ],
              ),
            ),
            // Floating Continue button (same action as tapping the current level).
            Positioned(
              left: 16,
              right: 16,
              bottom: 4,
              child: Chunky3DButton(
                text: HomeStrings.continueLevel(currentLevel),
                icon: Icons.play_arrow_rounded,
                iconLeading: true,
                height: 56,
                fontSize: 20,
                onPressed: () => _startLevel(currentLevel),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildMapArea(LevelProgressProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        final entries = <LevelMapEntry>[
          for (var level = 1; level <= 60; level++)
            LevelMapEntry(
              level,
              levelNodeKindFor(
                provider.getLevelState(level),
                level == provider.currentLevel,
              ),
            ),
        ];
        final width = constraints.maxWidth;
        if (_layout == null || !_layout!.sameShape(width, entries)) {
          _layout = LevelMapLayout.compute(width: width, entries: entries);
        }

        if (_dataReady && !_didInitialScroll) {
          _didInitialScroll = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _zoneInView.value = HomeZone.forLevel(provider.currentLevel).number;
            _scrollToCurrentLevel(provider.currentLevel);
          });
        }

        return LevelMapView(
          controller: _scrollController,
          layout: _layout!,
          // Space for the floating Continue button (56 + shadow + margins).
          extraBottom: 96,
          onScrollNotification: _onMapScroll,
          nodeBuilder: (entry) {
            final level = entry.level;
            return LevelNode(
              levelNumber: level,
              state: provider.getLevelState(level),
              isHard: LevelProgressProvider.isHardLevel(level),
              isBoss: LevelProgressProvider.isBossLevel(level),
              isCurrent: level == provider.currentLevel,
              onTap: () => _startLevel(level),
            );
          },
        );
      },
    );
  }

  void _selectSection(int index) {
    setState(() {
      _selectedSection = index;
      if (index == 0) {
        // Re-center the map on the current level when returning to Home.
        _didInitialScroll = false;
      }
    });
  }

  int _completedIn(LevelProgressProvider provider, HomeZone zone) {
    int count = 0;
    for (int i = zone.firstLevel; i <= zone.lastLevel; i++) {
      if (provider.getLevelState(i) == LevelState.completed) {
        count++;
      }
    }
    return count;
  }
}
