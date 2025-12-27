import 'package:flutter/foundation.dart';

// ! MARK: Job Model
class Job {
  final int id;
  final String title;
  final String description;
  final String difficulty;
  final int workingHours;
  final double payment;
  final String? location;
  final Map<String, dynamic>? recruiter;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.workingHours,
    required this.payment,
    this.location,
    this.recruiter,
  });

  // ! MARK: JSON Parsing
  factory Job.fromJson(Map<String, dynamic> json) {
    // ? Parse recruiter info from various possible keys
    Map<String, dynamic>? recruiterMap;
    try {
      if (json['recruiter'] is Map) {
        recruiterMap = Map<String, dynamic>.from(json['recruiter']);
      } else if (json['user'] is Map) {
        recruiterMap = Map<String, dynamic>.from(json['user']);
      } else if (json['posted_by'] is Map) {
        recruiterMap = Map<String, dynamic>.from(json['posted_by']);
      }
    } catch (_) {
      recruiterMap = null;
    }

    if (recruiterMap == null) {
      try {
        debugPrint(
          'Job.fromJson: recruiter missing or unexpected for job id=${json["id"]}',
        );
      } catch (_) {}
    }

    return Job(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      difficulty: json['difficulty'],
      workingHours: json['working_hours'] ?? json['workingHours'] ?? 0,
      payment: double.parse(json['payment'].toString()),
      location:
          json['location']?.toString() ?? json['job_location']?.toString(),
      recruiter: recruiterMap,
    );
  }
}
