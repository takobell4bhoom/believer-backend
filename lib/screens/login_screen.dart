import 'package:flutter/material.dart';

import '../core/api_error_mapper.dart';
import '../core/async_state.dart';
import '../navigation/app_routes.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'signup_screen.dart';

enum LoginAccountType { user, admin }

class LoginScreenRouteArgs {
  const LoginScreenRouteArgs({
    this.initialAccountType = LoginAccountType.user,
  });

  final LoginAccountType initialAccountType;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialAccountType = LoginAccountType.user,
    this.authService,
  });

  final LoginAccountType initialAccountType;
  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService;
  late LoginAccountType _selectedAccountType;

  AsyncState<void> _submitState = const AsyncState.idle();
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _errorText;

  bool get _isFilled =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  bool get _isAdmin => _selectedAccountType == LoginAccountType.admin;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _selectedAccountType = widget.initialAccountType;
  }

  Future<void> _tryLogin() async {
    if (_submitState.isLoading || !_isFilled) return;

    final emailError = ApiErrorMapper.validateEmail(_emailController.text);
    final passwordError =
        ApiErrorMapper.validatePassword(_passwordController.text);

    setState(() {
      _emailErrorText = emailError;
      _passwordErrorText = passwordError;
      _errorText = null;
    });

    if (emailError != null || passwordError != null) {
      return;
    }

    setState(() => _submitState = const AsyncState.loading());

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() => _submitState = const AsyncState.success(null));
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on ApiException catch (error) {
      setState(() {
        _submitState = const AsyncState.error('Login failed');
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } catch (error) {
      setState(() {
        _submitState = const AsyncState.error('Login failed');
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted && _submitState.isLoading) {
        setState(() => _submitState = const AsyncState.idle());
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openSignup() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.signup,
      arguments: SignUpScreenRouteArgs(
        initialAccountType:
            _isAdmin ? SignupAccountType.admin : SignupAccountType.user,
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
  }

  void _returnToOnboarding() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.onboarding,
      (_) => false,
    );
  }

  Future<bool> _handleSystemBack() async {
    _returnToOnboarding();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Log In',
      onBack: _returnToOnboarding,
      onWillPop: _handleSystemBack,
      subtitle: _isAdmin
          ? 'Mosque admins sign in with the same email and password they created during sign up.'
          : 'Use your email and password to sign in.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _AuthModeButton(
                  label: 'User Login',
                  selected: !_isAdmin,
                  onTap: () => setState(
                    () => _selectedAccountType = LoginAccountType.user,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AuthModeButton(
                  label: 'Mosque Admin Login',
                  selected: _isAdmin,
                  onTap: () => setState(
                    () => _selectedAccountType = LoginAccountType.admin,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AuthTextField(
            label: 'Email address',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hasError: _emailErrorText != null,
            onChanged: (_) => setState(() {
              _emailErrorText = null;
              _errorText = null;
            }),
          ),
          if (_emailErrorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _emailErrorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 24),
          AuthTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            showVisibilityToggle: true,
            hasError: _passwordErrorText != null,
            onChanged: (_) => setState(() {
              _passwordErrorText = null;
              _errorText = null;
            }),
          ),
          if (_passwordErrorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _passwordErrorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _openForgotPassword,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: AppColors.accentSoft,
                  decorationColor: AppColors.accentSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          AuthPrimaryButton(
            text: _submitState.isLoading ? 'Logging In...' : 'Log In',
            enabled: _isFilled && !_submitState.isLoading,
            onPressed: _tryLogin,
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      footer: AuthFooter(
        dividerText: 'Current sign-in method',
        promptText: 'Don’t have an account? ',
        actionText: 'Sign Up',
        onActionTap: _openSignup,
        showSocialAuthButtons: false,
        availabilityNote: _isAdmin
            ? 'Mosque admin sign up is available in this build.'
            : 'Email sign-in, password reset, and password change are available in this build.',
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor:
            selected ? AppColors.accentSoft.withValues(alpha: 0.12) : null,
        side: BorderSide(
          color: selected ? AppColors.accentSoft : AppColors.inputFill,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.primaryText,
        ),
      ),
    );
  }
}
