/// User roles in the application
enum UserRole {
  owner,
  cashier,
}

extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.owner:
        return 'OWNER';
      case UserRole.cashier:
        return 'CASHIER';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner/Admin';
      case UserRole.cashier:
        return 'Cashier';
    }
  }

  bool get isOwner => this == UserRole.owner;
  bool get isCashier => this == UserRole.cashier;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.cashier,
    );
  }
}
