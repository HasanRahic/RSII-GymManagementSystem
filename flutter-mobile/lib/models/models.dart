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
