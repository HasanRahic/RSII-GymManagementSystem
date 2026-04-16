import '../core/api_client.dart';
import '../models/models.dart';

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
    final data = await ApiClient.post('/training-sessions/$sessionId/reserve', {});
    return TrainingSessionModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> cancelReservation(int sessionId) async {
    await ApiClient.delete('/training-sessions/$sessionId/reserve');
  }

  static Future<List<TrainingSessionModel>> getMyReservations() async {
    final data = await ApiClient.get('/training-sessions/my-reservations') as List;
    return data.map((e) => TrainingSessionModel.fromJson(e)).toList();
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
