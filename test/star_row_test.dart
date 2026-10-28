import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mathalino_student_app/core/theme/mathalino_tokens.dart';
import 'package:mathalino_student_app/widgets/level_node.dart';
import 'package:mathalino_student_app/widgets/star_row.dart';
import 'package:mathalino_student_app/providers/level_progress_provider.dart';

/// A preview widget displaying the 0, 1, 2, and 3 star states side by side,
/// both as standalone [StarRow] badges and in full [LevelNode] completed nodes.
class StarRowPreviewScreen extends StatelessWidget {
  const StarRowPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: AppTokens.fontNunito),
      home: Scaffold(
        backgroundColor: AppTokens.background,
        appBar: AppBar(
          title: const Text('Star Rating Trophy Redesign Preview'),
          backgroundColor: AppTokens.primaryIndigo,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Standalone StarRow Badges (0, 1, 2, 3 stars)',
                style: AppTokens.baloo2(
                  fontSize: 18,
                  color: AppTokens.headingIndigo,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('0 Stars', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 6),
                      StarRow(stars: 0),
                    ],
                  ),
                  Column(
                    children: [
                      Text('1 Star', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 6),
                      StarRow(stars: 1),
                    ],
                  ),
                  Column(
                    children: [
                      Text('2 Stars', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 6),
                      StarRow(stars: 2),
                    ],
                  ),
                  Column(
                    children: [
                      Text('3 Stars (Glow)', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 6),
                      StarRow(stars: 3),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                'Completed Level Nodes on Map (0, 1, 2, 3 stars)',
                style: AppTokens.baloo2(
                  fontSize: 18,
                  color: AppTokens.headingIndigo,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Level 1 (0★)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      LevelNode(
                        levelNumber: 1,
                        state: LevelState.completed,
                        stars: 0,
                        onTap: () {},
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Level 2 (1★)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      LevelNode(
                        levelNumber: 2,
                        state: LevelState.completed,
                        stars: 1,
                        onTap: () {},
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Level 3 (2★)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      LevelNode(
                        levelNumber: 3,
                        state: LevelState.completed,
                        stars: 2,
                        onTap: () {},
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Level 4 (3★)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      LevelNode(
                        levelNumber: 4,
                        state: LevelState.completed,
                        stars: 3,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('StarRow Widget & Visual Tests', () {
    testWidgets(
      'renders 0, 1, 2, and 3 star states side-by-side in preview screen',
      (tester) async {
        await tester.pumpWidget(const StarRowPreviewScreen());
        await tester.pumpAndSettle();

        // 4 standalone StarRow + 4 in LevelNodes = 8 StarRow widgets
        expect(find.byType(StarRow), findsNWidgets(8));

        // Standalone StarRow widgets have their own semantics
        expect(find.bySemanticsLabel('0 of 3 stars'), findsOneWidget);
        expect(find.bySemanticsLabel('1 of 3 stars'), findsOneWidget);
        expect(find.bySemanticsLabel('2 of 3 stars'), findsOneWidget);
        expect(find.bySemanticsLabel('3 of 3 stars'), findsOneWidget);

        // LevelNode completed nodes have integrated semantics
        expect(
          find.bySemanticsLabel('Level 1, completed, 0 of 3 stars'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Level 2, completed, 1 of 3 stars'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Level 3, completed, 2 of 3 stars'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Level 4, completed, 3 of 3 stars'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LevelNode completed renders green circle, stars directly below, and number below stars',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: LevelNode(
                  levelNumber: 7,
                  state: LevelState.completed,
                  stars: 2,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Node check icon is present
        expect(find.byIcon(Icons.check), findsOneWidget);
        // StarRow is present
        expect(find.byType(StarRow), findsOneWidget);
        // Level number '7' is present
        expect(find.text('7'), findsOneWidget);

        // Check vertical order: circle top < stars top < level number top
        final circleFinder = find.byIcon(Icons.check);
        final starRowFinder = find.byType(StarRow);
        final numberFinder = find.text('7');

        final circlePos = tester.getCenter(circleFinder);
        final starRowPos = tester.getCenter(starRowFinder);
        final numberPos = tester.getCenter(numberFinder);

        expect(
          circlePos.dy < starRowPos.dy,
          isTrue,
          reason: 'Stars must be below the circle',
        );
        expect(
          starRowPos.dy < numberPos.dy,
          isTrue,
          reason: 'Level number must be below the stars',
        );
      },
    );

    testWidgets('Locked LevelNode does not render StarRow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LevelNode(
                levelNumber: 15,
                state: LevelState.locked,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StarRow), findsNothing);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('StarRow animateNew runs elastic animation without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: StarRow(stars: 3, animateNew: true))),
        ),
      );

      // Pump initial frame
      await tester.pump();
      // Pump halfway through stagger and elastic pop
      await tester.pump(const Duration(milliseconds: 300));
      // Settle full animation
      await tester.pumpAndSettle();

      expect(find.byType(StarRow), findsOneWidget);
    });

    testWidgets('StarRow respects reduced motion (disableAnimations = true)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: StarRow(stars: 3, animateNew: true)),
            ),
          ),
        ),
      );

      // Even with animateNew: true, disableAnimations should settle immediately
      await tester.pump();
      expect(find.byType(StarRow), findsOneWidget);
    });

    test('StarPainter builds a valid 5-point rounded star path', () {
      final path = StarPainter.buildStarPath(28.0);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('StarPainter builds a valid 4-point diamond sparkle path', () {
      final path = StarPainter.buildSparklePath(Offset.zero, 4.0);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });
  });
}
