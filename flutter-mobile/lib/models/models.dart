enum UserRole { admin, member, trainer }

class AuthResponse {
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? phoneNumber;
  final String? cityName;
  final int role;
  final String token;

  AuthResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.cityName,
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
      phoneNumber: j['phoneNumber']?.toString(),
      cityName: j['cityName']?.toString(),
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
  final String address;
  final String? description;
  final String? phoneNumber;
  final String? email;
  final String? imageUrl;
  final String openTime;
  final String closeTime;
  final int capacity;
  final int currentOccupancy;
  final int status;
  final double? latitude;
  final double? longitude;
  final int cityId;
  final String cityName;
  final String countryName;

  GymModel({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.phoneNumber,
    required this.email,
    required this.imageUrl,
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

  factory GymModel.fromJson(Map<String, dynamic> j) {
    return GymModel(
      id: j['id'],
      name: j['name'],
      address: (j['address'] ?? '').toString(),
      description: j['description']?.toString(),
      phoneNumber: j['phoneNumber']?.toString(),
      email: j['email']?.toString(),
      imageUrl: j['imageUrl']?.toString(),
      openTime: (j['openTime'] ?? '').toString(),
      closeTime: (j['closeTime'] ?? '').toString(),
      capacity: j['capacity'] ?? 0,
      currentOccupancy: j['currentOccupancy'] ?? 0,
      status: j['status'] is num ? (j['status'] as num).toInt() : 0,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      cityId: j['cityId'] ?? 0,
      cityName: (j['cityName'] ?? '').toString(),
      countryName: (j['countryName'] ?? '').toString(),
    );
  }

  bool get isOpen => status == 0;
  String get statusLabel => isOpen ? 'ONLINE' : 'OFFLINE';
}

class MembershipPlanModel {
  final int id;
  final String name;
  final String? description;
  final int durationDays;
  final double price;
  final bool isActive;
  final int gymId;
  final String gymName;

  MembershipPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.durationDays,
    required this.price,
    required this.isActive,
    required this.gymId,
    required this.gymName,
  });

  factory MembershipPlanModel.fromJson(Map<String, dynamic> j) {
    return MembershipPlanModel(
      id: j['id'],
      name: j['name'],
      description: j['description']?.toString(),
      durationDays: j['durationDays'] ?? 0,
      price: (j['price'] as num).toDouble(),
      isActive: j['isActive'] ?? true,
      gymId: j['gymId'] ?? 0,
      gymName: (j['gymName'] ?? '').toString(),
    );
  }
}

class TrainingSessionModel {
  final int id;
  final String title;
  final String? description;
  final int type;
  final String date;
  final String startTime;
  final String endTime;
  final int maxParticipants;
  final int currentParticipants;
  final double price;
  final bool isActive;
  final int trainerId;
  final String trainerFullName;
  final int gymId;
  final String gymName;
  final int trainingTypeId;
  final String trainingTypeName;

  TrainingSessionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.price,
    required this.isActive,
    required this.trainerId,
    required this.trainerFullName,
    required this.gymId,
    required this.gymName,
    required this.trainingTypeId,
    required this.trainingTypeName,
  });

  factory TrainingSessionModel.fromJson(Map<String, dynamic> j) {
    return TrainingSessionModel(
      id: j['id'],
      title: j['title'],
      description: j['description']?.toString(),
      type: j['type'] is num ? (j['type'] as num).toInt() : 0,
      date: (j['date'] ?? '').toString(),
      startTime: (j['startTime'] ?? '').toString(),
      endTime: (j['endTime'] ?? '').toString(),
      maxParticipants: j['maxParticipants'] ?? 0,
      currentParticipants: j['currentParticipants'] ?? 0,
      price: (j['price'] as num).toDouble(),
      isActive: j['isActive'] ?? true,
      trainerId: j['trainerId'] ?? 0,
      trainerFullName: (j['trainerFullName'] ?? '').toString(),
      gymId: j['gymId'] ?? 0,
      gymName: (j['gymName'] ?? '').toString(),
      trainingTypeId: j['trainingTypeId'] ?? 0,
      trainingTypeName: (j['trainingTypeName'] ?? '').toString(),
    );
  }

  bool get isGroup => type == 1;
}

class CityModel {
  final int id;
  final String name;
  final String? postalCode;
  final int countryId;
  final String countryName;

  CityModel({
    required this.id,
    required this.name,
    required this.postalCode,
    required this.countryId,
    required this.countryName,
  });

  factory CityModel.fromJson(Map<String, dynamic> j) {
    return CityModel(
      id: j['id'],
      name: j['name'],
      postalCode: j['postalCode']?.toString(),
      countryId: j['countryId'] ?? 0,
      countryName: (j['countryName'] ?? '').toString(),
    );
  }
}

class TrainingTypeModel {
  final int id;
  final String name;
  final String? description;

  TrainingTypeModel({
    required this.id,
    required this.name,
    required this.description,
  });

  factory TrainingTypeModel.fromJson(Map<String, dynamic> j) {
    return TrainingTypeModel(
      id: j['id'],
      name: j['name'],
      description: j['description']?.toString(),
    );
  }
}

class UserMembership {
  final int id;
  final int membershipPlanId;
  final String planName;
  final String gymName;
  final String startDate;
  final String endDate;
  final double price;
  final int status;
  final int daysRemaining;

  UserMembership({
    required this.id,
    required this.membershipPlanId,
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
      membershipPlanId: j['membershipPlanId'],
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

class TrainerApplicationModel {
  final int id;
  final int userId;
  final String userFullName;
  final String userEmail;
  final String biography;
  final String experience;
  final String? certifications;
  final String? availability;
  final int status;
  final String? adminNote;
  final String submittedAt;
  final String? reviewedAt;

  TrainerApplicationModel({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    required this.biography,
    required this.experience,
    required this.certifications,
    required this.availability,
    required this.status,
    required this.adminNote,
    required this.submittedAt,
    required this.reviewedAt,
  });

  factory TrainerApplicationModel.fromJson(Map<String, dynamic> j) {
    return TrainerApplicationModel(
      id: j['id'],
      userId: j['userId'],
      userFullName: j['userFullName'],
      userEmail: j['userEmail'],
      biography: j['biography'],
      experience: j['experience'],
      certifications: j['certifications']?.toString(),
      availability: j['availability']?.toString(),
      status: j['status'],
      adminNote: j['adminNote']?.toString(),
      submittedAt: j['submittedAt'],
      reviewedAt: j['reviewedAt']?.toString(),
    );
  }

  static const statusLabels = ['Na čekanju', 'Odobrena', 'Odbijena'];
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
