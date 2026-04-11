import '../services/api_client.dart';

class ApiErrorMapper {
  static const int minimumPasswordLength = 8;
  static const String passwordRequirementsText =
      'Use at least 8 characters. Letters, numbers, and symbols are all supported.';

  static String toUserMessage(Object error) {
    if (error is ApiException) {
      final code = error.errorCode?.toUpperCase();
      final message = error.message.toLowerCase();

      if (code == 'EMAIL_ALREADY_EXISTS' ||
          error.statusCode == 409 ||
          message.contains('already registered')) {
        return 'An account with this email already exists. Log in instead or use a different email.';
      }

      if (code == 'INVALID_CREDENTIALS' || error.statusCode == 401) {
        return 'Email or password is incorrect. Check your details and try again.';
      }

      if (code == 'INVALID_CURRENT_PASSWORD') {
        return 'Your current password is incorrect. Re-enter it and try again.';
      }

      if (code == 'INVALID_PASSWORD_RESET_TOKEN') {
        return 'This password reset link is invalid or has expired. Request a new one and try again.';
      }

      if (code == 'EMAIL_NOT_CONFIGURED') {
        return 'Password reset email is not available right now. Please try again later.';
      }

      if (code == 'PASSWORD_RESET_EMAIL_FAILED') {
        return 'We could not send the reset email right now. Please try again.';
      }

      if (code == 'PASSWORD_REUSE_NOT_ALLOWED' ||
          message.contains('different from your current password')) {
        return 'Choose a new password that is different from your current one.';
      }

      if (code == 'ACCOUNT_DISABLED' || message.contains('disabled')) {
        return 'This account is currently disabled. Please contact support.';
      }

      if (code == 'NETWORK_ERROR' || code == 'NETWORK_TIMEOUT') {
        return error.message;
      }

      if (code == 'VALIDATION_ERROR' || error.statusCode == 400) {
        return _validationMessage(error) ??
            'Please review your details and try again.';
      }

      if (message.contains('cannot reach backend') ||
          message.contains('request to ') ||
          message.contains('network') ||
          message.contains('timed out')) {
        return error.message;
      }

      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }

  static String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Enter your email address.';
    }

    const emailPattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
    if (!RegExp(emailPattern).hasMatch(trimmed)) {
      return 'Enter a valid email address, like name@example.com.';
    }

    return null;
  }

  static String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Enter your password.';
    }

    if (value.length < minimumPasswordLength) {
      return 'Password must be at least 8 characters long.';
    }

    return null;
  }

  static String? validatePasswordConfirmation(
    String password,
    String confirmation,
  ) {
    if (confirmation.isEmpty) {
      return 'Re-enter your password to confirm it.';
    }

    if (password != confirmation) {
      return 'Passwords do not match yet. Re-enter the same password to confirm.';
    }

    return null;
  }

  static String? _validationMessage(ApiException error) {
    final details = error.details;
    if (details != null) {
      for (final detail in details) {
        if (detail is! Map) {
          continue;
        }

        final rawPath = detail['path'];
        final field = rawPath is List && rawPath.isNotEmpty
            ? rawPath.first?.toString()
            : null;
        final message = detail['message']?.toString().toLowerCase() ?? '';

        switch (field) {
          case 'email':
            return 'Enter a valid email address, like name@example.com.';
          case 'password':
            if (message.contains('8') || message.contains('too small')) {
              return 'Password must be at least 8 characters long.';
            }
            return 'Enter your password and try again.';
          case 'newPassword':
            if (message.contains('different')) {
              return 'Choose a new password that is different from your current one.';
            }
            if (message.contains('8') || message.contains('too small')) {
              return 'Password must be at least 8 characters long.';
            }
            return 'Enter your new password and try again.';
          case 'currentPassword':
            return 'Enter your current password.';
        }
      }
    }

    final message = error.message.toLowerCase();
    if (message.contains('signup payload') ||
        message.contains('login payload') ||
        message.contains('forgot password payload') ||
        message.contains('reset password payload') ||
        message.contains('change password payload')) {
      return 'Please review your details and try again.';
    }

    return null;
  }
}
