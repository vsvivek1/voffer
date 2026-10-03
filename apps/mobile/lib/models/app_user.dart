enum UserRole { customer, firm }

UserRole roleFromString(String? value) =>
    value == 'firm' ? UserRole.firm : UserRole.customer;

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;

  /// The person's name for customers, the business name for firms.
  final String displayName;
  final UserRole role;

  bool get isFirm => role == UserRole.firm;

  AppUser copyWith({String? displayName}) => AppUser(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    role: role,
  );
}
