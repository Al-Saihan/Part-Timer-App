import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/job.dart';
import '../includes/auth.dart';

class ApiService {
  // ! Base URL - Laravel backend
  static final String baseUrl =
      dotenv.env['API_BASE_URL'] ?? "http://127.0.0.1:8000/api";

  // ! MARK: REGISTER
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String userType, // 'seeker' or 'recruiter'
  }) async {
    final url = Uri.parse('$baseUrl/register');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "user_type": userType,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to register: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: LOGIN
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      // Try to detect token in common response shapes and save it
      try {
        if (body is Map<String, dynamic>) {
          String? token;
          if (body['token'] is String) {
            token = body['token'];
          } else if (body['access_token'] is String) {
            token = body['access_token'];
          } else if (body['data'] is Map && body['data']['token'] is String) {
            token = body['data']['token'];
          }

          if (token != null) {
            await saveToken(token);
          }
        }
      } catch (_) {}

      return body;
    } else {
      throw Exception(
        'Failed to login: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: All Jobs
  static Future<List<Job>> fetchJobs() async {
    final url = Uri.parse('$baseUrl/jobs');

    final token = await getToken();
    final headers = {"Content-Type": "application/json"};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((job) => Job.fromJson(job)).toList();
    } else {
      throw Exception(
        'Failed to fetch jobs: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: LOGOUT
  static Future<void> logout() async {
    final url = Uri.parse('$baseUrl/logout');
    final token = await getToken();
    final headers = {"Content-Type": "application/json"};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.post(url, headers: headers);

    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Failed to logout: ${response.statusCode} ${response.body}');
    }
  }
}
