import '../core/api_client.dart';
import '../models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaymentFinalStatus { succeeded, failed, pending }

class GymService {
  static Future<List<GymModel>> getAll({String? search, String? city, String? status}) async {
    final query = <String>[];
    if (search != null && search.trim().isNotEmpty) {
      query.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (city != null && city.trim().isNotEmpty && city != 'Svi gradovi') {
      query.add('city=${Uri.encodeComponent(city.trim())}');
    }
    if (status != null && status.trim().isNotEmpty) {
      query.add('status=${Uri.encodeComponent(status.trim())}');
    }
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';

    final data = await ApiClient.get('/gyms$suffix') as List;
    return data.map((e) => GymModel.fromJson(e)).toList();
  }
}

class MembershipService {
  static Future<List<MembershipPlanModel>> getPlans({int? gymId}) async {
    final suffix = gymId == null ? '' : '?gymId=$gymId';
    final data = await ApiClient.get('/memberships/plans$suffix') as List;
    return data.map((e) => MembershipPlanModel.fromJson(e)).toList();
  }

  static Future<List<UserMembership>> getMyMemberships() async {
    final data = await ApiClient.get('/memberships/my') as List;
    return data.map((e) => UserMembership.fromJson(e)).toList();
  }

  static Future<UserMembership?> getMyActiveMembership() async {
    try {
      final data = await ApiClient.get('/memberships/my/active');
      return UserMembership.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getMyAccessStatus() async {
    final data = await ApiClient.get('/memberships/my/access-status');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<UserMembership> renew({
    required int userId,
    required int membershipPlanId,
    double discountPercent = 0,
  }) async {
    final data = await ApiClient.post('/memberships/renew', {
      'userId': userId,
      'membershipPlanId': membershipPlanId,
      'discountPercent': discountPercent,
    });
    return UserMembership.fromJson(data);
  }

  static Future<UserMembership> cancel(int membershipId) async {
    final data = await ApiClient.post('/memberships/$membershipId/cancel', {});
    return UserMembership.fromJson(data as Map<String, dynamic>);
  }
}

class PaymentService {
  static const _pendingPaymentsKey = 'pending_payment_ids';

  static Future<List<Map<String, dynamic>>> getMyPayments({int take = 20}) async {
    final data = await ApiClient.get('/payments/my?take=$take') as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createMembershipCheckout({
    required int membershipPlanId,
    double discountPercent = 0,
  }) async {
    final data = await ApiClient.post('/payments/membership-checkout', {
      'type': 0,
      'membershipPlanId': membershipPlanId,
      'trainingSessionId': null,
      'discountPercent': discountPercent,
      'sessionDurationDays': null,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> createSessionCheckout({
    required int trainingSessionId,
    required int sessionDurationDays,
  }) async {
    final data = await ApiClient.post('/payments/session-checkout', {
      'type': 1,
      'membershipPlanId': null,
      'trainingSessionId': trainingSessionId,
      'discountPercent': 0,
      'sessionDurationDays': sessionDurationDays,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> createShopOrder({
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await ApiClient.post('/payments/shop-order', {
      'items': items,
    });

    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getPaymentStatus(int paymentId) async {
    final data = await ApiClient.get('/payments/$paymentId/status');
    return Map<String, dynamic>.from(data as Map);
  }

  static PaymentFinalStatus parseFinalStatus(dynamic rawStatus) {
    final status = '$rawStatus'.toLowerCase();
    if (rawStatus == 1 || status == 'succeeded') return PaymentFinalStatus.succeeded;
    if (rawStatus == 2 || status == 'failed') return PaymentFinalStatus.failed;
    return PaymentFinalStatus.pending;
  }

  static Future<PaymentFinalStatus> waitForFinalStatus(
    int paymentId, {
    int attempts = 8,
    Duration interval = const Duration(seconds: 7),
  }) async {
    if (paymentId <= 0) return PaymentFinalStatus.pending;

    for (var i = 0; i < attempts; i++) {
      await Future.delayed(interval);
      try {
        final result = await getPaymentStatus(paymentId);
        final finalStatus = parseFinalStatus(result['status']);
        if (finalStatus != PaymentFinalStatus.pending) {
          return finalStatus;
        }
      } catch (_) {
        // Ignore transient errors and continue polling.
      }
    }

    return PaymentFinalStatus.pending;
  }

  static Future<List<int>> getPendingPaymentIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingPaymentsKey) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toList();
  }

  static Future<void> markPendingPayment(int paymentId) async {
    if (paymentId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingPaymentsKey) ?? <String>[];
    final value = paymentId.toString();
    if (!existing.contains(value)) {
      existing.add(value);
      await prefs.setStringList(_pendingPaymentsKey, existing);
    }
  }

  static Future<void> clearPendingPayment(int paymentId) async {
    if (paymentId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingPaymentsKey) ?? <String>[];
    existing.remove(paymentId.toString());
    await prefs.setStringList(_pendingPaymentsKey, existing);
  }

  static Future<Map<String, dynamic>> retryFailedPayment(int paymentId) async {
    final data = await ApiClient.post('/payments/$paymentId/retry-checkout', {});
    return Map<String, dynamic>.from(data as Map);
  }
}

class TrainingSessionService {
  static Future<List<TrainingSessionModel>> getAll({int? gymId, int? trainerId, int? trainingTypeId}) async {
    final query = <String>[];
    if (gymId != null) query.add('gymId=$gymId');
    if (trainerId != null) query.add('trainerId=$trainerId');
    if (trainingTypeId != null) query.add('trainingTypeId=$trainingTypeId');
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';

    final data = await ApiClient.get('/training-sessions$suffix') as List;
    return data.map((e) => TrainingSessionModel.fromJson(e)).toList();
  }

  static Future<TrainingSessionModel> reserve(int sessionId) async {
    await ApiClient.post('/training-sessions/$sessionId/reserve', {});
    final refreshed = await ApiClient.get('/training-sessions/$sessionId');
    return TrainingSessionModel.fromJson(
      Map<String, dynamic>.from(refreshed as Map),
    );
  }

  static Future<void> cancelReservation(int sessionId) async {
    await ApiClient.delete('/training-sessions/$sessionId/reserve');
  }

  static Future<Set<int>> getMyReservationSessionIds() async {
    final data = await ApiClient.get('/training-sessions/my-reservations') as List;
    final ids = <int>{};

    for (final item in data) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final rawStatus = map['status'];
      final status = '$rawStatus'.toLowerCase();
      final isConfirmed = rawStatus == 0 || status == 'confirmed';
      if (!isConfirmed) continue;

      final rawSessionId = map['trainingSessionId'];
      final sessionId = rawSessionId is int
          ? rawSessionId
          : int.tryParse('$rawSessionId');
      if (sessionId != null && sessionId > 0) {
        ids.add(sessionId);
      }
    }

    return ids;
  }

  static Future<List<TrainingSessionModel>> getMyReservations() async {
    final data = await ApiClient.get('/training-sessions/my-reservations') as List;
    return data.map((e) => TrainingSessionModel.fromJson(e)).toList();
  }

  static Future<List<TrainingSessionModel>> getMyPaidGroupSchedule() async {
    final data = await ApiClient.get('/training-sessions/my-paid-group-schedule') as List;
    return data.map((e) => TrainingSessionModel.fromJson(e)).toList();
  }

  static Future<List<RecommendedGymModel>> getRecommendedGyms({
    String? city,
    int? trainingTypeId,
  }) async {
    final query = <String>[];
    if (city != null && city.trim().isNotEmpty && city != 'Svi gradovi') {
      query.add('city=${Uri.encodeComponent(city.trim())}');
    }
    if (trainingTypeId != null) {
      query.add('trainingTypeId=$trainingTypeId');
    }
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';
    final data = await ApiClient.get('/training-sessions/recommendations$suffix') as List;
    return data
        .map((e) => RecommendedGymModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<List<TrainerProfileModel>> getTrainerProfiles({
    String? city,
    int? trainingTypeId,
    String? search,
  }) async {
    final query = <String>[];
    if (city != null && city.trim().isNotEmpty && city != 'Svi gradovi') {
      query.add('city=${Uri.encodeComponent(city.trim())}');
    }
    if (trainingTypeId != null) {
      query.add('trainingTypeId=$trainingTypeId');
    }
    if (search != null && search.trim().isNotEmpty) {
      query.add('search=${Uri.encodeComponent(search.trim())}');
    }
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';
    final data = await ApiClient.get('/training-sessions/trainers$suffix') as List;
    return data
        .map((e) => TrainerProfileModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class ReferenceService {
  static Future<List<CityModel>> getCities() async {
    final data = await ApiClient.get('/reference/cities') as List;
    return data.map((e) => CityModel.fromJson(e)).toList();
  }

  static Future<List<TrainingTypeModel>> getTrainingTypes() async {
    final data = await ApiClient.get('/reference/training-types') as List;
    return data.map((e) => TrainingTypeModel.fromJson(e)).toList();
  }
}

class CheckInService {
  static Future<CheckInModel> checkIn(int gymId) async {
    final data = await ApiClient.post('/checkins', {'gymId': gymId});
    return CheckInModel.fromJson(data);
  }

  static Future<CheckInModel> checkOut(int checkInId) async {
    final data = await ApiClient.post('/checkins/checkout', {'checkInId': checkInId});
    return CheckInModel.fromJson(data);
  }

  static Future<List<CheckInModel>> getMyHistory({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String>[];
    if (from != null) query.add('from=${Uri.encodeComponent(from.toIso8601String())}');
    if (to != null) query.add('to=${Uri.encodeComponent(to.toIso8601String())}');
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';

    final data = await ApiClient.get('/checkins/my$suffix') as List;
    return data.map((e) => CheckInModel.fromJson(e)).toList();
  }
}

class ProgressService {
  static Future<List<ProgressMeasurementModel>> getMyMeasurements({
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String>[];
    if (from != null) query.add('from=${Uri.encodeComponent(from.toIso8601String())}');
    if (to != null) query.add('to=${Uri.encodeComponent(to.toIso8601String())}');
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';

    final data = await ApiClient.get('/progress$suffix') as List;
    return data
        .map((e) => ProgressMeasurementModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<ProgressMeasurementModel> addMeasurement({
    required DateTime date,
    double? weightKg,
    double? bodyFatPercent,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? armCm,
    double? legCm,
    String? notes,
  }) async {
    final data = await ApiClient.post('/progress', {
      'date': date.toIso8601String(),
      'weightKg': weightKg,
      'bodyFatPercent': bodyFatPercent,
      'chestCm': chestCm,
      'waistCm': waistCm,
      'hipsCm': hipsCm,
      'armCm': armCm,
      'legCm': legCm,
      'notes': notes,
    });

    return ProgressMeasurementModel.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  static Future<void> deleteMeasurement(int measurementId) async {
    await ApiClient.delete('/progress/$measurementId');
  }

  static Future<List<UserBadgeModel>> getMyBadges() async {
    final data = await ApiClient.get('/progress/badges') as List;
    return data
        .map((e) => UserBadgeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class TrainerApplicationService {
  static Future<TrainerApplicationModel> apply({
    required String biography,
    required String experience,
    String? certifications,
    String? availability,
  }) async {
    final data = await ApiClient.post('/trainer-applications', {
      'biography': biography,
      'experience': experience,
      'certifications': certifications,
      'availability': availability,
    });
    return TrainerApplicationModel.fromJson(data as Map<String, dynamic>);
  }
}
