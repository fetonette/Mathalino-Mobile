import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/avatar_item.dart';

/// Outcome of a purchase attempt. Only [success] means coins were deducted.
enum AvatarPurchaseResult {
  /// Coins deducted exactly once, ownership saved, avatar equipped.
  success,

  /// Already owned: equipped for free, coins untouched.
  alreadyOwned,

  /// Balance is below the price. Nothing changed.
  insufficientCoins,

  /// No authenticated student is bound (or still loading). Nothing changed.
  notSignedIn,

  /// Another purchase is still in flight. Nothing changed.
  busy,

  /// Saving ownership or the coin deduction failed. No partial state kept.
  failed,
}

/// Manages avatar ownership and the equipped avatar for the signed-in student.
///
/// BATCH 10B PERSISTENCE MODEL
/// - State is scoped to ONE authenticated student ([boundUid]). Ownership and
///   the equipped selection are stored in SharedPreferences under keys that
///   include that student's uid, so a different student on the same device can
///   never see or inherit them.
/// - The session is bound by [syncSession] when the profile loads (see
///   `AvatarSessionBinder`) and unbound on logout. Profile refreshes for the
///   same student never re-bind, so a loading/refresh state cannot overwrite a
///   valid saved selection.
/// - The free starter (headlogo.png) is the default ONLY when no valid saved
///   selection exists.
/// - Legacy un-scoped keys from earlier batches are intentionally never read:
///   Batch 10A preview unlocks also wrote there without charging any coins.
class AvatarShopService extends ChangeNotifier {
  static const String _ownedKeyPrefix = 'mathalino_avatar_owned_v2:';
  static const String _equippedKeyPrefix = 'mathalino_avatar_equipped_v2:';

  static AvatarShopService? _instance;
  static AvatarShopService get instance => _instance ??= AvatarShopService._();

  AvatarShopService._();

  /// Visible for testing to reset instance state
  @visibleForTesting
  static void resetForTesting() {
    _instance = AvatarShopService._();
  }

  AvatarItem _equippedAvatar = AvatarCatalog.starterAvatar;
  final Set<String> _ownedAvatarIds = {AvatarCatalog.starterAvatar.id};

  String? _boundUid;
  bool _loading = false;
  bool _purchaseInFlight = false;
  int _bindGeneration = 0;

  AvatarItem get equippedAvatar => _equippedAvatar;
  Set<String> get ownedAvatarIds => Set.unmodifiable(_ownedAvatarIds);

  /// The student this state belongs to, or null when nobody is signed in.
  String? get boundUid => _boundUid;

  /// True while the saved state for [boundUid] is still being loaded.
  bool get isLoading => _loading;

  /// True while a purchase is being processed (UI disables buying).
  bool get isPurchasing => _purchaseInFlight;

  /// True once a student is bound and their saved state has finished loading.
  bool get isReady => _boundUid != null && !_loading;

  static String ownedKeyFor(String uid) => '$_ownedKeyPrefix$uid';
  static String equippedKeyFor(String uid) => '$_equippedKeyPrefix$uid';

  // ── Session lifecycle ────────────────────────────────────────────────

  /// Binds to the signed-in student, or unbinds when [uid] is null/empty.
  /// Idempotent for the already-bound student, so repeated profile refreshes
  /// can never reset or overwrite the saved selection.
  Future<void> syncSession({String? uid, String serverAvatarUrl = ''}) async {
    if (uid == null || uid.isEmpty) {
      if (_boundUid != null || _loading) unbind();
      return;
    }
    if (uid == _boundUid) return;
    await bindStudent(uid, serverAvatarUrl: serverAvatarUrl);
  }

  /// Clears in-memory state on logout. Saved per-student data stays on disk
  /// and is reloaded when that student signs in again.
  void unbind() {
    _bindGeneration++;
    _boundUid = null;
    _loading = false;
    _resetToDefaults();
    notifyListeners();
  }

  /// Loads the saved ownership and equipped avatar for [uid].
  ///
  /// Equipped avatar resolution:
  /// 1. The student's saved selection, when valid and owned (or free).
  /// 2. Otherwise the avatar named by the server profile's `avatar_url`
  ///    (display only - this NEVER grants ownership).
  /// 3. Otherwise the free starter.
  Future<void> bindStudent(String uid, {String serverAvatarUrl = ''}) async {
    final generation = ++_bindGeneration;
    _boundUid = uid;
    _loading = true;
    _resetToDefaults();
    notifyListeners();

    final owned = <String>{AvatarCatalog.starterAvatar.id};
    String? savedEquippedId;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in prefs.getStringList(ownedKeyFor(uid)) ?? const <String>[]) {
        if (AvatarCatalog.tryFindById(id) != null) owned.add(id);
      }
      savedEquippedId = prefs.getString(equippedKeyFor(uid));
    } catch (e) {
      debugPrint('[AvatarShopService] load error for $uid: $e');
    }

    // A newer bind/unbind superseded this one: discard the stale result.
    if (generation != _bindGeneration) return;

    AvatarItem equipped = AvatarCatalog.starterAvatar;
    final saved = savedEquippedId == null || savedEquippedId.isEmpty
        ? null
        : AvatarCatalog.tryFindById(savedEquippedId);
    if (saved != null && (saved.isFree || owned.contains(saved.id))) {
      equipped = saved;
    } else {
      final fromServer = AvatarCatalog.tryFindByPathOrFilename(serverAvatarUrl);
      if (fromServer != null) equipped = fromServer;
    }

    _ownedAvatarIds
      ..clear()
      ..addAll(owned);
    _equippedAvatar = equipped;
    _loading = false;
    notifyListeners();
  }

  void _resetToDefaults() {
    _equippedAvatar = AvatarCatalog.starterAvatar;
    _ownedAvatarIds
      ..clear()
      ..add(AvatarCatalog.starterAvatar.id);
  }

  // ── Queries ──────────────────────────────────────────────────────────

  /// Checks if an avatar is owned by the student.
  /// Free starter is always owned.
  bool isOwned(AvatarItem item) {
    if (item.isFree || item.id == AvatarCatalog.starterAvatar.id) return true;
    return _ownedAvatarIds.contains(item.id);
  }

  /// Checks if an avatar is currently equipped.
  bool isEquipped(AvatarItem item) {
    return _equippedAvatar.id == item.id;
  }

  /// Checks if student has enough coins for this avatar.
  bool canAfford(AvatarItem item, int studentCoins) {
    return studentCoins >= item.price;
  }

  // ── Mutations ────────────────────────────────────────────────────────

  Future<bool> _writePrefs(
    String uid, {
    required Set<String> owned,
    required String equippedId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final okOwned = await prefs.setStringList(ownedKeyFor(uid), owned.toList());
      final okEquipped = await prefs.setString(equippedKeyFor(uid), equippedId);
      return okOwned && okEquipped;
    } catch (e) {
      debugPrint('[AvatarShopService] save error for $uid: $e');
      return false;
    }
  }

  /// Equips an owned avatar for free. Never touches coins.
  /// Returns false (and changes nothing) when the avatar is not owned, nobody
  /// is signed in, or the selection could not be saved.
  Future<bool> equipAvatar(
    AvatarItem item, {
    Future<void> Function(String avatarUrl)? onAvatarEquipped,
  }) async {
    final uid = _boundUid;
    if (uid == null || _loading) return false;
    if (!isOwned(item)) {
      debugPrint('[AvatarShopService] Cannot equip locked avatar: ${item.id}');
      return false;
    }

    final saved = await _writePrefs(
      uid,
      owned: _ownedAvatarIds,
      equippedId: item.id,
    );
    // The student may have signed out / switched while saving.
    if (!saved || _boundUid != uid) return false;

    _equippedAvatar = item;
    notifyListeners();
    await _syncServerAvatar(item, onAvatarEquipped);
    return true;
  }

  /// Purchases [item]: deducts its price exactly once, saves ownership and
  /// equips it, or changes nothing at all.
  ///
  /// Safety properties:
  /// - Single-flight: a second call while one is running returns
  ///   [AvatarPurchaseResult.busy] (repeated taps cannot double-charge).
  /// - Already-owned avatars are equipped for free and never charged.
  /// - The balance is read fresh via [readCurrentCoins] after the guard, not
  ///   from a stale value captured at tap time.
  /// - Ordering: ownership is saved durably FIRST, then coins are committed
  ///   via [commitCoins] (which must throw on failure). If the coin commit
  ///   fails, ownership is rolled back, so there is never a charge without
  ///   ownership. (A crash between the two steps can only favour the student.)
  /// - Success is reported only after both steps succeeded.
  Future<AvatarPurchaseResult> purchaseAvatar({
    required AvatarItem item,
    required int Function() readCurrentCoins,
    required Future<void> Function(int newCoins) commitCoins,
    Future<void> Function(String avatarUrl)? onAvatarEquipped,
  }) async {
    final uid = _boundUid;
    if (uid == null || _loading) return AvatarPurchaseResult.notSignedIn;
    if (_purchaseInFlight) return AvatarPurchaseResult.busy;

    _purchaseInFlight = true;
    notifyListeners();
    try {
      if (isOwned(item)) {
        final equipped = await equipAvatar(item, onAvatarEquipped: onAvatarEquipped);
        return equipped
            ? AvatarPurchaseResult.alreadyOwned
            : AvatarPurchaseResult.failed;
      }

      final coins = readCurrentCoins();
      if (!canAfford(item, coins)) return AvatarPurchaseResult.insufficientCoins;

      final previousOwned = Set<String>.from(_ownedAvatarIds);
      final previousEquippedId = _equippedAvatar.id;
      final newOwned = <String>{...previousOwned, item.id};

      // 1. Durable ownership + selection first.
      final saved = await _writePrefs(uid, owned: newOwned, equippedId: item.id);
      if (!saved) return AvatarPurchaseResult.failed;
      if (_boundUid != uid) {
        await _writePrefs(uid, owned: previousOwned, equippedId: previousEquippedId);
        return AvatarPurchaseResult.failed;
      }

      // 2. Commit the coin deduction; roll ownership back if it fails.
      try {
        await commitCoins(coins - item.price);
      } catch (e) {
        debugPrint('[AvatarShopService] coin commit failed, rolling back: $e');
        await _writePrefs(uid, owned: previousOwned, equippedId: previousEquippedId);
        return AvatarPurchaseResult.failed;
      }

      // 3. Both durable steps succeeded - publish to the UI.
      if (_boundUid == uid) {
        _ownedAvatarIds
          ..clear()
          ..addAll(newOwned);
        _equippedAvatar = item;
        notifyListeners();
      }
      await _syncServerAvatar(item, onAvatarEquipped);
      return AvatarPurchaseResult.success;
    } finally {
      _purchaseInFlight = false;
      notifyListeners();
    }
  }

  /// Best-effort sync of the equipped avatar to the student's server profile.
  /// The local per-student record is authoritative, so a failure here never
  /// fails a purchase or an equip.
  Future<void> _syncServerAvatar(
    AvatarItem item,
    Future<void> Function(String avatarUrl)? onAvatarEquipped,
  ) async {
    if (onAvatarEquipped == null) return;
    try {
      await onAvatarEquipped(item.assetPath);
    } catch (e) {
      debugPrint('[AvatarShopService] Error syncing avatarUrl: $e');
    }
  }
}
