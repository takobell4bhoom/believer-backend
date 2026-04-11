import '../../services/api_client.dart';
import 'business_registration_models.dart';

class BusinessRegistrationErrorPresentation {
  const BusinessRegistrationErrorPresentation({
    required this.message,
    this.suggestedStep,
  });

  final String message;
  final BusinessRegistrationFlowStep? suggestedStep;
}

BusinessRegistrationErrorPresentation mapBusinessRegistrationActionError(
    Object error) {
  if (error is ApiException) {
    final code = error.errorCode?.toUpperCase();
    if (code == 'ACCOUNT_DISABLED') {
      return const BusinessRegistrationErrorPresentation(
        message: 'This account is currently disabled. Please contact support.',
      );
    }

    if (error.statusCode == 401 || code == 'UNAUTHORIZED') {
      return const BusinessRegistrationErrorPresentation(
        message: 'Please log in again to continue your business registration.',
      );
    }

    if (code == 'NETWORK_ERROR' || code == 'NETWORK_TIMEOUT') {
      return BusinessRegistrationErrorPresentation(message: error.message);
    }

    if (code == 'VALIDATION_ERROR' || error.statusCode == 400) {
      final issue = _firstIssue(error.details);
      if (issue != null) {
        final path = issue.path;
        final section = path.isNotEmpty ? path.first : null;
        final field = path.length > 1 ? path[1] : null;

        if (section == 'basicDetails') {
          return BusinessRegistrationErrorPresentation(
            message: _basicDetailsMessage(field, issue.message),
            suggestedStep: BusinessRegistrationFlowStep.basicDetails,
          );
        }

        if (section == 'contactDetails') {
          return BusinessRegistrationErrorPresentation(
            message: _contactDetailsMessage(field, issue.message),
            suggestedStep: BusinessRegistrationFlowStep.contactAndLocation,
          );
        }
      }

      return const BusinessRegistrationErrorPresentation(
        message: 'Please review your business details and try again.',
      );
    }

    return BusinessRegistrationErrorPresentation(message: error.message);
  }

  return const BusinessRegistrationErrorPresentation(
    message: 'Something went wrong. Please try again.',
  );
}

String mapBusinessRegistrationLoadError(Object error) {
  if (error is ApiException) {
    final code = error.errorCode?.toUpperCase();
    if (error.statusCode == 401 || code == 'UNAUTHORIZED') {
      return 'Please log in again to load your business registration.';
    }
    if (code == 'NETWORK_ERROR' || code == 'NETWORK_TIMEOUT') {
      return error.message;
    }
  }

  return 'Unable to load your business registration right now.';
}

class _ValidationIssue {
  const _ValidationIssue({
    required this.path,
    required this.message,
  });

  final List<String> path;
  final String message;
}

_ValidationIssue? _firstIssue(List<dynamic>? details) {
  if (details == null) {
    return null;
  }

  for (final detail in details) {
    if (detail is! Map) {
      continue;
    }

    final rawPath = detail['path'];
    final path = rawPath is List
        ? rawPath.map((segment) => segment.toString()).toList(growable: false)
        : const <String>[];
    final message = detail['message']?.toString();
    if (message == null || message.isEmpty) {
      continue;
    }

    return _ValidationIssue(path: path, message: message);
  }

  return null;
}

String _basicDetailsMessage(String? field, String fallback) {
  switch (field) {
    case 'businessName':
      return 'Enter your business name before continuing.';
    case 'logo':
      return 'Upload a business logo before submitting your listing.';
    case 'selectedType':
      return 'Choose a business category before submitting your listing.';
    case 'tagline':
      return 'Add a short business tagline before submitting your listing.';
    case 'description':
      return 'Add a business description before submitting your listing.';
    default:
      return fallback;
  }
}

String _contactDetailsMessage(String? field, String fallback) {
  switch (field) {
    case 'businessEmail':
      return 'Enter a valid business email address.';
    case 'phone':
      return 'Enter a valid business phone number.';
    case 'whatsapp':
      return 'Enter a valid WhatsApp number.';
    case 'openingTime':
    case 'closingTime':
      return 'Add both opening and closing hours before submitting.';
    case 'address':
      return 'Add your address, zip code, and city, or mark the business as online only.';
    case 'zipCode':
      return 'Add your zip code before submitting.';
    case 'city':
      return 'Add your city before submitting.';
    default:
      return fallback;
  }
}
