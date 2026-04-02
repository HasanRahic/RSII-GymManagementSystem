import '../core/api_client.dart';
import '../models/models.dart';

class GymService {
  static Future<List<GymModel>> getAll() async {
    final data = await ApiClient.get('/gyms') as List;
    return data.map((e) => GymModel.fromJson(e)).toList();
  }
}

class MembershipService {
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
