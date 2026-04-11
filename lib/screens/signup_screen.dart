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
import 'login_screen.dart';

enum SignupAccountType { user, admin }

class SignUpScreenRouteArgs {
  const SignUpScreenRouteArgs({
    this.initialAccountType = SignupAccountType.user,
  });

  final SignupAccountType initialAccountType;
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    this.initialAccountType = SignupAccountType.user,
    this.authService,
  });

  final SignupAccountType initialAccountType;
  final AuthService? authService;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthService _authService;
  late SignupAccountType _selectedAccountType;

  AsyncState<void> _submitState = const AsyncState.idle();
  String? _nameErrorText;
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;
  String? _errorText;

  bool get _isAdmin => _selectedAccountType == SignupAccountType.admin;

  bool get _hasBaseFieldsFilled =>
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  String get _screenSubtitle => _isAdmin
      ? 'Create your mosque admin account with email and password.'
      : 'Create your account with email and password.';

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _selectedAccountType = widget.initialAccountType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _trySignup() async {
    if (_submitState.isLoading || !_hasBaseFieldsFilled) {
      return;
    }

    final trimmedName = _nameController.text.trim();
    final trimmedEmail = _emailController.text.trim();
    final emailError = ApiErrorMapper.validateEmail(trimmedEmail);
    final passwordError = ApiErrorMapper.validatePassword(
      _passwordController.text,
    );
    final confirmPasswordError = ApiErrorMapper.validatePasswordConfirmation(
      _passwordController.text,
      _confirmPasswordController.text,
    );
    final nameError = trimmedName.isEmpty ? 'Enter your full name.' : null;

    setState(() {
      _nameErrorText = nameError;
      _emailErrorText = emailError;
      _passwordErrorText = passwordError;
      _confirmPasswordErrorText = confirmPasswordError;
      _errorText = null;
    });

    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      return;
    }

    setState(() => _submitState = const AsyncState.loading());

    try {
      await _authService.signup(
        fullName: trimmedName,
        email: trimmedEmail,
        password: _passwordController.text,
        accountType: _isAdmin ? 'admin' : 'community',
      );

      if (!mounted) {
        return;
      }

      setState(() => _submitState = const AsyncState.success(null));
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on ApiException catch (error) {
      final userMessage = ApiErrorMapper.toUserMessage(error);
      setState(() {
        _submitState = const AsyncState.error('Signup failed');
        if (error.errorCode == 'EMAIL_ALREADY_EXISTS') {
          _emailErrorText = userMessage;
          _errorText = null;
        } else {
          _errorText = userMessage;
        }
      });
    } catch (error) {
      setState(() {
        _submitState = const AsyncState.error('Signup failed');
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted && _submitState.isLoading) {
        setState(() => _submitState = const AsyncState.idle());
      }
    }
  }

  void _openLogin() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.login,
      arguments: LoginScreenRouteArgs(
        initialAccountType:
            _isAdmin ? LoginAccountType.admin : LoginAccountType.user,
      ),
    );
  }

  void _returnToAuthEntry() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.onboarding,
      (_) => false,
    );
  }

  Future<bool> _handleSystemBack() async {
    _returnToAuthEntry();
    return false;
  }

  void _selectAccountType(SignupAccountType accountType) {
    if (_selectedAccountType == accountType) {
      return;
    }

    setState(() {
      _selectedAccountType = accountType;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign Up',
      onBack: _returnToAuthEntry,
      onWillPop: _handleSystemBack,
      subtitle: _screenSubtitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SignupAccountTypeChip(
                  key: const ValueKey('signup-account-type-community'),
                  label: 'User Sign Up',
                  selected: !_isAdmin,
                  onTap: () => _selectAccountType(SignupAccountType.user),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SignupAccountTypeChip(
                  key: const ValueKey('signup-account-type-admin'),
                  label: 'Mosque Admin Sign Up',
                  selected: _isAdmin,
                  onTap: () => _selectAccountType(SignupAccountType.admin),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AuthTextField(
            label: 'Full name',
            controller: _nameController,
            hasError: _nameErrorText != null,
            onChanged: (_) => setState(() {
              _nameErrorText = null;
              _errorText = null;
            }),
          ),
          if (_nameErrorText != null) ...[
            const SizedBox(height: 8),
            _AuthErrorText(message: _nameErrorText!),
          ],
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
            _AuthErrorText(message: _emailErrorText!),
          ],
          const SizedBox(height: 18),
          AuthTextField(
            label: 'Password',
            controller: _passwordController,
            obscureText: true,
            showVisibilityToggle: true,
            hasError: _passwordErrorText != null,
            onChanged: (_) => setState(() {
              _passwordErrorText = null;
              _confirmPasswordErrorText = null;
              _errorText = null;
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _passwordErrorText ?? ApiErrorMapper.passwordRequirementsText,
            style: TextStyle(
              color: _passwordErrorText != null
                  ? AppColors.error
                  : AppColors.secondaryText,
              fontSize: 13,
              height: 1.35,
              fontWeight: _passwordErrorText != null
                  ? FontWeight.w500
                  : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 18),
          AuthTextField(
            label: 'Confirm password',
            controller: _confirmPasswordController,
            obscureText: true,
            showVisibilityToggle: true,
            hasError: _confirmPasswordErrorText != null,
            onChanged: (_) => setState(() {
              _confirmPasswordErrorText = null;
              _errorText = null;
            }),
          ),
          if (_confirmPasswordErrorText != null) ...[
            const SizedBox(height: 8),
            _AuthErrorText(message: _confirmPasswordErrorText!),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            _AuthErrorText(message: _errorText!),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            text: _submitState.isLoading
                ? 'Creating Account...'
                : 'Create Account',
            enabled: _hasBaseFieldsFilled && !_submitState.isLoading,
            onPressed: _trySignup,
          ),
        ],
      ),
      footer: AuthFooter(
        dividerText: 'Current sign-up method',
        promptText: 'Already have an account? ',
        actionText: 'Log In',
        onActionTap: _openLogin,
        showSocialAuthButtons: false,
        availabilityNote: _isAdmin
            ? 'Mosque admin sign up is available in this build.'
            : 'Email and password sign-up is available in this build.',
      ),
    );
  }
}

class _SignupAccountTypeChip extends StatelessWidget {
  const _SignupAccountTypeChip({
    super.key,
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

class _AuthErrorText extends StatelessWidget {
  const _AuthErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: AppColors.error,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
  }
}
