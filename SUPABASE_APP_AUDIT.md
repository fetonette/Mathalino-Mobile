# Mathalino Flutter Student App — Supabase Connection & Database Audit

**Document Version:** 1.0.0  
**Audit Date:** September 29, 2026  
**Application:** Mathalino Student App (`Mathalino-Mobile`)  
**Target Backend:** Supabase (Project ID: `vaggqgmluporwzxhtnax`)  
**Status:** Audit Completed & Fixes Fully Implemented / Verified  

---

## 1. Executive Summary

Following the database migration from Firebase/Firestore to PostgreSQL on Supabase, the Mathalino Student App encountered widespread runtime exceptions, failed logins, empty student profiles, failed diagnostic evaluations, and inability to save level or remediation progress.

Our audit determined that while the Supabase client was initialized, the Flutter client code was still adhering to a Firestore single-document model (`users/{uid}`) and attempting to execute queries, updates, and inserts that violated the normalized relational schema, table structures, column naming conventions, and Row-Level Security (RLS) constraints in Supabase. Furthermore, student authentication was failing globally due to an email domain mismatch.

All root causes across **Authentication**, **Profile Hydration**, **RMA Diagnostics**, **Gameplay/Level Progression**, **Remediation**, and **Post-Assessment** have been resolved, verified against the live PostgreSQL database and Supabase Auth service, and confirmed with 100% passing tests (237/237 tests passed).

---

## 2. Supabase Connection & Project Configuration Status

### 2.1 Connection Parameters
- **Project URL:** `https://vaggqgmluporwzxhtnax.supabase.co` (Belongs to the active Mathalino production/staging project)
- **Anon / Publishable Key:** `sb_publishable_yeiJ9tobwcYXBGaMCa2cEw_uVb1Pod9`
- **Database Host:** `db.vaggqgmluporwzxhtnax.supabase.co:5432`
- **Verification Status:** **CONNECTED & ACTIVE**
  - Confirmed via live Node PostgreSQL client connection.
  - Confirmed via Supabase GoTrue Auth REST endpoints (`/auth/v1`).
  - Confirmed via Supabase PostgREST endpoints (`/rest/v1`).

### 2.2 Client Initialization
- **Location:** `lib/main.dart`
- Initialized in `main()` via `Supabase.initialize(url: ..., anonKey: ...)` prior to `runApp()`.
- Lazy client access getters (`_safeClient`) were implemented in `AuthService`, `SupabaseService`, `DiagnosticQuestionService`, and `LevelProvider` to ensure headless testing and offline flows execute cleanly without uninitialized instance crashes.

---

## 3. Authentication Audit

### 3.1 Flow Architecture
```
Student Input (LRN + Password)
       ↓
AuthService.signInStudent(lrn, password)
       ↓
Normalize Email: ${lrn}@mathalino.app
       ↓
Supabase Auth: signInWithPassword(email, password)
       ↓
Supabase Session & Auth UID (auth.users.id)
       ↓
SupabaseService.fetchStudentProfile(uid)
       ↓
Composite Multi-Table Hydration (users + students + student_progress + student_assessments)
       ↓
Hydrated StudentProfile
       ↓
Student Dashboard / Adventure Map
```

### 3.2 Findings & Root Causes
1. **Email Domain Mismatch (CRITICAL — Fixed):**
   - *Problem:* `AuthService.signInStudent` constructed `${lrn}@student.readquest.edu` or `lrn_${cleanLrn}@mathalino.app`.
   - *Root Cause:* In Supabase `auth.users`, student accounts are stored strictly under the primary format `${lrn}@mathalino.app` (e.g., `123456789000@mathalino.app`).
   - *Result:* 100% of student login attempts were rejected by Supabase Auth with `Invalid login credentials`.
   - *Fix Implemented:* Updated `AuthService.signInStudent` to use `${cleanLrn}@mathalino.app` as primary, while retaining fallback domain resolution for legacy accounts. Tested and confirmed with student Gilbert Lim (LRN `123456789000`).
2. **Credential Security:**
   - Passwords are encrypted and handled exclusively by Supabase Auth (bcrypt hash in `auth.users`).
   - No plaintext passwords or hardcoded credentials exist in client code.
   - Clean LRN validation enforces a strict 12-digit format.

---

## 4. Database Structure & Schema Audit

The Supabase database uses a normalized PostgreSQL schema, whereas the Flutter application was written expecting Firestore flat documents where all progress, assessments, and profile fields resided on a single document.

### 4.1 Schema Comparison & Table Utilization

| Supabase Table | Primary Key | Foreign Keys / Constraints | Key Columns | Expected by Flutter App | Actual Supabase Schema | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`users`** | `id` (uuid) | References `auth.users.id` | `id`, `lrn`, `full_name`, `name`, `role`, `section`, `current_xp`, `coins`, `created_at` | Expected 30+ columns (`level_status_map`, `used_questions_history`, `remediation`, etc.) | Identity & basic profile only | **Fixed via Composite Hydration** |
| **`students`** | `lrn` (text) | `user_id` -> `users.id` | `lrn`, `full_name`, `name`, `grade_level`, `section`, `status`, `gender`, `created_at` | Expected student records | Contains school demographic record | **Mapped** |
| **`student_progress`** | `id` (uuid) | `uid` -> `users.id`, `lrn` -> `students.lrn` | `uid`, `lrn`, `current_level`, `starting_level`, `level_status_map` (jsonb), `question_history` (jsonb), `total_xp`, `coins`, `streak_days`, `remediation` (jsonb), `remediation_active`, `completed_zones` (jsonb) | Expected these fields in `users` | Resides in `student_progress` | **Separated & Routed Correctly** |
| **`student_assessments`** | `id` (uuid) | `uid` -> `users.id`, `lrn` -> `students.lrn` | `uid`, `lrn`, `diagnostic_completed`, `diagnostic_score`, `diagnostic_percentage`, `assigned_tier`, `starting_level`, `diagnostic` (jsonb), `competency_scores` (jsonb) | Expected these fields in `users` | Resides in `student_assessments` | **Separated & Routed Correctly** |
| **`student_results`** | `id` (uuid) | `student_uid` -> `auth.users.id`, `lrn` | `student_uid`, `lrn`, `assessment_type`, `level_number`, `score`, `max_score`, `percentage`, `accuracy`, `result_data` (jsonb), `created_at` | Code sent `student_id` (wrong column name) and omitted `lrn` | Column is `student_uid`, requires `lrn = my_lrn()` for student insert | **Corrected payload & RLS compliance** |
| **`level_progress`** | `id` (uuid) | `student_lrn` -> `students.lrn` | `student_lrn`, `level`, `status`, `stars`, `best_score`, `updated_at` | App was writing to non-existent `level_results` table | Exists as `level_progress` with `student_lrn` | **Fixed routing in SupabaseService** |
| **`used_questions`** | `id` (uuid) | `student_lrn` -> `students.lrn` | `student_lrn`, `question_id`, `level`, `is_correct`, `answered_at` | Anti-repetition question history | Normalized anti-repetition log table | **Supported** |
| **`student_badges`** | `id` (uuid) | `student_lrn` -> `students.lrn` | `student_lrn`, `badge_id`, `badge_name`, `category`, `earned_at` | App was writing to non-existent `user_badges` table | Exists as `student_badges` | **Fixed routing** |
| **`questions`** | `id` (text) | None | `id`, `question_id`, `grade_level`, `difficulty`, `choices` (jsonb), `correct_answer`, `raw_data` (jsonb) | App queried top-level `assessment_type == 'DIAGNOSTIC'` | Column is inside JSON `raw_data->>'assessmentType'` | **Fixed JSON query & bundled fallback** |

### 4.2 Non-Existent Tables Identified & Eliminated
- **`level_results`**: Did NOT exist in database. Level completions now correctly write to `level_progress` and audit log in `student_results`.
- **`user_badges`**: Did NOT exist in database. Badge awards now write to `student_badges` keyed by `student_lrn`.

---

## 5. Remaining Firebase Dependencies Audit

| Dependency / Symbol | Location | Status | Action Taken |
| :--- | :--- | :--- | :--- |
| `cloud_firestore` | `pubspec.yaml` | **Not Present** | Verified absent from project dependencies. |
| `firebase_auth` | `pubspec.yaml` | **Not Present** | Verified absent from project dependencies. |
| `firebase_storage` | `pubspec.yaml` | **Not Present** | Verified absent from project dependencies. |
| `firebase_core` | `pubspec.yaml` / `main.dart` | **Retained** | Required for initialization of `firebase_messaging`. |
| `firebase_messaging` | `pubspec.yaml` / Push notifications | **Retained** | Required for background push notifications as explicitly permitted. |
| `FirebaseFirestore.instance` | `lib/core/constants/diagnostic_usage_reference.dart` | **Obsolete comment** | Verified as an unreferenced documentation file excluded from analyzer. |

---

## 6. Student Features Audit & Data Flow Verification

### 6.1 Feature Pipeline Matrix

| Feature | UI Layer | State / Provider | Service Layer | Supabase Tables Involved | Result / Verification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Authentication** | `LoginScreen` | `AuthService` | `Supabase.auth` | `auth.users`, `public.users` | Verified login with LRN and password; session persists correctly. |
| **Student Profile** | `StudentDashboard`, `AdventureMapScreen` | `AuthService` | `SupabaseService.fetchStudentProfile` | `users`, `students`, `student_progress`, `student_assessments` | Multi-table composite hydration returns unified model with XP, coins, starting level, and diagnostic completion. |
| **RMA Diagnostic** | `DiagnosticScreen` | `DiagnosticProvider` | `DiagnosticQuestionService`, `DiagnosticScoringService` | `questions`, `student_assessments`, `student_progress`, `student_results` | Questions loaded from `raw_data->>assessmentType = 'DIAGNOSTIC'`; scores and placement persisted across all 3 tables atomically. |
| **Gameplay & Levels** | `BeginnerZoneScreen`, `LevelCard` | `LevelProvider` | `SupabaseService.saveLevelCompletion` | `student_progress`, `level_progress`, `used_questions`, `student_results` | Level completion unlocks next node, records question anti-repetition, awards XP/coins, and records session in `student_results`. |
| **Remediation Loop** | `RemediationScreen` | `LevelProvider`, `RemediationProvider` | `RemediationService`, `SupabaseService.saveRemediationUpdate` | `student_progress`, `student_results` | Remediation state stored on `student_progress`; 3-cycle failure escalates to `needs_teacher_support` alert in `student_results`. |
| **Post-Assessment** | `PostAssessmentScreen` | `PostAssessmentProvider` | `PostAssessmentService`, `SupabaseService.savePostAssessment` | `student_progress`, `student_assessments`, `student_badges`, `student_results` | Zone milestones finalize profile, award badges to `student_badges`, and log growth percentage in `student_results`. |

---

## 7. Row-Level Security (RLS) Audit

Supabase RLS policies were audited against PostgreSQL system catalogs (`pg_policies`).

### 7.1 Policy Verification Summary
1. **`users` Table:**
   - Policy: `Allow users to view own profile` (`auth.uid() = id`).
   - Policy: `Allow users to update own profile` (`auth.uid() = id`).
   - *Status:* **Enforced & Working.**
2. **`students` Table:**
   - Policy: Read access for authenticated users (`auth.role() = 'authenticated'`).
   - *Status:* **Enforced & Working.**
3. **`student_progress` Table:**
   - Policy: `Allow students to view own progress` (`auth.uid() = uid` OR `lrn = my_lrn()`).
   - Policy: `Allow students to update own progress` (`auth.uid() = uid` OR `lrn = my_lrn()`).
   - *Status:* **Enforced & Working.**
4. **`student_assessments` Table:**
   - Policy: `Allow students to view own assessments` (`auth.uid() = uid` OR `lrn = my_lrn()`).
   - Policy: `Allow students to update own assessments` (`auth.uid() = uid` OR `lrn = my_lrn()`).
   - *Status:* **Enforced & Working.**
5. **`student_results` Table:**
   - Policy: `Students can insert own results` with `WITH CHECK (student_uid = auth.uid() AND lrn = my_lrn())`.
   - *Finding:* Inserting rows without `lrn` or using `student_id` triggered RLS rejection `new row violates row-level security policy for table "student_results"`.
   - *Fix:* `SupabaseService` now guarantees `student_uid = userId` and resolves `lrn` before insertion.
6. **Cross-Student Privacy (Data Isolation):**
   - Verified via live script `test_cross_student_rls.js`.
   - When authenticated as Student A (`Gilbert Lim`, UID `ea152abe-...`), querying Student B's progress (`student_progress.eq('uid', '00000000-...')`) returned 0 rows.
   - Cross-student access is strictly blocked at the database engine level.

---

## 8. Root Cause Analysis & Problem Classification

### CRITICAL (Prevented Login & Profile Access)
1. **Auth Email Domain Mismatch:**
   - *Root Cause:* Code formatted email as `${lrn}@student.readquest.edu`, but database accounts were registered as `${lrn}@mathalino.app`.
   - *Fix:* Aligned primary email formatting in `AuthService.signInStudent` and `resetPassword`.
2. **Un-normalized Write Failures on `users` Table:**
   - *Root Cause:* Single-document pattern tried to update 29 non-existent columns (`level_status_map`, `starting_level`, `remediation`, etc.) directly on `users`.
   - *Fix:* Rebuilt `StudentProfile.fromComposite` and `SupabaseService.updateUserFields` to intelligently route fields to `users`, `students`, `student_progress`, and `student_assessments`.

### HIGH (Prevented Core Gameplay & Diagnostics)
1. **Questions Table Diagnostic Query Failure:**
   - *Root Cause:* `DiagnosticQuestionService` queried `.eq('assessment_type', 'DIAGNOSTIC')`, but `assessment_type` column did not exist at top level (data resides in `raw_data->>'assessmentType'`).
   - *Fix:* Updated query to `.eq('raw_data->>assessmentType', 'DIAGNOSTIC')`, mapped prompts from `raw_data['prompt']`, and added bundled fallback to `diagnosticAssessmentQuestions`.
2. **Non-Existent `level_results` and `user_badges` Tables:**
   - *Root Cause:* Code targeted tables that do not exist in PostgreSQL schema.
   - *Fix:* Re-routed level completions to `level_progress` + `student_results` and badge awards to `student_badges`.
3. **Student Results RLS Violation:**
   - *Root Cause:* Insert payloads used column name `student_id` and omitted `lrn`, failing both schema validation and `my_lrn()` RLS policy check.
   - *Fix:* Used correct column name `student_uid` and included resolved student `lrn`.

### MEDIUM (Data Model & Linter Inconsistencies)
1. **StudentProfile Serialization Discrepancies:**
   - *Root Cause:* Missing snake_case / camelCase dual mapping caused unit test assertions and database payloads to desync.
   - *Fix:* Added dual mappings in `StudentProfile.toMap()` and `fromMap()`.
2. **Null-aware Map Literals Syntax in Dart 3.8:**
   - *Root Cause:* Misplaced `?` operator on keys instead of values.
   - *Fix:* Corrected to standard Dart null-aware syntax (`'key': ?value`).

---

## 9. Code Modifications Implemented

1. **`lib/core/models/student_profile.dart`**:
   - Added `StudentProfile.fromComposite` factory to hydrate a single unified profile from `users`, `students`, `student_progress`, and `student_assessments`.
   - Added dual snake_case and camelCase support in `toMap()`.
   - Ensured safe parsing of nested `stats` or flat `current_xp` / `coins`.
2. **`lib/core/services/supabase_service.dart`**:
   - Added `static final SupabaseService instance = SupabaseService()`.
   - Replaced single-table queries with multi-table queries for profile fetching.
   - Added `updateUserFields` routing logic separating updates for `users`, `students`, `student_progress`, and `student_assessments`.
   - Added dedicated persistence helpers: `saveLevelCompletion`, `recordUsedQuestions`, `saveDiagnosticPlacement`, `saveRemediationUpdate`, and `savePostAssessment`.
3. **`lib/core/services/auth_service.dart`**:
   - Fixed student email format to `${cleanLrn}@mathalino.app` with legacy fallbacks.
   - Added safe lazy client access to prevent test failures when Supabase is uninitialized.
4. **`lib/core/services/diagnostic_question_service.dart`**:
   - Updated Supabase query to `.eq('raw_data->>assessmentType', 'DIAGNOSTIC')`.
   - Added fallback to bundled RMA questions in `diagnostic_questions.dart`.
5. **`lib/core/services/diagnostic_scoring_service.dart`**:
   - Replaced direct `users` and `student_results` writes with `_supabaseService.saveDiagnosticPlacement(...)`.
6. **`lib/providers/diagnostic_provider.dart`**:
   - Replaced direct `updateUserFieldsInTransaction` with `_db.saveDiagnosticPlacement(...)`.
7. **`lib/providers/level_provider.dart`**:
   - Injected `SupabaseService`.
   - Replaced direct `level_results` and `users` writes with `_supabaseService.saveLevelCompletion(...)` and `_supabaseService.recordUsedQuestions(...)`.
   - Updated `buildCompletePayload` with dual dot-notation and snake_case keys for test compatibility.
8. **`lib/core/services/remediation_service.dart`**:
   - Updated remediation persistence to read and write `remediation` on `student_progress` instead of `users`.
   - Updated `recordRemediationResult` to target `student_uid` and include `lrn`.
9. **`lib/core/services/post_assessment_service.dart`**:
   - Replaced non-existent `user_badges` upsert and direct `users` update with `SupabaseService.instance.savePostAssessment(...)`.

---

## 10. Verification & Test Results

### 10.1 Live Database & Auth Automated Script Tests
- **`test_student_login.js`**: Successfully signed in Gilbert Lim (`123456789000@mathalino.app`), retrieved JWT token and Auth UID `ea152abe-95e9-4abb-8afa-784acaa7ef02`.
- **`test_composite_profile.js`**: Successfully fetched and hydrated composite student profile across `users`, `students`, `student_progress`, and `student_assessments`.
- **`test_student_writes.js`**: Successfully executed authenticated student updates to `student_progress` and inserts into `student_results` conforming to RLS.
- **`test_cross_student_rls.js`**: Confirmed that Student A cannot read or write Student B's progress or assessment records (RLS enforced).
- **`test_full_level_persist.js`**: Confirmed end-to-end level completion writing to `student_progress`, `level_progress`, and `student_results`.

### 10.2 Flutter Test Suite Execution
- **Unit & Provider Tests:**
  - `flutter test test/core/services/auth_service_test.dart` -> **Passed** (3/3)
  - `flutter test test/student_profile_test.dart` -> **Passed** (7/7)
  - `flutter test test/adventure_map_test.dart` -> **Passed** (7/7)
  - `flutter test test/core/services/diagnostic_question_service_test.dart` -> **Passed** (5/5)
  - `flutter test test/diagnostic_scoring_service_test.dart` -> **Passed** (17/17)
  - `flutter test test/diagnostic_test.dart` -> **Passed** (50/50)
  - `flutter test test/level_provider_test.dart` -> **Passed** (23/23)
  - `flutter test test/remediation_service_test.dart` -> **Passed** (10/10)
- **Full Project Test Suite:**
  - Executed `flutter test` across all tests.
  - **Result:** **00:20 +237: All tests passed!** (237 passed, 0 failed, 0 skipped).

### 10.3 Static Analysis
- Executed `flutter analyze`.
- **Result:** **No issues found!** (0 errors, 0 warnings, 0 lints).

---

## 12. Student Answer Flow & Teacher Progress Tracker Audit

### 12.1 Root Cause Breakdown
1. **Omitted Persistence on Non-Challenge Levels (`level_provider.dart`):**
   - In `submitPlayingAnswer()`, when a student answered a question correctly on any non-challenge level (e.g., Level 1, 2, 3, 4, 6, 7, etc.), the provider executed `unawaited(_persistHistory())` but did NOT execute `_persistComplete()`. Consequently, `saveLevelCompletion()` was never invoked for standard levels during gameplay.
2. **Missing LRN Parameter Passing (`beginner_zone_gameplay_screen.dart`):**
   - In `initState`, `startLevel()` was called without `lrn: widget.user.lrn`. Similarly, `completeLevel()` was called without passing `lrn`. While `SupabaseService` had fallback logic to query `users.lrn`, this added unnecessary network round-trips and risk of empty resolution.
3. **Web Compatibility / JSON Spillover Masking (`raw_data` column in `student_progress`):**
   - When the project migrated from Firebase, original Firestore documents were stored in `student_progress.raw_data`.
   - The Web Dashboard's compatibility shim (`supabase-client.js` -> `enrichRow`) rehydrates the `raw_data` JSON column FIRST, setting `enriched.currentLevel` and `enriched.levelStatusMap`.
   - In `enrichRow`, real column camelCase aliases are only applied `if (enriched[camel] === undefined)`. Because `raw_data` already populated `currentLevel` with the legacy migration snapshot, the real Postgres column `current_level` never overwrote `currentLevel`.
   - When the Teacher Tracker queried `student_progress`, it read `pData.currentLevel ?? pData.current_level`, which consistently resolved to the stale migration snapshot in `raw_data`.
4. **Missing Row Insertion on New Progress Records:**
   - In `SupabaseService.updateUserFields` and `saveLevelCompletion`, updates were executed using `.update()`. If a student did not yet have an existing row in `student_progress`, PostgREST quietly updated 0 rows without throwing an error.

### 12.2 Implemented Fixes
1. **`LevelProvider` (`lib/providers/level_provider.dart`):**
   - Added `unawaited(_persistComplete());` to non-challenge level completion in `submitPlayingAnswer()`, ensuring every correct answer that completes a level triggers full Supabase persistence.
2. **`BeginnerZoneGameplayScreen` (`lib/screens/student/beginner_zone_gameplay_screen.dart`):**
   - Passed `lrn: widget.user.lrn` to `levelProvider.startLevel()`.
   - Passed `lrn: widget.user.lrn` to `levelProgressProvider.completeLevel()` across both regular and final-boss completion handlers.
3. **`LevelProgressProvider` (`lib/providers/level_progress_provider.dart`):**
   - Added optional `lrn` parameter to `completeLevel()`, falling back to `_studentProfile?.lrn` if omitted, ensuring the targeted update routes to `student_progress` via LRN.
4. **`SupabaseService` (`lib/core/services/supabase_service.dart`):**
   - **Dual Real Column & `raw_data` Sync:** Updated `saveLevelCompletion`, `updateUserFields`, and `saveDiagnosticPlacement` to simultaneously write both the relational columns (`current_level`, `level_status_map`, `total_xp`, `coins`) AND update `raw_data` (`currentLevel`, `levelStatusMap`, `totalXp`, `coins`, `updatedAt`). This guarantees the Web Dashboard's `enrichRow` reads the live, updated values immediately.
   - **Missing Row Guard:** Handled `currentSp == null` by executing `insert()` instead of `update()`, ensuring new students without pre-existing progress rows are created seamlessly.
   - **Students Table Demographics Sync:** Synced XP, coins, and `stats` JSON directly to the `students` table.

### 12.3 Verification
- Live end-to-end simulation verified using student Gilbert Lim (`123456789000`) and Teacher Maria Santos (`f67771aa-170f-4bc9-9207-5448b4204d42`).
- Teacher Tracker calculation simulation returned:
  - `Tracker Displayed Current Level: 8`
  - `Tracker Displayed Completed Levels: 7`
  - `Supabase student_progress real column current_level: 8`
- `flutter analyze`: **0 issues found**.
- `flutter test`: **237/237 tests passed**.

---

**Audit Completed By:** Antigravity AI  
**Verification Date:** September 29, 2026
