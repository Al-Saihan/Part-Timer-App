import 'package:shared_preferences/shared_preferences.dart';

// ! MARK: Constants
const _kAuthTokenKey = 'auth_token';
const _kUserIdKey = 'user_id';
const _kUserTypeKey = 'user_type';

// ! MARK: Token Management
// ? Save authentication token
Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAuthTokenKey, token);
}

// ? Check if user is logged in
Future<bool> isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kAuthTokenKey) != null;
}

Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kAuthTokenKey);
}

Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kAuthTokenKey);
}

// ! MARK: User ID
Future<void> saveUserId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kUserIdKey, id);
}

Future<int?> getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_kUserIdKey);
}

Future<void> clearUserId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kUserIdKey);
}

// ! MARK: User Type
// ? Manages 'recruiter' or 'seeker' user type
Future<void> saveUserType(String type) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUserTypeKey, type);
}

Future<String?> getUserType() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kUserTypeKey);
}

Future<void> clearUserType() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kUserTypeKey);
}
