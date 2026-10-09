/// Presentation-only strings and zone info for the Home / level map screen.
///
/// The project has no localization system yet, so every Home text lives here
/// to make a future move to ARB/intl files a one-file change.
class HomeStrings {
  HomeStrings._();

  static const String levelWord = 'Level';
  static const String start = 'START';
  static const String logoutTitle = 'Log out?';

  static String levelOf(int level) => 'Level $level';
  static String continueLevel(int level) => 'Continue · Level $level';
  static String zoneChip(int zone) => 'ZONE $zone';
  static String levelsDone(int done, int total) =>
      '$done of $total levels done';
  static String xp(int xp) => '$xp XP';

  // Message bubble ---------------------------------------------------------
  static String welcomeNew(String name) =>
      "Welcome, $name! Let's start with Level 1.";
  static String resumeMidZone(String name, int level) =>
      'Great job, $name! Level $level is waiting for you.';
  static String newZone(String name, int level) =>
      'Awesome, $name! A new zone starts at Level $level!';
  static String allDone(String name) =>
      'Amazing, $name! You finished every level!';

  /// First name only, truncated with "…" after [maxChars] characters.
  static String firstName(String full, {int maxChars = 12}) {
    final trimmed = full.trim();
    var first = trimmed.isEmpty ? 'Student' : trimmed.split(RegExp(r'\s+')).first;
    if (first.runes.length > maxChars) {
      first = '${String.fromCharCodes(first.runes.take(maxChars))}…';
    }
    return first;
  }

  // Semantics --------------------------------------------------------------
  static String nodeCompleted(int level) => 'Level $level, completed';
  static String nodeCurrent(int level) =>
      'Level $level, current level, tap to start';
  static String nodeUnlocked(int level) => 'Level $level, unlocked, tap to start';
  static String nodeLocked(int level) => 'Level $level, locked';
  static const String avatarLabel = 'Student avatar';
  static String coinsLabel(int coins) => '$coins coins';
  static String xpLabel(int xp) => '$xp experience points';
}

/// Static presentation data for the three zones (levels 1-60).
class HomeZone {
  final int number;
  final String name;
  final String description;
  final int firstLevel;
  final int lastLevel;

  const HomeZone(
    this.number,
    this.name,
    this.description,
    this.firstLevel,
    this.lastLevel,
  );

  int get total => lastLevel - firstLevel + 1;

  static const List<HomeZone> all = [
    HomeZone(1, 'Foundations Realm', 'Counting, adding and number sense', 1, 20),
    HomeZone(2, 'Explorer Peak', 'Fractions, measuring and shapes', 21, 40),
    HomeZone(3, 'Mastery Citadel', 'Problem solving, data and multi-step math', 41, 60),
  ];

  static HomeZone forLevel(int level) {
    if (level <= 20) return all[0];
    if (level <= 40) return all[1];
    return all[2];
  }
}
