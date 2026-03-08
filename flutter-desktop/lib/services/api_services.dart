import '../core/api_client.dart';
import '../models/models.dart';

// ─── Gym Service ──────────────────────────────────────────────────────────────

class GymService {
  static Future<List<GymModel>> getAll({
    String? search,
    String? city,
    int? status,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (status != null) params['status'] = status.toString();
    final q = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    final data = await ApiClient.get('/gyms$q') as List;
    return data.map((e) => GymModel.fromJson(e)).toList();
  }

  static Future<GymModel> create(Map<String, dynamic> dto) async {
    final data = await ApiClient.post('/gyms', dto);
    return GymModel.fromJson(data);
  }

  static Future<GymModel> update(int id, Map<String, dynamic> dto) async {
    final data = await ApiClient.put('/gyms/$id', dto);
    return GymModel.fromJson(data);
  }

  static Future<GymModel> updateStatus(int id, int status) async {
    final data = await ApiClient.patch('/gyms/$id/status?status=$status');
    return GymModel.fromJson(data);
  }
}

// ─── User Service ─────────────────────────────────────────────────────────────

class UserService {
  static Future<List<UserModel>> getAll({String? search, String? role}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;
    final q = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    final data = await ApiClient.get('/users$q') as List;
    return data.map((e) => UserModel.fromJson(e)).toList();
  }

  static Future<UserModel> getById(int id) async {
    final data = await ApiClient.get('/users/$id');
    return UserModel.fromJson(data);
  }

  static Future<void> setActive(int id, bool isActive) async {
    await ApiClient.patch('/users/$id/active?isActive=$isActive');
  }
}

// ─── Membership Service ───────────────────────────────────────────────────────

class MembershipService {
  static Future<List<MembershipPlan>> getPlans({int? gymId}) async {
    final q = gymId != null ? '?gymId=$gymId' : '';
    final data = await ApiClient.get('/memberships/plans$q') as List;
    return data.map((e) => MembershipPlan.fromJson(e)).toList();
  }

  static Future<MembershipPlan> createPlan(Map<String, dynamic> dto) async {
    final data = await ApiClient.post('/memberships/plans', dto);
    return MembershipPlan.fromJson(data);
  }

  static Future<List<UserMembership>> getAllMemberships() async {
    final data = await ApiClient.get('/memberships') as List;
    return data.map((e) => UserMembership.fromJson(e)).toList();
  }

  static Future<UserMembership> renew(Map<String, dynamic> dto) async {
    final data = await ApiClient.post('/memberships/renew', dto);
    return UserMembership.fromJson(data);
  }
}

// ─── Check-in Service ─────────────────────────────────────────────────────────

class CheckInService {
  static Future<List<CheckInModel>> getGymCheckIns(int gymId,
      {String? date}) async {
    final q = date != null ? '?date=$date' : '';
    final data = await ApiClient.get('/checkins/gym/$gymId$q') as List;
    return data.map((e) => CheckInModel.fromJson(e)).toList();
  }

  static Future<List<CheckInModel>> getAllCheckIns({String? date}) async {
    // Get check-ins from all gyms by fetching with a broad date range via reports
    // We fallback to gym 1 if no specific gym; screens should load per gym
    final data = await ApiClient.get('/checkins/gym/1${date != null ? '?date=$date' : ''}') as List;
    return data.map((e) => CheckInModel.fromJson(e)).toList();
  }
}

// ─── Trainer Application Service ──────────────────────────────────────────────

class TrainerService {
  static Future<List<TrainerApplication>> getAll({int? status}) async {
    final q = status != null ? '?status=$status' : '';
    final data = await ApiClient.get('/trainer-applications$q') as List;
    return data.map((e) => TrainerApplication.fromJson(e)).toList();
  }

  static Future<TrainerApplication> review(
      int id, int status, String? adminNote) async {
    final data = await ApiClient.patch('/trainer-applications/$id/review', {
      'status': status,
      if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
    });
    return TrainerApplication.fromJson(data);
  }
}

// ─── Report Service ───────────────────────────────────────────────────────────

class ReportService {
  static Future<DashboardStats> getDashboard({int? gymId}) async {
    final q = gymId != null ? '?gymId=$gymId' : '';
    final data = await ApiClient.get('/reports/dashboard$q');
    return DashboardStats.fromJson(data);
  }

  static Future<double> getRevenue(String from, String to,
      {int? gymId}) async {
    var q = '?from=$from&to=$to';
    if (gymId != null) q += '&gymId=$gymId';
    final data = await ApiClient.get('/reports/revenue$q');
    return (data as num).toDouble();
  }

  static Future<List<CheckInModel>> getCheckInReport(String from, String to,
      {int? gymId}) async {
    var q = '?from=$from&to=$to';
    if (gymId != null) q += '&gymId=$gymId';
    final data = await ApiClient.get('/reports/checkins$q') as List;
    return data.map((e) => CheckInModel.fromJson(e)).toList();
  }
}

// ─── Reference Service ────────────────────────────────────────────────────────

class ReferenceService {
  static Future<List<ReferenceItem>> getCities({int? countryId}) async {
    final q = countryId != null ? '?countryId=$countryId' : '';
    final data = await ApiClient.get('/reference/cities$q') as List;
    return data.map((e) => ReferenceItem.fromJson(e)).toList();
  }
}
