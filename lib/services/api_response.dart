class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message = '',
    this.statusCode,
  });
}