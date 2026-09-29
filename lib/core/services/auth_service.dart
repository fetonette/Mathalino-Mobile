import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as supa show AuthException;

import '../errors/auth_exception.dart';
import '../models/student_profile.dart';
import 'supabase_service.dart';

/// Authentication Service for Mathalino Student App
/// Handles LRN to Supabase Auth email mapping, profile loading,
/// role verification, and custom exception handling.
/// Firebase is kept only for push notification tokens (firebase_messaging).
class AuthService extends ChangeNotifier {
  final SupabaseClient? _injectedClient;
  final SupabaseService _db;

  SupabaseClient get _supabase {
    final client = _injectedClient;
    if (client != null) return client;
    return Supabase.instance.client;
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

  AuthService({SupabaseClient? supabaseClient, SupabaseService? db})
      : _injectedClient = supabaseClient,
        _db = db ?? SupabaseService(client: supabaseClient) {
    _initAuth();
  }

  void _initAuth() {
    try {
      // Restore any existing session on app start
      _user = _supabase.auth.currentUser;
      if (_user != null) {
        ensureProfileLoaded();
      }

      // Listen to auth state changes (login / logout / token refresh)
      _supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        _user = session?.user;

        if (_user == null || event == AuthChangeEvent.signedOut) {
          _studentProfile = null;
          stopProfileSubscription();
        } else if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.initialSession) {
          ensureProfileLoaded();
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[AuthService] Supabase not yet initialized: $e');
    }
  }

  /// Loads (or returns cached) the signed-in student's profile.
  /// Starts a real-time subscription to keep it live-synced.
  Future<StudentProfile?> ensureProfileLoaded() async {
    if (_studentProfile != null) return _studentProfile;
    final uid = _user?.id;
    if (uid == null) return null;

    try {
      final profile = await _db.fetchStudentProfile(uid);
      if (profile != null) {
        _studentProfile = profile;
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
  /// Maps 12-digit LRN to Supabase Auth email: {LRN}@mathalino.app
  /// Fetches StudentProfile from Supabase normalized tables.
  /// Verifies role == 'student'.
  /// Returns StudentProfile or throws custom AuthException.
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

      // 2. Map LRN to Supabase Auth email: primary is {LRN}@mathalino.app
      final primaryEmail = '$cleanLrn@mathalino.app';
      AuthResponse response;

      try {
        response = await _supabase.auth.signInWithPassword(
          email: primaryEmail,
          password: password,
        );
      } on supa.AuthException catch (primaryErr) {
        // Fallback 1: try readquest format
        try {
          final fallbackEmail1 = '$cleanLrn@student.readquest.edu';
          response = await _supabase.auth.signInWithPassword(
            email: fallbackEmail1,
            password: password,
          );
        } on supa.AuthException catch (_) {
          // Fallback 2: try legacy prefix format
          try {
            final fallbackEmail2 = 'lrn_$cleanLrn@mathalino.app';
            response = await _supabase.auth.signInWithPassword(
              email: fallbackEmail2,
              password: password,
            );
          } on supa.AuthException catch (_) {
            throw _handleSupabaseAuthException(primaryErr);
          }
        }
      }

      final authenticatedUser = response.user;
      if (authenticatedUser == null) {
        throw AuthException('Failed to authenticate student credentials.');
      }

      _user = authenticatedUser;

      // 3. Fetch student profile from `users` table
      final profile = await _db.fetchStudentProfile(authenticatedUser.id);

      if (profile == null) {
        await _supabase.auth.signOut();
        _user = null;
        _studentProfile = null;
        throw AuthException(
          'Student account profile not found in database. Please contact your teacher.',
          code: 'PROFILE_NOT_FOUND',
        );
      }

      // 4. Security check: Verify role == 'student'
      if (profile.role != 'student') {
        await _supabase.auth.signOut();
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

      // Keep the profile live-synced while the student is authenticated.
      subscribeToProfile(authenticatedUser.id);

      return profile;
    } on supa.AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      rethrow;
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

  /// Backward-compatible login method returning `Future<bool>` for UI compatibility.
  Future<bool> loginWithLRN(String lrn, String password) async {
    try {
      await signInStudent(lrn, password);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts a real-time Supabase subscription on the `users` table row
  /// so the profile stays synchronized with the Teacher Dashboard.
  void subscribeToProfile(String uid) {
    _profileSubscription?.cancel();
    try {
      _profileSubscription = _db.subscribeStudentProfile(uid).listen(
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

  /// Reset password using LRN — sends a reset email via Supabase Auth.
  Future<bool> resetPassword(String lrn) async {
    _setLoading(true);
    _clearError();

    try {
      final cleanLrn = lrn.trim();
      if (cleanLrn.length != 12 || !RegExp(r'^[0-9]{12}$').hasMatch(cleanLrn)) {
        throw AuthException('Please enter a valid 12-digit LRN');
      }

      final email = '$cleanLrn@mathalino.app';
      try {
        await _supabase.auth.resetPasswordForEmail(email);
      } on supa.AuthException catch (_) {
        // Try fallback formats if primary not found
        try {
          final fallbackEmail1 = '$cleanLrn@student.readquest.edu';
          await _supabase.auth.resetPasswordForEmail(fallbackEmail1);
        } catch (_) {
          final fallbackEmail2 = 'lrn_$cleanLrn@mathalino.app';
          await _supabase.auth.resetPasswordForEmail(fallbackEmail2);
        }
      }

      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      rethrow;
    } catch (e) {
      final authEx = AuthException('Password reset failed: ${e.toString()}');
      _setError(authEx.message);
      _setLoading(false);
      throw authEx;
    }
  }

  /// Fetch user profile data map for UI dashboard display.
  Future<Map<String, dynamic>?> getUserData() async {
    if (_user == null) return null;
    try {
      if (_studentProfile != null) return _studentProfile!.toMap();
      final profile = await _db.fetchStudentProfile(_user!.id);
      if (profile != null) {
        _studentProfile = profile;
        return _studentProfile!.toMap();
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] getUserData error: $e');
      return null;
    }
  }

  /// Logout current user.
  Future<void> logout() async {
    try {
      stopProfileSubscription();
      await _supabase.auth.signOut();
      _user = null;
      _studentProfile = null;
      notifyListeners();
    } catch (e) {
      final authEx = AuthException('Logout failed: ${e.toString()}');
      _setError(authEx.message);
      throw authEx;
    }
  }

  /// User-friendly Supabase AuthException parser.
  AuthException _handleSupabaseAuthException(supa.AuthException e) {
    String message;
    final msg = e.message.toLowerCase();

    if (msg.contains('invalid login') || msg.contains('invalid credentials') ||
        msg.contains('wrong password') || msg.contains('invalid password')) {
      message = 'Incorrect password. Please try again.';
    } else if (msg.contains('user not found') || msg.contains('no user')) {
      message = 'No student account found with this LRN. Please check with your teacher.';
    } else if (msg.contains('email not confirmed')) {
      message = 'Account not verified. Please contact your teacher.';
    } else if (msg.contains('too many requests') || msg.contains('rate limit')) {
      message = 'Too many login attempts. Please try again later.';
    } else if (msg.contains('network') || msg.contains('connection')) {
      message = 'Network error. Please check your internet connection.';
    } else if (msg.contains('disabled') || msg.contains('banned')) {
      message = 'This account has been disabled. Please contact your teacher.';
    } else {
      message = e.message.isNotEmpty
          ? e.message
          : 'Authentication failed. Please try again.';
    }
    return AuthException(message, code: e.statusCode?.toString(), originalError: e);
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
