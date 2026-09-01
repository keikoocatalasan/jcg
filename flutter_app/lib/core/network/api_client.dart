import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';
import '../errors/result.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient(this.baseUrl, {http.Client? client})
      : _client = client ?? http.Client();

  String? _getToken() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Map<String, String> _headers({bool multipart = false}) {
    final headers = <String, String>{
      if (!multipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Result<Map<String, dynamic>>> get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client.get(uri, headers: _headers());
      return _handleResponse(response);
    } catch (e) {
      return Failure(_toAppError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client.post(
        uri,
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      return Failure(_toAppError(e));
    }
  }

  Future<Result<Map<String, dynamic>>> postMultipart(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, String>? fields,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(multipart: true));
      request.fields.addAll(fields ?? {});
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return Failure(_toAppError(e));
    }
  }

  Result<Map<String, dynamic>> _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Success(body);
    }

    final error = body['error'] as Map<String, dynamic>?;
    final detail = body['detail'];
    final detailError = detail is Map<String, dynamic>
        ? detail['error'] as Map<String, dynamic>?
        : null;
    final message = error?['message'] as String? ??
        detailError?['message'] as String? ??
        detail as String? ??
        body['message'] as String? ??
        'Request failed with status ${response.statusCode}';

    return Failure(AppError(
      code: error?['code'] as String? ??
          detailError?['code'] as String? ??
          'SERVER_ERROR',
      message: message,
      details: {'statusCode': response.statusCode, 'body': body},
    ));
  }

  AppError _toAppError(Object e) {
    if (e is SocketException) {
      return AppError(
        code: 'NETWORK',
        message: 'No internet connection',
        details: e,
      );
    }
    if (e is FormatException) {
      return AppError(
        code: 'FORMAT_ERROR',
        message: 'Invalid response format',
        details: e,
      );
    }
    if (e is http.ClientException) {
      return AppError(
        code: 'NETWORK',
        message: 'Connection error: ${e.message}',
        details: e,
      );
    }
    return AppError(
      code: 'UNKNOWN',
      message: e.toString(),
      details: e,
    );
  }

  void dispose() {
    _client.close();
  }
}
