import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/mathalino_tokens.dart';
import '../../providers/diagnostic_provider.dart';
import 'diagnostic_screen.dart';

/// Welcome screen shown to students before their diagnostic assessment.
/// Features animated floating math tiles, waving mascot GIF, and styled white card.
class DiagnosticWelcomeScreen extends StatefulWidget {
  const DiagnosticWelcomeScreen({super.key});

  @override
  State<DiagnosticWelcomeScreen> createState() =>
      _DiagnosticWelcomeScreenState();
}

class _DiagnosticWelcomeScreenState extends State<DiagnosticWelcomeScreen>
    with TickerProviderStateMixin {
  late final List<AnimationController> _tileControllers;
  late final List<Animation<double>> _tileAnimations;

  // Tile animation config: [durationSec, delaySec]
  final _tileConfigs = const [
    (2.6, 0.0), // +
    (3.4, 0.6), // x
    (3.0, 1.2), // /
    (3.8, 1.8), // -
  ];

  @override
  void initState() {
    super.initState();
    _tileControllers = [];
    _tileAnimations = [];

    for (var i = 0; i < _tileConfigs.length; i++) {
      final config = _tileConfigs[i];
      final controller = AnimationController(
        duration: Duration(milliseconds: (config.$1 * 1000).round()),
        vsync: this,
      );

      final animation = Tween<double>(begin: 0.0, end: -8.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );

      _tileControllers.add(controller);
      _tileAnimations.add(animation);

      // Start with delay
      if (config.$2 > 0) {
        Future.delayed(
          Duration(milliseconds: (config.$2 * 1000).round()),
          () {
            if (mounted) {
              controller.repeat(reverse: true);
            }
          },
        );
      } else {
        controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _tileControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startAssessment(BuildContext context) {
    context.read<DiagnosticProvider>().resetDiagnostic();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const DiagnosticScreen(),
        settings: const RouteSettings(name: '/diagnostic'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = math.min(1.0, screenWidth / 390.0);

    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Hero Area: Floating tiles, stars, mascot
                  SizedBox(
                    height: 275 * scale,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Star 1 (Yellow)
                        Positioned(
                          left: 115 * scale,
                          top: 50 * scale,
                          child: Icon(
                            Icons.star_rounded,
                            size: 20 * scale,
                            color: const Color(0xFFFBBF24),
                          ),
                        ),

                        // Star 2 (Periwinkle)
                        Positioned(
                          left: 249 * scale,
                          top: 51 * scale,
                          child: Icon(
                            Icons.star_rounded,
                            size: 15 * scale,
                            color: const Color(0xFF818CF8),
                          ),
                        ),

                        // Floating Tile 1: + (left 64, top 99, tilt -12 deg)
                        _buildFloatingTile(
                          index: 0,
                          left: 64 * scale,
                          top: 99 * scale,
                          tiltDeg: -12,
                          color: const Color(0xFFFBBF24),
                          symbolColor: const Color(0xFF7C2D12),
                          symbol: '+',
                          disableMotion: disableMotion,
                          scale: scale,
                        ),

                        // Floating Tile 2: x (left 266, top 92, tilt 10 deg)
                        _buildFloatingTile(
                          index: 1,
                          left: 266 * scale,
                          top: 92 * scale,
                          tiltDeg: 10,
                          color: const Color(0xFF34D399),
                          symbolColor: const Color(0xFF064E3B),
                          symbol: '×',
                          disableMotion: disableMotion,
                          scale: scale,
                        ),

                        // Floating Tile 3: / (left 76, top 214, tilt 8 deg)
                        _buildFloatingTile(
                          index: 2,
                          left: 76 * scale,
                          top: 200 * scale,
                          tiltDeg: 8,
                          color: const Color(0xFF818CF8),
                          symbolColor: const Color(0xFF1E1B4B),
                          symbol: '÷',
                          disableMotion: disableMotion,
                          scale: scale,
                        ),

                        // Floating Tile 4: - (left 278, top 217, tilt -8 deg)
                        _buildFloatingTile(
                          index: 3,
                          left: 278 * scale,
                          top: 205 * scale,
                          tiltDeg: -8,
                          color: const Color(0xFF7DD3FC),
                          symbolColor: const Color(0xFF0C4A6E),
                          symbol: '−',
                          disableMotion: disableMotion,
                          scale: scale,
                        ),

                        // Mascot: mascot-hello.gif (centered, feet standing right above card)
                        Positioned(
                          top: 90 * scale,
                          child: SizedBox(
                            width: 120 * scale,
                            height: 185 * scale,
                            child: Image.asset(
                              'assets/mascots/mascot-hello.gif',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                'assets/mascots/mascot-hello.gif.gif',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                  'image/MLOGO.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main White Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFFE0E7FF),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFE0E7FF),
                          offset: Offset(0, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Greeting
                        Text(
                          'Hello, Student!',
                          textAlign: TextAlign.center,
                          style: AppTokens.baloo2(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.primaryIndigo,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 2. Subheading
                        Text(
                          "Let's find your math level",
                          textAlign: TextAlign.center,
                          style: AppTokens.baloo2(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.bodyText,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 3. Explanation body
                        Text(
                          'Answer 20 questions so we can choose the best starting point for your Mathalino adventure.',
                          textAlign: TextAlign.center,
                          style: AppTokens.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.secondaryText,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 4. Primary Button: Start Assessment
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [
                              BoxShadow(
                                color: AppTokens.primaryShadow,
                                offset: Offset(0, 6),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _startAssessment(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTokens.primaryIndigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Start Assessment',
                                  style: AppTokens.baloo2(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 5. Log out link
                        SizedBox(
                          height: 44,
                          child: TextButton.icon(
                            onPressed: () {
                              context
                                  .read<DiagnosticProvider>()
                                  .resetDiagnostic();
                              context.read<AuthService>().logout();
                            },
                            icon: const Icon(
                              Icons.logout_rounded,
                              size: 20,
                              color: Color(0xFF971E31),
                            ),
                            label: Text(
                              'Log out',
                              style: AppTokens.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF971E31),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF971E31),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingTile({
    required int index,
    required double left,
    required double top,
    required double tiltDeg,
    required Color color,
    required Color symbolColor,
    required String symbol,
    required bool disableMotion,
    required double scale,
  }) {
    final tiltRad = tiltDeg * math.pi / 180.0;
    final tileSize = 40.0 * scale;

    Widget tile = Transform.rotate(
      angle: tiltRad,
      child: Opacity(
        opacity: 0.85,
        child: Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13 * scale),
          ),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                fontFamily: AppTokens.fontBaloo2,
                fontSize: 24 * scale,
                fontWeight: FontWeight.w900,
                color: symbolColor,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );

    if (disableMotion || index >= _tileAnimations.length) {
      return Positioned(
        left: left,
        top: top,
        child: tile,
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _tileAnimations[index],
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _tileAnimations[index].value),
            child: child,
          );
        },
        child: tile,
      ),
    );
  }
}
