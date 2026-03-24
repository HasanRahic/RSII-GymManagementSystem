import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  static String? _token;

  static Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('jwt_token', token);
    } else {
      await prefs.remove('jwt_token');
    }
  }

  static Future<bool> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    return _token != null;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse('$kApiBase$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  static dynamic _handle(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(resp.body);
    }

    var message = 'HTTP ${resp.statusCode}';
    try {
      final err = jsonDecode(resp.body);
      if (err is Map && err['message'] != null) {
        message = err['message'].toString();
      }
    } catch (_) {}

    throw ApiException(resp.statusCode, message);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}
