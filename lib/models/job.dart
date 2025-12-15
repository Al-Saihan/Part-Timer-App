class Job {
  final int id;
  final String title;
  final String description;
  final String difficulty;
  final int workingHours;
  final double payment;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.workingHours,
    required this.payment,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      difficulty: json['difficulty'],
      workingHours: json['working_hours'],
      payment: double.parse(json['payment'].toString()),
    );
  }
}
