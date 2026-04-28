import 'package:flutter/material.dart';

const String _serverBaseOverride = String.fromEnvironment('SERVER_BASE_URL');
const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');

final String kServerBase = _resolveServerBase();
final String kApiBase = _resolveApiBase();

String _resolveServerBase() {
  if (_serverBaseOverride.trim().isNotEmpty) {
    return _serverBaseOverride;
  }

  return 'http://localhost:5190';
}

String _resolveApiBase() {
  if (_apiBaseOverride.trim().isNotEmpty) {
    return _apiBaseOverride;
  }

  return '$kServerBase/api';
}

// Color palette
const Color kSidebar = Color(0xFF1E293B);
const Color kSidebarSel = Color(0xFF334155);
const Color kPrimary = Color(0xFF3B82F6);
const Color kBackground = Color(0xFFF1F5F9);
const Color kGreen = Color(0xFF22C55E);
const Color kOrange = Color(0xFFF97316);
const Color kPurple = Color(0xFF8B5CF6);
const Color kRed = Color(0xFFEF4444);
const Color kTeal = Color(0xFF14B8A6);
const Color kCard = Colors.white;
