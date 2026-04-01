import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  AuthResponse? _user;
  bool _loading = false;
  String? _error;

  AuthResponse? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<bool> tryAutoLogin() async {
    final hasToken = await ApiClient.loadToken();
    if (!hasToken) {
      _user = null;
      notifyListeners();
      return false;
    }

    try {
      final data = await ApiClient.get('/users/me');
      final token = ApiClient.currentToken;
      if (token == null) return false;

      _user = AuthResponse(
        id: data['id'],
        firstName: data['firstName'] ?? '',
        lastName: data['lastName'] ?? '',
        username: data['username'] ?? '',
        email: data['email'] ?? '',
        role: data['role'] ?? 0,
        token: token,
      );
      notifyListeners();
      return true;
    } catch (_) {
      await ApiClient.setToken(null);
      _user = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.post('/auth/login', {
        'username': username,
        'password': password,
      });
      _user = AuthResponse.fromJson(data);
      await ApiClient.setToken(_user!.token);
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'Greska pri prijavi.';
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await ApiClient.setToken(null);
    _user = null;
    notifyListeners();
  }
}
