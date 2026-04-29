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
    if (!hasToken) return false;

    try {
      final me = await ApiClient.get('/users/me') as Map<String, dynamic>;
      final roleRaw = me['role'];
      final role = roleRaw is int
          ? roleRaw
          : (roleRaw is String
              ? _roleFromString(roleRaw)
              : 0);

      _user = AuthResponse(
        id: me['id'],
        firstName: me['firstName'],
        lastName: me['lastName'],
        username: me['username'],
        email: me['email'],
        role: role,
        token: ApiClient.currentToken ?? '',
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

  int _roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 0;
      case 'member':
        return 1;
      case 'trainer':
        return 2;
      default:
        return 0;
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
    } catch (e) {
      _error = 'Greška pri prijavi.';
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.post('/auth/logout', {});
    } catch (_) {
      // Best-effort server logout; local cleanup still has to happen.
    }
    await ApiClient.setToken(null);
    _user = null;
    notifyListeners();
  }
}
