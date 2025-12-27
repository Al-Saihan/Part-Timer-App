// ! MARK: API Response
// ? Generic response wrapper for all API calls
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
