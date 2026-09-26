import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory Badge.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw FormatException('Badge document ${doc.id} is empty');
    }
    return Badge.fromMap(data, doc.id);
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
    final earnedAt = map['earnedAt'];
    return EarnedBadge(
      badgeId: badgeId,
      userId: map['userId']?.toString() ?? '',
      earnedAt: earnedAt is Timestamp ? earnedAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'earnedAt': Timestamp.fromDate(earnedAt),
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
