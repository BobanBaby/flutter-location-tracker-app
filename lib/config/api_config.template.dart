// Template configuration file for API Keys.
// Copy this file to lib/config/api_config.dart and add your actual API Key.
class ApiConfig {
  static const String googleRoutesApiKey = String.fromEnvironment(
    'GOOGLE_ROUTES_API_KEY',
    defaultValue: 'YOUR_GOOGLE_ROUTES_API_KEY_HERE',
  );
}
