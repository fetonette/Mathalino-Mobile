import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mathalino_student_app/core/models/avatar_item.dart';
import 'package:mathalino_student_app/core/models/student_profile.dart';
import 'package:mathalino_student_app/core/services/auth_service.dart';
import 'package:mathalino_student_app/core/services/avatar_shop_service.dart';
import 'package:mathalino_student_app/providers/learn_provider.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';
import 'package:mathalino_student_app/screens/student/avatar_shop_screen.dart';
import 'package:mathalino_student_app/widgets/avatar_session_binder.dart';

/// Minimal in-memory stand-in for the student's server-side coin balance.
class _Wallet {
  int coins;
  int commits = 0;
  _Wallet(this.coins);
}

Future<AvatarPurchaseResult> _buy(
  AvatarShopService service,
  AvatarItem item,
  _Wallet wallet, {
  Future<void> Function(int newCoins)? commit,
}) {
  return service.purchaseAvatar(
    item: item,
    readCurrentCoins: () => wallet.coins,
    commitCoins: commit ??
        (newCoins) async {
          wallet.commits++;
          wallet.coins = newCoins;
        },
  );
}

class _AuthDouble extends ChangeNotifier implements AuthService {
  StudentProfile? _profile;
  _AuthDouble(this._profile);

  void signOut() {
    _profile = null;
    notifyListeners();
  }

  void signIn(StudentProfile p) {
    _profile = p;
    notifyListeners();
  }

  @override
  StudentProfile? get studentProfile => _profile;

  @override
  Future<void> persistCoinBalance({
    required String forUid,
    required int newCoins,
  }) async {
    if (_profile == null || _profile!.uid != forUid) {
      throw StateError('refused');
    }
    _profile = _profile!.copyWith(stats: _profile!.stats.copyWith(coins: newCoins));
    notifyListeners();
  }

  @override
  Future<void> updateAvatarUrl(String avatarUrl) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(avatarUrl: avatarUrl);
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProgressDouble extends ChangeNotifier implements LevelProgressProvider {
  @override
  StudentProfile? get studentProfile => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudentProfile _student(String uid, {int coins = 175, String avatarUrl = ''}) {
  return StudentProfile(
    uid: uid,
    lrn: '123456789018',
    displayName: 'Test $uid',
    gradeLevel: 4,
    assignedCategory: 'Intermediate',
    currentLevel: 15,
    startingLevel: 1,
    diagnosticCompleted: true,
    verificationCode: 'MTH-1234',
    stats: StudentStats(coins: coins, totalXp: 500),
    usedQuestionsHistory: const [],
    avatarUrl: avatarUrl,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AvatarItem girl50;
  late AvatarItem girl150;
  late AvatarItem boy100;
  late AvatarItem bulb;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarShopService.resetForTesting();
    girl50 = AvatarCatalog.findById('girl_50');
    girl150 = AvatarCatalog.findById('girl_150');
    boy100 = AvatarCatalog.findById('boy_100');
    bulb = AvatarCatalog.findById('item_bulb_100');
  });

  /// Simulates killing and relaunching the app: a brand-new service instance,
  /// while SharedPreferences (disk) is kept.
  AvatarShopService restart() {
    AvatarShopService.resetForTesting();
    return AvatarShopService.instance;
  }

  group('Batch 10B — Purchase & persistence', () {
    test('1. Purchase deducts the price exactly once', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(175);

      final r = await _buy(s, girl50, wallet);

      expect(r, AvatarPurchaseResult.success);
      expect(wallet.coins, 125);
      expect(wallet.commits, 1);
    });

    test('2. Purchased ownership persists across restart', () async {
      var s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      await _buy(s, girl50, _Wallet(175));

      s = restart();
      await s.bindStudent('stu-1');

      expect(s.isOwned(girl50), isTrue);
    });

    test('3+4. Equipped avatar persists across restart (the reported bug)', () async {
      var s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      await _buy(s, girl50, _Wallet(175));
      expect(s.equippedAvatar.id, 'girl_50');

      s = restart();
      // Before binding, a fresh process shows the default - this is exactly the
      // state the app was stuck in because nothing ever loaded the saved data.
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);

      await s.bindStudent('stu-1');
      expect(s.equippedAvatar.id, 'girl_50');
    });

    test('3b. Equipping a different owned avatar persists across restart', () async {
      var s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(500);
      await _buy(s, girl50, wallet);
      await _buy(s, boy100, wallet);
      expect(await s.equipAvatar(girl50), isTrue);

      s = restart();
      await s.bindStudent('stu-1');

      expect(s.equippedAvatar.id, 'girl_50');
      expect(s.isOwned(boy100), isTrue);
    });

    test('5. Logout then login keeps ownership and equipped avatar', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      await _buy(s, girl50, _Wallet(175));

      s.unbind();
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
      expect(s.isOwned(girl50), isFalse);

      await s.bindStudent('stu-1');
      expect(s.equippedAvatar.id, 'girl_50');
      expect(s.isOwned(girl50), isTrue);
    });

    test('5b. A different student on the same device never inherits the avatar', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      await _buy(s, girl50, _Wallet(175));

      s.unbind();
      await s.bindStudent('stu-2');

      expect(s.isOwned(girl50), isFalse);
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
    });

    test('6. Re-equipping an owned avatar never deducts coins', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(175);
      await _buy(s, girl50, wallet);
      await s.equipAvatar(AvatarCatalog.starterAvatar);
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
      final coinsBefore = wallet.coins;
      final commitsBefore = wallet.commits;

      // Equip path
      expect(await s.equipAvatar(girl50), isTrue);
      // "Buy" path on an owned avatar must also be free
      final r = await _buy(s, girl50, wallet);

      expect(r, AvatarPurchaseResult.alreadyOwned);
      expect(wallet.coins, coinsBefore);
      expect(wallet.commits, commitsBefore);
      expect(s.equippedAvatar.id, 'girl_50');
    });

    test('7. Repeated purchase taps cannot charge twice', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(175);
      final gate = Completer<void>();

      // First tap: commit is held open (slow network).
      final first = _buy(s, girl50, wallet, commit: (n) async {
        await gate.future;
        wallet.commits++;
        wallet.coins = n;
      });
      await Future<void>.delayed(Duration.zero);
      expect(s.isPurchasing, isTrue);

      // Extra taps while the first is in flight are rejected without effect.
      final second = await _buy(s, girl50, wallet);
      final third = await _buy(s, boy100, wallet);
      expect(second, AvatarPurchaseResult.busy);
      expect(third, AvatarPurchaseResult.busy);

      gate.complete();
      expect(await first, AvatarPurchaseResult.success);

      // A tap after completion is a free equip, not a second charge.
      expect(await _buy(s, girl50, wallet), AvatarPurchaseResult.alreadyOwned);
      expect(wallet.commits, 1);
      expect(wallet.coins, 125);
      expect(s.isOwned(boy100), isFalse);
    });

    test('8a. Failed coin commit: no false success, no ownership, no partial state', () async {
      var s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(175);

      final r = await _buy(s, girl50, wallet, commit: (_) async {
        throw Exception('network down');
      });

      expect(r, AvatarPurchaseResult.failed);
      expect(wallet.coins, 175);
      expect(s.isOwned(girl50), isFalse);
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
      expect(s.isPurchasing, isFalse);

      // Rolled back on disk too: nothing is owned after a restart.
      s = restart();
      await s.bindStudent('stu-1');
      expect(s.isOwned(girl50), isFalse);
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);

      // And the student can still buy it successfully afterwards (charged once).
      expect(await _buy(s, girl50, wallet), AvatarPurchaseResult.success);
      expect(wallet.coins, 125);
    });

    test('8b. Insufficient coins: nothing changes', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(30);

      final r = await _buy(s, girl50, wallet);

      expect(r, AvatarPurchaseResult.insufficientCoins);
      expect(wallet.coins, 30);
      expect(wallet.commits, 0);
      expect(s.isOwned(girl50), isFalse);
    });

    test('8c. Balance is read fresh at purchase time, not captured at tap time', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(500);
      await _buy(s, boy100, wallet); // wallet is now 400

      final r = await _buy(s, girl150, wallet); // must use 400, not a stale 500

      expect(r, AvatarPurchaseResult.success);
      expect(wallet.coins, 250);
    });

    test('8d. Purchase is refused when nobody is signed in', () async {
      final s = AvatarShopService.instance;
      final wallet = _Wallet(500);

      expect(await _buy(s, girl50, wallet), AvatarPurchaseResult.notSignedIn);
      expect(wallet.commits, 0);
      expect(wallet.coins, 500);
    });

    test('9. Free headlogo is the default only when there is no saved selection', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
      expect(s.isOwned(AvatarCatalog.starterAvatar), isTrue);

      await _buy(s, girl50, _Wallet(175));
      final s2 = restart();
      await s2.bindStudent('stu-1');
      expect(s2.equippedAvatar.id, 'girl_50'); // saved selection wins
      expect(s2.isOwned(AvatarCatalog.starterAvatar), isTrue); // still free
    });

    test('10. Boy, Girl and Math Buddy avatars are all purchasable by any student', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      final wallet = _Wallet(1000);

      expect(await _buy(s, girl50, wallet), AvatarPurchaseResult.success);
      expect(await _buy(s, boy100, wallet), AvatarPurchaseResult.success);
      expect(await _buy(s, bulb, wallet), AvatarPurchaseResult.success);
      expect(wallet.coins, 1000 - 50 - 100 - 100);
    });
  });

  group('Batch 10B — Loading never overwrites a saved selection', () {
    test('Profile refreshes for the same student do not re-bind or reset', () async {
      final s = AvatarShopService.instance;
      await s.syncSession(uid: 'stu-1', serverAvatarUrl: '');
      await _buy(s, girl50, _Wallet(175));

      // A refreshed profile (e.g. coin update) carries a stale/empty avatar_url.
      await s.syncSession(uid: 'stu-1', serverAvatarUrl: '');
      await s.syncSession(uid: 'stu-1', serverAvatarUrl: 'assets/avatar/headlogo.png');

      expect(s.equippedAvatar.id, 'girl_50');
      expect(s.isOwned(girl50), isTrue);
    });

    test('Saved selection beats the server avatar_url', () async {
      var s = AvatarShopService.instance;
      await s.bindStudent('stu-1');
      await _buy(s, girl50, _Wallet(175));

      s = restart();
      await s.bindStudent('stu-1', serverAvatarUrl: 'assets/avatar/headlogo.png');

      expect(s.equippedAvatar.id, 'girl_50');
    });

    test('Server avatar_url is shown when there is no saved selection, but grants NO ownership', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1', serverAvatarUrl: 'assets/avatar/50(Girl).png');

      expect(s.equippedAvatar.id, 'girl_50');
      expect(s.isOwned(girl50), isFalse);

      // Nothing was persisted from the unverified server value.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(AvatarShopService.ownedKeyFor('stu-1')), isNull);
      expect(prefs.getString(AvatarShopService.equippedKeyFor('stu-1')), isNull);
    });

    test('Unknown server avatar_url falls back to the free starter', () async {
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1', serverAvatarUrl: 'https://example.com/x.png');
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
    });

    test('A superseded bind (fast account switch) is discarded', () async {
      SharedPreferences.setMockInitialValues({
        AvatarShopService.ownedKeyFor('stu-A'): ['girl_50'],
        AvatarShopService.equippedKeyFor('stu-A'): 'girl_50',
      });
      final s = AvatarShopService.instance;

      final bindA = s.bindStudent('stu-A');
      final bindB = s.bindStudent('stu-B');
      await Future.wait([bindA, bindB]);

      expect(s.boundUid, 'stu-B');
      expect(s.isOwned(girl50), isFalse);
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
    });

    test('Legacy un-scoped keys are never read (10A preview unlocks were free)', () async {
      SharedPreferences.setMockInitialValues({
        'mathalino_preview_owned_ids': ['girl_50', 'boy_100'],
        'mathalino_equipped_avatar_id': 'girl_50',
      });
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');

      expect(s.isOwned(girl50), isFalse);
      expect(s.isOwned(boy100), isFalse);
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
    });

    test('Corrupt saved ids are ignored; saved equipped must be owned or free', () async {
      SharedPreferences.setMockInitialValues({
        AvatarShopService.ownedKeyFor('stu-1'): ['not_an_avatar'],
        AvatarShopService.equippedKeyFor('stu-1'): 'girl_250', // not owned
      });
      final s = AvatarShopService.instance;
      await s.bindStudent('stu-1');

      expect(s.ownedAvatarIds, {AvatarCatalog.starterAvatar.id});
      expect(s.equippedAvatar.id, AvatarCatalog.starterAvatar.id);
    });
  });

  group('Batch 10B — Identifier resolution', () {
    test('Every catalog avatar resolves to itself by path and by filename', () {
      for (final a in AvatarCatalog.allAvatars) {
        expect(AvatarCatalog.tryFindByPathOrFilename(a.assetPath)?.id, a.id,
            reason: 'path ${a.assetPath}');
        expect(AvatarCatalog.tryFindByPathOrFilename(a.filename)?.id, a.id,
            reason: 'filename ${a.filename}');
      }
    });

    test('150(Girl).png is not mistaken for 50(Girl).png (suffix-match bug)', () {
      expect(AvatarCatalog.findByPathOrFilename('assets/avatar/150(Girl).png').id, 'girl_150');
      expect(AvatarCatalog.findByPathOrFilename('assets/avatar/50(Girl).png').id, 'girl_50');
    });

    test('Unknown or empty values resolve to null (strict) or starter (lenient)', () {
      expect(AvatarCatalog.tryFindByPathOrFilename(''), isNull);
      expect(AvatarCatalog.tryFindByPathOrFilename('assets/avatar/nope.png'), isNull);
      expect(AvatarCatalog.findByPathOrFilename('').id, AvatarCatalog.starterAvatar.id);
    });
  });

  group('Batch 10B — App wiring (session binder + shop screen)', () {
    Widget app(_AuthDouble auth) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<LevelProgressProvider>.value(value: _ProgressDouble()),
          ChangeNotifierProvider<LearnProvider>(create: (_) => LearnProvider()),
          ChangeNotifierProvider.value(value: AvatarShopService.instance),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              AvatarSessionBinder(child: child ?? const SizedBox.shrink()),
          home: const AvatarShopScreen(),
        ),
      );
    }

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('Buy in the UI, restart the app, avatar is still equipped and owned', (tester) async {
      phone(tester);
      var auth = _AuthDouble(_student('stu-1', coins: 175));
      await tester.pumpWidget(app(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sparkle Girl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy & Equip (50 Coins)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buy & Equip'));
      await tester.pumpAndSettle();

      expect(find.textContaining('50 coins deducted'), findsOneWidget);
      expect(auth.studentProfile!.stats.coins, 125);
      expect(AvatarShopService.instance.equippedAvatar.id, 'girl_50');

      // ── Restart: tear the tree down, fresh process-level state, same disk. ──
      await tester.pumpWidget(const SizedBox());
      AvatarShopService.resetForTesting();
      expect(AvatarShopService.instance.equippedAvatar.id, AvatarCatalog.starterAvatar.id);

      // Server returns the already-deducted balance; avatar_url may even be empty.
      auth = _AuthDouble(_student('stu-1', coins: 125));
      await tester.pumpWidget(app(auth));
      await tester.pumpAndSettle();

      expect(AvatarShopService.instance.equippedAvatar.id, 'girl_50');
      expect(AvatarShopService.instance.isOwned(girl50), isTrue);
      expect(auth.studentProfile!.stats.coins, 125, reason: 'Loading must not change coins');
      // Grid card shows Sparkle Girl as EQUIPPED, and tapping it opens the modal
      // showing "✓ Currently equipped".
      expect(find.text('Sparkle Girl'), findsWidgets);
      expect(find.text('EQUIPPED'), findsOneWidget);
      await tester.tap(find.text('Sparkle Girl'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('✓ Currently equipped'), findsOneWidget);
    });

    testWidgets('Logout clears the avatar from view; login restores it', (tester) async {
      phone(tester);
      final auth = _AuthDouble(_student('stu-1', coins: 175));
      await tester.pumpWidget(app(auth));
      await tester.pumpAndSettle();
      await AvatarShopService.instance.equipAvatar(AvatarCatalog.starterAvatar);
      await _buy(AvatarShopService.instance, girl50, _Wallet(175));
      expect(AvatarShopService.instance.equippedAvatar.id, 'girl_50');

      auth.signOut();
      await tester.pumpAndSettle();
      expect(AvatarShopService.instance.boundUid, isNull);
      expect(AvatarShopService.instance.equippedAvatar.id, AvatarCatalog.starterAvatar.id);

      auth.signIn(_student('stu-1', coins: 125));
      await tester.pumpAndSettle();
      expect(AvatarShopService.instance.boundUid, 'stu-1');
      expect(AvatarShopService.instance.equippedAvatar.id, 'girl_50');
    });

    testWidgets('Re-equipping an owned avatar in the UI never changes coins', (tester) async {
      phone(tester);
      final auth = _AuthDouble(_student('stu-1', coins: 175));
      await tester.pumpWidget(app(auth));
      await tester.pumpAndSettle();
      await _buy(AvatarShopService.instance, girl50, _Wallet(175));
      await AvatarShopService.instance.equipAvatar(AvatarCatalog.starterAvatar);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sparkle Girl'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Equip Avatar'));
      await tester.pumpAndSettle();

      expect(AvatarShopService.instance.equippedAvatar.id, 'girl_50');
      expect(auth.studentProfile!.stats.coins, 175);
    });
  });
}

