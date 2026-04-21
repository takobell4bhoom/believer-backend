String? resolveExplicitBrowserRoute({Uri? currentUri}) {
  final uri = currentUri ?? Uri.base;
  final directPath = _normalizePath(uri.path);
  if (_isExplicitAuthRoute(directPath)) {
    return directPath;
  }

  final fragment = uri.fragment;
  if (fragment.isEmpty) {
    return _hasResetToken(uri) ? '/reset-password' : null;
  }

  final fragmentUri = _parseFragmentUri(fragment);
  final fragmentPath = _normalizePath(fragmentUri.path);
  if (_isExplicitAuthRoute(fragmentPath)) {
    return fragmentPath;
  }

  return _hasResetToken(uri) ? '/reset-password' : null;
}

String? readBrowserTokenParameter(String key, {Uri? currentUri}) {
  final uri = currentUri ?? Uri.base;
  final directValue = uri.queryParameters[key]?.trim();
  if (directValue != null && directValue.isNotEmpty) {
    return directValue;
  }

  final fragment = uri.fragment;
  if (fragment.isEmpty) {
    return null;
  }

  final fragmentValue =
      _parseFragmentUri(fragment).queryParameters[key]?.trim();
  if (fragmentValue == null || fragmentValue.isEmpty) {
    return null;
  }

  return fragmentValue;
}

Uri _parseFragmentUri(String fragment) {
  final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
  return Uri.parse(normalized);
}

String _normalizePath(String path) {
  if (path.isEmpty) {
    return '/';
  }

  final normalized = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  return normalized;
}

bool _isExplicitAuthRoute(String path) {
  return path == '/forgot-password' || path == '/reset-password';
}

bool _hasResetToken(Uri uri) {
  return readBrowserTokenParameter('token', currentUri: uri)?.isNotEmpty ==
      true;
}
