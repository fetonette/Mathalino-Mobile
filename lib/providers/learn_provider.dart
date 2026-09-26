import 'package:flutter/foundation.dart';
import '../core/models/learn_content_models.dart';
import '../core/models/student_profile.dart';
import '../core/services/learn_content_service.dart';

/// State management for the Learn section
class LearnProvider extends ChangeNotifier {
  final LearnContentService _service;

  GradeLearnContent? _currentGradeContent;
  LearnContentPackage? _fullPackage;
  bool _isLoading = false;
  String? _errorMessage;
  int? _loadedGradeLevel;

  LearnProvider({LearnContentService? service})
      : _service = service ?? LearnContentService() {
    _currentGradeContent = _service.getGradeSync(1);
    _loadedGradeLevel = 1;
  }

  GradeLearnContent? get currentGradeContent => _currentGradeContent;
  LearnContentPackage? get fullPackage => _fullPackage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get loadedGradeLevel => _loadedGradeLevel;

  /// Loads grade-appropriate Learn content for the current student.
  /// Follows LEARN_CONTENT_STRUCTURE.md §8:
  /// Content is strictly determined by the student's grade level.
  Future<void> loadForStudent(StudentProfile? profile) async {
    final targetGrade = (profile != null && profile.gradeLevel > 0) ? profile.gradeLevel : 1;

    // Immediately set from synchronous cache (0ms latency, guaranteed)
    final syncContent = _service.getGradeSync(targetGrade);
    if (syncContent != null) {
      _currentGradeContent = syncContent;
      _loadedGradeLevel = targetGrade;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _currentGradeContent = await _service.fetchFromAsset(targetGrade);
      _loadedGradeLevel = targetGrade;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_currentGradeContent == null) {
        _errorMessage = 'Unable to load lessons. Please try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Finds a module by key or name (Number Sense, Operations, Fractions, Geometry)
  LearnModule? findModule(String moduleKey) {
    return _currentGradeContent?.getModule(moduleKey);
  }

  /// Force refresh
  Future<void> refresh(StudentProfile? profile) async {
    _service.clearCache();
    _currentGradeContent = null;
    _loadedGradeLevel = null;
    await loadForStudent(profile);
  }
}
