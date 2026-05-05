class ApiConfig {
  static const String _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
  static const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  static String get baseUrl {
    if (_baseUrlFromEnv.isNotEmpty) {
      return _baseUrlFromEnv;
    }

    if (_isReleaseBuild) {
      throw StateError(
        'API_BASE_URL is required for release builds. '
        'Build with --dart-define=API_BASE_URL=https://your-backend-domain/api/v1',
      );
    }

    return 'http://10.0.2.2:8000/api/v1';
  }
  
  // API Endpoints
  static const String sendOtp = '/otp/send';
  static const String verifyOtp = '/otp/verify';
  static const String createEntry = '/entry/create';
  static const String searchEntry = '/entry/search';
  static const String myActiveEntries = '/entry/my-active'; // Append /{phone}
  static const String verifyPnr = '/pnr/verify';
  static const String getUserLimits = '/user/limits'; // Append /{phone}
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
