import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/avatar_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/avatar_shop_service.dart';
import '../../core/theme/mathalino_tokens.dart';
import '../../providers/level_progress_provider.dart';

/// Clean, child-friendly Avatar Shop UI for MathALINO.
///
/// BATCH 10B BEHAVIOUR:
/// - Real purchases: coins are deducted exactly once and ownership is saved
///   per student (see [AvatarShopService]); re-equipping owned avatars is free.
/// - Students can browse both Boy and Girl avatars regardless of Sex.
/// - Free starter avatar (headlogo.png) is unlocked and owned by default.
class AvatarShopScreen extends StatefulWidget {
  final bool showBackButton;
  const AvatarShopScreen({super.key, this.showBackButton = true});

  @override
  State<AvatarShopScreen> createState() => _AvatarShopScreenState();
}

class _AvatarShopScreenState extends State<AvatarShopScreen> {
  final AvatarShopService _shopService = AvatarShopService.instance;
  AvatarCategory _selectedCategory = AvatarCategory.all;
  AvatarItem? _selectedPreviewAvatar;

  @override
  void initState() {
    super.initState();
    // _selectedPreviewAvatar stays null until the student taps an avatar, so
    // the hero card keeps following the equipped avatar (including after the
    // saved selection finishes loading).
  }

  @override
  Widget build(BuildContext context) {
    // Read student profile and coins safely
    final authService = context.watch<AuthService>();
    final levelProgressProvider = context.watch<LevelProgressProvider>();
    final profile = authService.studentProfile ?? levelProgressProvider.studentProfile;
    final int currentCoins = profile?.stats.coins ?? 0;

    return AnimatedBuilder(
      animation: _shopService,
      builder: (context, _) {
        final equippedAvatar = _shopService.equippedAvatar;
        final activeAvatar = _selectedPreviewAvatar ?? equippedAvatar;

        final filteredAvatars = AvatarCatalog.getFiltered(_selectedCategory);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(context, currentCoins),
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Category Filter Chips (All, Characters, Math Buddies)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _buildFilterChips(),
                  ),
                ),

                // 2. Avatar Grid (tapping an avatar opens the preview/action modal)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, widget.showBackButton ? 24 : 96),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filteredAvatars[index];
                        final isItemOwned = _shopService.isOwned(item);
                        final isItemEquipped = _shopService.isEquipped(item);
                        final isSelected = item.id == activeAvatar.id;

                        return _buildAvatarGridItem(
                          item: item,
                          isOwned: isItemOwned,
                          isEquipped: isItemEquipped,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedPreviewAvatar = item;
                            });
                            _showAvatarPreviewModal(item);
                          },
                        );
                      },
                      childCount: filteredAvatars.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Top App Bar with back button, Title, and Coin Chip
  PreferredSizeWidget _buildAppBar(BuildContext context, int coins) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: widget.showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTokens.headingIndigo, size: 28),
              tooltip: 'Back to Profile',
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(
        'Avatar Shop',
        style: AppTokens.baloo2(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppTokens.headingIndigo,
        ),
      ),
      actions: [
        // Coin Balance Chip
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTokens.accentOrange, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1AD97706),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: AppTokens.accentOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$coins',
                    style: AppTokens.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shows the avatar preview & action card as a centered modal when an avatar
  /// in the grid is clicked.
  void _showAvatarPreviewModal(AvatarItem item) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (modalCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: AnimatedBuilder(
            animation: _shopService,
            builder: (ctx, _) {
              final authService = ctx.watch<AuthService>();
              final levelProgressProvider = ctx.watch<LevelProgressProvider>();
              final profile =
                  authService.studentProfile ?? levelProgressProvider.studentProfile;
              final int currentCoins = profile?.stats.coins ?? 0;

              final isOwned = _shopService.isOwned(item);
              final isEquipped = _shopService.isEquipped(item);
              final canAfford = _shopService.canAfford(item, currentCoins);
              final coinsNeeded = item.price - currentCoins;

              return _buildPreviewHeroCard(
                previewAvatar: item,
                isOwned: isOwned,
                isEquipped: isEquipped,
                canAfford: canAfford,
                coinsNeeded: coinsNeeded,
                currentCoins: currentCoins,
                modalContext: modalCtx,
              );
            },
          ),
        );
      },
    );
  }

  /// Large Preview Hero Card shown inside the modal when an avatar is clicked
  Widget _buildPreviewHeroCard({
    required AvatarItem previewAvatar,
    required bool isOwned,
    required bool isEquipped,
    required bool canAfford,
    required int coinsNeeded,
    required int currentCoins,
    BuildContext? modalContext,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isEquipped
              ? AppTokens.primaryIndigo
              : const Color(0xFFE2E8F0),
          width: isEquipped ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Large round avatar frame
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEEF2FF),
                        border: Border.all(
                          color: isEquipped
                              ? const Color(0xFF10B981)
                              : AppTokens.primaryIndigo,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A4338CA),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarImage(previewAvatar),
                      ),
                    ),
                    if (isEquipped)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Avatar Details and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            previewAvatar.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.baloo2(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.bodyText,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (modalContext != null)
                          InkWell(
                            onTap: () => Navigator.of(modalContext).pop(),
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Price & Category Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (previewAvatar.isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'FREE STARTER',
                              style: AppTokens.baloo2(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  color: AppTokens.accentOrange,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${previewAvatar.price} Coins',
                                  style: AppTokens.baloo2(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Category Tag (Informational only, never restricted)
                        Text(
                          previewAvatar.category == AvatarCategory.girl
                              ? 'Girl Character'
                              : previewAvatar.category == AvatarCategory.boy
                                  ? 'Boy Character'
                                  : previewAvatar.category == AvatarCategory.mathBuddies
                                      ? 'Math Buddy'
                                      : 'Free Starter',
                          style: AppTokens.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Status Text
                    Text(
                      isEquipped
                          ? '✓ Currently equipped'
                          : isOwned
                              ? 'Unlocked & ready to wear'
                              : canAfford
                                  ? 'Ready to preview unlock!'
                                  : 'Need $coinsNeeded more coins',
                      style: AppTokens.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isEquipped
                            ? const Color(0xFF10B981)
                            : isOwned
                                ? AppTokens.primaryIndigo
                                : canAfford
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button based on state
          SizedBox(
            width: double.infinity,
            height: 46,
            child: _buildPreviewActionButton(
              previewAvatar: previewAvatar,
              isOwned: isOwned,
              isEquipped: isEquipped,
              canAfford: canAfford,
              coinsNeeded: coinsNeeded,
              currentCoins: currentCoins,
              modalContext: modalContext,
            ),
          ),
        ],
      ),
    );
  }

  /// Action button for the preview hero modal
  Widget _buildPreviewActionButton({
    required AvatarItem previewAvatar,
    required bool isOwned,
    required bool isEquipped,
    required bool canAfford,
    required int coinsNeeded,
    required int currentCoins,
    BuildContext? modalContext,
  }) {
    if (isEquipped) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
        label: Text(
          'Equipped',
          style: AppTokens.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF059669),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD1FAE5),
          disabledBackgroundColor: const Color(0xFFD1FAE5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    if (isOwned) {
      return ElevatedButton.icon(
        // Re-equipping an owned avatar is always free (never touches coins).
        onPressed: _shopService.isPurchasing
            ? null
            : () async {
                if (modalContext != null && Navigator.of(modalContext).canPop()) {
                  Navigator.of(modalContext).pop();
                }
                await _equipOwned(previewAvatar);
              },
        icon: const Icon(Icons.checkroom_rounded, color: Colors.white, size: 20),
        label: Text(
          'Equip Avatar',
          style: AppTokens.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.primaryIndigo,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    // Locked avatar: Sufficient vs Insufficient coins
    if (canAfford) {
      return ElevatedButton.icon(
        // Disabled while a purchase is in flight so repeated taps cannot queue
        // a second charge.
        onPressed: _shopService.isPurchasing
            ? null
            : () {
                if (modalContext != null && Navigator.of(modalContext).canPop()) {
                  Navigator.of(modalContext).pop();
                }
                _showPurchaseConfirmationDialog(
                  previewAvatar: previewAvatar,
                  currentCoins: currentCoins,
                );
              },
        icon: Icon(
          _shopService.isPurchasing ? Icons.hourglass_top_rounded : Icons.lock_open_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          _shopService.isPurchasing
              ? 'Processing...'
              : 'Buy & Equip (${previewAvatar.price} Coins)',
          style: AppTokens.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          disabledBackgroundColor: const Color(0xFFFCD34D),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    // Insufficient coins
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You need $coinsNeeded more coins! Keep playing Adventure levels to earn coins! ⭐',
            ),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      icon: const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 20),
      label: Text(
        'Need $coinsNeeded More Coins',
        style: AppTokens.baloo2(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE2E8F0),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Filter pill buttons (All, Characters [with Boy / Girl subfilters], Math Buddies)
  Widget _buildFilterChips() {
    final isCharacterActive = _selectedCategory == AvatarCategory.characters ||
        _selectedCategory == AvatarCategory.boy ||
        _selectedCategory == AvatarCategory.girl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main categories: All, Characters, Math Buddies
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterPill('All', AvatarCategory.all),
              const SizedBox(width: 8),
              _buildFilterPill(
                'Characters',
                AvatarCategory.characters,
                isSelectedOverride: isCharacterActive,
              ),
              const SizedBox(width: 8),
              _buildFilterPill('Math Buddies', AvatarCategory.mathBuddies),
            ],
          ),
        ),

        // Optional subfilters under Characters: All Characters / Boy / Girl
        if (isCharacterActive) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildSubfilterPill(
                  'All Characters',
                  isSelected: _selectedCategory == AvatarCategory.characters,
                  onTap: () {
                    setState(() {
                      _selectedCategory = AvatarCategory.characters;
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildSubfilterPill(
                  'Boy',
                  isSelected: _selectedCategory == AvatarCategory.boy,
                  onTap: () {
                    setState(() {
                      _selectedCategory = AvatarCategory.boy;
                    });
                  },
                ),
                const SizedBox(width: 6),
                _buildSubfilterPill(
                  'Girl',
                  isSelected: _selectedCategory == AvatarCategory.girl,
                  onTap: () {
                    setState(() {
                      _selectedCategory = AvatarCategory.girl;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterPill(
    String label,
    AvatarCategory category, {
    bool? isSelectedOverride,
  }) {
    final isSelected = isSelectedOverride ?? (_selectedCategory == category);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTokens.primaryIndigo : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTokens.primaryIndigo : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x264338CA),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTokens.baloo2(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppTokens.bodyText,
          ),
        ),
      ),
    );
  }

  Widget _buildSubfilterPill(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTokens.primaryIndigo : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTokens.baloo2(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppTokens.primaryIndigo : AppTokens.secondaryText,
          ),
        ),
      ),
    );
  }

  /// Grid item card representing an avatar
  Widget _buildAvatarGridItem({
    required AvatarItem item,
    required bool isOwned,
    required bool isEquipped,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEquipped
                ? const Color(0xFF10B981)
                : isSelected
                    ? AppTokens.primaryIndigo
                    : const Color(0xFFE2E8F0),
            width: isEquipped || isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0x1F4338CA)
                  : const Color(0x0A000000),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Status Tag Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isEquipped)
                  _buildMiniBadge('EQUIPPED', const Color(0xFF10B981), Colors.white)
                else if (isOwned)
                  _buildMiniBadge('OWNED', const Color(0xFFEEF2FF), AppTokens.primaryIndigo)
                else if (item.isFree)
                  _buildMiniBadge('FREE', const Color(0xFFD1FAE5), const Color(0xFF065F46))
                else
                  _buildMiniBadge('${item.price} 🪙', const Color(0xFFFEF3C7), const Color(0xFF92400E)),

                if (!isOwned && !item.isFree)
                  const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF94A3B8))
                else if (isEquipped)
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 6),

            // Avatar Image Frame
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxAvailable = constraints.maxHeight < constraints.maxWidth
                        ? constraints.maxHeight
                        : constraints.maxWidth;
                    final size = (maxAvailable * 0.98).clamp(96.0, 142.0);
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isEquipped
                              ? const Color(0xFF10B981)
                              : isSelected
                                  ? AppTokens.primaryIndigo
                                  : const Color(0xFFCBD5E1),
                          width: isEquipped || isSelected ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0x264338CA)
                                : const Color(0x0F000000),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildAvatarImage(item),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Avatar Name
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTokens.baloo2(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTokens.bodyText,
              ),
            ),

            // Tap prompt
            Text(
              isEquipped
                  ? 'Active'
                  : isOwned
                      ? 'Tap to preview'
                      : 'Tap to view',
              style: AppTokens.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTokens.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTokens.baloo2(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  /// Safe Avatar Image Builder with fallback placeholder
  Widget _buildAvatarImage(AvatarItem item) {
    if (!item.isAssetAvailable) {
      return const Center(
        child: Icon(
          Icons.person_rounded,
          size: 56,
          color: Color(0xFF94A3B8),
        ),
      );
    }

    return Image.asset(
      item.assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.sentiment_satisfied_alt_rounded,
            size: 48,
            color: AppTokens.primaryIndigo,
          ),
        );
      },
    );
  }

  /// Confirmation dialog shown before a real purchase and coin deduction.
  void _showPurchaseConfirmationDialog({
    required AvatarItem previewAvatar,
    required int currentCoins,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: AppTokens.accentOrange, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buy Avatar',
                  style: AppTokens.baloo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.headingIndigo,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar Image
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEEF2FF),
                  border: Border.all(color: AppTokens.primaryIndigo, width: 3),
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _buildAvatarImage(previewAvatar),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                previewAvatar.name,
                style: AppTokens.baloo2(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.bodyText,
                ),
              ),
              const SizedBox(height: 8),

              // Coin Cost Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: AppTokens.accentOrange, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Price: ${previewAvatar.price} Coins',
                      style: AppTokens.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Balance & Safe Preview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Your Balance:',
                            style: AppTokens.nunito(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.secondaryText,
                            ),
                          ),
                        ),
                        Text(
                          '$currentCoins Coins',
                          style: AppTokens.baloo2(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.headingIndigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'After Purchase:',
                            style: AppTokens.nunito(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ),
                        Text(
                          '${currentCoins - previewAvatar.price} Coins',
                          style: AppTokens.baloo2(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTokens.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.secondaryText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop();
                      _purchase(previewAvatar);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Buy & Equip',
                        style: AppTokens.baloo2(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _snack(String message, Color color, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Equips an already-owned avatar. Free: never touches coins.
  Future<void> _equipOwned(AvatarItem item) async {
    final auth = context.read<AuthService>();
    final ok = await _shopService.equipAvatar(
      item,
      onAvatarEquipped: (url) => auth.updateAvatarUrl(url),
    );
    if (ok) {
      _snack('${item.name} equipped!', const Color(0xFF10B981), seconds: 2);
    } else {
      _snack('Could not equip ${item.name}. Please try again.', const Color(0xFFDC2626));
    }
  }

  /// Real purchase: deducts coins exactly once and saves ownership, or fails
  /// without changing anything. Success is only shown after both succeeded.
  Future<void> _purchase(AvatarItem item) async {
    final auth = context.read<AuthService>();
    final levelProgress = context.read<LevelProgressProvider>();
    final uid = _shopService.boundUid;
    if (uid == null) {
      _snack('Please wait a moment and try again.', const Color(0xFFDC2626));
      return;
    }

    int freshCoins() =>
        (auth.studentProfile ?? levelProgress.studentProfile)?.stats.coins ?? 0;

    final result = await _shopService.purchaseAvatar(
      item: item,
      readCurrentCoins: freshCoins,
      commitCoins: (newCoins) => auth.persistCoinBalance(forUid: uid, newCoins: newCoins),
      onAvatarEquipped: (url) => auth.updateAvatarUrl(url),
    );

    switch (result) {
      case AvatarPurchaseResult.success:
        _snack(
          '🎉 ${item.name} purchased and equipped! (${item.price} coins deducted)',
          const Color(0xFF10B981),
        );
      case AvatarPurchaseResult.alreadyOwned:
        _snack('${item.name} is already yours - equipped for free!', const Color(0xFF10B981));
      case AvatarPurchaseResult.insufficientCoins:
        _snack(
          'You need ${item.price - freshCoins()} more coins! Keep playing Adventure levels to earn coins! ⭐',
          const Color(0xFFDC2626),
        );
      case AvatarPurchaseResult.busy:
        break; // A purchase is already running; ignore the extra tap.
      case AvatarPurchaseResult.notSignedIn:
        _snack('Please wait a moment and try again.', const Color(0xFFDC2626));
      case AvatarPurchaseResult.failed:
        _snack(
          'The purchase could not be completed, so no coins were spent. Please check your connection and try again.',
          const Color(0xFFDC2626),
          seconds: 4,
        );
    }
  }
}
