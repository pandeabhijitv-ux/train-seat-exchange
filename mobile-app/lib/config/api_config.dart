class ApiConfig {
  // Change this to your server URL
  static const String baseUrl = 'http://localhost:8000/api/v1';
  
  // API Endpoints
  static const String sendOtp = '/otp/send';
  static const String verifyOtp = '/otp/verify';
  static const String createEntry = '/entry/create';
  static const String searchEntry = '/entry/search';
  static const String verifyPnr = '/pnr/verify';
  static const String getUserLimits = '/user/limits'; // Append /{phone}
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
