/// Customer model
class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final double outstanding; // total outstanding credit
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.outstanding = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'outstanding': outstanding,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : (json['createdAt'] as DateTime),
      );
}
