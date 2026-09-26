# Mathalino — RMA Content → Flutter/Dart Integration Plan

This plan converts the RMA Grade 1–6 assessment materials (Teacher's Booklets,
Assessment/Learner's Booklets, Score Sheets, and the Grade 4–6 RMA test) plus the
existing `Mathalino_Rule_Based_Game_Logic` and `System_Architecture_and_Context`
documents into a Flutter/Dart-ready content pipeline. No pedagogical content,
scoring rules, or numbers have been changed — only re-expressed as structured data.

---

## 1. Analysis: What the source files actually contain

Across the RMA Grade 1–3 toolkits (Teacher's Booklet + Assessment/Learner's Booklet +
Score Sheet) and the RMA Grade 4–6 test, every item shares the same underlying shape:

| Concept in source PDFs/DOCX | Meaning |
|---|---|
| Grade level (1–6) | Content pool / difficulty tier |
| Task letter (Task A, B, C…) | A **competency group** — a named cluster of items testing related skills |
| Curriculum code (e.g. `NAG1Q1-LC4`, `MGG3Q1-LC6`) | The **competency ID** — maps to "strand" (Number & Algebra / Measurement & Geometry) |
| Item number / sub-letter (A1a, C3b, 30a, 37b) | The **question ID** within a task |
| Prompt text (+ optional image: number cards, clocks, shapes, graphs) | The **question stem** |
| Multiple choice options (A/B/C/D) OR blank to fill in OR oral response | The **question type** |
| Answer key (e.g. `A3. 3, 8, 9, 10, 12`, `C3b. 36`) | The **correct answer(s)**, sometimes with acceptable variants ("2 or 2 breads") |
| Scoring Guide ("1 for correct, 0 for incorrect") | **Points per item** (mostly 1 pt; RMA Grades 1–3 rarely deviate) |
| Time allotment (30 seconds, 40 seconds…) | Optional **time limit metadata** (for timed/oral RMA-style items; the 40-item Grade 4–6 written test doesn't use this) |
| Score Sheet task totals (e.g. "TASK A: 8 points") | **Max points per task**, used for RMA sub-scores — separate from the Mathalino 20-item diagnostic percentage |

Two important distinctions carried over from the Game Logic doc, preserved as-is:

1. **RMA ≠ Mathalino diagnostic.** The RMA toolkits are 20–40 item clinical/paper
   assessments. Mathalino's in-app diagnostic is a **20-item RMA-based/adapted**
   assessment. The data model keeps a `source` field (`"RMA_OFFICIAL"` vs
   `"MATHALINO_ADAPTED"`) so the app never claims to *be* the official RMA.
2. Some RMA tasks are **not natively app-answerable** (tracing line segments,
   physically manipulating popsicle sticks/counters, oral-only response, drawing a
   140° angle). These are flagged `interactionType` values like `trace`, `draw`,
   `manipulative`, `oral` and are excluded from the Mathalino digital item pool by
   default (`isDigitallyPlayable: false`) — a teacher/parent app could still render
   them for offline/paper use, but the student game engine skips them when
   selecting questions.

---

## 2. Recommended data structure (big picture)

```
Grade (1-6)
 └── Strand / Domain            e.g. "Number and Algebra", "Measurement and Geometry"
      └── Competency            e.g. NAG1Q1-LC4  "Count up to 100 ..."
           └── Task (source grouping, optional, for traceability to RMA booklet)
                └── Question(s)  — the atomic, answerable unit
```

* **Question** is the atomic unit the game engine selects, presents, and scores.
* **Grade + competency + difficulty** are the filters used by the Content Selection
  Algorithm described in section 4/6 of the architecture doc.
* **Storage**: ship the full question bank as **versioned JSON assets** bundled with
  the app (fast, offline-first, no read costs) and **mirror it in Firestore**
  (`/question_bank/...`) so content can be updated/expanded remotely without an app
  release — the repository layer merges both (see §5).
* **Answer keys stay server-authoritative in Firestore** even if questions are
  bundled locally, OR are included in the signed asset bundle but never sent to the
  client already-graded — validation always happens through `ScoringService`
  (client-side is fine for a game like this since it's non-adversarial; if anti-cheat
  matters later, move `validateAnswer` into a Cloud Function).

---

## 3. Dart models

See `lib/models/question_model.dart` and `lib/models/assessment_models.dart` for the
full, compilable definitions. Summary of the model graph:

```
QuestionModel
 ├── id, grade, strand, competencyCode, competencyDescription
 ├── taskLabel, taskSourceRef (e.g. "RMA_G1_TaskA_Item1")
 ├── prompt, promptImageAsset
 ├── QuestionType (multipleChoice, numericInput, textInput, ordering,
 │                 patternCompletion, trueFalse, wordProblem, trace, draw,
 │                 manipulative, oral)
 ├── List<AnswerChoice> choices        (nullable — only for MCQ/trueFalse)
 ├── List<String> acceptableAnswers    (normalized correct answers, supports
 │                                       multiple valid forms: "2", "2 breads")
 ├── int points
 ├── DifficultyTier (normal, hard, superHardcore, finalBoss)
 ├── int? timeLimitSeconds
 ├── bool isDigitallyPlayable
 ├── QuestionSource (rmaOfficial, mathalinoAdapted)
 └── metadata (explanation, tags)

AnswerChoice        { id, text, imageAsset }
StudentAnswer       { questionId, rawResponse, timeTakenSeconds }
GradingResult       { questionId, isCorrect, pointsAwarded, correctAnswerShown }
AssessmentAttempt    (diagnostic OR level OR remediation)
 ├── attemptId, studentId, assessmentType, gradeLevelContext
 ├── List<QuestionModel> questionsServed
 ├── List<StudentAnswer> answers
 ├── List<GradingResult> itemBreakdown
 ├── score, maxScore, percentage
 └── timestamp
StudentProgress
 ├── uid, assignedCategory, currentLevel, startingLevel
 ├── usedQuestionsHistory (Set<String>)
 ├── competencyMastery (Map<competencyCode, MasteryStat>)
 └── stats (xp, coins, streakDays, lastActiveDate)
```

---

## 4. Sample converted data

Two representative slices are provided as ready-to-load JSON:

* `assets/data/questions/grade1_sample.json` — converted from the **RMA Grade 1**
  Teacher's Booklet + Assessment Materials Booklet + Score Sheet (Tasks A–D shown as
  a worked example: number reading, one-more/one-less, ordering, fractions,
  addition with popsicle sticks). Oral/manipulative items are included but marked
  `isDigitallyPlayable: false` with a suggested `digitalAdaptation` note (e.g. the
  popsicle-stick task becomes an on-screen counting-and-add widget).
* `assets/data/questions/grade4_sample.json` — converted from the **RMA Grade 4–6**
  40-item written test (multiple choice + constructed response items 1, 4, 6, 13,
  17, 21, 30a/30b, 34, 35, 38 shown as a worked sample covering MCQ, fill-in,
  two-part probability items, and word problems).

These two files demonstrate every field the schema needs; the remaining ~180 items
across the six RMA grade levels follow the identical shape and can be transcribed by
a content team (or Claude, in a follow-up pass) into the same JSON structure without
any code changes.

---

## 5. Data-loading logic (Flutter)

`QuestionRepository` (see `lib/services/question_repository.dart`):

1. On first launch / cache-miss, load the bundled JSON from
   `assets/data/questions/grade{N}.json` via `rootBundle.loadString(...)` and parse
   into `List<QuestionModel>` — this guarantees the app works fully offline.
2. In parallel (non-blocking), check Firestore `/question_bank_meta/{grade}` for a
   `contentVersion` number newer than the locally cached one. If newer, pull the
   updated question set from `/question_bank/{grade}/{competencyCode}/{questionId}`
   with `withConverter` (per the project's Firestore coding standard) and overwrite
   the local cache (`shared_preferences`/`hive`/`sqflite` — any local cache is fine,
   the point is a stable `contentVersion` check).
3. Expose a single method the game engine calls:
   ```dart
   Future<List<QuestionModel>> selectQuestions({
     required int minGrade,
     required int maxGrade,
     required List<String> allowedCompetencies,
     required DifficultyTier difficulty,
     required Set<String> excludeQuestionIds, // usedQuestionsHistory
     required int count,
   });
   ```
   This directly implements the "Content Selection Algorithm" already specified in
   the architecture doc (grade range → competency → difficulty → not-recently-used).
4. All network/Firestore calls wrapped in `try/catch` with graceful fallback to the
   bundled asset copy, per the project's execution/safety rules.

---

## 6. Answer-validation and scoring logic

`ScoringService` (see `lib/services/scoring_service.dart`) implements grading purely
from `QuestionModel.acceptableAnswers`, so it works identically for RMA-style items
and future custom Mathalino items:

* **multipleChoice / trueFalse** → compare selected `AnswerChoice.id` to the stored
  correct choice id.
* **numericInput** → parse to `num`, compare with optional tolerance (default 0,
  since RMA items are exact integers/decimals like `7.1` or `36`).
* **textInput / wordProblem** → normalize (trim, lowercase, strip extra spaces,
  strip peso signs/units) then match against **any** entry in `acceptableAnswers`
  — this is exactly how the RMA answer keys already express flexibility (e.g.
  `"15 or 15 popsicle sticks"` → `["15", "15 popsicle sticks"]`).
* **ordering / patternCompletion** → compare the submitted ordered list/sequence to
  the stored correct sequence.
* **trace / draw / manipulative / oral** → not auto-gradable; `isDigitallyPlayable`
  is `false` so the game-content selector never serves these to the student app
  (they remain in the dataset for a future teacher/print-assessment tool).

Score aggregation reuses the Game Logic doc's formulas exactly:

```dart
double percentage(int correct, int total) => (correct / total) * 100;

// Diagnostic placement — mirrors Mathalino_Rule_Based_Game_Logic §3 verbatim
Category categorize(double pct) {
  if (pct >= 100) return Category.mastery;
  if (pct >= 75) return Category.advanced;
  if (pct >= 50) return Category.intermediate;
  return Category.beginner;
}
```

`ItemBreakdown` records, per question: `questionId`, `studentAnswer`, `isCorrect`,
`competencyCode` — this feeds both `student_results.itemBreakdown` (already defined
in the architecture doc) and the "Needs Attention" competency-tagging rule (§7 of
the Game Logic doc).

---

## 7. Firebase/Firestore structure

Extends — does not conflict with — the collections already defined in the
architecture doc (`/users/{userId}`, `/student_results/{resultId}`):

```
/question_bank_meta/{grade}
    contentVersion: int
    lastUpdated: timestamp

/question_bank/{grade}/{competencyCode}/{questionId}
    ...same fields as QuestionModel (see §3)

/users/{userId}
    ...existing fields...
    usedQuestionsHistory: array<string>          // already specced
    competencyMastery: map<string, {correct:int, attempts:int, lastAttempt:ts}>  // NEW

/student_results/{resultId}
    ...existing fields (assessmentType, score, maxScore, percentage)...
    itemBreakdown: array<{questionId, studentAnswer, isCorrect, competencyCode}>
```

Security rules follow the existing pattern: `question_bank*` is world-readable to
authenticated `student` role, write-restricted to `admin`/`content-manager` roles
(students never write questions); `users/{uid}` and `student_results` keep the
existing owner-only read/update rule already defined in the architecture doc.

---

## 8. Step-by-step integration into the existing Mathalino Student App

1. **Add models** — drop `question_model.dart` and `assessment_models.dart` into
   `lib/models/`.
2. **Add services** — drop `question_repository.dart` and `scoring_service.dart`
   into `lib/core/services/` (per the project's file-architecture rule).
3. **Bundle content** — create `assets/data/questions/grade1.json` … `grade6.json`
   (start from the two sample files provided; extend with remaining RMA items and
   any purely Mathalino-authored items using the same schema). Register the
   `assets/data/questions/` folder in `pubspec.yaml`.
4. **Seed Firestore** — write a one-time admin script (Node.js Admin SDK or a
   temporary Flutter debug screen) that reads each JSON file and upserts into
   `/question_bank/{grade}/{competencyCode}/{questionId}`, then writes
   `/question_bank_meta/{grade}.contentVersion = 1`.
5. **Wire the repository into the diagnostic flow** — in the Step 2 diagnostic
   screen (per architecture doc §3), call
   `QuestionRepository.selectQuestions(minGrade:1, maxGrade:6, ..., count:20)` to
   build the 20-item Mathalino-adapted diagnostic, run `ScoringService` on
   submission, then apply the existing `categorize()` / starting-level rules and
   write `/student_results` + update `/users/{uid}`.
6. **Wire it into level play** — the 60-level engine (Step 3–5 of the architecture
   doc) calls the same `selectQuestions()` with the zone's grade range + level's
   `DifficultyTier` (`normal`/`hard`/`superHardcore`/`finalBoss`, derived from the
   `level MOD 5` rule already specified) and passes
   `excludeQuestionIds: usedQuestionsHistory` to satisfy the "don't repeat
   questions" and remediation rules (§13 of the Game Logic doc) unchanged.
7. **Remediation** — on a failed Hard/Super Hardcore/Final Boss question, call
   `selectQuestions()` again scoped to the same competency and the level's
   preparation range (`challengeLevel - 4` … `challengeLevel - 1`), exactly per the
   existing pseudocode — no changes needed there, since it's already
   content-source-agnostic.
8. **XP/Coins/Badges hook** — after `ScoringService` returns a `GradingResult` list,
   feed it into the existing rewards logic (Step 6 of the architecture doc) —
   `points` per question (from `QuestionModel.points`) sums into level score, which
   the existing XP formula already consumes.
9. **Scale-up** — to add Grade N content or a brand-new topic later: append new
   JSON objects following the schema, bump `contentVersion`, re-run the seed script.
   No Dart code changes are required because the selector, model, and scorer are all
   schema-driven, not hardcoded per grade/topic.

---

## 9. Files delivered with this plan

```
lib/
  models/
    question_model.dart
    assessment_models.dart
  services/
    question_repository.dart
    scoring_service.dart
assets/
  data/
    questions/
      grade1_sample.json   (RMA Grade 1, Tasks A–D worked example)
      grade4_sample.json   (RMA Grade 4-6 test, worked example items)
```
