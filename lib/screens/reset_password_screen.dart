import 'package:flutter/material.dart';

import '../core/api_error_mapper.dart';
import '../core/async_state.dart';
import '../navigation/app_routes.dart';
import '../navigation/browser_route_state.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.authService,
    this.initialToken,
  });

  final AuthService? authService;
  final String? initialToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final AuthService _authService;

  AsyncState<void> _submitState = const AsyncState.idle();
  String? _passwordErrorText;
  String? _confirmErrorText;
  String? _errorText;
  String? _successText;
  late final String? _resetToken;

  bool get _isFilled =>
      _passwordController.text.isNotEmpty && _confirmController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _resetToken = widget.initialToken ?? readBrowserTokenParameter('token');
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitState.isLoading || !_isFilled) {
      return;
    }

    final passwordError = ApiErrorMapper.validatePassword(
      _passwordController.text,
    );
    final confirmError = ApiErrorMapper.validatePasswordConfirmation(
      _passwordController.text,
      _confirmController.text,
    );
    final resetToken = _resetToken;
    final linkError = (resetToken == null || resetToken.isEmpty)
        ? 'This reset link is incomplete. Request a new one and try again.'
        : null;

    setState(() {
      _passwordErrorText = passwordError;
      _confirmErrorText = confirmError;
      _errorText = linkError;
      _successText = null;
    });

    if (passwordError != null || confirmError != null || linkError != null) {
      return;
    }

    setState(() => _submitState = const AsyncState.loading());

    try {
      await _authService.resetPassword(
        token: resetToken!,
        newPassword: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitState = const AsyncState.success(null);
        _successText =
            'Your password has been updated. Log in with your new password.';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitState = const AsyncState.error('Reset failed');
        _errorText = ApiErrorMapper.toUserMessage(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitState = const AsyncState.error('Reset failed');
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

  void _openForgotPassword() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.forgotPassword,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = _resetToken?.isNotEmpty == true;

    return AuthScaffold(
      title: 'Reset Password',
      subtitle:
          'Choose a new password for your account. This one-time link expires automatically.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasToken) ...[
            const Text(
              'This reset link is incomplete or no longer includes a token. Request a new password reset email to continue.',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
          ],
          AuthTextField(
            label: 'New password',
            controller: _passwordController,
            obscureText: true,
            showVisibilityToggle: true,
            hasError: _passwordErrorText != null,
            onChanged: (_) => setState(() {
              _passwordErrorText = null;
              _errorText = null;
              _successText = null;
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
              ),
            ),
          ],
          const SizedBox(height: 20),
          AuthTextField(
            label: 'Confirm new password',
            controller: _confirmController,
            obscureText: true,
            showVisibilityToggle: true,
            hasError: _confirmErrorText != null,
            onChanged: (_) => setState(() {
              _confirmErrorText = null;
              _errorText = null;
              _successText = null;
            }),
          ),
          if (_confirmErrorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _confirmErrorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 28),
          AuthPrimaryButton(
            text: _submitState.isLoading
                ? 'Updating Password...'
                : 'Update Password',
            enabled: hasToken && _isFilled && !_submitState.isLoading,
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
            const SizedBox(height: 12),
            TextButton(
              onPressed: _openLogin,
              child: const Text('Back to Log In'),
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
        dividerText: 'Need a fresh link?',
        promptText: 'Request another reset email: ',
        actionText: 'Try Again',
        onActionTap: _openForgotPassword,
        showSocialAuthButtons: false,
        availabilityNote:
            'This screen only supports email-based password resets in this slice.',
      ),
    );
  }
}
