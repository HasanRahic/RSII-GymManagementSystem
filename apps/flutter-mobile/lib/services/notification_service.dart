import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _available = true;

  static bool get _supportsLocalNotifications =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static Future<void> initialize() async {
    if (_initialized || !_available) return;
    if (!_supportsLocalNotifications) {
      _available = false;
      return;
    }

    try {
      tz.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(
        android: android,
        iOS: DarwinInitializationSettings(),
      );

      await _plugin.initialize(initSettings);

      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (_) {
      _available = false;
    }
  }

  static Future<void> syncSessionReminders(
    List<TrainingSessionModel> sessions,
  ) async {
    await initialize();
    if (!_initialized || !_available) return;

    try {
      await _plugin.cancelAll();

      final now = DateTime.now();
      final eligibleSessions = sessions.where((session) {
        final start = _sessionStartAt(session);
        return start.isAfter(now) && start.difference(now).inHours <= 24;
      }).toList();

      for (final session in eligibleSessions) {
        final start = _sessionStartAt(session);
        final notifyAt = start.subtract(const Duration(hours: 1));
        if (notifyAt.isBefore(now)) {
          continue;
        }

        final notificationId = _notificationIdForSession(session.id);

        await _plugin.zonedSchedule(
          notificationId,
          'Grupni trening uskoro',
          '${session.title} pocinje u ${_formatTime(start)} u ${session.gymName}.',
          tz.TZDateTime.from(notifyAt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'session_reminders',
              'Podsjetnici za treninge',
              channelDescription: 'Podsjetnici za grupne treninge i termine',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      _available = false;
    }
  }

  static int _notificationIdForSession(int sessionId) => 100000 + sessionId;

  static DateTime _sessionStartAt(TrainingSessionModel session) {
    final merged = DateTime.tryParse('${session.date}T${session.startTime}');
    if (merged != null) return merged;

    final dateOnly = DateTime.tryParse(session.date);
    if (dateOnly != null) return dateOnly;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatTime(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
