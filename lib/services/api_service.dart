import 'dart:convert';
import 'package:flutter/rendering.dart';
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
      final parsed = jsonDecode(response.body);
      debugPrint('register returning: ${jsonEncode(parsed)}');
      return parsed;
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
      try {
        debugPrint('login returning: ${jsonEncode(body)}');
      } catch (_) {
        debugPrint('login returning (unencodable): $body');
      }

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
      return body;
    } else {
      debugPrint('Login failed: ${response.statusCode} ${response.headers}');
      throw Exception(
        'Failed to login: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: All Jobs
  static Future<List<Job>> fetchJobs() async {
    final url = Uri.parse('$baseUrl/jobs');

    final token = await getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

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
          // Single wrapper or map of id -> wrapper
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

      // Diagnostics for normalized items
      for (var item in normalized) {
        try {
          final id = item['id']?.toString() ?? '<no-id>';
          final hasRecruiter = item.containsKey('recruiter') ? (item['recruiter'] == null ? 'null' : item['recruiter'].runtimeType.toString()) : 'absent';
          debugPrint('fetchJobs(normalized): job id=$id recruiter=$hasRecruiter');
        } catch (_) {}
      }

      try {
        debugPrint('fetchJobs returning normalized ${jsonEncode(normalized)}');
      } catch (_) {
        debugPrint('fetchJobs returning ${normalized.length} normalized items');
      }

      return normalized.map((job) => Job.fromJson(job)).toList();
    } else {
      throw Exception(
        'Failed to fetch jobs: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Fetch single job details
  static Future<Map<String, dynamic>> fetchJobDetails({
    required int jobId,
  }) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      debugPrint('fetchJobDetails: parsed=$parsed');
      if (parsed is Map<String, dynamic>) {
        try {
          debugPrint('fetchJobDetails returning: ${jsonEncode(parsed)}');
        } catch (_) {
          debugPrint('fetchJobDetails returning (non-encodable): $parsed');
        }
        return parsed;
      }
      throw Exception('Unexpected job details format');
    } else {
      throw Exception(
        'Failed to fetch job details: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Logout
  static Future<void> logout() async {
    final url = Uri.parse('$baseUrl/logout');
    final token = await getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.post(url, headers: headers);

    if (response.statusCode == 200) {
      // clear local user id as well
      await clearUserId();
      debugPrint('logout successful');
      return;
    } else {
      throw Exception(
        'Failed to logout: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Fetch Current User
  static Future<Map<String, dynamic>?> _fetchCurrentUser() async {
    final token = await getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    // Only call the canonical /me endpoint (keep client simple and avoid hitting non-existing endpoints)
    try {
      final url = Uri.parse('$baseUrl/me');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        try {
          final parsed = jsonDecode(response.body);
          try {
            debugPrint('_fetchCurrentUser parsed: ${jsonEncode(parsed)}');
          } catch (_) {
            debugPrint('_fetchCurrentUser parsed (non-encodable): $parsed');
          }
          return parsed is Map<String, dynamic> ? parsed : null;
        } catch (_) {
          return null;
        }
      }
    } catch (_) {}

    return null;
  }

  // Public wrapper to fetch current authenticated user
  static Future<Map<String, dynamic>?> fetchCurrentUser() async {
    return await _fetchCurrentUser();
  }

  // ! MARK: Job Apply
  static Future<Map<String, dynamic>> applyJob({required int jobId}) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/apply');
    final token = await getToken();

    int? seekerId = await getUserId();
    debugPrint('applyJob: saved seekerId=$seekerId');

    // If no saved seeker id, try to fetch current authenticated user
    if (seekerId == null) {
      try {
        final fetched = await _fetchCurrentUser();
        if (fetched != null) {
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
      throw Exception(
        'Missing seeker_id: cannot apply without a seeker id. Ensure user is logged in.',
      );
    }

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final body = jsonEncode({'seeker_id': seekerId});

    final response = await http.post(url, headers: headers, body: body);

    debugPrint('Status code: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    // Try to parse JSON safely
    dynamic parsed;
    try {
      parsed = jsonDecode(response.body);
    } catch (_) {
      parsed = null;
    }

    if (response.statusCode == 200) {
      final result = (parsed is Map<String, dynamic>) ? parsed : {'message': 'Applied'};
      try {
        debugPrint('applyJob returning: ${jsonEncode(result)}');
      } catch (_) {
        debugPrint('applyJob returning (non-encodable): $result');
      }
      return result;
    } else {
      // clearer message when HTML redirect returned
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html')) {
        throw Exception(
          'Failed to apply: server returned HTML (possible redirect). Check API_BASE_URL and authentication.',
        );
      }

      final bodyStr = response.body;
      debugPrint('Error applying to job: ${response.statusCode} $bodyStr');
      throw Exception('Failed to apply: ${response.statusCode} $bodyStr');
    }
  }

  // ! MARK: Submit Rating
  static Future<Map<String, dynamic>> submitRating({
    required int ratedUserId,
    required int jobId,
    required int rating,
    String? review,
  }) async {
    final url = Uri.parse('$baseUrl/ratings');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

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
        return parsed is Map<String, dynamic> ? parsed : {'success': true};
      } catch (_) {
        return {'success': true};
      }
    } else {
      throw Exception('Failed to submit rating: ${response.statusCode} ${response.body}');
    }
  }

  // ! MARK: Fetch eligible rating candidates for authenticated user
  static Future<List<Map<String, dynamic>>> fetchEligibleRatings() async {
    final url = Uri.parse('$baseUrl/ratings/eligible');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      try {
        debugPrint('fetchEligibleRatings returning: ${jsonEncode(data)}');
      } catch (_) {
        debugPrint('fetchEligibleRatings returning ${data.length} items');
      }
      return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthenticated (401)');
    } else {
      throw Exception('Failed to fetch eligible ratings: ${response.statusCode} ${response.body}');
    }
  }

  // ! MARK: Fetch ratings created by authenticated user
  static Future<List<Map<String, dynamic>>> fetchMyRatings() async {
    final url = Uri.parse('$baseUrl/ratings/mine');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      try {
        debugPrint('fetchMyRatings returning: ${jsonEncode(data)}');
      } catch (_) {}
      return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Failed to fetch my ratings: ${response.statusCode} ${response.body}');
    }
  }

  // ! MARK: Fetch ratings about authenticated user
  static Future<List<Map<String, dynamic>>> fetchRatingsAboutMe() async {
    final url = Uri.parse('$baseUrl/ratings/about-me');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      try {
        debugPrint('fetchRatingsAboutMe returning: ${jsonEncode(data)}');
      } catch (_) {}
      return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Failed to fetch ratings about me: ${response.statusCode} ${response.body}');
    }
  }

  // ! MARK: CREATE JOB (recruiter)
  static Future<Map<String, dynamic>> createJob({
    required String title,
    required String description,
    required String difficulty,
    required int workingHours,
    required double payment,
    String? location,
  }) async {
    final url = Uri.parse('$baseUrl/jobs');
    final token = await getToken();
    final recruiterId = await getUserId();

    if (recruiterId == null) {
      throw Exception(
        'Missing recruiter_id: cannot create job without a recruiter id.',
      );
    }

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

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
    debugPrint('Create job - Response body: ${response.body}');

    try {
      final parsed = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = parsed is Map<String, dynamic> ? parsed : {'success': true};
        try {
          debugPrint('createJob returning: ${jsonEncode(result)}');
        } catch (_) {
          debugPrint('createJob returning (non-encodable): $result');
        }
        return result;
      } else {
        throw Exception(
          'Failed to create job: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to create job: $e');
    }
  }

  // ! MARK: Fetch Posted Jobs (recruiter)
  static Future<List<Map<String, dynamic>>> fetchPostedJobs() async {
    final url = Uri.parse('$baseUrl/jobs/posted');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      try {
        debugPrint('fetchPostedJobs returning: ${jsonEncode(data)}');
      } catch (_) {
        debugPrint('fetchPostedJobs returning ${data.length} items');
      }
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      throw Exception(
        'Failed to fetch posted jobs: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Fetch Applicants (for recruiter's jobs)
  static Future<List<Map<String, dynamic>>> fetchApplicants() async {
    final url = Uri.parse('$baseUrl/applicants');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      try {
        debugPrint('fetchApplicants returning: ${jsonEncode(data)}');
      } catch (_) {
        debugPrint('fetchApplicants returning ${data.length} items');
      }
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      throw Exception(
        'Failed to fetch applicants: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Fetch applications for current seeker (applied jobs)
  static Future<List<Map<String, dynamic>>> fetchAppliedJobs() async {
    final url = Uri.parse('$baseUrl/jobs/applied');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      try {
        debugPrint('fetchAppliedJobs returning: ${jsonEncode(data)}');
      } catch (_) {
        debugPrint('fetchAppliedJobs returning ${data.length} items');
      }
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      throw Exception(
        'Failed to fetch applied jobs: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Update Application Status (recruiter)
  static Future<Map<String, dynamic>> updateApplicationStatus({
    required int applicationId,
    required String status,
  }) async {
    final url = Uri.parse('$baseUrl/applications/$applicationId/status');
    final token = await getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final body = jsonEncode({'status': status});
    final response = await http.patch(url, headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final parsed = jsonDecode(response.body);
        final result = parsed is Map<String, dynamic> ? parsed : {'success': true};
        try {
          debugPrint('updateApplicationStatus returning: ${jsonEncode(result)}');
        } catch (_) {
          debugPrint('updateApplicationStatus returning (non-encodable): $result');
        }
        return result;
      } catch (e) {
        debugPrint('updateApplicationStatus returning success fallback');
        return {'success': true};
      }
    } else {
      throw Exception(
        'Failed to update status: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Forgot password (verify email exists)
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/password/forgot');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode({'email': email});

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      try {
        debugPrint('forgotPassword returning: ${jsonEncode(parsed)}');
      } catch (_) {
        debugPrint('forgotPassword returning (non-encodable): $parsed');
      }
      return parsed is Map<String, dynamic> ? parsed : {'message': 'OK'};
    } else {
      throw Exception(
        'Failed to verify email: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Reset password (change password by email)
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
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
      try {
        debugPrint('resetPassword returning: ${jsonEncode(parsed)}');
      } catch (_) {
        debugPrint('resetPassword returning (non-encodable): $parsed');
      }
      return parsed is Map<String, dynamic> ? parsed : {'message': 'OK'};
    } else {
      throw Exception(
        'Failed to reset password: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Update user bio
  static Future<Map<String, dynamic>> updateBio({required String? bio}) async {
    final url = Uri.parse('$baseUrl/user/bio');
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final body = jsonEncode({'bio': bio});

    final response = await http.patch(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      try {
        debugPrint('updateBio returning: ${jsonEncode(parsed)}');
      } catch (_) {
        debugPrint('updateBio returning (non-encodable): $parsed');
      }
      return parsed is Map<String, dynamic> ? parsed : {'success': true};
    } else {
      throw Exception(
        'Failed to update bio: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Update user skills
  static Future<Map<String, dynamic>> updateSkills({
    required String? skills,
  }) async {
    final url = Uri.parse('$baseUrl/user/skills');
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final body = jsonEncode({'skills': skills});

    final response = await http.patch(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      try {
        debugPrint('updateSkills returning: ${jsonEncode(parsed)}');
      } catch (_) {
        debugPrint('updateSkills returning (non-encodable): $parsed');
      }
      return parsed is Map<String, dynamic> ? parsed : {'success': true};
    } else {
      throw Exception(
        'Failed to update skills: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Update user location
  static Future<Map<String, dynamic>> updateLocation({
    required String? location,
  }) async {
    final url = Uri.parse('$baseUrl/user/location');
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final body = jsonEncode({'location': location});

    final response = await http.patch(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      try {
        debugPrint('updateLocation returning: ${jsonEncode(parsed)}');
      } catch (_) {
        debugPrint('updateLocation returning (non-encodable): $parsed');
      }
      return parsed is Map<String, dynamic> ? parsed : {'success': true};
    } else {
      throw Exception(
        'Failed to update location: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ! MARK: Update user profile picture (select from predefined avatars)
  static Future<Map<String, dynamic>> updateProfilePic({
    required String profilePic,
  }) async {
    final url = Uri.parse('$baseUrl/user/profile-pic');
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final body = jsonEncode({'profile_pic': profilePic});

    final response = await http.patch(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      try {
        debugPrint('updateProfilePic returning: ${jsonEncode(parsed)}');
      } catch (_) {
        debugPrint('updateProfilePic returning (non-encodable): $parsed');
      }
      return parsed is Map<String, dynamic> ? parsed : {'success': true};
    } else {
      throw Exception(
        'Failed to update profile picture: ${response.statusCode} ${response.body}',
      );
    }
  }
}
