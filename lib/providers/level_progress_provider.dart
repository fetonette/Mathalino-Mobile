import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:mathalino_student_app/core/constants/game_rules.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/firestore_service.dart';

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
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
    } catch (e) {
      return FirebaseFirestore.instance;
    }
  }

  int _currentLevel = 1;
  int _startingLevel = 1;
  Map<int, String> _levelStatusMap = {};
  bool _isLoading = false;
  String? _errorMessage;
  StudentProfile? _studentProfile;
  StreamSubscription<StudentProfile>? _profileSubscription;

  int get currentLevel => _currentLevel;
  int get startingLevel => _startingLevel;
  Map<int, String> get levelStatusMap => _levelStatusMap;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  StudentProfile? get studentProfile => _studentProfile;

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
      // 1. Dual-read: Try modular /student_progress/{userId} first
      Map<String, dynamic>? progressData;
      try {
        final progressSnap =
            await _firestore.collection('student_progress').doc(userId).get();
        if (progressSnap.exists && progressSnap.data() != null) {
          progressData = progressSnap.data();
        }
      } catch (err) {
        debugPrint('[LevelProgressProvider] student_progress read fallback: $err');
      }

      // 2. Fetch /users/{userId} (profile anchor)
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final userData = docSnapshot.data()!;

        // Merge progressData over userData (progressData takes precedence for progression)
        final mergedData = {
          ...userData,
          ...?progressData,
        };

        _currentLevel = ((mergedData['currentLevel'] ??
                    mergedData['level'] ??
                    1) as num)
            .toInt()
            .clamp(1, 60);
        _startingLevel =
            ((mergedData['startingLevel'] ?? 1) as num).toInt().clamp(1, 60);

        final rawStatusMap =
            mergedData['levelStatusMap'] ?? mergedData['levelStatus'];
        if (rawStatusMap is Map) {
          _levelStatusMap = rawStatusMap.map(
            (key, value) =>
                MapEntry(int.tryParse(key.toString()) ?? 1, value.toString()),
          );
        }

        _studentProfile = StudentProfile.fromMap(mergedData, userId);
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
      final service = FirestoreService(firestore: _firestore);
      _profileSubscription = service.subscribeStudentProfile(userId).listen(
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
  Future<void> completeLevel(String userId, int level) async {
    if (level < 1 || level > 60) return;

    _levelStatusMap[level] = 'completed';
    if (level >= _currentLevel && level < 60) {
      _currentLevel = level + 1;
      _levelStatusMap[_currentLevel] = (isHardLevel(_currentLevel) || isBossLevel(_currentLevel))
          ? 'challenge'
          : 'unlocked';
    }

    notifyListeners();

    // Sync to Firestore
    try {
      final stringKeyMap = _levelStatusMap.map((k, v) => MapEntry(k.toString(), v));
      await _firestore.collection('users').doc(userId).set({
        'currentLevel': _currentLevel,
        'levelStatus': stringKeyMap,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[LevelProgressProvider] Firestore sync error: $e');
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
