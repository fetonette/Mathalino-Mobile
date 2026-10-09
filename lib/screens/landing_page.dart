import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../core/theme/mathalino_tokens.dart';
import '../widgets/chunky_3d_button.dart';
import '../widgets/floating_math_tile.dart';

/// Landing Page (Welcome View)
/// Gamified welcome screen featuring Mathalino logo, floating math tiles,
/// feature carousel with side peeking, and 3D primary button.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _carouselIndex = 0;

  final List<Map<String, dynamic>> _features = const [
    {
      'icon': Icons.star_rounded,
      'title': 'Earn XP & Coins',
      'description': 'Collect rewards as you solve math problems',
      'color': AppTokens.accentOrange,
      'ringColor': AppTokens.accentRing,
    },
    {
      'icon': Icons.explore_rounded,
      'title': 'Solve Quests',
      'description': 'Complete exciting math adventures',
      'color': Color(0xFF10B981),
      'ringColor': Color(0xFFA7F3D0),
    },
    {
      'icon': Icons.map_rounded,
      'title': 'Unlock World Maps',
      'description': 'Discover new lands as you progress',
      'color': AppTokens.primaryIndigo,
      'ringColor': AppTokens.indigoRing,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Responsive sizing
    final isCompact = screenHeight < 720;
    final logoWidth = isCompact
        ? math.min(220.0, screenWidth * 0.58)
        : math.min(250.0, screenWidth * 0.65);

    return Scaffold(
      backgroundColor: AppTokens.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTokens.background,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // --- Top Section: Logo & Floating Decorations ---
                        _buildTopDecorationsAndLogo(screenWidth, logoWidth, isCompact),

                        const SizedBox(height: 8),

                        // --- Title & Subtitle ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Text(
                                'Welcome to Mathalino!',
                                style: TextStyle(
                                  fontFamily: AppTokens.fontBaloo2,
                                  fontSize: isCompact ? 28 : 33,
                                  fontWeight: FontWeight.w800,
                                  color: AppTokens.headingIndigo,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Math Made Fun!',
                                style: TextStyle(
                                  fontFamily: AppTokens.fontBaloo2,
                                  fontSize: isCompact ? 19 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTokens.orangeText,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isCompact ? 14 : 20),

                        // --- Middle Section: Feature Carousel ---
                        _buildCarousel(screenWidth),

                        const SizedBox(height: 12),

                        // --- Page Indicator Dots (12px under cards) ---
                        _buildPageDots(),

                        const Spacer(),

                        SizedBox(height: isCompact ? 14 : 22),

                        // --- Bottom Section: 3D Button & Footer Note ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Chunky3DButton(
                            text: 'Start Learning',
                            iconLeading: true,
                            icon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Are you a Teacher or Parent?\nVisit our Web Portal to log in.',
                            style: TextStyle(
                              fontFamily: AppTokens.fontNunito,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTokens.secondaryText,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopDecorationsAndLogo(
      double screenWidth, double logoWidth, bool isCompact) {
    final logoTop = isCompact ? 16.0 : 24.0;
    // Stack height accommodates the full square logo + top offset with generous breathing space below
    final stackHeight = logoTop + logoWidth + (isCompact ? 20.0 : 28.0);

    return SizedBox(
      width: screenWidth,
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1. Tiny 4-point yellow star near top left
          Positioned(
            left: screenWidth * 0.23,
            top: isCompact ? 6 : 12,
            child: const FourPointStar(
              size: 15,
              color: AppTokens.accentOrange,
            ),
          ),

          // 2. Tiny 4-point periwinkle star near top right
          Positioned(
            right: screenWidth * 0.21,
            top: isCompact ? 10 : 16,
            child: const FourPointStar(
              size: 13,
              color: AppTokens.tilePeriwinkle,
            ),
          ),

          // 3. Top-left yellow "+" math tile (-12 deg)
          Positioned(
            left: math.max(12.0, (screenWidth - logoWidth) / 2 - 44),
            top: isCompact ? 10 : 18,
            child: const FloatingMathTile(
              size: 46,
              radius: AppTokens.radiusTileWelcome,
              symbol: '+',
              symbolSize: 30,
              backgroundColor: AppTokens.tileYellow,
              symbolColor: AppTokens.tileSymbolYellow,
              angleInDegrees: -12,
              delay: Duration.zero,
            ),
          ),

          // 4. Top-right mint "×" math tile (10 deg)
          Positioned(
            right: math.max(12.0, (screenWidth - logoWidth) / 2 - 44),
            top: isCompact ? 14 : 24,
            child: const FloatingMathTile(
              size: 46,
              radius: AppTokens.radiusTileWelcome,
              symbol: '×',
              symbolSize: 30,
              backgroundColor: AppTokens.tileMint,
              symbolColor: AppTokens.tileSymbolMint,
              angleInDegrees: 10,
              delay: Duration(milliseconds: 600),
            ),
          ),

          // 5. Left periwinkle "÷" math tile (8 deg) beside logo's lower half
          Positioned(
            left: math.max(10.0, (screenWidth - logoWidth) / 2 - 48),
            top: logoTop + logoWidth * 0.52,
            child: const FloatingMathTile(
              size: 46,
              radius: AppTokens.radiusTileWelcome,
              symbol: '÷',
              symbolSize: 30,
              backgroundColor: AppTokens.tilePeriwinkle,
              symbolColor: AppTokens.tileSymbolPeriwinkle,
              angleInDegrees: 8,
              delay: Duration(milliseconds: 1200),
            ),
          ),

          // 6. Right sky "−" math tile (-8 deg) beside logo's lower half
          Positioned(
            right: math.max(10.0, (screenWidth - logoWidth) / 2 - 48),
            top: logoTop + logoWidth * 0.56,
            child: const FloatingMathTile(
              size: 46,
              radius: AppTokens.radiusTileWelcome,
              symbol: '−',
              symbolSize: 30,
              backgroundColor: AppTokens.tileSky,
              symbolColor: AppTokens.tileSymbolSky,
              angleInDegrees: -8,
              delay: Duration(milliseconds: 1800),
            ),
          ),

          // 7. Center Mascot Logo
          Positioned(
            top: logoTop,
            child: Image.asset(
              'image/MLOGO.png',
              width: logoWidth,
              height: logoWidth,
              fit: BoxFit.contain,
              semanticLabel: 'Mathalino Logo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel(double screenWidth) {
    // 300 wide card + 12 margin between cards = 312 pitch
    final fraction = (312.0 / screenWidth).clamp(0.70, 0.90);

    return SizedBox(
      height: 220, // 208 card height + 6px bottom shadow + 6px breathing room
      child: CarouselSlider.builder(
        itemCount: _features.length,
        options: CarouselOptions(
          height: 220,
          viewportFraction: fraction,
          initialPage: 0,
          enableInfiniteScroll: true,
          enlargeCenterPage: false,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 4),
          autoPlayAnimationDuration: const Duration(milliseconds: 800),
          onPageChanged: (index, reason) {
            setState(() {
              _carouselIndex = index;
            });
          },
        ),
        itemBuilder: (context, index, realIndex) {
          final feature = _features[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Center(
              child: Container(
                width: 300,
                height: 208,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  border: Border.all(color: AppTokens.cardBorder, width: 3),
                  boxShadow: const [AppTokens.cardSolidShadow],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 76px circle icon with 4px lighter ring
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: feature['color'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: feature['ringColor'] as Color,
                          width: 4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        feature['icon'] as IconData,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(
                      feature['title'] as String,
                      style: TextStyle(
                        fontFamily: AppTokens.fontBaloo2,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.bodyText,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      feature['description'] as String,
                      style: TextStyle(
                        fontFamily: AppTokens.fontNunito,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.secondaryText,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_features.length, (index) {
        final isActive = index == _carouselIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? AppTokens.primaryIndigo : AppTokens.inputBorder,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}
