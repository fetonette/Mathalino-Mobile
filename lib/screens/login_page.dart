import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/services/auth_service.dart';
import '../core/services/supabase_service.dart';
import '../core/theme/mathalino_tokens.dart';
import '../widgets/chunky_3d_button.dart';
import '../widgets/floating_math_tile.dart';

/// Student Login Page
/// Restyled according to Mathalino playful gamified design specifications
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _lrnController = TextEditingController();
  final _passwordController = TextEditingController();

  final FocusNode _lrnFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  String? _lrnError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _lrnFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _passwordController.dispose();
    _lrnFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateLRN(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please check your LRN and try again';
    }
    if (text.length != 12) {
      return 'LRN must be exactly 12 digits';
    }
    if (!RegExp(r'^[0-9]{12}$').hasMatch(text)) {
      return 'LRN must contain only numbers';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  bool get _isLrnValid {
    final text = _lrnController.text.trim();
    return text.length == 12 && RegExp(r'^[0-9]{12}$').hasMatch(text);
  }

  Future<void> _handleLogin() async {
    final lrnErr = _validateLRN(_lrnController.text);
    final pwdErr = _validatePassword(_passwordController.text);

    setState(() {
      _lrnError = lrnErr;
      _passwordError = pwdErr;
    });

    if (lrnErr != null || pwdErr != null) return;

    setState(() => _isSubmitting = true);

    final authService = context.read<AuthService>();
    final success = await authService.loginWithLRN(
      _lrnController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      await _routeByDiagnosticStatus(authService);
    } else {
      _showErrorDialog(authService.errorMessage ?? 'Login failed');
    }
  }

  /// Routes a freshly authenticated student based on trustworthy diagnostic
  /// evidence:
  ///  * completed  → Adventure Map (existing progress preserved, no retake).
  ///  * none       → RMA welcome flow (genuinely new student).
  ///  * indeterminate → a clear retry state; NEVER an automatic retake, so a
  ///    transient read/RLS failure cannot send a returning student back to RMA.
  Future<void> _routeByDiagnosticStatus(AuthService authService) async {
    final status = await authService.resolveDiagnosticRouting();
    if (!mounted) return;
    switch (status) {
      case DiagnosticCompletionStatus.completed:
        Navigator.pushReplacementNamed(
          context,
          '/adventure_map',
          arguments: const {'showWelcomeBack': true},
        );
        break;
      case DiagnosticCompletionStatus.none:
        Navigator.pushReplacementNamed(context, '/diagnostic_welcome');
        break;
      case DiagnosticCompletionStatus.indeterminate:
        _showProgressCheckRetryDialog(authService);
        break;
    }
  }

  void _showProgressCheckRetryDialog(AuthService authService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.wifi_tethering_error_rounded,
                color: AppTokens.primaryIndigo),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Checking your progress',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
            ),
          ],
        ),
        content: const Text(
          'We could not confirm your saved progress right now. '
          'You will NOT be asked to repeat the diagnostic. '
          'Please check your internet connection and try again.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              setState(() => _isSubmitting = true);
              await _routeByDiagnosticStatus(authService);
              if (mounted) setState(() => _isSubmitting = false);
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await authService.logout();
              } catch (_) {}
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTokens.errorRed),
            const SizedBox(width: 12),
            Text(
              'Login Failed',
              style: TextStyle(
                fontFamily: AppTokens.fontBaloo2,
                color: AppTokens.bodyText,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontFamily: AppTokens.fontNunito,
            color: AppTokens.secondaryText,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppTokens.primaryIndigo),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: AppTokens.fontBaloo2,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentPasswordResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_reset_rounded, color: AppTokens.primaryIndigo, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Password Reset',
                style: TextStyle(
                  fontFamily: AppTokens.fontBaloo2,
                  color: AppTokens.bodyText,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
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
                fontFamily: AppTokens.fontNunito,
                color: AppTokens.secondaryText,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.cardBorder.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTokens.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, color: AppTokens.primaryIndigo, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'For Teachers:',
                        style: TextStyle(
                          fontFamily: AppTokens.fontNunito,
                          color: AppTokens.primaryIndigo,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Class Roster → Click the key icon next to student name',
                    style: TextStyle(
                      fontFamily: AppTokens.fontNunito,
                      color: AppTokens.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.family_restroom_rounded,
                          color: AppTokens.primaryIndigo, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'For Parents:',
                        style: TextStyle(
                          fontFamily: AppTokens.fontNunito,
                          color: AppTokens.primaryIndigo,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Settings → Linked Children → Click the key icon',
                    style: TextStyle(
                      fontFamily: AppTokens.fontNunito,
                      color: AppTokens.secondaryText,
                      fontSize: 13,
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
            style: TextButton.styleFrom(foregroundColor: AppTokens.primaryIndigo),
            child: Text(
              'Got it',
              style: TextStyle(
                fontFamily: AppTokens.fontBaloo2,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isCompact = screenHeight < 720;

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
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // --- Top Bar: Back Button & Top Tiles Area ---
                            _buildTopBarAndLogo(screenWidth, isCompact),

                            const SizedBox(height: 8),

                            // --- Title & Subtitle ---
                            Text(
                              'Student Login',
                              style: TextStyle(
                                fontFamily: AppTokens.fontBaloo2,
                                fontSize: isCompact ? 28 : 32,
                                fontWeight: FontWeight.w800,
                                color: AppTokens.headingIndigo,
                                height: 1.15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Type your LRN to keep learning!',
                              style: TextStyle(
                                fontFamily: AppTokens.fontNunito,
                                fontSize: isCompact ? 15 : 17,
                                fontWeight: FontWeight.w700,
                                color: AppTokens.secondaryText,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: isCompact ? 18 : 26),

                            // --- LRN Input ---
                            _buildLrnField(),

                            const SizedBox(height: 18),

                            // --- Password Input ---
                            _buildPasswordField(),

                            SizedBox(height: isCompact ? 22 : 28),

                            // --- Login Button ---
                            Chunky3DButton(
                              text: 'Login',
                              iconLeading: false,
                              icon: Icons.arrow_forward_rounded,
                              isLoading: _isSubmitting,
                              onPressed: _handleLogin,
                            ),

                            const SizedBox(height: 16),

                            // --- Forgot Password Link ---
                            Semantics(
                              button: true,
                              label: 'Forgot password? Reset here',
                              child: GestureDetector(
                                onTap: _showStudentPasswordResetDialog,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Forgot password? ',
                                      style: TextStyle(
                                        fontFamily: AppTokens.fontNunito,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: AppTokens.bodyText,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Reset here',
                                          style: TextStyle(
                                            fontFamily: AppTokens.fontNunito,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: AppTokens.headingIndigo,
                                            decoration: TextDecoration.underline,
                                            decorationColor: AppTokens.headingIndigo,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
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

  Widget _buildTopBarAndLogo(double screenWidth, bool isCompact) {
    final logoTop = isCompact ? 12.0 : 18.0;
    final logoWidth = isCompact ? 175.0 : 200.0;
    final stackHeight = logoTop + logoWidth + (isCompact ? 20.0 : 28.0);

    return SizedBox(
      width: double.infinity,
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1. Back button (top-left: 48x48 white circle, 3px #E0E7FF border)
          Positioned(
            left: 0,
            top: 4,
            child: Semantics(
              label: 'Go back',
              button: true,
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTokens.cardBorder, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppTokens.headingIndigo,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),

          // 2. Top-right yellow "+" floating tile
          Positioned(
            right: 0,
            top: 6,
            child: const FloatingMathTile(
              size: 40,
              radius: AppTokens.radiusTileLogin,
              symbol: '+',
              symbolSize: 26,
              backgroundColor: AppTokens.tileYellow,
              symbolColor: AppTokens.tileSymbolYellow,
              angleInDegrees: 10,
              delay: Duration.zero,
            ),
          ),

          // 3. Mid-left sky "=" floating tile
          Positioned(
            left: 0,
            top: logoTop + logoWidth * 0.44,
            child: const FloatingMathTile(
              size: 40,
              radius: AppTokens.radiusTileLogin,
              symbol: '=',
              symbolSize: 26,
              backgroundColor: AppTokens.tileSky,
              symbolColor: AppTokens.tileSymbolSky,
              angleInDegrees: -6,
              delay: Duration(milliseconds: 700),
            ),
          ),

          // 4. Mid-right mint "×" floating tile
          Positioned(
            right: 0,
            top: logoTop + logoWidth * 0.48,
            child: const FloatingMathTile(
              size: 40,
              radius: AppTokens.radiusTileLogin,
              symbol: '×',
              symbolSize: 26,
              backgroundColor: AppTokens.tileMint,
              symbolColor: AppTokens.tileSymbolMint,
              angleInDegrees: 8,
              delay: Duration(milliseconds: 1400),
            ),
          ),

          // 5. Logo Mascot centered below top bar
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

  Widget _buildLrnField() {
    final isFocused = _lrnFocusNode.hasFocus;
    final hasError = _lrnError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label above field
        Text(
          'Learner Reference Number (LRN)',
          style: TextStyle(
            fontFamily: AppTokens.fontNunito,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTokens.bodyText,
          ),
        ),
        const SizedBox(height: 8),

        // Input Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusInput),
            border: Border.all(
              color: hasError
                  ? AppTokens.errorRed
                  : (isFocused ? AppTokens.primaryIndigo : AppTokens.inputBorder),
              width: 3.0,
            ),
            boxShadow: isFocused && !hasError
                ? const [
                    BoxShadow(
                      color: AppTokens.focusGlow,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              // 38px circular badge (#E0E7FF) with ID-card icon
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppTokens.iconBadgeFill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.badge_rounded,
                    color: AppTokens.primaryIndigo,
                    size: 20,
                  ),
                ),
              ),

              // Text Field
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                  child: TextFormField(
                    controller: _lrnController,
                    focusNode: _lrnFocusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    style: TextStyle(
                      fontFamily: AppTokens.fontNunito,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppTokens.bodyText,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: 'Enter 12-digit LRN',
                      hintStyle: TextStyle(
                        fontFamily: AppTokens.fontNunito,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: AppTokens.secondaryText.withValues(alpha: 0.5),
                      ),
                    ),
                    onChanged: (value) {
                      if (_lrnError != null) {
                        setState(() {
                          _lrnError = _validateLRN(value);
                        });
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),

              // 32px circular #047857 badge with white check when valid
              if (_isLrnValid)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppTokens.successGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),

        // Error message under field
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              _lrnError!,
              style: TextStyle(
                fontFamily: AppTokens.fontNunito,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTokens.errorRed,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField() {
    final isFocused = _passwordFocusNode.hasFocus;
    final hasError = _passwordError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label above field
        Text(
          'Password',
          style: TextStyle(
            fontFamily: AppTokens.fontNunito,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTokens.bodyText,
          ),
        ),
        const SizedBox(height: 8),

        // Input Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusInput),
            border: Border.all(
              color: hasError
                  ? AppTokens.errorRed
                  : (isFocused ? AppTokens.primaryIndigo : AppTokens.inputBorder),
              width: 3.0,
            ),
            boxShadow: isFocused && !hasError
                ? const [
                    BoxShadow(
                      color: AppTokens.focusGlow,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              // 38px circular badge (#E0E7FF) with Lock icon
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppTokens.iconBadgeFill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppTokens.primaryIndigo,
                    size: 20,
                  ),
                ),
              ),

              // Text Field
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: !_isPasswordVisible,
                    style: TextStyle(
                      fontFamily: AppTokens.fontNunito,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: _isPasswordVisible ? 0.5 : 2.0,
                      color: AppTokens.bodyText,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(
                        fontFamily: AppTokens.fontNunito,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: AppTokens.secondaryText.withValues(alpha: 0.5),
                      ),
                    ),
                    onChanged: (value) {
                      if (_passwordError != null) {
                        setState(() {
                          _passwordError = _validatePassword(value);
                        });
                      }
                    },
                  ),
                ),
              ),

              // 48x48 eye button on the right that toggles visibility
              Semantics(
                label: _isPasswordVisible ? 'Hide password' : 'Show password',
                button: true,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    iconSize: 24,
                    tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: AppTokens.secondaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // Error message under field
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              _passwordError!,
              style: TextStyle(
                fontFamily: AppTokens.fontNunito,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTokens.errorRed,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
