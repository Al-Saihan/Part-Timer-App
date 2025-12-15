import 'package:shared_preferences/shared_preferences.dart';

const _kAuthTokenKey = 'auth_token';
const _kUserIdKey = 'user_id';

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAuthTokenKey, token);
}

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
