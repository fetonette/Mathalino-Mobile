import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../core/theme/app_colors.dart';
import '../widgets/animated_logo.dart';

/// Landing Page (Onboarding View)
/// Features animated logo, feature carousel, and login button
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.backgroundLight,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Section: Animated Logo + Title
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AnimatedLogo(size: 150),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Mathalino!',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Math Made Fun!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Middle Section: Feature Carousel
              Expanded(
                flex: 2,
                child: _buildFeatureCarousel(),
              ),

              // Bottom Section: Login Button + Footer
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildLoginButton(context),
                        const SizedBox(height: 12),
                        _buildFooterNote(context),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCarousel() {
    final features = [
      {
        'icon': Icons.star,
        'title': 'Earn XP & Coins',
        'description': 'Collect rewards as you solve math problems',
        'color': AppColors.accent,
      },
      {
        'icon': Icons.explore,
        'title': 'Solve Quests',
        'description': 'Complete exciting math adventures',
        'color': AppColors.success,
      },
      {
        'icon': Icons.map,
        'title': 'Unlock World Maps',
        'description': 'Discover new lands as you progress',
        'color': AppColors.primary,
      },
    ];

    return CarouselSlider(
      options: CarouselOptions(
        height: 200,
        viewportFraction: 0.85,
        enlargeCenterPage: true,
        enableInfiniteScroll: true,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 4),
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
      ),
      items: features.map((feature) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: feature['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      feature['title'] as String,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature['description'] as String,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(context, '/login');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.login, size: 20),
            const SizedBox(width: 12),
            Text(
              'Start Learning',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterNote(BuildContext context) {
    return Text(
      'Are you a Teacher or Parent?\nVisit our Web Portal to log in.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }
}
