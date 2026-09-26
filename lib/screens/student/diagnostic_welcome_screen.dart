import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'diagnostic_screen.dart';

/// Welcome screen shown to students before their first diagnostic assessment.
class DiagnosticWelcomeScreen extends StatelessWidget {
  const DiagnosticWelcomeScreen({super.key});

  void _startAssessment(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const DiagnosticScreen(),
        settings: const RouteSettings(name: '/diagnostic'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          size: 56,
                          color: AppColors.accentDark,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        "Hello, Student!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Let's find your math level",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Answer 20 questions so we can choose the best starting point for your Mathalino adventure.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _startAssessment(context),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Assessment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.read<AuthService>().logout(),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
