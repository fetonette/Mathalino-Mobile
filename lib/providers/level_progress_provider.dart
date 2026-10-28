import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mathalino_student_app/core/constants/game_rules.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/supabase_service.dart';

/// Enum representing the 4 possible visual states of a level node
enum LevelState {
  locked,
  unlocked,
  completed,
  challenge,
}

/// Level Progress Provider for Mathalino Student App
/// Manages level status for 60 levels across 3 zones (Zone 1: 1-20, Zone 2: 21-40, Zone 3: 41-60).
class LevelProgressProvider extends ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  int _currentLevel = 1;
  int _startingLevel = 1;
  Map<int, String> _levelStatusMap = {};
  bool _isLoading = false;
  String? _errorMessage;
  StudentProfile? _studentProfile;
  StreamSubscription<StudentProfile>? _profileSubscription;

  // Total Stars (SUM of level_progress.stars for completed levels). Kept
  // separate from XP/Coins/Streak. Only ever overwritten by a SUCCESSFUL read;
  // failures preserve the last known value.
  int _totalStars = 0;
  bool _totalStarsLoaded = false;
  bool _isLoadingTotalStars = false;
  String? _totalStarsError;

  // Per-level earned stars sourced ONLY from genuine completed `level_progress`
  // rows (keyed by level). An absent key means there is no completed row (locked
  // / current / unlocked / diagnostic placement-skipped) so the UI shows nothing.
  // `_levelStarsLoadedForLrn` binds the map to one exact student so a previous
  // account's values can never be shown after an account switch.
  Map<int, int> _levelStarsByLevel = {};
  String? _levelStarsLoadedForLrn;

  int get currentLevel => _currentLevel;
  int get startingLevel => _startingLevel;
  Map<int, String> get levelStatusMap => _levelStatusMap;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  StudentProfile? get studentProfile => _studentProfile;

  /// Actual Total Stars (last successfully-read value).
  int get totalStars => _totalStars;

  /// Whether Total Stars has been loaded at least once this session.
  bool get totalStarsLoaded => _totalStarsLoaded;

  /// Whether a Total Stars read is currently in flight.
  bool get isLoadingTotalStars => _isLoadingTotalStars;

  /// Non-null when the most recent Total Stars read failed. The displayed value
  /// is the preserved last-known [_totalStars], never a forced 0.
  String? get totalStarsError => _totalStarsError;

  /// Earned stars for [level] from the signed-in student's completed
  /// `level_progress` rows. Returns `null` when there is NO completed row for
  /// that level (locked / current / unlocked / diagnostic placement-skipped),
  /// and `0` for a genuine completed row whose stored stars is NULL/0. Guarded
  /// by the student's LRN so a different account's cached map is never exposed.
  int? starsForLevel(int level) {
    final lrn = _studentProfile?.lrn ?? '';
    if (lrn.isEmpty || _levelStarsLoadedForLrn != lrn) return null;
    return _levelStarsByLevel[level];
  }

  /// Helper to check if a level is a Hard gate (5, 10, 15, 45, 50, 55).
  ///
  /// Delegates to the shared zone-aware rule in game_rules.dart — the
  /// Intermediate zone (21–40) intentionally has NO hard gates, so a naive
  /// `level % 5 == 0` must not be used here.
  static bool isHardLevel(int level) => isHardGateLevel(level);

  /// Helper to check if a level is a Boss level (20 or 60).
  ///
  /// Level 40 is NOT a boss any more — the Intermediate spec demoted it to
  /// "Moderate (Multi-Step)" so Zone 2 unlocks in a straight line.
  static bool isBossLevel(int level) => isBossGateLevel(level);

  /// Get Zone Number for a given level (1: 1-20, 2: 21-40, 3: 41-60)
  static int getZoneForLevel(int level) {
    if (level <= 20) return 1;
    if (level <= 40) return 2;
    return 3;
  }

  /// Initialize provider with explicit values or defaults
  void initLocal({
    int currentLevel = 1,
    int startingLevel = 1,
    Map<int, String>? customStatusMap,
  }) {
    _currentLevel = currentLevel.clamp(1, 60);
    _startingLevel = startingLevel.clamp(1, 60);
    _levelStatusMap = customStatusMap ?? {};
    _recalculateStatusMap();
    notifyListeners();
  }

  /// Fetch level progress from Firestore /student_progress/{userId} with fallback to /users/{userId}
  Future<void> fetchProgress(String userId) async {
    _setLoading(true);
    try {
      // Fetch from users table (Supabase)
      final profile = await _db.fetchStudentProfile(userId);
      if (profile != null) {
        _currentLevel = profile.currentLevel.clamp(1, 60);
        _startingLevel = profile.startingLevel.clamp(1, 60);
        _levelStatusMap = _stringKeyMapToInt(profile.levelStatusMap);
        _studentProfile = profile;
        // Load Total Stars from genuine completed level_progress rows.
        // refreshTotalStars is self-contained (never throws) so a stars read
        // failure cannot disrupt level-progress loading.
        await refreshTotalStars();
      }
      _recalculateStatusMap();
    } catch (e) {
      debugPrint('[LevelProgressProvider] Fetch error: $e');
      _errorMessage = 'Failed to load level progress';
    } finally {
      _setLoading(false);
    }
  }

  /// Subscribes to real-time updates on /users/{userId}.
  ///
  /// When the Teacher Dashboard updates the student document (e.g. changes
  /// section, status, currentLevel, or levelStatus), this stream fires
  /// immediately and keeps the in-memory state and UI in sync.
  void subscribeToProfile(String userId) {
    _profileSubscription?.cancel();
    try {
      _profileSubscription = _db.subscribeStudentProfile(userId).listen(
        (profile) {
          _studentProfile = profile;
          _currentLevel = profile.currentLevel.clamp(1, 60);
          _startingLevel = profile.startingLevel.clamp(1, 60);

          _levelStatusMap = _stringKeyMapToInt(profile.levelStatusMap);
          _recalculateStatusMap();

          _errorMessage = null;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[LevelProgressProvider] Profile subscription error: $e');
          _errorMessage = 'Lost connection to student profile';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[LevelProgressProvider] Failed to start profile subscription: $e');
    }
  }

  Map<int, String> _stringKeyMapToInt(Map<String, dynamic>? map) {
    if (map == null) return {};
    return map.map(
      (key, value) => MapEntry(int.tryParse(key.toString()) ?? 1, value.toString()),
    );
  }

  /// Test hook: injects a profile snapshot the same way the real-time
  /// Firestore stream would, so the provider's state stays testable.
  void injectProfileFromSnapshot(Map<String, dynamic> snapshot, String uid) {
    final profile = StudentProfile.fromMap(snapshot, uid);
    _studentProfile = profile;
    _currentLevel = profile.currentLevel.clamp(1, 60);
    _startingLevel = profile.startingLevel.clamp(1, 60);
    _levelStatusMap = _stringKeyMapToInt(profile.levelStatusMap);
    _recalculateStatusMap();
    _errorMessage = null;
    notifyListeners();
  }

  /// Resolve LevelState for any given level number (1 to 60)
  LevelState getLevelState(int level) {
    if (level < 1 || level > 60) return LevelState.locked;

    // 1. Explicit status check from Firestore levelStatus map
    final explicitStatus = _levelStatusMap[level];

    if (explicitStatus == 'completed') {
      return LevelState.completed;
    }

    if (explicitStatus == 'challenge') {
      return LevelState.challenge;
    }

    if (explicitStatus == 'unlocked') {
      if (isHardLevel(level) || isBossLevel(level)) {
        return LevelState.challenge;
      }
      return LevelState.unlocked;
    }

    if (explicitStatus == 'locked') {
      return LevelState.locked;
    }

    // 2. Default logic based on currentLevel & startingLevel:
    // Levels below startingLevel are automatically unlocked/completed for students placed higher
    if (level < _startingLevel) {
      return LevelState.completed;
    }

    // Levels up to currentLevel are unlocked
    if (level < _currentLevel) {
      return LevelState.completed;
    }

    if (level == _currentLevel) {
      if (isHardLevel(level) || isBossLevel(level)) {
        return LevelState.challenge;
      }
      return LevelState.unlocked;
    }

    // Future levels are locked
    return LevelState.locked;
  }

  /// Recalculate and fill status entries for all 60 levels
  void _recalculateStatusMap() {
    for (int i = 1; i <= 60; i++) {
      if (!_levelStatusMap.containsKey(i)) {
        if (i < _startingLevel || i < _currentLevel) {
          _levelStatusMap[i] = 'completed';
        } else if (i == _currentLevel) {
          _levelStatusMap[i] = (isHardLevel(i) || isBossLevel(i)) ? 'challenge' : 'unlocked';
        } else {
          _levelStatusMap[i] = 'locked';
        }
      }
    }
  }

  /// Update a level's status and advance currentLevel if completed
  Future<void> completeLevel(String userId, int level, {String? lrn}) async {
    if (level < 1 || level > 60) return;

    _levelStatusMap[level] = 'completed';
    if (level >= _currentLevel && level < 60) {
      _currentLevel = level + 1;
      _levelStatusMap[_currentLevel] = (isHardLevel(_currentLevel) || isBossLevel(_currentLevel))
          ? 'challenge'
          : 'unlocked';
    }

    notifyListeners();

    // Sync to Supabase
    try {
      final stringKeyMap = _levelStatusMap.map((k, v) => MapEntry(k.toString(), v));
      final resolvedLrn = (lrn != null && lrn.isNotEmpty) ? lrn : (_studentProfile?.lrn ?? '');
      await _db.updateUserFields(userId, {
        if (resolvedLrn.isNotEmpty) 'lrn': resolvedLrn,
        'current_level': _currentLevel,
        'level_status_map': stringKeyMap,
      });
    } catch (e) {
      debugPrint('[LevelProgressProvider] Supabase sync error: $e');
    }
  }

  /// Re-reads the signed-in student's completed `level_progress` rows ONCE and
  /// refreshes BOTH Total Stars (the SUM) and the per-level star map from that
  /// single query (no duplicate read). On failure it PRESERVES the last-known
  /// value for the SAME student (never silently resets to 0) and records an error
  /// flag. On an account switch (different LRN) it clears the stale map so a
  /// previous student's stars are never shown. Safe to call after a completion.
  Future<void> refreshTotalStars() async {
    final lrn = _studentProfile?.lrn ?? '';
    if (lrn.isEmpty) {
      // No identity: never expose a previous student's per-level stars.
      _levelStarsByLevel = {};
      _levelStarsLoadedForLrn = null;
      _totalStarsError = 'No student LRN available for total stars.';
      notifyListeners();
      return;
    }
    // Whether the currently-loaded map already belongs to this exact student.
    final bool isSameStudent = _levelStarsLoadedForLrn == lrn;
    _isLoadingTotalStars = true;
    _totalStarsError = null;
    notifyListeners();
    try {
      // One read provides both the per-level map and the aggregate total.
      final Map<int, int> map = await _db.fetchLevelStarsByLevel(lrn);
      _levelStarsByLevel = map;
      _levelStarsLoadedForLrn = lrn;
      _totalStars = map.values.fold<int>(0, (sum, s) => sum + s);
      _totalStarsLoaded = true;
    } catch (e) {
      debugPrint('[LevelProgressProvider] Total stars refresh error: $e');
      _totalStarsError = 'Could not refresh total stars.';
      // Preserve last-known values ONLY for the same student. On an account
      // switch (new LRN) clear them so the previous student's stars never leak.
      if (!isSameStudent) {
        _levelStarsByLevel = {};
        _levelStarsLoadedForLrn = null;
        _totalStars = 0;
        _totalStarsLoaded = false;
      }
    } finally {
      _isLoadingTotalStars = false;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    super.dispose();
  }
}
