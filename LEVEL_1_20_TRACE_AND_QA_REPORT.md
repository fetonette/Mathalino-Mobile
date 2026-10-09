# Mathalino Level 1–20 Question System Trace & QA Report

---

## A. Current Status
**Level 1–20 Status:** **`WORKING`**  
All 100 visual, child-friendly questions extracted from the docx source file are inserted, mapped, verified in Supabase PostgreSQL, loaded via `QuestionBankService`, deserialized with visual asset metadata through `QuestionModel`, presented in `BeginnerZoneGameplayScreen`, validated against Fisher-Yates shuffled choices, and properly persisted upon level completion.

---

## B. Question Source
The authoritative questions for Levels 1–20 originate from:
1. **Primary Source Document:**  
   `files/Mathalino_Levels_1-20_100_Visual_ChildFriendly (1).docx`  
   - 100 questions covering Grade 1–3 math competencies.
   - 54 unique visual figures/diagrams extracted into `assets/data/questions/level_images/`.
2. **Authoritative Runtime Source:**  
   Supabase PostgreSQL table `public.question_bank` (`db.vaggqgmluporwzxhtnax.supabase.co:5432`).
3. **Bundled Asset & Offline-Fallback Source:**  
   `assets/data/questions/question_bank_level1-20.json`  
   - Composite priority: Supabase `public.question_bank` is authoritative when network/database is available; local assets ensure zero downtime when offline.

---

## C. Supabase Database Verification
The Supabase database table `public.question_bank` was verified directly against the production instance:

### 1. Schema & Structure
- **Table:** `public.question_bank`
- **Primary Key:** `question_id` (Unique index `question_bank_pkey`)
- **Indexed Columns:** `question_id`, `level` (`idx_question_bank_level`)
- **Columns Added/Populated:**
  - `question_id`: Text (e.g., `L1-Q1` … `L20-Q5`)
  - `level`: Integer (1 to 20)
  - `domain`: Text (e.g., `Counting`, `Number symbols`, `Comparison`, `Fractions`, `Money`)
  - `grade_tag`: Text (`Grade 1-3`)
  - `difficulty`: Text (`Preparation`, `Hard`, `Super Hardcore`)
  - `question_text`: Text
  - `choices`: JSONB (Keys: `"A"`, `"B"`, `"C"`, `"D"`)
  - `correct_answer`: Text (`A`, `B`, `C`, or `D`)
  - `challenge_group`: Integer (5, 10, 15, or 20)
  - `attempt_number`: Integer (default 0)
  - `image_path`: Text (e.g., `assets/data/questions/level_images/image1.png`)
  - `activity`: Text (e.g., `Visual Count`, `Visual Match`, `Visual Compare`, `Drag & Drop`)
  - `game_ui`: Text (UI presentation instructions)
  - `raw_data`: JSONB (Mirrored metadata for backward compatibility)
  - `id`: Text (equals `question_id`)

### 2. Available Question Counts Per Level in Supabase
| Level | Question Count | With Image Asset | Difficulty | Challenge Group |
|---|---|---|---|---|
| **Level 1** | 5 | 4 | Preparation | 5 |
| **Level 2** | 5 | 4 | Preparation | 5 |
| **Level 3** | 5 | 4 | Preparation | 5 |
| **Level 4** | 5 | 2 | Preparation | 5 |
| **Level 5** | 5 | 3 | Hard (Gate) | 5 |
| **Level 6** | 5 | 3 | Preparation | 10 |
| **Level 7** | 5 | 3 | Preparation | 10 |
| **Level 8** | 5 | 2 | Preparation | 10 |
| **Level 9** | 5 | 2 | Preparation | 10 |
| **Level 10** | 5 | 4 | Hard (Gate) | 10 |
| **Level 11** | 5 | 3 | Preparation | 15 |
| **Level 12** | 5 | 2 | Preparation | 15 |
| **Level 13** | 5 | 3 | Preparation | 15 |
| **Level 14** | 5 | 2 | Preparation | 15 |
| **Level 15** | 5 | 4 | Hard (Gate) | 15 |
| **Level 16** | 5 | 2 | Preparation | 20 |
| **Level 17** | 5 | 4 | Preparation | 20 |
| **Level 18** | 5 | 2 | Preparation | 20 |
| **Level 19** | 5 | 4 | Preparation | 20 |
| **Level 20** | 5 | 5 | Super Hardcore (Boss) | 20 |
| **Total (L1–20)** | **100** | **68** | — | — |

*All 54 referenced illustration files exist locally in `assets/data/questions/level_images/` and are registered in `pubspec.yaml`.*

---

## D. Runtime Flow Trace
The end-to-end execution flow executes without any architectural breaks:

```
Source Docx
    ↓
Parsed JSON (`all_100_structured.json` / `question_bank_level1-20.json`)
    ↓
Supabase Database (`public.question_bank`, 100 rows for Levels 1–20)
    ↓
`QuestionBankService.fetchQuestionBank()` (Authoritative Supabase fetch + asset compositing)
    ↓
`QuestionModel.fromMap()` (Maps question_text, choices, answer key, and visual metadata image_path, activity, game_ui)
    ↓
`GameLogicService.selectQuestion()` (Picks eligible question via Fisher-Yates shuffle, respecting used history & gate rules)
    ↓
`QuestionModel.withShuffledChoices()` (Fisher-Yates shuffles choices for student presentation while preserving the answer key)
    ↓
`LevelProvider.startLevel()` (Sets phase to PlayerPhase.playing, loads current question)
    ↓
`BeginnerZoneGameplayScreen` (Renders question card, header, illustration if present, and choices A/B/C/D)
    ↓
Student Selection (`_submit(choiceKey)`)
    ↓
`LevelProvider.submitAnswer()` → `QuestionModel.isCorrect()`
    ↓ (Evaluation: correct vs incorrect)
- If Correct (Preparation Level):
    Shows Answer Feedback ("Correct!"), updates session score, advances to `PlayerPhase.levelComplete`.
- If Incorrect (Preparation Level):
    Shows Feedback ("Incorrect"), allows in-place retry without breaking progress.
- If Incorrect (Challenge Gate Level 5, 10, 15, 20):
    Transitions to `PlayerPhase.remediationPrep` to remediate lower levels [L-4 … L-1].
    ↓
Level Complete Screen
    ↓ Student taps "Continue"
`LevelProgressProvider.completeLevel()`
    ↓
Supabase Updates:
    - `public.users` (`current_level` updated to next level, `level_status_map` updated)
    - `public.student_results` (Session results recorded with score, accuracy, zone)
```

---

## E. Root Causes Identified

### 1. Database Discrepancy & Overwrite Loop
- **Problem:** When opening Levels 1–20, the app continued displaying old legacy questions from September 27 (e.g., `L1-Q1`: *"Which number is greater: 4 or 7?"*) without images.
- **Evidence:** `SELECT question_text FROM public.question_bank WHERE question_id = 'L1-Q1'` returned the September 27 record.
- **Root Cause:** The SQL migration script `update_question_bank_levels_1_20.sql` was generated on disk but had **never been executed** against the Supabase database. Because `QuestionBankService.fetchQuestionBank()` was written to composite Supabase rows *over* the local bundled assets (`byId[q.questionId] = q`), the old rows in Supabase completely overwrote the new questions in `question_bank_level1-20.json`.
- **Impact:** Any changes made to the local JSON were erased in memory at runtime as soon as the app connected to Supabase.

### 2. Missing Visual Metadata Deserialization in `QuestionModel.fromMap`
- **Problem:** Even after preparing question data with illustrations, image illustrations failed to render in `BeginnerZoneGameplayScreen`.
- **Evidence:** `QuestionModel.fromMap` only read top-level keys: `map['image_path']`, `map['activity']`, and `map['game_ui']`. In the initial SQL script, these fields were placed inside the `raw_data` JSONB column.
- **Root Cause:** When `fromMap` parsed a Supabase row that stored visual properties in `raw_data`, `imagePath` evaluated to `null`.
- **Impact:** `question.imagePath != null` was false, suppressing illustrations on visual questions.

### 3. Defensive Type Casting Gap
- **Problem:** Supabase and JSON deserializers can supply `level`, `challenge_group`, or `attempt_number` as Strings, Integers, or null.
- **Evidence:** Direct casts like `map['level'] as int` throw runtime type errors when data arrives as numeric strings or doubles.
- **Root Cause:** Lack of defensive parsing in `QuestionModel.fromMap`.
- **Impact:** Potential runtime crash on network deserialization.

---

## F. Fixes Implemented

1. **Supabase Database Migration Executed:**
   - Added first-class columns `image_path text`, `activity text`, and `game_ui text` to `public.question_bank`.
   - Executed all 100 upsert statements for Levels 1–20 from `files/update_question_bank_levels_1_20.sql` onto Supabase PostgreSQL.
   - Populated both top-level columns and nested `raw_data` JSONB for complete backward and forward compatibility.
   - Verified that all 100 rows now hold the new docx content and image paths.

2. **Upgraded `QuestionModel.fromMap`:**
   - Updated `QuestionModel.fromMap` in `lib/core/models/question_model.dart` to check both top-level map keys (`image_path`, `activity`, `game_ui`) and nested `raw_data` map keys (`rawData['image_path']`, etc.).
   - Added defensive parsing for `level`, `challenge_group`, and `attempt_number` using `int.tryParse` fallbacks.

3. **Validated Runtime Architecture:**
   - Verified that `QuestionBankService` successfully fetches Supabase questions and merges any missing levels from bundled assets without data corruption.
   - Verified that answer validation using `QuestionModel.isCorrect` correctly matches display keys, stable choice keys, and text values after Fisher-Yates shuffling.

---

## G. QA Results for Modified Levels

### Level 1 (Preparation)
- **Question L1-Q1:** "How many apples do you see?"
- **Choices:** A: 3, B: 4, C: 5, D: 6 | **Correct:** B (4)
- **Visual Asset:** `assets/data/questions/level_images/image1.png`
- **Result:** PASSED. Image renders, choice B validated as correct, feedback dialog opens, advances cleanly.

### Level 5 (Hard Challenge Gate)
- **Question L5-Q1:** "CHALLENGE: What is 7 + 8?"
- **Choices:** A: 13, B: 14, C: 15, D: 16 | **Correct:** C (15)
- **Result:** PASSED. Hard badge rendered, wrong answer triggers remediation preparation in range [1..4], correct answer completes level.

### Level 10 (Hard Challenge Gate)
- **Question L10-Q1:** "CHALLENGE: 6 boxes have 4 pencils each. How many pencils?"
- **Choices:** A: 20, B: 22, C: 24, D: 26 | **Correct:** C (24)
- **Visual Asset:** `assets/data/questions/level_images/image25.png`
- **Result:** PASSED. Image renders, remediation preparation works for range [6..9], correct answer completes level.

### Level 15 (Hard Challenge Gate)
- **Question L15-Q1:** "CHALLENGE: 8 boxes have 6 pencils each. 5 are used. How many are left?"
- **Choices:** A: 43, B: 48, C: 53, D: 58 | **Correct:** A (43)
- **Visual Asset:** `assets/data/questions/level_images/image37.png`
- **Result:** PASSED. Multi-step visual challenge correctly identifies choice A.

### Level 20 (Super Hardcore Boss)
- **Question L20-Q1:** "SUPER CHALLENGE: You have 500 points. Spend 150. How many remain?"
- **Choices:** A: 300, B: 350, C: 400, D: 450 | **Correct:** B (350)
- **Visual Asset:** `assets/data/questions/level_images/image50.png`
- **Result:** PASSED. Super Hardcore badge renders, Level 20 completion saves to Supabase and unlocks Zone 2.

---

## H. Regression Testing
1. **Levels 21–60 (Intermediate & Advanced Zones):**
   - Verified that Intermediate Zone levels (21–40) continue to operate with straight-line progression (no remediation gates, Moderate badge).
   - Verified that Advanced Zone levels (41–60) continue to restore challenge gates at 45/50/55/60 and complete with `adventureComplete` at Level 60.
   - All tests in `test/question_bank_service_test.dart` and `test/level_provider_test.dart` PASSED (31/31).
2. **Diagnostic Assessment:**
   - Tested 20-item sequential flow and multi-account state reset.
   - All tests in `test/diagnostic_flow_test.dart` and `test/diagnostic_test.dart` PASSED (56/56).
3. **Static Analysis:**
   - Ran `flutter analyze` across the entire codebase.
   - **Result:** `No issues found!` (0 errors, 0 warnings).
