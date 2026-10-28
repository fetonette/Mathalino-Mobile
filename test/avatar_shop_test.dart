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
import 'package:mathalino_student_app/screens/student/adventure_sections.dart';
import 'package:mathalino_student_app/screens/student/avatar_shop_screen.dart';
import 'package:mathalino_student_app/widgets/home/home_widgets.dart';
import 'package:mathalino_student_app/widgets/avatar_session_binder.dart';

// Test doubles for AuthService and LevelProgressProvider
class TestAuthService extends ChangeNotifier implements AuthService {
  StudentProfile? _profile;

  TestAuthService([this._profile]);

  @override
  StudentProfile? get studentProfile => _profile;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> updateCoins(int newCoins) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(
        stats: _profile!.stats.copyWith(coins: newCoins),
      );
      notifyListeners();
    }
  }

  @override
  Future<void> persistCoinBalance({
    required String forUid,
    required int newCoins,
  }) async {
    if (_profile == null || _profile!.uid != forUid) {
      throw StateError('Coin update refused: not the authenticated student.');
    }
    _profile = _profile!.copyWith(
      stats: _profile!.stats.copyWith(coins: newCoins),
    );
    notifyListeners();
  }

  @override
  Future<void> updateAvatarUrl(String avatarUrl) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(
        avatarUrl: avatarUrl,
      );
      notifyListeners();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestLevelProgressProvider extends ChangeNotifier implements LevelProgressProvider {
  @override
  int get currentLevel => 15;

  @override
  int get totalStars => 40;

  @override
  bool get isLoading => false;

  @override
  StudentProfile? get studentProfile => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildTestApp({
  required Widget child,
  StudentProfile? profile,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(
        create: (_) => TestAuthService(profile),
      ),
      ChangeNotifierProvider<LevelProgressProvider>(
        create: (_) => TestLevelProgressProvider(),
      ),
      ChangeNotifierProvider<LearnProvider>(
        create: (_) => LearnProvider(),
      ),
      ChangeNotifierProvider.value(
        value: AvatarShopService.instance,
      ),
    ],
    child: MaterialApp(
      // Exercises the real session binder so the saved avatar loads for the
      // signed-in test student, exactly like the production app.
      builder: (context, child) =>
          AvatarSessionBinder(child: child ?? const SizedBox.shrink()),
      home: Scaffold(body: child),
      routes: {
        '/avatar_shop': (context) => const AvatarShopScreen(),
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarShopService.resetForTesting();
  });

  group('Batch 10A — Avatar Catalog & Assets', () {
    test('Catalog contains all 20 expected avatars with exact filenames and prices', () {
      final avatars = AvatarCatalog.allAvatars;
      expect(avatars.length, 20);

      // Free starter
      final starter = AvatarCatalog.starterAvatar;
      expect(starter.filename, 'headlogo.png');
      expect(starter.price, 0);
      expect(starter.isFree, isTrue);
      expect(starter.isAssetAvailable, isTrue);

      // Girl avatars
      final g50 = AvatarCatalog.findById('girl_50');
      expect(g50.filename, '50(Girl).png');
      expect(g50.price, 50);
      expect(g50.category, AvatarCategory.girl);
      expect(g50.isAssetAvailable, isTrue);

      final g100 = AvatarCatalog.findById('girl_100');
      expect(g100.filename, '100(girl).png');
      expect(g100.price, 100);
      expect(g100.category, AvatarCategory.girl);
      expect(g100.isAssetAvailable, isTrue);

      final g150 = AvatarCatalog.findById('girl_150');
      expect(g150.filename, '150(Girl).png');
      expect(g150.price, 150);
      expect(g150.category, AvatarCategory.girl);
      expect(g150.isAssetAvailable, isTrue);

      final g200 = AvatarCatalog.findById('girl_200');
      expect(g200.filename, '200(girl).png');
      expect(g200.price, 200);
      expect(g200.category, AvatarCategory.girl);
      expect(g200.isAssetAvailable, isTrue);

      final g250 = AvatarCatalog.findById('girl_250');
      expect(g250.filename, '250(girl).png');
      expect(g250.price, 250);
      expect(g250.category, AvatarCategory.girl);
      expect(g250.isAssetAvailable, isTrue);

      // Boy avatars
      final b100 = AvatarCatalog.findById('boy_100');
      expect(b100.filename, '100(boy).png');
      expect(b100.price, 100);
      expect(b100.category, AvatarCategory.boy);
      expect(b100.isAssetAvailable, isTrue);

      final b150 = AvatarCatalog.findById('boy_150');
      expect(b150.filename, '150(boy).png');
      expect(b150.price, 150);
      expect(b150.category, AvatarCategory.boy);
      expect(b150.isAssetAvailable, isTrue);

      final b200 = AvatarCatalog.findById('boy_200');
      expect(b200.filename, '200(boy).png');
      expect(b200.price, 200);
      expect(b200.category, AvatarCategory.boy);
      expect(b200.isAssetAvailable, isTrue);

      final b250 = AvatarCatalog.findById('boy_250');
      expect(b250.filename, '250(boy).png');
      expect(b250.price, 250);
      expect(b250.category, AvatarCategory.boy);
      expect(b250.isAssetAvailable, isTrue);

      // Math Buddies
      final bulb = AvatarCatalog.findById('item_bulb_100');
      expect(bulb.filename, '100(bulb).png');
      expect(bulb.price, 100);
      expect(bulb.category, AvatarCategory.mathBuddies);

      final ruler = AvatarCatalog.findById('item_ruler_100');
      expect(ruler.filename, '100(ruler).png');
      expect(ruler.price, 100);
      expect(ruler.category, AvatarCategory.mathBuddies);

      final plus = AvatarCatalog.findById('item_plus_150');
      expect(plus.filename, '150(plus).png');
      expect(plus.price, 150);
      expect(plus.category, AvatarCategory.mathBuddies);

      final minus = AvatarCatalog.findById('item_minus_150');
      expect(minus.filename, '150(minus).png');
      expect(minus.price, 150);
      expect(minus.category, AvatarCategory.mathBuddies);

      final times = AvatarCatalog.findById('item_times_150');
      expect(times.filename, '150(times).png');
      expect(times.price, 150);
      expect(times.category, AvatarCategory.mathBuddies);

      final divide = AvatarCatalog.findById('item_divide_150');
      expect(divide.filename, '150(divide).png');
      expect(divide.price, 150);
      expect(divide.category, AvatarCategory.mathBuddies);

      final star = AvatarCatalog.findById('item_star_150');
      expect(star.filename, '150(star).png');
      expect(star.price, 150);
      expect(star.category, AvatarCategory.mathBuddies);

      final pencil = AvatarCatalog.findById('item_pencil_200');
      expect(pencil.filename, '200(pencil).png');
      expect(pencil.price, 200);
      expect(pencil.category, AvatarCategory.mathBuddies);

      final eraser = AvatarCatalog.findById('item_eraser_200');
      expect(eraser.filename, '200(eraser).png');
      expect(eraser.price, 200);
      expect(eraser.category, AvatarCategory.mathBuddies);

      final calculator = AvatarCatalog.findById('item_calculator_200');
      expect(calculator.filename, '200(calculator).png');
      expect(calculator.price, 200);
      expect(calculator.category, AvatarCategory.mathBuddies);
    });

    test('Filtering by category returns accurate subsets', () {
      final all = AvatarCatalog.getFiltered(AvatarCategory.all);
      expect(all.length, 20);

      final characters = AvatarCatalog.getFiltered(AvatarCategory.characters);
      expect(characters.length, 9);

      final mathBuddies = AvatarCatalog.getFiltered(AvatarCategory.mathBuddies);
      expect(mathBuddies.length, 10);
      expect(mathBuddies.every((a) => a.category == AvatarCategory.mathBuddies), isTrue);

      final girls = AvatarCatalog.getFiltered(AvatarCategory.girl);
      expect(girls.length, 5);
      expect(girls.every((a) => a.category == AvatarCategory.girl), isTrue);

      final boys = AvatarCatalog.getFiltered(AvatarCategory.boy);
      expect(boys.length, 4);
      expect(boys.every((a) => a.category == AvatarCategory.boy), isTrue);
    });
  });

  group('Batch 10A — AvatarShopService & Safety', () {
    test('Free starter avatar is owned and equipped by default', () {
      final service = AvatarShopService.instance;
      expect(service.isOwned(AvatarCatalog.starterAvatar), isTrue);
      expect(service.isEquipped(AvatarCatalog.starterAvatar), isTrue);
    });

    test('Locked avatar is not owned by default', () {
      final service = AvatarShopService.instance;
      final g50 = AvatarCatalog.findById('girl_50');
      expect(service.isOwned(g50), isFalse);
      expect(service.isEquipped(g50), isFalse);
    });

    test('Affordability check correctly evaluates student coin balance', () {
      final service = AvatarShopService.instance;
      final g50 = AvatarCatalog.findById('girl_50'); // 50 coins

      expect(service.canAfford(g50, 40), isFalse);
      expect(service.canAfford(g50, 50), isTrue);
      expect(service.canAfford(g50, 100), isTrue);
    });
    // Purchase / persistence / safety behaviour is covered in
    // test/batch_10b_avatar_persistence_test.dart.
  });

  group('Batch 10A — Avatar Shop UI Widgets', () {
    final mockStudent = StudentProfile(
      uid: 'student_123',
      lrn: '123456789018',
      displayName: 'fettiz',
      gradeLevel: 4,
      assignedCategory: 'Intermediate',
      currentLevel: 15,
      startingLevel: 1,
      diagnosticCompleted: true,
      verificationCode: 'MTH-1234',
      stats: const StudentStats(coins: 175, totalXp: 500),
      usedQuestionsHistory: const [],
    );

    testWidgets('AvatarShopScreen renders title, coin balance, preview card, and filter chips', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      // Title & Coins
      expect(find.text('Avatar Shop'), findsOneWidget);
      expect(find.text('175'), findsOneWidget); // Student coins

      // Equipped starter card in grid
      expect(find.text('Starter Logo'), findsWidgets);
      expect(find.text('EQUIPPED'), findsOneWidget);

      // Tapping the avatar card opens the preview modal
      await tester.tap(find.text('Starter Logo'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('FREE STARTER'), findsOneWidget);
      expect(find.text('Equipped'), findsOneWidget);
      // Close the modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Temporary notice banner removed
      expect(find.textContaining('Batch 10A Preview'), findsNothing);

      // Filters
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Characters'), findsOneWidget);
      expect(find.text('Math Buddies'), findsOneWidget);
    });

    testWidgets('Switching category filter updates displayed avatars without restricting by Sex', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      // Tap Characters filter: subfilter pills appear
      await tester.tap(find.text('Characters'));
      await tester.pumpAndSettle();

      expect(find.text('All Characters'), findsOneWidget);
      expect(find.text('Boy'), findsOneWidget);
      expect(find.text('Girl'), findsOneWidget);

      // Tap Boy subfilter: only boy avatars appear
      await tester.tap(find.text('Boy'));
      await tester.pumpAndSettle();

      expect(find.text('Cool Boy'), findsOneWidget);
      expect(find.text('Sparkle Girl'), findsNothing);

      // Tap Girl subfilter: only girl avatars appear
      await tester.tap(find.text('Girl'));
      await tester.pumpAndSettle();

      expect(find.text('Sparkle Girl'), findsOneWidget);
      expect(find.text('Cool Boy'), findsNothing);

      // Tap Math Buddies filter: only math avatars appear
      await tester.tap(find.text('Math Buddies'));
      await tester.pumpAndSettle();

      expect(find.text('Bright Bulb'), findsOneWidget);
      expect(find.text('Cool Boy'), findsNothing);
      expect(find.text('Sparkle Girl'), findsNothing);

      // Tap All filter: avatars return
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Sparkle Girl'), findsOneWidget);
    });

    testWidgets('Tapping locked avatar previews it in the hero card', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      // Tap 50(Girl) Sparkle Girl in the grid
      await tester.tap(find.text('Sparkle Girl'));
      await tester.pumpAndSettle();

      // Preview hero updates to Sparkle Girl with price and Buy & Equip button
      expect(find.text('Buy & Equip (50 Coins)'), findsOneWidget);
    });

    testWidgets('Tapping Buy & Equip shows confirmation dialog and deducts coins exactly once', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      // Select affordable avatar (Sparkle Girl 50 coins, student has 175)
      await tester.tap(find.text('Sparkle Girl'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buy & Equip (50 Coins)'));
      await tester.pumpAndSettle();

      // Dialog appears with the real after-purchase balance
      expect(find.text('Buy Avatar'), findsOneWidget);
      expect(find.text('Price: 50 Coins'), findsOneWidget);
      expect(find.text('125 Coins'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Buy & Equip'));
      await tester.pumpAndSettle();

      // Success only after coins AND ownership saved: 175 - 50 = 125
      expect(find.textContaining('purchased and equipped'), findsOneWidget);
      expect(find.text('125'), findsOneWidget);
      expect(AvatarShopService.instance.isOwned(AvatarCatalog.findById('girl_50')), isTrue);
      expect(AvatarShopService.instance.isEquipped(AvatarCatalog.findById('girl_50')), isTrue);
    });

    testWidgets('Insufficient coins shows clear feedback and disables purchasing', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final poorStudent = StudentProfile(
        uid: 'student_456',
        lrn: '123456789018',
        displayName: 'fettiz',
        gradeLevel: 4,
        assignedCategory: 'Intermediate',
        currentLevel: 5,
        startingLevel: 1,
        diagnosticCompleted: true,
        verificationCode: 'MTH-1234',
        stats: const StudentStats(coins: 30, totalXp: 100), // Only 30 coins
        usedQuestionsHistory: const [],
      );

      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(),
        profile: poorStudent,
      ));
      await tester.pumpAndSettle();

      // Tap 50(Girl) Sparkle Girl (costs 50 coins, student has 30, needs 20)
      await tester.tap(find.text('Sparkle Girl'));
      await tester.pumpAndSettle();

      // Action button shows Need 20 More Coins
      expect(find.text('Need 20 More Coins'), findsOneWidget);

      // Tap disabled button triggers guidance snackbar
      await tester.tap(find.text('Need 20 More Coins'));
      await tester.pumpAndSettle();

      expect(find.textContaining('You need 20 more coins'), findsOneWidget);
    });

    testWidgets('AvatarShopScreen renders cleanly on 360px width without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Avatar Shop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdventureProfileView contains Avatar Shop button and tappable equipped avatar', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestApp(
        child: const AdventureProfileView(),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Avatar Shop'), findsOneWidget);
      expect(find.byIcon(Icons.palette_rounded), findsOneWidget);
    });

    testWidgets('HomeBottomNav renders 5 tabs including Avatar Shop at index 2', (tester) async {
      int tappedIndex = -1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomNav(
            selectedIndex: 2,
            onSelected: (idx) => tappedIndex = idx,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(HomeBottomNav.items.length, 5);
      expect(HomeBottomNav.items[0].label, 'Home');
      expect(HomeBottomNav.items[1].label, 'Learn');
      expect(HomeBottomNav.items[2].label, 'Avatar Shop');
      expect(HomeBottomNav.items[3].label, 'Progress');
      expect(HomeBottomNav.items[4].label, 'Profile');

      expect(find.text('Avatar Shop'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);

      await tester.tap(find.text('Avatar Shop'));
      expect(tappedIndex, 2);
    });

    testWidgets('HomeBottomNav renders cleanly on 360px width without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: HomeBottomNav(
            selectedIndex: 2,
            onSelected: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Avatar Shop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AvatarShopScreen hides back button when showBackButton is false', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const AvatarShopScreen(showBackButton: false),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Avatar Shop'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('AdventureProfileView triggers onNavigateToShop callback when tapped', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool shopNavigated = false;
      await tester.pumpWidget(buildTestApp(
        child: AdventureProfileView(
          onNavigateToShop: () => shopNavigated = true,
        ),
        profile: mockStudent,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avatar Shop'));
      expect(shopNavigated, isTrue);
    });

    testWidgets('HomeHeader displays equipped avatar in the top bar and handles onAvatarTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeHeader(
            name: 'Jia Lim',
            level: 36,
            coins: 100,
            xp: 200,
            stars: 50,
            onAvatarTap: () => tapped = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Jia Lim'), findsOneWidget);
      expect(find.text('Level 36'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });
}
