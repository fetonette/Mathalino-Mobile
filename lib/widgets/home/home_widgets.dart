import 'package:flutter/material.dart';

import '../../core/theme/mathalino_tokens.dart';
import 'home_strings.dart';

/// Scales text but keeps these compact chrome elements from breaking at large
/// system font sizes.
Widget _clamp(Widget child, {double max = 1.3}) =>
    MediaQuery.withClampedTextScaling(
      minScaleFactor: 1.0,
      maxScaleFactor: max,
      child: child,
    );

// ─── Header ─────────────────────────────────────────────────────────────────

class HomeHeader extends StatelessWidget {
  final String name;
  final int level;
  final int coins;
  final int xp;

  const HomeHeader({
    super.key,
    required this.name,
    required this.level,
    required this.coins,
    required this.xp,
  });

  @override
  Widget build(BuildContext context) {
    return _clamp(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: Row(
          children: [
            Semantics(
              label: HomeStrings.avatarLabel,
              image: true,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTokens.primaryIndigo,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.baloo2(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.bodyText,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    HomeStrings.levelOf(level),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.orangeText,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatPill(
              border: AppTokens.accentOrange,
              icon: Icons.monetization_on_rounded,
              iconColor: AppTokens.accentOrange,
              text: '$coins',
              textColor: AppTokens.bodyText,
              semantics: HomeStrings.coinsLabel(coins),
            ),
            const SizedBox(width: 8),
            _StatPill(
              border: AppTokens.primaryIndigo,
              icon: Icons.star_rounded,
              iconColor: AppTokens.primaryIndigo,
              text: HomeStrings.xp(xp),
              textColor: AppTokens.headingIndigo,
              semantics: HomeStrings.xpLabel(xp),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final String semantics;

  const _StatPill({
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 5),
            Text(
              text,
              maxLines: 1,
              style: AppTokens.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Zone card ──────────────────────────────────────────────────────────────

class ZoneCard extends StatelessWidget {
  final HomeZone zone;
  final int completed;

  const ZoneCard({super.key, required this.zone, required this.completed});

  @override
  Widget build(BuildContext context) {
    final total = zone.total;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    return _clamp(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          color: AppTokens.zoneCard,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTokens.accentOrange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    HomeStrings.zoneChip(zone.number),
                    style: AppTokens.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTokens.zoneChipText,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    HomeStrings.levelsDone(completed, total),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              zone.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.baloo2(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15,
              ),
            ),
            Text(
              zone.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTokens.zoneDescription,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: AppTokens.zoneTrack),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: const SizedBox.expand(
                          child: ColoredBox(color: AppTokens.zoneFill),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mascot message bubble ──────────────────────────────────────────────────

class MascotBubble extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final double maxWidth;

  const MascotBubble({
    super.key,
    required this.text,
    required this.onTap,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: _clamp(
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTokens.cardBorder, width: 2),
                  ),
                  child: Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.headingIndigo,
                      height: 1.3,
                    ),
                  ),
                ),
                // Small rotated-square tail pointing right at the mascot.
                Positioned(
                  right: -7,
                  top: 22,
                  child: Transform.rotate(
                    angle: 0.7853981634, // 45°
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: AppTokens.cardBorder, width: 2),
                          right:
                              BorderSide(color: AppTokens.cardBorder, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom navigation ──────────────────────────────────────────────────────

class HomeNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const HomeNavItem(this.label, this.icon, this.selectedIcon);
}

class HomeBottomNav extends StatelessWidget {
  static const List<HomeNavItem> items = [
    HomeNavItem('Home', Icons.home_outlined, Icons.home_rounded),
    HomeNavItem('Learn', Icons.menu_book_outlined, Icons.menu_book_rounded),
    HomeNavItem('Progress', Icons.bar_chart_rounded, Icons.bar_chart_rounded),
    HomeNavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 72 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTokens.navBorder, width: 1)),
      ),
      child: _clamp(
        Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
        max: 1.2,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final HomeNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTokens.headingIndigo : AppTokens.lockedContent;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppTokens.navActivePill : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              style: AppTokens.nunito(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
