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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.authService,
  });

  final AuthService? authService;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  late final AuthService _authService;

  AsyncState<void> _submitState = const AsyncState.idle();
  String? _emailErrorText;
  String? _errorText;
  String? _successText;

  bool get _isFilled => _emailController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitState.isLoading || !_isFilled) {
      return;
    }

    final emailError = ApiErrorMapper.validateEmail(_emailController.text);
    setState(() {
      _emailErrorText = emailError;
      _errorText = null;
      _successText = null;
    });

    if (emailError != null) {
      return;
    }

    setState(() => _submitState = const AsyncState.loading());

    try {
      await _authService.requestPasswordReset(
        email: _emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitState = const AsyncState.success(null);
        _successText =
            'If an account exists for this email, a one-time reset link is on the way.';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitState = const AsyncState.error('Password reset failed');
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitState = const AsyncState.error('Password reset failed');
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted && _submitState.isLoading) {
        setState(() => _submitState = const AsyncState.idle());
      }
    }
  }

  void _openLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot Password',
      subtitle:
          'Enter your email address and we will send a one-time password reset link if the account exists.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'Email address',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hasError: _emailErrorText != null,
            onChanged: (_) => setState(() {
              _emailErrorText = null;
              _errorText = null;
              _successText = null;
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
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'For privacy, this screen always shows the same result whether or not the email is registered.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(
            text:
                _submitState.isLoading ? 'Sending Link...' : 'Send Reset Link',
            enabled: _isFilled && !_submitState.isLoading,
            onPressed: _submit,
          ),
          if (_successText != null) ...[
            const SizedBox(height: 12),
            Text(
              _successText!,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
        dividerText: 'Back to sign in',
        promptText: 'Remembered your password? ',
        actionText: 'Log In',
        onActionTap: _openLogin,
        showSocialAuthButtons: false,
        availabilityNote:
            'Password reset is available through email only in this slice.',
      ),
    );
  }
}
