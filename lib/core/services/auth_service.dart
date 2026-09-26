import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../errors/auth_exception.dart';
import '../models/student_profile.dart';
import 'firestore_service.dart';

/// Authentication Service for Mathalino Student App
/// Handles LRN to Firebase Auth email mapping, Firestore typed converter queries,
/// role verification, and custom exception handling.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
    } catch (e) {
      return FirebaseFirestore.instance;
    }
  }

  User? _user;
  StudentProfile? _studentProfile;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<StudentProfile>? _profileSubscription;

  User? get user => _user;
  StudentProfile? get studentProfile => _studentProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthService() {
    _user = _auth.currentUser;
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user == null) {
        _studentProfile = null;
        stopProfileSubscription();
      } else {
        // Persisted session (app restart): load the student's details from
        // Firestore so the Profile UI never shows empty/placeholder data.
        ensureProfileLoaded();
      }
      notifyListeners();
    });
  }

  /// Loads (or already loaded) the signed-in student's profile from
  /// `/users/{uid}` and keeps it live-synced.
  ///
  /// Safe to call repeatedly: if a profile is already cached it returns
  /// immediately; otherwise it fetches once via the typed converter and
  /// starts the real-time subscription. Never throws — failures are logged
  /// and surfaced via `errorMessage`.
  Future<StudentProfile?> ensureProfileLoaded() async {
    if (_studentProfile != null) return _studentProfile;
    final uid = _user?.uid;
    if (uid == null) return null;

    try {
      final docSnapshot = await _fetchTypedStudentProfile(uid);
      if (docSnapshot.exists && docSnapshot.data() != null) {
        _studentProfile = docSnapshot.data();
        subscribeToProfile(uid);
        notifyListeners();
        return _studentProfile;
      }
      _errorMessage =
          'Student profile not found for this account. Please contact your teacher.';
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[AuthService] ensureProfileLoaded error: $e');
      _errorMessage = 'Could not load your student profile. Check your connection.';
      notifyListeners();
      return null;
    }
  }

  /// Primary Student Login method
  /// Maps 12-digit LRN to Firebase Auth email: {LRN}@student.readquest.edu
  /// (matches the email format used by the Teacher Dashboard when provisioning
  /// student accounts). Falls back to the legacy lrn_{LRN}@mathalino.app format
  /// for backward compatibility with older accounts.
  /// Fetches typed StudentProfile from Firestore at /users/{uid}
  /// Verifies role == 'student'
  /// Returns StudentProfile or throws custom AuthException
  Future<StudentProfile> signInStudent(String lrn, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Validate LRN format (12 digits)
      final cleanLrn = lrn.trim();
      if (cleanLrn.length != 12 || !RegExp(r'^[0-9]{12}$').hasMatch(cleanLrn)) {
        throw AuthException('Please enter a valid 12-digit LRN');
      }

      if (password.isEmpty) {
        throw AuthException('Please enter your password');
      }

      // 2. Map LRN to Firebase Auth email format: {LRN}@student.readquest.edu
      //    This is the canonical format used by the Teacher Dashboard when
      //    provisioning student accounts via createUserWithEmailAndPassword.
      final primaryEmail = '$cleanLrn@student.readquest.edu';
      UserCredential credential;

      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: primaryEmail,
          password: password,
        );
      } on FirebaseAuthException catch (authErr) {
        // Fallback check for legacy lrn_ prefix email format
        if (authErr.code == 'user-not-found') {
          try {
            final fallbackEmail = 'lrn_$cleanLrn@mathalino.app';
            credential = await _auth.signInWithEmailAndPassword(
              email: fallbackEmail,
              password: password,
            );
          } on FirebaseAuthException catch (fallbackErr) {
            // IMPORTANT: Throw the ACTUAL fallback error (e.g. wrong-password)
            // instead of the original user-not-found from the primary attempt.
            throw _handleFirebaseAuthException(fallbackErr);
          }
        } else {
          throw _handleFirebaseAuthException(authErr);
        }
      }

      final authenticatedUser = credential.user;
      if (authenticatedUser == null) {
        throw AuthException('Failed to authenticate student credentials.');
      }

      _user = authenticatedUser;

      // 3. Fetch user's Firestore document at /users/{uid} using typed converter
      final DocumentSnapshot<StudentProfile> docSnapshot = await _fetchTypedStudentProfile(authenticatedUser.uid);

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        await _auth.signOut();
        _user = null;
        _studentProfile = null;
        throw AuthException(
          'Student account profile not found in database. Please contact your teacher.',
          code: 'PROFILE_NOT_FOUND',
        );
      }

      final profile = docSnapshot.data()!;

      // 4. Security check: Verify role == 'student'
      if (profile.role != 'student') {
        await _auth.signOut();
        _user = null;
        _studentProfile = null;
        throw AuthException(
          'This portal is strictly for Students. '
          'Teachers and Parents must use the Web Dashboard.',
          code: 'UNAUTHORIZED_ROLE',
        );
      }

      _studentProfile = profile;
      _setLoading(false);
      notifyListeners();

      // Keep the profile live-synced with the Teacher Dashboard while
      // the student is authenticated.
      subscribeToProfile(authenticatedUser.uid);

      return profile;
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      rethrow;
    } on FirebaseException catch (e) {
      final authEx = AuthException(
        'Database connection error: ${e.message}',
        code: e.code,
        originalError: e,
      );
      _setError(authEx.message);
      _setLoading(false);
      throw authEx;
    } catch (e) {
      final authEx = AuthException(
        'An unexpected error occurred during login: ${e.toString()}',
        originalError: e,
      );
      _setError(authEx.message);
      _setLoading(false);
      throw authEx;
    }
  }

  /// Helper method using typed Firestore converter with resilience fallbacks
  Future<DocumentSnapshot<StudentProfile>> _fetchTypedStudentProfile(String uid) async {
    final converter = _firestore.collection('users').doc(uid).withConverter<StudentProfile>(
          fromFirestore: (snapshot, _) => StudentProfile.fromFirestore(snapshot),
          toFirestore: (profile, _) => profile.toFirestore(),
        );

    try {
      return await converter.get();
    } catch (e) {
      debugPrint('[AuthService] Primary typed query error: $e. Retrying default Firestore instance...');
      final fallbackConverter = FirebaseFirestore.instance.collection('users').doc(uid).withConverter<StudentProfile>(
            fromFirestore: (snapshot, _) => StudentProfile.fromFirestore(snapshot),
            toFirestore: (profile, _) => profile.toFirestore(),
          );
      return await fallbackConverter.get();
    }
  }

  /// Fetch user profile data map for UI dashboard display
  Future<Map<String, dynamic>?> getUserData() async {
    if (_user == null) return null;

    try {
      if (_studentProfile != null) {
        return _studentProfile!.toMap();
      }
      final docSnapshot = await _fetchTypedStudentProfile(_user!.uid);
      if (docSnapshot.exists && docSnapshot.data() != null) {
        _studentProfile = docSnapshot.data();
        return _studentProfile!.toMap();
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] getUserData error: $e');
      return null;
    }
  }

  /// Backward-compatible login method returning `Future<bool>` for UI compatibility
  Future<bool> loginWithLRN(String lrn, String password) async {
    try {
      await signInStudent(lrn, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts a real-time Firestore subscription on /users/{uid} so the
  /// profile stays synchronized with the Teacher Dashboard while the student
  /// is logged in. When the teacher edits the student (section, status,
  /// parent info, avatar, XP, etc.), `_studentProfile` updates automatically
  /// and listeners are notified.
  void subscribeToProfile(String uid) {
    _profileSubscription?.cancel();
    try {
      final service = FirestoreService(firestore: _firestore);
      _profileSubscription = service.subscribeStudentProfile(uid).listen(
        (profile) {
          _studentProfile = profile;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[AuthService] Profile subscription error: $e');
        },
      );
    } catch (e) {
      debugPrint('[AuthService] Failed to start profile subscription: $e');
    }
  }

  void stopProfileSubscription() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  /// Reset password for a student using their LRN
  Future<bool> resetPassword(String lrn) async {
    _setLoading(true);
    _clearError();

    try {
      final cleanLrn = lrn.trim();
      if (cleanLrn.length != 12 || !RegExp(r'^[0-9]{12}$').hasMatch(cleanLrn)) {
        throw AuthException('Please enter a valid 12-digit LRN');
      }

      // Use the canonical email format: {LRN}@student.readquest.edu
      // (matches the format used by the Teacher Dashboard when provisioning
      // student accounts). Fall back to the legacy lrn_ prefix format if needed.
      final email = '$cleanLrn@student.readquest.edu';
      try {
        await _auth.sendPasswordResetEmail(email: email);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          final legacyEmail = 'lrn_$cleanLrn@mathalino.app';
          await _auth.sendPasswordResetEmail(email: legacyEmail);
        } else {
          rethrow;
        }
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      final authEx = _handleFirebaseAuthException(e);
      _setError(authEx.message);
      _setLoading(false);
      throw authEx;
    } catch (e) {
      final authEx = AuthException('Password reset failed: ${e.toString()}');
      _setError(authEx.message);
      _setLoading(false);
      throw authEx;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      stopProfileSubscription();
      await _auth.signOut();
      _user = null;
      _studentProfile = null;
      notifyListeners();
    } catch (e) {
      final authEx = AuthException('Logout failed: ${e.toString()}');
      _setError(authEx.message);
      throw authEx;
    }
  }

  /// User-friendly FirebaseAuthException parser
  AuthException _handleFirebaseAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No student account found with this LRN. Please check with your teacher.';
        break;
      case 'wrong-password':
      case 'invalid-credential':
        message = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        message = 'Invalid LRN email format.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled. Please contact your teacher.';
        break;
      case 'too-many-requests':
        message = 'Too many login attempts. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your internet connection.';
        break;
      default:
        message = e.message ?? 'Authentication failed. Please try again.';
    }
    return AuthException(message, code: e.code, originalError: e);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
