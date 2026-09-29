import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide ChangeNotifierProvider;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/models/student_profile.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'firebase_options.dart';
import 'providers/diagnostic_provider.dart';
import 'providers/learn_provider.dart';
import 'providers/level_progress_provider.dart';
import 'providers/level_provider.dart';
import 'providers/post_assessment_provider.dart';
import 'providers/remediation_provider.dart';
import 'screens/landing_page.dart';
import 'screens/login_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/student/adventure_map_screen.dart';
import 'screens/student/diagnostic_screen.dart';
import 'screens/student/diagnostic_welcome_screen.dart';
import 'screens/student/post_assessment_screen.dart';
import 'screens/student/remediation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — kept only for Firebase Cloud Messaging (push notifications).
  // All database and auth operations now use Supabase.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Supabase — the primary database and auth provider.
  await Supabase.initialize(
    url: 'https://vaggqgmluporwzxhtnax.supabase.co',
    publishableKey: 'sb_publishable_yeiJ9tobwcYXBGaMCa2cEw_uVb1Pod9',
  );

  runApp(const ProviderScope(child: MathalinoApp()));
}

class MathalinoApp extends StatelessWidget {
  const MathalinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LevelProgressProvider()),
        ChangeNotifierProvider(create: (_) => LevelProvider()),
        ChangeNotifierProvider(create: (_) => RemediationProvider()),
        ChangeNotifierProvider(create: (_) => DiagnosticProvider()),
        ChangeNotifierProvider(create: (_) => PostAssessmentProvider()),
        ChangeNotifierProvider(create: (_) => LearnProvider()),
      ],
      child: MaterialApp(
        title: 'Mathalino - Student App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/landing',
        routes: {
          '/landing': (context) => const LandingPage(),
          '/login': (context) => const LoginPage(),
          '/forgot_password': (context) => const ForgotPasswordPage(),
          '/adventure_map': (context) => const AdventureMapScreen(),
          '/diagnostic_welcome': (context) => const DiagnosticWelcomeScreen(),
          '/diagnostic': (context) => const DiagnosticScreen(),
          '/post_assessment': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final level =
                (args is Map ? args['levelMilestone'] : null) as int? ?? 20;
            return PostAssessmentScreen(levelMilestone: level);
          },
          '/remediation': (context) {
            // RemediationScreen requires a StudentProfile, contentPool, and
            // failedLevel. These are passed via Navigator.push with arguments
            // (see adventure_map_screen.dart). This route is a fallback.
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is Map<String, dynamic>) {
              return RemediationScreen(
                user: args['user'] as StudentProfile,
                contentPool: (args['contentPool'] as List<dynamic>? ?? [])
                    .map((e) => e.toString())
                    .toList(),
                failedLevel: (args['failedLevel'] as int? ?? 1),
              );
            }
            return const Scaffold(
              body: Center(child: Text('Remediation requires user data')),
            );
          },
        },
      ),
    );
  }
}
