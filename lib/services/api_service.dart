import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/job.dart';
import '../models/chat_room.dart';
import '../includes/auth.dart';
import 'api_response.dart';

class ApiService {
  // ! Base URL - Laravel backend
  static final String baseUrl =
      dotenv.env['API_BASE_URL'] ?? "http://127.0.0.1:8000/api";

  // ! NEW: Centralized User-Friendly Error Handler
  static ApiResponse<T> _handleError<T>(http.Response response) {
    String message = 'Something went wrong. Please try again.';
    
    try {
      final body = jsonDecode(response.body);

      if (response.statusCode == 422) {
        // Laravel Validation Errors
        if (body['validation'] != null && body['validation']['message'] != null) {
          message = body['validation']['message'];
        } else if (body['errors'] != null) {
          // Get the first validation error message
          var errors = body['errors'] as Map<String, dynamic>;
          message = errors.values.first[0];
        } else {
          message = body['message'] ?? 'Validation failed.';
        }
      } else if (response.statusCode == 401) {
        message = "Invalid Credentials. Please try again.";
      } else if (response.statusCode == 403) {
        message = body['message'] ?? "You don't have permission to do this.";
      } else if (response.statusCode == 404) {
        message = "Error 404: Not Found! :(.";
      } else if (body['message'] != null) {
        message = body['message'];
      } else if (body['error'] != null) {
        message = body['error'];
      }
    } catch (_) {
      // If JSON parsing fails, use status code based message
      if (response.statusCode == 500) {
        message = "Server error. Please try again later.";
      }
    }

    return ApiResponse<T>(
      success: false,
      message: message,
      statusCode: response.statusCode,
    );
  }

  // Helper for debug logs
  static String _shortForLogging(dynamic parsed) {
    try {
      if (parsed == null) return '<empty response>';
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('message')) return parsed['message'].toString();
        if (parsed.containsKey('data')) return 'Object with data';
        return 'Object with ${parsed.length} keys';
      }
      if (parsed is List) return 'List with ${parsed.length} items';
      return parsed.toString();
    } catch (_) {
      return '<non-encodable response>';
    }
  }

  // ! MARK: REGISTER
  static Future<ApiResponse<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
    required String userType, // 'seeker' or 'recruiter'
  }) async {
    try {
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsed = jsonDecode(response.body);
        debugPrint('register returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed,
          message: 'Registration successful!',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('Register error: $e');
      return ApiResponse(
        success: false,
        message: 'Connection error. Please check your internet.',
      );
    }
  }

  // ! MARK: LOGIN
  static Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/login');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        debugPrint('login returning: ${_shortForLogging(body)}');

        // Try to detect token and user id in common response shapes and save them
        try {
          if (body is Map<String, dynamic>) {
            String? token;
            int? userId;

            if (body['token'] is String) token = body['token'];
            if (body['access_token'] is String) token = body['access_token'];
            if (body['data'] is Map) {
              final data = body['data'] as Map<String, dynamic>;
              if (data['token'] is String) token = data['token'];
              if (data['user'] is Map && data['user']['id'] != null) {
                userId = data['user']['id'];
              }
              if (data['id'] is int) userId = data['id'];
              if (data['user_id'] is int) userId = data['user_id'];
            }

            if (body['user'] is Map && body['user']['id'] != null) {
              userId = body['user']['id'];
            }
            if (body['user_id'] is int) userId = body['user_id'];
            if (body['id'] is int) userId = body['id'];

            if (token != null) await saveToken(token);
            if (userId != null) await saveUserId(userId);
            // detect and save user_type when present
            try {
              String? utype;
              if (body['user'] is Map && body['user']['user_type'] is String) {
                utype = body['user']['user_type'];
              }
              if (body['data'] is Map) {
                final data = body['data'] as Map<String, dynamic>;
                if (data['user'] is Map && data['user']['user_type'] is String) {
                  utype = data['user']['user_type'];
                }
                if (data['user_type'] is String) utype = data['user_type'];
              }
              if (body['user_type'] is String) utype = body['user_type'];
              if (utype != null) await saveUserType(utype);
            } catch (_) {}
          }
        } catch (_) {}

        return ApiResponse(
          success: true,
          data: body,
          message: 'Login successful!',
        );
      } else {
        debugPrint('Login failed: status=${response.statusCode}');
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return ApiResponse(
        success: false,
        message: 'Connection error. Please check your internet.',
      );
    }
  }

  // ! MARK: All Jobs
  static Future<ApiResponse<List<Job>>> fetchJobs() async {
    try {
      final url = Uri.parse('$baseUrl/jobs');

      final token = await getToken();
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<Map<String, dynamic>> normalized = [];

        try {
          if (decoded is List) {
            for (var item in decoded) {
              if (item is Map) {
                Map<String, dynamic> jobMap;
                if (item.containsKey('job')) {
                  jobMap = Map<String, dynamic>.from(item['job']);
                  if (item.containsKey('recruiter') && item['recruiter'] != null) {
                    jobMap['recruiter'] = item['recruiter'];
                  } else if (item.containsKey('user') && item['user'] != null) {
                    jobMap['recruiter'] = item['user'];
                  }
                } else {
                  jobMap = Map<String, dynamic>.from(item);
                }
                normalized.add(jobMap);
              }
            }
          } else if (decoded is Map) {
            if (decoded.containsKey('job')) {
              final item = decoded;
              final Map<String, dynamic> jobMap = Map<String, dynamic>.from(item['job']);
              if (item.containsKey('recruiter') && item['recruiter'] != null) {
                jobMap['recruiter'] = item['recruiter'];
              } else if (item.containsKey('user') && item['user'] != null) {
                jobMap['recruiter'] = item['user'];
              }
              normalized.add(jobMap);
            } else {
              for (var value in decoded.values) {
                if (value is Map) {
                  Map<String, dynamic> jobMap;
                  if (value.containsKey('job')) {
                    jobMap = Map<String, dynamic>.from(value['job']);
                    if (value.containsKey('recruiter') && value['recruiter'] != null) {
                      jobMap['recruiter'] = value['recruiter'];
                    } else if (value.containsKey('user') && value['user'] != null) {
                      jobMap['recruiter'] = value['user'];
                    }
                  } else {
                    jobMap = Map<String, dynamic>.from(value);
                  }
                  normalized.add(jobMap);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('fetchJobs: normalization error: $e');
        }

        debugPrint('fetchJobs returning ${normalized.length} normalized items');

        final jobs = normalized.map((job) => Job.fromJson(job)).toList();
        return ApiResponse(
          success: true,
          data: jobs,
          message: 'Jobs loaded successfully.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchJobs error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load jobs. Please try again.',
      );
    }
  }

  // ! MARK: Fetch single job details
  static Future<ApiResponse<Map<String, dynamic>>> fetchJobDetails({
    required int jobId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/jobs/$jobId');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('fetchJobDetails: parsed=${_shortForLogging(parsed)}');
        if (parsed is Map<String, dynamic>) {
          return ApiResponse(
            success: true,
            data: parsed,
            message: 'Job details loaded.',
          );
        }
        return ApiResponse(
          success: false,
          message: 'Unexpected response format.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchJobDetails error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load job details.',
      );
    }
  }

  // ! MARK: Logout
  static Future<ApiResponse<void>> logout() async {
    try {
      final url = Uri.parse('$baseUrl/logout');
      final token = await getToken();
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

      final response = await http.post(url, headers: headers);

      if (response.statusCode == 200) {
        await clearUserId();
        debugPrint('logout successful');
        return ApiResponse(
          success: true,
          message: 'Logged out successfully.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      return ApiResponse(
        success: false,
        message: 'Logout failed. Please try again.',
      );
    }
  }

  // ! MARK: Fetch Current User
  static Future<ApiResponse<Map<String, dynamic>>> fetchCurrentUser() async {
    try {
      final token = await getToken();
      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

      final url = Uri.parse('$baseUrl/me');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('fetchCurrentUser parsed: ${_shortForLogging(parsed)}');
        if (parsed is Map<String, dynamic>) {
          return ApiResponse(
            success: true,
            data: parsed,
            message: 'User data loaded.',
          );
        }
        return ApiResponse(
          success: false,
          message: 'Unexpected response format.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchCurrentUser error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load user data.',
      );
    }
  }

  // ! MARK: Job Apply
  static Future<ApiResponse<Map<String, dynamic>>> applyJob({required int jobId}) async {
    try {
      final url = Uri.parse('$baseUrl/jobs/$jobId/apply');
      final token = await getToken();

      int? seekerId = await getUserId();
      debugPrint('applyJob: saved seekerId=$seekerId');

      // If no saved seeker id, try to fetch current authenticated user
      if (seekerId == null) {
        try {
          final userResponse = await fetchCurrentUser();
          if (userResponse.success && userResponse.data != null) {
            final fetched = userResponse.data!;
            if (fetched['id'] is int) {
              seekerId = fetched['id'];
            } else if (fetched['user_id'] is int) {
              seekerId = fetched['user_id'];
            }

            if (seekerId != null) {
              await saveUserId(seekerId);
              debugPrint('applyJob: fetched seekerId=$seekerId');
            }
          }
        } catch (e) {
          debugPrint('applyJob: error fetching current user: $e');
        }
      }

      if (seekerId == null) {
        return ApiResponse(
          success: false,
          message: 'Please log in to apply for jobs.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'seeker_id': seekerId});

      final response = await http.post(url, headers: headers, body: body);

      debugPrint('Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final parsed = jsonDecode(response.body);
          final result = (parsed is Map<String, dynamic>) ? parsed : {'message': 'Applied'};
          debugPrint('applyJob returning: ${_shortForLogging(result)}');
          return ApiResponse(
            success: true,
            data: result,
            message: 'Application submitted successfully!',
          );
        } catch (_) {
          return ApiResponse(
            success: true,
            message: 'Application submitted successfully!',
          );
        }
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('applyJob error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to submit application. Please try again.',
      );
    }
  }

  // ! MARK: Submit Rating
  static Future<ApiResponse<Map<String, dynamic>>> submitRating({
    required int ratedUserId,
    required int jobId,
    required int rating,
    String? review,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/ratings');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'rated_user_id': ratedUserId,
        'job_id': jobId,
        'rating': rating,
        'review': review,
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final parsed = jsonDecode(response.body);
          return ApiResponse(
            success: true,
            data: parsed is Map<String, dynamic> ? parsed : {'success': true},
            message: 'Rating submitted successfully!',
          );
        } catch (_) {
          return ApiResponse(
            success: true,
            message: 'Rating submitted successfully!',
          );
        }
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('submitRating error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to submit rating. Please try again.',
      );
    }
  }

  // ! MARK: Fetch eligible rating candidates for authenticated user
  static Future<ApiResponse<List<Map<String, dynamic>>>> fetchEligibleRatings() async {
    try {
      final url = Uri.parse('$baseUrl/ratings/eligible');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint('fetchEligibleRatings returning: ${_shortForLogging(data)}');
        return ApiResponse(
          success: true,
          data: data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList(),
          message: 'Eligible ratings loaded.',
        );
      } else if (response.statusCode == 401) {
        return ApiResponse(
          success: false,
          message: 'Session expired. Please log in again.',
          statusCode: 401,
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchEligibleRatings error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load eligible ratings.',
      );
    }
  }

  // ! MARK: Fetch ratings created by authenticated user
  static Future<ApiResponse<List<Map<String, dynamic>>>> fetchMyRatings() async {
    try {
      final url = Uri.parse('$baseUrl/ratings/mine');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint('fetchMyRatings returning: ${_shortForLogging(data)}');
        return ApiResponse(
          success: true,
          data: data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList(),
          message: 'Your ratings loaded.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchMyRatings error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load your ratings.',
      );
    }
  }

  // ! MARK: Fetch ratings about authenticated user
  static Future<ApiResponse<List<Map<String, dynamic>>>> fetchRatingsAboutMe() async {
    try {
      final url = Uri.parse('$baseUrl/ratings/about-me');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint('fetchRatingsAboutMe returning: ${_shortForLogging(data)}');
        return ApiResponse(
          success: true,
          data: data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList(),
          message: 'Ratings about you loaded.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchRatingsAboutMe error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load ratings about you.',
      );
    }
  }

  // ! MARK: CREATE JOB (recruiter)
  static Future<ApiResponse<Map<String, dynamic>>> createJob({
    required String title,
    required String description,
    required String difficulty,
    required int workingHours,
    required double payment,
    String? location,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/jobs');
      final token = await getToken();
      final recruiterId = await getUserId();

      if (recruiterId == null) {
        return ApiResponse(
          success: false,
          message: 'Please log in to create jobs.',
        );
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'recruiter_id': recruiterId,
        'title': title,
        'description': description,
        'difficulty': difficulty,
        'working_hours': workingHours,
        'payment': payment,
        'location': location,
      });

      final response = await http.post(url, headers: headers, body: body);

      debugPrint('Create job - Status code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final parsed = jsonDecode(response.body);
          final result = parsed is Map<String, dynamic> ? parsed : {'success': true};
          debugPrint('createJob returning: ${_shortForLogging(result)}');
          return ApiResponse(
            success: true,
            data: result,
            message: 'Job created successfully!',
          );
        } catch (_) {
          return ApiResponse(
            success: true,
            message: 'Job created successfully!',
          );
        }
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('createJob error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to create job. Please try again.',
      );
    }
  }

  // ! MARK: Fetch Posted Jobs (recruiter)
  static Future<ApiResponse<List<Map<String, dynamic>>>> fetchPostedJobs() async {
    try {
      final url = Uri.parse('$baseUrl/jobs/posted');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint('fetchPostedJobs returning ${data.length} items');
        return ApiResponse(
          success: true,
          data: data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList(),
          message: 'Posted jobs loaded.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchPostedJobs error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load posted jobs.',
      );
    }
  }

  // ! MARK: Fetch Applicants (for recruiter's jobs)
  static Future<ApiResponse<List<Map<String, dynamic>>>> fetchApplicants() async {
    try {
      final url = Uri.parse('$baseUrl/applicants');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint('fetchApplicants returning ${data.length} items');
        return ApiResponse(
          success: true,
          data: data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList(),
          message: 'Applicants loaded.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchApplicants error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load applicants.',
      );
    }
  }

  // ! MARK: Fetch applications for current seeker (applied jobs)
  static Future<ApiResponse<List<Map<String, dynamic>>>> fetchAppliedJobs() async {
    try {
      final url = Uri.parse('$baseUrl/jobs/applied');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint('fetchAppliedJobs returning ${data.length} items');
        return ApiResponse(
          success: true,
          data: data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList(),
          message: 'Applied jobs loaded.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchAppliedJobs error: $e');
      return ApiResponse(
        success: false,
        message: 'Could not load applied jobs.',
      );
    }
  }

  // ! MARK: Update Application Status (recruiter)
  static Future<ApiResponse<Map<String, dynamic>>> updateApplicationStatus({
    required int applicationId,
    required String status,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/applications/$applicationId/status');
      final token = await getToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({'status': status});
      final response = await http.patch(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final parsed = jsonDecode(response.body);
          final result = parsed is Map<String, dynamic> ? parsed : {'success': true};
          debugPrint('updateApplicationStatus returning: ${_shortForLogging(result)}');
          return ApiResponse(
            success: true,
            data: result,
            message: 'Application status updated!',
          );
        } catch (e) {
          debugPrint('updateApplicationStatus returning success fallback');
          return ApiResponse(
            success: true,
            message: 'Application status updated!',
          );
        }
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('updateApplicationStatus error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to update status. Please try again.',
      );
    }
  }

  // ! MARK: Forgot password (verify email exists)
  static Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required String email,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/password/forgot');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode({'email': email});

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('forgotPassword returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed is Map<String, dynamic> ? parsed : {'message': 'OK'},
          message: 'Email verified. You can now reset your password.',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('forgotPassword error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to verify email. Please try again.',
      );
    }
  }

  // ! MARK: Reset password (change password by email)
  static Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/password/reset');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode({
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('resetPassword returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed is Map<String, dynamic> ? parsed : {'message': 'OK'},
          message: 'Password reset successfully!',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('resetPassword error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to reset password. Please try again.',
      );
    }
  }

  // ! MARK: Update user bio
  static Future<ApiResponse<Map<String, dynamic>>> updateBio({required String? bio}) async {
    try {
      final url = Uri.parse('$baseUrl/user/bio');
      final token = await getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({'bio': bio});

      final response = await http.patch(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('updateBio returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed is Map<String, dynamic> ? parsed : {'success': true},
          message: 'Bio updated successfully!',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('updateBio error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to update bio. Please try again.',
      );
    }
  }

  // ! MARK: Update user skills
  static Future<ApiResponse<Map<String, dynamic>>> updateSkills({
    required String? skills,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/user/skills');
      final token = await getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({'skills': skills});

      final response = await http.patch(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('updateSkills returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed is Map<String, dynamic> ? parsed : {'success': true},
          message: 'Skills updated successfully!',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('updateSkills error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to update skills. Please try again.',
      );
    }
  }

  // ! MARK: Update user location
  static Future<ApiResponse<Map<String, dynamic>>> updateLocation({
    required String? location,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/user/location');
      final token = await getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({'location': location});

      final response = await http.patch(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('updateLocation returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed is Map<String, dynamic> ? parsed : {'success': true},
          message: 'Location updated successfully!',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('updateLocation error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to update location. Please try again.',
      );
    }
  }

  // ! MARK: Update user profile picture (select from predefined avatars)
  static Future<ApiResponse<Map<String, dynamic>>> updateProfilePic({
    required String profilePic,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/user/profile-pic');
      final token = await getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({'profile_pic': profilePic});

      final response = await http.patch(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('updateProfilePic returning: ${_shortForLogging(parsed)}');
        return ApiResponse(
          success: true,
          data: parsed is Map<String, dynamic> ? parsed : {'success': true},
          message: 'Profile picture updated successfully!',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('updateProfilePic error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to update profile picture. Please try again.',
      );
    }
  }

  // ! MARK: Chat API Methods

  /// Get all chat rooms for authenticated user
  static Future<ApiResponse<List<ChatRoom>>> fetchChatRooms() async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          message: 'Not authenticated',
        );
      }

      final response = await http.get(
        Uri.parse('$baseUrl/chat/rooms'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('fetchChatRooms status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final rooms = (parsed['chat_rooms'] ?? parsed['data'] ?? parsed['rooms'] ?? []) as List;
        return ApiResponse(
          success: true,
          data: rooms.map((r) => ChatRoom.fromJson(r)).toList(),
          message: 'Chat rooms loaded',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchChatRooms error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to load chat rooms',
      );
    }
  }

  /// Create or get existing chat room with another user
  static Future<ApiResponse<ChatRoom>> createOrGetChatRoom({
    required int otherUserId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          message: 'Not authenticated',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/rooms'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'other_user_id': otherUserId}),
      );

      debugPrint('createOrGetChatRoom status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsed = jsonDecode(response.body);
        final roomData = parsed['chat_room'] ?? parsed['data'] ?? parsed['room'] ?? parsed;
        return ApiResponse(
          success: true,
          data: ChatRoom.fromJson(roomData),
          message: parsed['message'] ?? 'Chat room ready',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('createOrGetChatRoom error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to create chat room',
      );
    }
  }

  /// Get messages for a chat room
  static Future<ApiResponse<List<ChatMessage>>> fetchChatMessages({
    required int roomId,
    int perPage = 50,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          message: 'Not authenticated',
        );
      }

      final response = await http.get(
        Uri.parse('$baseUrl/chat/rooms/$roomId/messages?per_page=$perPage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('fetchChatMessages status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        final messages = (parsed['messages'] ?? parsed['data'] ?? []) as List;
        
        // Get current user ID for isMe property
        final currentUserResponse = await fetchCurrentUser();
        final currentUserId = currentUserResponse.data?['id'];

        return ApiResponse(
          success: true,
          data: messages
              .map((m) => ChatMessage.fromJson(m, currentUserId: currentUserId))
              .toList(),
          message: 'Messages loaded',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('fetchChatMessages error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to load messages',
      );
    }
  }

  /// Send a message to a chat room
  static Future<ApiResponse<ChatMessage>> sendChatMessage({
    required int roomId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          message: 'Not authenticated',
        );
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/rooms/$roomId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'content': content,
          'message_type': messageType,
        }),
      );

      debugPrint('sendChatMessage status: ${response.statusCode}');
      debugPrint('sendChatMessage response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsed = jsonDecode(response.body);
        debugPrint('sendChatMessage parsed: $parsed');
        
        // Check if response has success field and it's true
        final isSuccess = parsed['success'] == true || response.statusCode == 201;
        
        if (!isSuccess) {
          return ApiResponse(
            success: false,
            message: parsed['message'] ?? 'Failed to send message',
          );
        }
        
        final messageData = parsed['message'] ?? parsed['data'] ?? parsed;
        debugPrint('sendChatMessage messageData: $messageData');
        
        final currentUserResponse = await fetchCurrentUser();
        final currentUserId = currentUserResponse.data?['id'];

        return ApiResponse(
          success: true,
          data: ChatMessage.fromJson(messageData, currentUserId: currentUserId),
          message: 'Message sent',
        );
      } else {
        debugPrint('sendChatMessage error response: ${response.body}');
        return _handleError(response);
      }
    } catch (e, stackTrace) {
      debugPrint('sendChatMessage error: $e');
      debugPrint('sendChatMessage stackTrace: $stackTrace');
      return ApiResponse(
        success: false,
        message: 'Failed to send message',
      );
    }
  }

  /// Delete a message (only sender can delete)
  static Future<ApiResponse<void>> deleteChatMessage({
    required int roomId,
    required int messageId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          message: 'Not authenticated',
        );
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/chat/rooms/$roomId/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('deleteChatMessage status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse(
          success: true,
          message: 'Message deleted',
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('deleteChatMessage error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to delete message',
      );
    }
  }
}
