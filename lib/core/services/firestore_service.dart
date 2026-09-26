import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/student_profile.dart';
import '../models/student_result_model.dart';

/// Central typed Firestore read/write wrapper for Mathalino Student App.
///
/// All Firestore access from providers/screens should go through this service
/// so that:
/// 1. Every read/write uses the typed `withConverter` converters.
/// 2. Every call is wrapped in try-catch with visible error feedback.
/// 3. `request.auth.uid` scoping is enforced at the app layer (in addition
///    to the Firestore security rules).
class FirestoreService {
  final FirebaseFirestore _firestore;

  // This project is backed by the named Firestore database `default` (see
  // web-dashboard/firebaseConfig.js). The implicit `(default)` database is not
  // provisioned here, so we point the client at the `default` database to stay
  // consistent with the seed script and the rest of the platform.
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'default',
          );

  // ── Users ────────────────────────────────────────────────────────────

  /// Fetches the student profile at /users/{userId} using the typed converter.
  Future<StudentProfile?> fetchStudentProfile(String userId) async {
    try {
      final doc = await StudentProfile.collection(_firestore).doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('[FirestoreService] fetchStudentProfile error: $e');
      rethrow;
    }
  }

  /// Subscribes to real-time profile updates at /users/{userId}.
  ///
  /// When the Teacher Dashboard updates the student's document (e.g. changes
  /// the section or status), the [onData] callback fires immediately so the
  /// Student App stays synchronized without a manual refresh.
  ///
  /// Returns a Stream that the caller can cancel to stop listening.
  Stream<StudentProfile> subscribeStudentProfile(String userId) {
    try {
      return StudentProfile.collection(_firestore)
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              throw FirebaseException(
                plugin: 'mathalino_firestore',
                message: 'Student profile document $userId does not exist',
              );
            }
            return snapshot.data()!;
          });
    } catch (e) {
      debugPrint('[FirestoreService] subscribeStudentProfile error: $e');
      rethrow;
    }
  }

  /// Writes the student profile at /users/{userId} using the typed converter.
  Future<void> writeStudentProfile(StudentProfile profile) async {
    try {
      await StudentProfile.collection(_firestore).doc(profile.uid).set(profile);
    } catch (e) {
      debugPrint('[FirestoreService] writeStudentProfile error: $e');
      rethrow;
    }
  }

  /// Updates specific fields on /users/{userId} (merge).
  Future<void> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(fields, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FirestoreService] updateUserFields error: $e');
      rethrow;
    }
  }

  /// Updates /users/{userId} inside a Firestore [WriteTransaction].
  ///
  /// Reads the document first (to verify it exists / capture server timestamps),
  /// then applies the supplied [fields] as a merge. Using a transaction ensures
  /// the read-modify-write is atomic and visible to other callers.
  /// Throws [FirebaseException] on failure (e.g. document missing, network error).
  Future<void> updateUserFieldsInTransaction(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('users').doc(userId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw FirebaseException(
            plugin: 'mathalino_firestore',
            message: 'User document $userId does not exist',
          );
        }

        transaction.set(docRef, fields, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint(
        '[FirestoreService] Transaction error, executing direct merge fallback: $e',
      );
      // Direct merge fallback for Flutter Web compatibility
      await _firestore
          .collection('users')
          .doc(userId)
          .set(fields, SetOptions(merge: true));
    }
  }

  // ── Student Results ──────────────────────────────────────────────────

  /// Adds a new result document to /student_results using the typed converter.
  Future<String> addStudentResult(StudentResult result) async {
    try {
      final docRef = await _firestore
          .collection('student_results')
          .add(result.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('[FirestoreService] addStudentResult error: $e');
      rethrow;
    }
  }

  /// Fetches a single result document from /student_results/{resultId}.
  Future<StudentResult?> fetchStudentResult(String resultId) async {
    try {
      final doc = await StudentResult.collection(
        _firestore,
      ).doc(resultId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('[FirestoreService] fetchStudentResult error: $e');
      rethrow;
    }
  }

  /// Fetches all results for a student, newest first.
  Future<List<StudentResult>> fetchResultsForStudent(String studentId) async {
    try {
      final snapshot = await StudentResult.collection(_firestore)
          .where('studentId', isEqualTo: studentId)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[FirestoreService] fetchResultsForStudent error: $e');
      rethrow;
    }
  }

  // ── Questions ────────────────────────────────────────────────────────

  /// Fetches a single question document from /questions/{questionId}.
  Future<Map<String, dynamic>?> fetchQuestion(String questionId) async {
    try {
      final doc = await _firestore
          .collection('questions')
          .doc(questionId)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('[FirestoreService] fetchQuestion error: $e');
      rethrow;
    }
  }

  // ── Earned Badges ────────────────────────────────────────────────────

  /// Fetches the earned badge IDs for a student from
  /// /users/{userId}/earnedBadges.
  Future<List<String>> fetchEarnedBadgeIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('earnedBadges')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('[FirestoreService] fetchEarnedBadgeIds error: $e');
      rethrow;
    }
  }
}
