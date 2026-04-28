// ─── Enums ────────────────────────────────────────────────────────────────────

enum UserRole { admin, member, trainer }
enum GymStatus { active, maintenance }
enum MembershipStatus { active, expired, cancelled }
enum AppStatus { pending, approved, rejected }

// ─── Auth ─────────────────────────────────────────────────────────────────────

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

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        id: (j['id'] as num?)?.toInt() ?? 0,
        firstName: (j['firstName'] ?? '').toString(),
        lastName: (j['lastName'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] as num?)?.toInt() ?? 0,
        token: (j['token'] ?? '').toString(),
      );

  String get fullName => '$firstName $lastName';
  UserRole get userRole => UserRole.values[role];
}

// ─── User ─────────────────────────────────────────────────────────────────────

class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? phoneNumber;
  final String? dateOfBirth;
  final int role;
  final bool isActive;
  final String? profileImageUrl;
  final int? cityId;
  final String? cityName;
  final int? primaryGymId;
  final String? primaryGymName;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    this.phoneNumber,
    this.dateOfBirth,
    required this.role,
    required this.isActive,
    this.profileImageUrl,
    this.cityId,
    this.cityName,
    this.primaryGymId,
    this.primaryGymName,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      firstName: (j['firstName'] ?? '').toString(),
      lastName: (j['lastName'] ?? '').toString(),
      username: (j['username'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      phoneNumber: j['phoneNumber']?.toString(),
      dateOfBirth: j['dateOfBirth']?.toString(),
      role: (j['role'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] == true,
      profileImageUrl: j['profileImageUrl']?.toString(),
      cityId: (j['cityId'] as num?)?.toInt(),
      cityName: j['cityName']?.toString(),
      primaryGymId: (j['primaryGymId'] as num?)?.toInt(),
      primaryGymName: j['primaryGymName']?.toString(),
      );

  String get fullName => '$firstName $lastName';
  UserRole get userRole => UserRole.values[role];

  static const roleLabels = ['Admin', 'Član', 'Trener'];
  String get roleLabel => roleLabels[role];
}

// ─── Gym ──────────────────────────────────────────────────────────────────────

class GymModel {
  final int id;
  final String name;
  final String address;
  final String? description;
  final String phoneNumber;
  final String email;
  final String? imageUrl;
  final String openTime;
  final String closeTime;
  final int capacity;
  final int currentOccupancy;
  final int status;
  final double latitude;
  final double longitude;
  final int cityId;
  final String cityName;
  final String countryName;

  GymModel({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.phoneNumber,
    required this.email,
    this.imageUrl,
    required this.openTime,
    required this.closeTime,
    required this.capacity,
    required this.currentOccupancy,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.cityId,
    required this.cityName,
    required this.countryName,
  });

  factory GymModel.fromJson(Map<String, dynamic> j) => GymModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      description: j['description']?.toString(),
      phoneNumber: (j['phoneNumber'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      imageUrl: j['imageUrl']?.toString(),
      openTime: (j['openTime'] ?? '').toString(),
      closeTime: (j['closeTime'] ?? '').toString(),
      capacity: (j['capacity'] as num?)?.toInt() ?? 0,
      currentOccupancy: (j['currentOccupancy'] as num?)?.toInt() ?? 0,
      status: (j['status'] as num?)?.toInt() ?? 0,
      latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
      cityId: (j['cityId'] as num?)?.toInt() ?? 0,
      cityName: (j['cityName'] ?? '').toString(),
      countryName: (j['countryName'] ?? '').toString(),
      );

  bool get isActive => status == 0;
  int get occupancyPct => capacity > 0
      ? ((currentOccupancy / capacity) * 100).round()
      : 0;
}

// ─── Membership ───────────────────────────────────────────────────────────────

class MembershipPlan {
  final int id;
  final String name;
  final String? description;
  final int durationDays;
  final double price;
  final bool isActive;
  final int gymId;
  final String gymName;

  MembershipPlan({
    required this.id,
    required this.name,
    this.description,
    required this.durationDays,
    required this.price,
    required this.isActive,
    required this.gymId,
    required this.gymName,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> j) => MembershipPlan(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: (j['name'] ?? '').toString(),
      description: j['description']?.toString(),
      durationDays: (j['durationDays'] as num?)?.toInt() ?? 0,
      price: (j['price'] as num?)?.toDouble() ?? 0,
      isActive: j['isActive'] == true,
      gymId: (j['gymId'] as num?)?.toInt() ?? 0,
      gymName: (j['gymName'] ?? '').toString(),
      );
}

class UserMembership {
  final int id;
  final int userId;
  final String fullName;
  final int membershipPlanId;
  final String planName;
  final int gymId;
  final String gymName;
  final String startDate;
  final String endDate;
  final double price;
  final double discountPercent;
  final int status;
  final int daysRemaining;

  UserMembership({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.membershipPlanId,
    required this.planName,
    required this.gymId,
    required this.gymName,
    required this.startDate,
    required this.endDate,
    required this.price,
    required this.discountPercent,
    required this.status,
    required this.daysRemaining,
  });

  factory UserMembership.fromJson(Map<String, dynamic> j) => UserMembership(
      id: (j['id'] as num?)?.toInt() ?? 0,
      userId: (j['userId'] as num?)?.toInt() ?? 0,
      fullName: (j['fullName'] ?? '').toString(),
      membershipPlanId: (j['membershipPlanId'] as num?)?.toInt() ?? 0,
      planName: (j['planName'] ?? '').toString(),
      gymId: (j['gymId'] as num?)?.toInt() ?? 0,
      gymName: (j['gymName'] ?? '').toString(),
      startDate: (j['startDate'] ?? '').toString(),
      endDate: (j['endDate'] ?? '').toString(),
      price: (j['price'] as num?)?.toDouble() ?? 0,
      discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0,
      status: (j['status'] as num?)?.toInt() ?? 0,
      daysRemaining: (j['daysRemaining'] as num?)?.toInt() ?? 0,
      );

  MembershipStatus get membershipStatus => MembershipStatus.values[status];
  static const statusLabels = ['Aktivna', 'Istekla', 'Otkazana'];
  String get statusLabel => statusLabels[status];
}

// ─── Check-in ─────────────────────────────────────────────────────────────────

class CheckInModel {
  final int id;
  final int userId;
  final String userFullName;
  final int gymId;
  final String gymName;
  final String checkInTime;
  final String? checkOutTime;
  final int? durationMinutes;

  CheckInModel({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.gymId,
    required this.gymName,
    required this.checkInTime,
    this.checkOutTime,
    this.durationMinutes,
  });

  factory CheckInModel.fromJson(Map<String, dynamic> j) => CheckInModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        userFullName: (j['userFullName'] ?? '').toString(),
        gymId: (j['gymId'] as num?)?.toInt() ?? 0,
        gymName: (j['gymName'] ?? '').toString(),
        checkInTime: (j['checkInTime'] ?? '').toString(),
        checkOutTime: j['checkOutTime']?.toString(),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt(),
      );
}

// ─── Trainer Application ──────────────────────────────────────────────────────

class TrainerApplication {
  final int id;
  final int userId;
  final String userFullName;
  final String userEmail;
  final String? biography;
  final String? experience;
  final String? certifications;
  final String? availability;
  final int status;
  final String? adminNote;
  final String submittedAt;
  final String? reviewedAt;

  TrainerApplication({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    this.biography,
    this.experience,
    this.certifications,
    this.availability,
    required this.status,
    this.adminNote,
    required this.submittedAt,
    this.reviewedAt,
  });

  factory TrainerApplication.fromJson(Map<String, dynamic> j) =>
      TrainerApplication(
        id: (j['id'] as num?)?.toInt() ?? 0,
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        userFullName: (j['userFullName'] ?? '').toString(),
        userEmail: (j['userEmail'] ?? '').toString(),
        biography: j['biography']?.toString(),
        experience: j['experience']?.toString(),
        certifications: j['certifications']?.toString(),
        availability: j['availability']?.toString(),
        status: (j['status'] as num?)?.toInt() ?? 0,
        adminNote: j['adminNote']?.toString(),
        submittedAt: (j['submittedAt'] ?? '').toString(),
        reviewedAt: j['reviewedAt']?.toString(),
      );

  AppStatus get appStatus => AppStatus.values[status];
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

class DashboardStats {
  final int totalMembers;
  final int activeMemberships;
  final int totalCheckInsToday;
  final int currentOccupancy;
  final double revenueThisMonth;
  final int pendingTrainerApplications;

  DashboardStats({
    required this.totalMembers,
    required this.activeMemberships,
    required this.totalCheckInsToday,
    required this.currentOccupancy,
    required this.revenueThisMonth,
    required this.pendingTrainerApplications,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> j) => DashboardStats(
        totalMembers: (j['totalMembers'] as num?)?.toInt() ?? 0,
        activeMemberships: (j['activeMemberships'] as num?)?.toInt() ?? 0,
        totalCheckInsToday: (j['totalCheckInsToday'] as num?)?.toInt() ?? 0,
        currentOccupancy: (j['currentOccupancy'] as num?)?.toInt() ?? 0,
        revenueThisMonth: (j['revenueThisMonth'] as num?)?.toDouble() ?? 0,
        pendingTrainerApplications:
            (j['pendingTrainerApplications'] as num?)?.toInt() ?? 0,
      );
}

// ─── Reference ────────────────────────────────────────────────────────────────

class ReferenceItem {
  final int id;
  final String name;
  ReferenceItem({required this.id, required this.name});
  factory ReferenceItem.fromJson(Map<String, dynamic> j) =>
      ReferenceItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
      );
}
