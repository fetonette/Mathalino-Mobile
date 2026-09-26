import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../widgets/animated_logo.dart';
import '../widgets/gamified_loading_spinner.dart';

/// Forgot Password Page
/// Allows students to request a password reset using their LRN
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _lrnController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _lrnController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Simulate validation delay
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => _isSubmitting = false);

    // Show information dialog instead of sending email
    if (mounted) {
      _showInfoDialog();
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.primary,
              size: 28,
            ),
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
              'Forgot your password? Please ask your Teacher or Parent to reset your password from their Web Dashboard.',
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
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: AppColors.primary,
                        size: 18,
                      ),
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
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
            colors: [
              AppColors.background,
              AppColors.backgroundLight,
            ],
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
                      'Reset Password',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'Enter your LRN to receive a password reset link',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // LRN Input
                    _buildLRNInput(),
                    const SizedBox(height: 24),

                    // Reset Button
                    _buildResetButton(),
                    const SizedBox(height: 16),

                    // Back to Login Link
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text.rich(
                        TextSpan(
                          text: 'Remember your password? ',
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textPrimary,
          ),
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
            prefixIcon: Icon(
              Icons.badge,
              color: AppColors.primary,
            ),
            suffixIcon: _lrnController.text.length == 12
                ? Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                  )
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

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleResetPassword,
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
                'Send Reset Link',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
