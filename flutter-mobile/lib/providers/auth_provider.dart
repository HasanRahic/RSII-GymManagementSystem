import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  static const _cityCachePrefix = 'cached_city_name_user_';
  static const _userCachePrefix = 'cached_user_profile_user_';

  AuthResponse? _user;
  bool _loading = false;
  String? _error;

  Future<void> _cacheCityName(int userId, String? cityName) async {
    if (cityName == null || cityName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cityCachePrefix$userId', cityName.trim());
  }

  Future<String?> _readCachedCityName(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_cityCachePrefix$userId');
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _cacheUserProfile(AuthResponse user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_userCachePrefix${user.id}',
      jsonEncode({
        'id': user.id,
        'firstName': user.firstName,
        'lastName': user.lastName,
        'username': user.username,
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'cityName': user.cityName,
        'role': user.role,
      }),
    );
    await _cacheCityName(user.id, user.cityName);
  }

  Future<Map<String, dynamic>?> _readCachedUserProfile(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_userCachePrefix$userId');
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore corrupt cached payload and fall back to API response.
    }

    return null;
  }

  String? _pickString(dynamic primary, [dynamic fallback]) {
    final primaryText = primary?.toString().trim();
    if (primaryText != null && primaryText.isNotEmpty) return primaryText;

    final fallbackText = fallback?.toString().trim();
    if (fallbackText != null && fallbackText.isNotEmpty) return fallbackText;

    return null;
  }

  Future<AuthResponse> _buildUserFromApiData(
    Map<String, dynamic> data,
    String token,
  ) async {
    final userId = data['id'] as int;
    final cached = await _readCachedUserProfile(userId);
    final cityName = _pickString(data['cityName'], cached?['cityName']) ??
        await _readCachedCityName(userId);

    return AuthResponse(
      id: userId,
      firstName: _pickString(data['firstName'], cached?['firstName']) ?? '',
      lastName: _pickString(data['lastName'], cached?['lastName']) ?? '',
      username: _pickString(data['username'], cached?['username']) ?? '',
      email: _pickString(data['email'], cached?['email']) ?? '',
      phoneNumber: _pickString(data['phoneNumber'], cached?['phoneNumber']),
      cityName: cityName,
      role: data['role'] ?? cached?['role'] ?? 0,
      token: token,
    );
  }

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
      final data = Map<String, dynamic>.from(
        await ApiClient.get('/users/me') as Map,
      );
      final token = ApiClient.currentToken;
      if (token == null) return false;

      final user = await _buildUserFromApiData(data, token);
      _user = user;
      await _cacheUserProfile(user);
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
      final auth = AuthResponse.fromJson(data);
      await ApiClient.setToken(auth.token);
      await refreshMe();
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

  Future<void> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
    DateTime? dateOfBirth,
    int? cityId,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.post('/auth/register', {
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'cityId': cityId,
      });
      final auth = AuthResponse.fromJson(data);
      await ApiClient.setToken(auth.token);
      await refreshMe();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = 'Greska pri registraciji.';
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

  Future<void> refreshMe() async {
    final data = Map<String, dynamic>.from(
      await ApiClient.get('/users/me') as Map,
    );
    final token = ApiClient.currentToken;
    if (token == null) return;

    final user = await _buildUserFromApiData(data, token);
    _user = user;
    await _cacheUserProfile(user);
    notifyListeners();
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    String? phoneNumber,
  }) async {
    if (_user == null) {
      throw ApiException(401, 'Niste prijavljeni.');
    }

    final current = await ApiClient.get('/users/me');

    await ApiClient.put('/users/${_user!.id}', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'dateOfBirth': current['dateOfBirth'],
      'cityId': current['cityId'],
      'primaryGymId': current['primaryGymId'],
      'profileImageUrl': current['profileImageUrl'],
    });

    await refreshMe();
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await ApiClient.post('/users/change-password', {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }
}
