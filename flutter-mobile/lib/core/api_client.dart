import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  static String? _token;
  static const Duration _requestTimeout = Duration(seconds: 12);

  static String? get currentToken => _token;

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

  static Future<dynamic> get(String path) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$kApiBase$path'),
            headers: _headers,
          )
          .timeout(_requestTimeout);
      return _handle(resp);
    } on TimeoutException {
      throw ApiException(408, 'Server ne odgovara. Provjerite da li je backend pokrenut.');
    } on SocketException {
      throw ApiException(0, 'Nema konekcije sa backendom.');
    }
  }

  static Future<dynamic> getRaw(String url) async {
    try {
      final resp = await http
          .get(
            Uri.parse(url),
            headers: _headers,
          )
          .timeout(_requestTimeout);
      return _handle(resp);
    } on TimeoutException {
      throw ApiException(408, 'Server ne odgovara. Provjerite da li je backend pokrenut.');
    } on SocketException {
      throw ApiException(0, 'Nema konekcije sa backendom.');
    }
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$kApiBase$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _handle(resp);
    } on TimeoutException {
      throw ApiException(408, 'Server ne odgovara. Provjerite da li je backend pokrenut.');
    } on SocketException {
      throw ApiException(0, 'Nema konekcije sa backendom.');
    }
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http
          .put(
            Uri.parse('$kApiBase$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _handle(resp);
    } on TimeoutException {
      throw ApiException(408, 'Server ne odgovara. Provjerite da li je backend pokrenut.');
    } on SocketException {
      throw ApiException(0, 'Nema konekcije sa backendom.');
    }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final resp = await http
          .delete(
            Uri.parse('$kApiBase$path'),
            headers: _headers,
          )
          .timeout(_requestTimeout);
      return _handle(resp);
    } on TimeoutException {
      throw ApiException(408, 'Server ne odgovara. Provjerite da li je backend pokrenut.');
    } on SocketException {
      throw ApiException(0, 'Nema konekcije sa backendom.');
    }
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
