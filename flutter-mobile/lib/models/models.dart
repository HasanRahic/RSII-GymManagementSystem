enum UserRole { admin, member, trainer }

class AuthResponse {
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final int role;
  final String token;

  AuthResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.role,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) {
    return AuthResponse(
      id: j['id'],
      firstName: j['firstName'],
      lastName: j['lastName'],
      username: j['username'],
      email: j['email'],
      role: j['role'],
      token: j['token'],
    );
  }

  String get fullName => '$firstName $lastName';
  UserRole get userRole => UserRole.values[role];

  static const roleLabels = ['Admin', 'Clan', 'Trener'];
  String get roleLabel => roleLabels[role];
}

class GymModel {
  final int id;
  final String name;
  final String cityName;

  GymModel({
    required this.id,
    required this.name,
    required this.cityName,
  });

  factory GymModel.fromJson(Map<String, dynamic> j) {
    return GymModel(
      id: j['id'],
      name: j['name'],
      cityName: (j['cityName'] ?? '').toString(),
    );
  }
}

class UserMembership {
  final int id;
  final String planName;
  final String gymName;
  final String startDate;
  final String endDate;
  final double price;
  final int status;
  final int daysRemaining;

  UserMembership({
    required this.id,
    required this.planName,
    required this.gymName,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.status,
    required this.daysRemaining,
  });

  factory UserMembership.fromJson(Map<String, dynamic> j) {
    return UserMembership(
      id: j['id'],
      planName: j['planName'],
      gymName: j['gymName'],
      startDate: j['startDate'],
      endDate: j['endDate'],
      price: (j['price'] as num).toDouble(),
      status: j['status'],
      daysRemaining: j['daysRemaining'],
    );
  }

  static const statusLabels = ['Aktivna', 'Istekla', 'Otkazana'];
  String get statusLabel => statusLabels[status];
}

class CheckInModel {
  final int id;
  final String gymName;
  final String checkInTime;
  final String? checkOutTime;
  final int? durationMinutes;

  CheckInModel({
    required this.id,
    required this.gymName,
    required this.checkInTime,
    required this.checkOutTime,
    required this.durationMinutes,
  });

  factory CheckInModel.fromJson(Map<String, dynamic> j) {
    return CheckInModel(
      id: j['id'],
      gymName: j['gymName'],
      checkInTime: j['checkInTime'],
      checkOutTime: j['checkOutTime'],
      durationMinutes: j['durationMinutes'],
    );
  }

  bool get isActive => checkOutTime == null;
}
