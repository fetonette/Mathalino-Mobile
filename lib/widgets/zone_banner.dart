import 'package:flutter/material.dart';

/// Zone Banner Widget displaying zone headers for Zones 1, 2, and 3
class ZoneBanner extends StatelessWidget {
  final int zoneNumber;
  final String title;
  final String description;
  final Color primaryColor;
  final int completedCount;
  final int totalCount;

  const ZoneBanner({
    super.key,
    required this.zoneNumber,
    required this.title,
    required this.description,
    required this.primaryColor,
    this.completedCount = 0,
    this.totalCount = 20,
  });

  /// Factory constructor for Zone 1 (Levels 1-20, Color #1E3A8A)
  factory ZoneBanner.zone1({int completedCount = 0}) {
    return ZoneBanner(
      zoneNumber: 1,
      title: 'Zone 1: Foundations Realm',
      description: 'Master elementary counting, basic operations, and number sense (Levels 1-20)',
      primaryColor: const Color(0xFF1E3A8A), // Deep Navy
      completedCount: completedCount,
      totalCount: 20,
    );
  }

  /// Factory constructor for Zone 2 (Levels 21-40, Color #4F46E5)
  factory ZoneBanner.zone2({int completedCount = 0}) {
    return ZoneBanner(
      zoneNumber: 2,
      title: 'Zone 2: Explorer Peak',
      description: 'Conquer fractions, measurement, and geometric reasoning (Levels 21-40)',
      primaryColor: const Color(0xFF4F46E5), // Indigo
      completedCount: completedCount,
      totalCount: 20,
    );
  }

  /// Factory constructor for Zone 3 (Levels 41-60, Color #7C3AED)
  factory ZoneBanner.zone3({int completedCount = 0}) {
    return ZoneBanner(
      zoneNumber: 3,
      title: 'Zone 3: Mastery Citadel',
      description: 'Tackle advanced problem solving, data analysis, and multi-step math (Levels 41-60)',
      primaryColor: const Color(0xFF7C3AED), // Purple
      completedCount: completedCount,
      totalCount: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withValues(alpha:0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha:0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B), // Gold Amber Accent
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ZONE $zoneNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount / $totalCount Completed',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha:0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );
  }
}
