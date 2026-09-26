/// Pre-Assessment Module - Quick Reference & Usage Guide
/// 
/// This file demonstrates how to use the diagnostic assessment module
/// in different scenarios.

// ============================================================================
// 1. INITIALIZING THE DIAGNOSTIC ASSESSMENT
// ============================================================================

/// Initialize diagnostic on screen load
void initDiagnostic(BuildContext context) async {
  final provider = context.read<DiagnosticProvider>();
  final authService = context.read<AuthService>();
  final profile = authService.studentProfile;
  
  if (profile != null) {
    try {
      await provider.loadDiagnosticQuestions(
        userId: profile.uid,
        gradeLevel: profile.gradeLevel,
        usedQuestionsHistory: profile.usedQuestionsHistory,
      );
      // Questions loaded successfully
      // UI will automatically update via ChangeNotifier
    } catch (e) {
      print('Error loading diagnostic: $e');
    }
  }
}

// ============================================================================
// 2. DISPLAYING CURRENT QUESTION
// ============================================================================

/// Show current question to student
Widget buildCurrentQuestion(BuildContext context) {
  return Consumer<DiagnosticProvider>(
    builder: (context, provider, _) {
      final question = provider.currentQuestion;
      if (question == null) {
        return const Center(child: Text('No question available'));
      }
      
      return Column(
        children: [
          // Progress indicator
          Text('Question ${provider.currentIndex + 1} of ${provider.totalQuestions}'),
          
          // Progress bar
          LinearProgressIndicator(
            value: provider.currentIndex / provider.totalQuestions,
            minHeight: 8,
          ),
          
          // Score display
          Text('Correct: ${provider.correctCountSoFar}'),
          
          // Question card
          QuestionCard(
            question: question,
            onAnswerSelected: (answer) => _submitAnswer(context, answer),
          ),
        ],
      );
    },
  );
}

// ============================================================================
// 3. HANDLING STUDENT ANSWER
// ============================================================================

/// Process student's answer
Future<void> _submitAnswer(BuildContext context, dynamic answer) async {
  final provider = context.read<DiagnosticProvider>();
  
  // Record answer and check if complete
  final isComplete = provider.answerCurrentQuestion(answer);
  
  if (isComplete) {
    // All 20 questions answered - submit diagnostic
    await _submitDiagnostic(context, provider);
  }
  // Otherwise, provider notifies listeners and UI updates to next question
}

// ============================================================================
// 4. SUBMITTING DIAGNOSTIC ASSESSMENT
// ============================================================================

/// Submit completed diagnostic and get placement result
Future<void> _submitDiagnostic(
  BuildContext context,
  DiagnosticProvider provider,
) async {
  final authService = context.read<AuthService>();
  final profile = authService.studentProfile;
  
  if (profile == null) return;
  
  try {
    // Submit diagnostic
    final placement = await provider.submitDiagnostic(
      userId: profile.uid,
      currentProfile: profile,
    );
    
    // Navigate to results screen
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DiagnosticResultsScreen(
            placement: placement,
            correctAnswers: provider.correctCountSoFar,
            totalQuestions: provider.totalQuestions,
            studentName: profile.displayName,
            onContinue: () => _navigateToAdventureMap(context),
          ),
        ),
      );
    }
  } catch (e) {
    // Handle error
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting diagnostic: $e')),
      );
    }
  }
}

// ============================================================================
// 5. ACCESSING PLACEMENT RESULT
// ============================================================================

/// Get placement result after submission
void _accessPlacementResult(BuildContext context) {
  final provider = context.read<DiagnosticProvider>();
  
  if (provider.placementResult != null) {
    final placement = provider.placementResult!;
    
    print('Category: ${placement.category}');           // e.g., "Intermediate"
    print('Starting Level: ${placement.startingLevel}'); // e.g., 21
    print('Score: ${placement.scorePercentage}%');       // e.g., 75.0%
    print('Content Pool: ${placement.contentPool}');     // e.g., [Grade 1-6]
  }
}

// ============================================================================
// 6. ANALYZING PERFORMANCE
// ============================================================================

/// Analyze diagnostic performance with insights
void _analyzePerformance(BuildContext context) {
  final provider = context.read<DiagnosticProvider>();
  final assessmentService = DiagnosticAssessmentService();
  
  if (provider.questions.isNotEmpty && provider.isComplete) {
    final analysis = assessmentService.analyzeDiagnosticPerformance(
      questions: provider.questions,
      answers: provider._answers,  // Note: typically private, use getter
      scorePercentage: provider.placementResult?.scorePercentage ?? 0.0,
      placementCategory: provider.placementResult?.category ?? 'Beginner',
    );
    
    print('Strengths: ${analysis['strengthCompetencies']}');
    print('Weaknesses: ${analysis['weakCompetencies']}');
    print('Recommendations: ${analysis['recommendations']}');
  }
}

// ============================================================================
// 7. CUSTOM UI - SHOW RESULTS
// ============================================================================

/// Build custom results display
Widget buildResultsSummary(PlacementResult placement, int correct, int total) {
  final percentage = placement.scorePercentage;
  
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Score
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          Text('$correct / $total Correct'),
          
          // Category
          Chip(
            label: Text(placement.category),
            backgroundColor: _getCategoryColor(placement.category),
          ),
          
          // Starting Level
          Text('Starting Level: ${placement.startingLevel}'),
          
          // Content Pools
          const Text('Available Content:'),
          Wrap(
            children: placement.contentPool.map((pool) {
              return Chip(label: Text(pool));
            }).toList(),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// 8. ERROR HANDLING
// ============================================================================

/// Handle diagnostic errors gracefully
void _handleDiagnosticError(BuildContext context, DiagnosticProvider provider) {
  if (provider.errorMessage != null) {
    // Show error UI
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(provider.errorMessage!),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Retry loading
              provider.resetDiagnostic();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. LOADING STATES
// ============================================================================

/// Show loading indicator while diagnostic loads
Widget buildLoadingState(DiagnosticProvider provider) {
  if (provider.isLoading) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  if (provider.isSubmitting) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Submitting your assessment...'),
        ],
      ),
    );
  }
  
  return const SizedBox.shrink();
}

// ============================================================================
// 10. DIRECT QUESTION ACCESS
// ============================================================================

/// Access diagnostic questions programmatically
void _accessQuestions() {
  final assessmentService = DiagnosticAssessmentService();
  
  // Load all 20 questions
  final questions = assessmentService.loadDiagnosticQuestions();
  print('Loaded ${questions.length} diagnostic questions');
  
  // Get specific question
  final q1 = assessmentService.getDiagnosticQuestion('diag_001');
  if (q1 != null) {
    print('Q1: ${q1.questionText}');
    print('Type: ${q1.type}');
    print('Correct Answer: ${q1.correctAnswer}');
  }
  
  // Get competency description
  final desc = assessmentService.getCompetencyDescription('M1NS');
  print('M1NS: $desc');
}

// ============================================================================
// 11. PLACEMENT RULES
// ============================================================================

/// Access placement rules for a category
void _getPlacementRules(String category) {
  final assessmentService = DiagnosticAssessmentService();
  
  final rule = assessmentService.getPlacementRuleInfo(category);
  if (rule != null) {
    print('Category: ${rule['category']}');
    print('Starting Level: ${rule['startingLevel']}');
    print('Content Pools: ${rule['contentPools']}');
    print('Description: ${rule['description']}');
  }
  
  // Get content pools for a specific category
  final pools = assessmentService.getContentPoolsForCategory('Advanced');
  print('Advanced content pools: $pools');
}

// ============================================================================
// 12. VALIDATION
// ============================================================================

/// Validate diagnostic before submission
void _validateDiagnostic(DiagnosticProvider provider) {
  final assessmentService = DiagnosticAssessmentService();
  
  // Note: Typically _answers is private, this shows the concept
  // In practice, use provider's public methods
  
  // For demonstration:
  final errors = assessmentService.validateDiagnosticCompletion(
    questions: provider.questions,
    answers: [], // Replace with actual answers
  );
  
  if (errors.isNotEmpty) {
    print('Validation errors:');
    for (final error in errors) {
      print('  - $error');
    }
  } else {
    print('Diagnostic is valid and ready for submission');
  }
}

// ============================================================================
// 13. GENERATE DETAILED REPORT
// ============================================================================

/// Generate comprehensive diagnostic report
Map<String, dynamic> _buildDetailedReport(
  String studentId,
  String studentName,
  int gradeLevel,
  DiagnosticProvider provider,
) {
  final assessmentService = DiagnosticAssessmentService();
  
  return assessmentService.buildDiagnosticResultReport(
    studentId: studentId,
    studentName: studentName,
    gradeLevel: gradeLevel,
    questions: provider.questions,
    answers: [], // Use actual answers from provider
    correctCount: provider.correctCountSoFar,
    scorePercentage: provider.placementResult?.scorePercentage ?? 0.0,
    placementCategory: provider.placementResult?.category ?? 'Beginner',
  );
}

// ============================================================================
// 14. RESETTING DIAGNOSTIC
// ============================================================================

/// Reset diagnostic to allow restart
void _resetDiagnostic(BuildContext context) {
  final provider = context.read<DiagnosticProvider>();
  
  provider.resetDiagnostic();
  // State cleared, can start fresh with loadDiagnosticQuestions()
}

// ============================================================================
// 15. INTEGRATION WITH STUDENT PROFILE
// ============================================================================

/// After diagnostic, student profile is automatically updated
void _accessUpdatedProfile(BuildContext context) async {
  final authService = context.read<AuthService>();
  final firestoreService = FirestoreService();
  
  final profile = await firestoreService.fetchStudentProfile(
    authService.currentUser!.uid,
  );
  
  if (profile != null) {
    print('Assigned Category: ${profile.assignedCategory}');    // e.g., "Intermediate"
    print('Starting Level: ${profile.startingLevel}');          // e.g., 21
    print('Current Level: ${profile.currentLevel}');            // e.g., 21
    print('Diagnostic Score: ${profile.diagnosticScore}');      // e.g., 15
    print('Diagnostic Percentage: ${profile.diagnosticPercentage}'); // e.g., 75.0
    print('Diagnostic Completed: ${profile.diagnosticCompleted}'); // e.g., true
    print('Completed At: ${profile.diagnosticCompletedAt}');    // Timestamp
  }
}

// ============================================================================
// HELPER FUNCTION
// ============================================================================

Color _getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'mastery':
      return Colors.amber;
    case 'advanced':
      return Colors.blue;
    case 'intermediate':
      return Colors.green;
    case 'beginner':
    default:
      return Colors.orange;
  }
}

// ============================================================================
// FIRESTORE RESULT VERIFICATION
// ============================================================================

/// Example of checking results in Firestore (for testing/debugging)
Future<void> _verifyDiagnosticResults(String studentId) async {
  final firestore = FirebaseFirestore.instance;
  
  // Check user profile
  final userDoc = await firestore.collection('users').doc(studentId).get();
  if (userDoc.exists) {
    final data = userDoc.data()!;
    print('User Profile Updated:');
    print('  - assignedCategory: ${data['assignedCategory']}');
    print('  - startingLevel: ${data['startingLevel']}');
    print('  - diagnosticScore: ${data['diagnosticScore']}');
    print('  - diagnosticPercentage: ${data['diagnosticPercentage']}');
    print('  - diagnosticCompleted: ${data['diagnosticCompleted']}');
    print('  - diagnosticCompletedAt: ${data['diagnosticCompletedAt']}');
  }
  
  // Check results
  final resultsQuery = await firestore
      .collection('student_results')
      .where('studentId', isEqualTo: studentId)
      .where('assessmentType', isEqualTo: 'diagnostic')
      .orderBy('timestamp', descending: true)
      .limit(1)
      .get();
  
  if (resultsQuery.docs.isNotEmpty) {
    final resultData = resultsQuery.docs.first.data();
    print('Diagnostic Result Created:');
    print('  - score: ${resultData['score']}');
    print('  - maxScore: ${resultData['maxScore']}');
    print('  - percentage: ${resultData['percentage']}');
    print('  - itemBreakdown entries: ${(resultData['itemBreakdown'] as Map).length}');
  }
}

// ============================================================================
// STATE MANAGEMENT PATTERN (in Provider context)
// ============================================================================

class ExampleDiagnosticWidget extends StatefulWidget {
  const ExampleDiagnosticWidget({super.key});

  @override
  State<ExampleDiagnosticWidget> createState() => _ExampleDiagnosticWidgetState();
}

class _ExampleDiagnosticWidgetState extends State<ExampleDiagnosticWidget> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = context.read<AuthService>();
    final provider = context.read<DiagnosticProvider>();
    final profile = authService.studentProfile;
    
    if (profile != null && !provider.isLoading && provider.questions.isEmpty) {
      provider.loadDiagnosticQuestions(
        userId: profile.uid,
        gradeLevel: profile.gradeLevel,
        usedQuestionsHistory: profile.usedQuestionsHistory,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DiagnosticProvider>(
      builder: (context, provider, _) {
        // Build UI based on provider state
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (provider.errorMessage != null) {
          return Center(child: Text(provider.errorMessage!));
        }
        
        if (provider.isComplete && provider.placementResult != null) {
          return buildResultsSummary(
            provider.placementResult!,
            provider.correctCountSoFar,
            provider.totalQuestions,
          );
        }
        
        return buildCurrentQuestion(context);
      },
    );
  }
}

// ============================================================================
// TESTING HELPER
// ============================================================================

/// Unit test example
void exampleUnitTest() {
  // Example: Test scoring for a multiple choice question
  final assessmentService = DiagnosticAssessmentService();
  final question = assessmentService.getDiagnosticQuestion('diag_003');
  
  assert(question != null);
  assert(question!.type == 'multipleChoice');
  assert(question.correctAnswer is List || question.correctAnswer is String);
  
  // Test with different answer formats
  // - "B" should match "B. 10"
  // - "B. 10" should match "B"
  // Both should score the question correctly
  
  print('Test passed: Question loaded and type verified');
}

// ============================================================================
// END - Quick Reference Guide
// ============================================================================
