import 'package:aaysha_stores/enums/user_role.dart';

/// User model representing app users (Owner/Cashier)
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profileImageUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.profileImageUrl,
  });

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.name,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'shopPhone': shopPhone,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
    };
  }

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      role: UserRoleExtension.fromString(json['role'] as String? ?? 'CASHIER'),
      shopName: json['shopName'] as String?,
      shopAddress: json['shopAddress'] as String?,
      shopPhone: json['shopPhone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : (json['createdAt'] as DateTime),
      updatedAt: json['updatedAt'] != null
          ? json['updatedAt'] is String
              ? DateTime.parse(json['updatedAt'] as String)
              : (json['updatedAt'] as DateTime)
          : null,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }

  /// Create a copy with modifications
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, email: $email, role: ${role.displayName})';
}
