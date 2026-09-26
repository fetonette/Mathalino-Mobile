# 📱 Mathalino Student App

Mathalino is a gamified, adaptive primary mathematics learning platform for learners in Grades 1–6. It integrates the Regional Mathematical Assessment (RMA) framework and standard DepEd math competencies into an adventure world map.

## 📖 Comprehensive Documentation
For the complete technical and feature breakdown, please refer to the master documentation:
- **[Mathalino Student App Master Details](../md%20files/MATHALINO_STUDENT_APP_DETAILS.md)**

## 🚀 Key Features
- **🔑 LRN Authentication:** 12-digit Learner Reference Number sign-in with role guards.
- **🎯 20-Item RMA Diagnostic Assessment:** Automated placement into Foundation (Level 1), Intermediate (Level 21), or Advanced (Level 41) tiers.
- **🗺️ 60-Level Serpentine Adventure Map:** 3 thematic zones with dynamic locked/active/completed states and smooth auto-scrolling.
- **🎮 Adaptive Gameplay Engine:** 300 pre-bundled questions, canonical option ordering, and instant feedback.
- **🩺 Failure & Remediation Engine:** Hard and Boss gates with sliding 75% mastery review loops across preparation ranges.
- **📊 Milestone Post-Assessments:** Levels 20, 40, and 60 track domain-specific accuracy and comparative learning growth.
- **🏆 Gamification Economy:** XP, coins, streaks with up to +50% multipliers, and achievement badges committed via atomic Firestore transactions.

## 🧪 Testing & Verification
```bash
# Run the automated test suite (190/190 passing)
flutter test

# Run static analysis (0 errors)
flutter analyze
```

