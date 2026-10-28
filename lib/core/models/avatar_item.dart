/// Categories for filtering in the Avatar Shop.
enum AvatarCategory {
  all,
  starter,
  characters,
  mathBuddies,
  girl,
  boy,
}

/// Representation of an individual avatar in the MathALINO Avatar Catalog.
class AvatarItem {
  final String id;
  final String name;
  final String filename;
  final String assetPath;
  final int price;
  final AvatarCategory category;
  final bool isAssetAvailable;

  const AvatarItem({
    required this.id,
    required this.name,
    required this.filename,
    required this.assetPath,
    required this.price,
    required this.category,
    this.isAssetAvailable = true,
  });

  bool get isFree => price == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catalog containing all official MathALINO avatars.
class AvatarCatalog {
  AvatarCatalog._();

  /// Confirmed Avatar Directory: assets/avatar/
  static const String avatarDir = 'assets/avatar';

  /// Default Free Starter Avatar
  static const AvatarItem starterAvatar = AvatarItem(
    id: 'starter_headlogo',
    name: 'Starter Logo',
    filename: 'headlogo.png',
    assetPath: '$avatarDir/headlogo.png',
    price: 0,
    category: AvatarCategory.starter,
    isAssetAvailable: true,
  );

  /// Complete Avatar Catalog
  static const List<AvatarItem> allAvatars = [
    // FREE STARTER
    starterAvatar,

    // GIRL AVATARS
    AvatarItem(
      id: 'girl_50',
      name: 'Sparkle Girl',
      filename: '50(Girl).png',
      assetPath: '$avatarDir/50(Girl).png',
      price: 50,
      category: AvatarCategory.girl,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'girl_100',
      name: 'Sunny Girl',
      filename: '100(girl).png',
      assetPath: '$avatarDir/100(girl).png',
      price: 100,
      category: AvatarCategory.girl,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'girl_150',
      name: 'Joyful Girl',
      filename: '150(Girl).png',
      assetPath: '$avatarDir/150(Girl).png',
      price: 150,
      category: AvatarCategory.girl,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'girl_200',
      name: 'Star Girl',
      filename: '200(girl).png',
      assetPath: '$avatarDir/200(girl).png',
      price: 200,
      category: AvatarCategory.girl,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'girl_250',
      name: 'Princess Crown',
      filename: '250(girl).png',
      assetPath: '$avatarDir/250(girl).png',
      price: 250,
      category: AvatarCategory.girl,
      isAssetAvailable: true,
    ),

    // BOY AVATARS
    AvatarItem(
      id: 'boy_100',
      name: 'Cool Boy',
      filename: '100(boy).png',
      assetPath: '$avatarDir/100(boy).png',
      price: 100,
      category: AvatarCategory.boy,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'boy_150',
      name: 'Champ Boy',
      filename: '150(boy).png',
      assetPath: '$avatarDir/150(boy).png',
      price: 150,
      category: AvatarCategory.boy,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'boy_200',
      name: 'Super Boy',
      filename: '200(boy).png',
      assetPath: '$avatarDir/200(boy).png',
      price: 200,
      category: AvatarCategory.boy,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'boy_250',
      name: 'Legend Boy',
      filename: '250(boy).png',
      assetPath: '$avatarDir/250(boy).png',
      price: 250,
      category: AvatarCategory.boy,
      isAssetAvailable: true,
    ),

    // MATH BUDDIES
    AvatarItem(
      id: 'item_bulb_100',
      name: 'Bright Bulb',
      filename: '100(bulb).png',
      assetPath: '$avatarDir/100(bulb).png',
      price: 100,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_ruler_100',
      name: 'Smart Ruler',
      filename: '100(ruler).png',
      assetPath: '$avatarDir/100(ruler).png',
      price: 100,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_plus_150',
      name: 'Plus Sign',
      filename: '150(plus).png',
      assetPath: '$avatarDir/150(plus).png',
      price: 150,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_minus_150',
      name: 'Minus Sign',
      filename: '150(minus).png',
      assetPath: '$avatarDir/150(minus).png',
      price: 150,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_times_150',
      name: 'Multiply Sign',
      filename: '150(times).png',
      assetPath: '$avatarDir/150(times).png',
      price: 150,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_divide_150',
      name: 'Divide Sign',
      filename: '150(divide).png',
      assetPath: '$avatarDir/150(divide).png',
      price: 150,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_star_150',
      name: 'Golden Star',
      filename: '150(star).png',
      assetPath: '$avatarDir/150(star).png',
      price: 150,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_pencil_200',
      name: 'Sharp Pencil',
      filename: '200(pencil).png',
      assetPath: '$avatarDir/200(pencil).png',
      price: 200,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_eraser_200',
      name: 'Magic Eraser',
      filename: '200(eraser).png',
      assetPath: '$avatarDir/200(eraser).png',
      price: 200,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
    AvatarItem(
      id: 'item_calculator_200',
      name: 'Calculator',
      filename: '200(calculator).png',
      assetPath: '$avatarDir/200(calculator).png',
      price: 200,
      category: AvatarCategory.mathBuddies,
      isAssetAvailable: true,
    ),
  ];

  /// Filter avatars by category.
  /// Note: Free Starter is visible in All, or when viewing all filters.
  static List<AvatarItem> getFiltered(AvatarCategory category) {
    switch (category) {
      case AvatarCategory.all:
        return allAvatars;
      case AvatarCategory.starter:
        return allAvatars.where((a) => a.category == AvatarCategory.starter).toList();
      case AvatarCategory.characters:
        return allAvatars.where((a) => a.category == AvatarCategory.girl || a.category == AvatarCategory.boy).toList();
      case AvatarCategory.mathBuddies:
        return allAvatars.where((a) => a.category == AvatarCategory.mathBuddies).toList();
      case AvatarCategory.girl:
        return allAvatars.where((a) => a.category == AvatarCategory.girl).toList();
      case AvatarCategory.boy:
        return allAvatars.where((a) => a.category == AvatarCategory.boy).toList();
    }
  }

  /// Look up an avatar by its ID.
  static AvatarItem findById(String id) {
    return allAvatars.firstWhere(
      (a) => a.id == id,
      orElse: () => starterAvatar,
    );
  }

  /// Strict lookup of an avatar by its exact catalog [id]; null when unknown.
  static AvatarItem? tryFindById(String id) {
    for (final a in allAvatars) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Strict lookup by asset path or filename; null when nothing matches.
  ///
  /// Matches the EXACT file name (the last path segment). A suffix match is
  /// deliberately NOT used: `assets/avatar/150(Girl).png` ends with
  /// `50(Girl).png`, which would resolve a saved Joyful Girl to Sparkle Girl.
  static AvatarItem? tryFindByPathOrFilename(String pathOrFilename) {
    final cleaned = pathOrFilename.trim().replaceAll('\\', '/');
    if (cleaned.isEmpty) return null;
    final basename = cleaned.split('/').last;
    for (final a in allAvatars) {
      if (a.assetPath == cleaned || a.filename == basename) return a;
    }
    return null;
  }

  /// Look up an avatar by assetPath or filename (falls back to the starter).
  static AvatarItem findByPathOrFilename(String pathOrFilename) {
    return tryFindByPathOrFilename(pathOrFilename) ?? starterAvatar;
  }
}
