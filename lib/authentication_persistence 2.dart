import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationPersistence {
  static const String _emailKey = 'saved_email';
  static const String _passwordKey = 'saved_password';
  static const String _rememberMeKey = 'remember_me';

  // Save user credentials
  static Future<void> saveCredentials(String email, String password, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (rememberMe) {
      await prefs.setString(_emailKey, email);
      await prefs.setString(_passwordKey, password);
    } else {
      // If remember me is turned off, clear the saved credentials
      await prefs.remove(_emailKey);
      await prefs.remove(_passwordKey);
    }
    
    // Always save the remember me preference
    await prefs.setBool(_rememberMeKey, rememberMe);
  }

  // Load saved email
  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // Load saved password
  static Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_passwordKey);
  }

  // Load remember me preference
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Clear all saved credentials
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
    await prefs.setBool(_rememberMeKey, false);
  }
} 