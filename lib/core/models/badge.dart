
/// A badge in the global badge catalog, stored at `/badges/{badgeId}`.
class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    this.icon = '🏅',
  });

  factory Badge.fromMap(Map<String, dynamic> map, String id) {
    return Badge(
      id: id,
      name: map['name']?.toString() ?? id,
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '🏅',
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
    };
  }
}

/// A badge earned by a student, stored at `/users/{userId}/earnedBadges/{badgeId}`.
class EarnedBadge {
  final String badgeId;
  final String userId;
  final DateTime earnedAt;

  const EarnedBadge({
    required this.badgeId,
    required this.userId,
    required this.earnedAt,
  });

  factory EarnedBadge.fromMap(Map<String, dynamic> map, String badgeId) {
    final earnedAtRaw = map['earned_at'] ?? map['earnedAt'];
    final earnedAt = earnedAtRaw is String
        ? DateTime.tryParse(earnedAtRaw) ?? DateTime.now()
        : DateTime.now();
    return EarnedBadge(
      badgeId: badgeId,
      userId: map['user_id']?.toString() ?? map['userId']?.toString() ?? '',
      earnedAt: earnedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
      'earned_at': earnedAt.toIso8601String(),
    };
  }
}

/// Well-known badge IDs used across the app.
class BadgeIds {
  static const String perfectScore = 'perfect_score';
  static const String speedDemon = 'speed_demon';
  static const String streakMaster = 'streak_master';
  static const String bossSlayer = 'boss_slayer';
  static const String zone1Master = 'zone_1_master';
  static const String zone2Master = 'zone_2_master';
  static const String mathWizard = 'math_wizard';

  const BadgeIds._();
}
