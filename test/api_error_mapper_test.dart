import 'package:believer/core/api_error_mapper.dart';
import 'package:believer/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps duplicate email into launch-safe copy', () {
    final message = ApiErrorMapper.toUserMessage(
      ApiException(
        'Email is already registered',
        statusCode: 409,
        errorCode: 'EMAIL_ALREADY_EXISTS',
      ),
    );

    expect(
      message,
      'An account with this email already exists. Log in instead or use a different email.',
    );
  });

  test('maps validation details into field-friendly copy', () {
    final message = ApiErrorMapper.toUserMessage(
      ApiException(
        'Invalid signup payload',
        statusCode: 400,
        errorCode: 'VALIDATION_ERROR',
        details: [
          {
            'path': ['password'],
            'message': 'Too small: expected string to have >=8 characters',
          },
        ],
      ),
    );

    expect(message, 'Password must be at least 8 characters long.');
  });

  test('preserves actionable network configuration guidance', () {
    final message = ApiErrorMapper.toUserMessage(
      ApiException(
        'Cannot reach http://10.0.2.2:4000. Android emulator should use http://10.0.2.2:4000. For a physical device, set API_BASE_URL to your computer\'s LAN IP.',
        errorCode: 'NETWORK_ERROR',
      ),
    );

    expect(
      message,
      'Cannot reach http://10.0.2.2:4000. Android emulator should use http://10.0.2.2:4000. For a physical device, set API_BASE_URL to your computer\'s LAN IP.',
    );
  });
}
