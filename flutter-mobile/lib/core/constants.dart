import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

final String kServerBase = _resolveServerBase();
final String kApiBase = _resolveApiBase();

String _resolveServerBase() {
	if (!kIsWeb && Platform.isAndroid) {
		// Android emulator maps host machine localhost to 10.0.2.2
		return 'http://10.0.2.2:5190';
	}

	return 'http://localhost:5190';
}

String _resolveApiBase() {
	return '$kServerBase/api';
}

const Color kPrimary = Color(0xFF3B82F6);
const Color kBackground = Color(0xFFF1F5F9);
const Color kRed = Color(0xFFEF4444);
const Color kGreen = Color(0xFF10B981);
