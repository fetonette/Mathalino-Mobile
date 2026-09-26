import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/services/auth_service.dart';
import '../widgets/animated_logo.dart';
import '../widgets/gamified_loading_spinner.dart';

/// Student Login Page
/// Firebase-connected with LRN and password authentication
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _lrnController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _lrnController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authService = context.read<AuthService>();
    final success = await authService.loginWithLRN(
      _lrnController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      // Check if the student has completed the diagnostic assessment.
      // If not, route to the diagnostic screen; otherwise go to the world map.
      final profile = authService.studentProfile;
      if (profile != null && !profile.diagnosticCompleted) {
        Navigator.pushReplacementNamed(context, '/diagnostic_welcome');
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/adventure_map',
          arguments: const {'showWelcomeBack': true},
        );
      }
    } else if (mounted) {
      _showErrorDialog(authService.errorMessage ?? 'Login failed');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Text(
              'Login Failed',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows student password reset dialog
  /// Explains that students must ask their Teacher or Parent to reset password
  /// from the Web Dashboard since student accounts use LRNs without email access
  void _showStudentPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Password Reset',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student accounts use 12-digit LRNs and do not have email access. To reset your password, please ask your Teacher or Parent to perform the reset from the Web Dashboard.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'For Teachers:',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Class Roster → Click the key icon next to student name',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.family_restroom,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'For Parents:',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Settings → Linked Children → Click the key icon',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text(
              'Got it',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.backgroundLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // Logo
                    const AnimatedLogo(size: 120),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Student Login',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Enter your LRN to continue learning',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // LRN Input
                    _buildLRNInput(),
                    const SizedBox(height: 16),

                    // Password Input
                    _buildPasswordInput(),
                    const SizedBox(height: 24),

                    // Login Button
                    _buildLoginButton(),
                    const SizedBox(height: 16),

                    // Forgot Password Link
                    TextButton(
                      onPressed: _showStudentPasswordResetDialog,
                      child: Text.rich(
                        TextSpan(
                          text: 'Forgot password? ',
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: 'Reset here',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLRNInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learner Reference Number (LRN)',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _lrnController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: InputDecoration(
            hintText: 'Enter 12-digit LRN',
            prefixIcon: Icon(Icons.badge, color: AppColors.primary),
            suffixIcon: _lrnController.text.length == 12
                ? Icon(Icons.check_circle, color: AppColors.success)
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your LRN';
            }
            if (value.length != 12) {
              return 'LRN must be exactly 12 digits';
            }
            if (!RegExp(r'^[0-9]{12}$').hasMatch(value)) {
              return 'LRN must contain only numbers';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textLight,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const GamifiedLoadingSpinner(size: 24, color: Colors.white)
            : Text(
                'Login',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
