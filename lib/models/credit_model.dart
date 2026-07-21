/// Credit record for partial payments
class CreditModel {
  final String id;
  final String customerId;
  final String saleId;
  final double amount; // outstanding amount
  final DateTime createdAt;

  CreditModel({
    required this.id,
    required this.customerId,
    required this.saleId,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'saleId': saleId,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CreditModel.fromJson(Map<String, dynamic> json) => CreditModel(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        saleId: json['saleId'] as String,
        amount: (json['amount'] as num).toDouble(),
        createdAt: json['createdAt'] is String ? DateTime.parse(json['createdAt'] as String) : (json['createdAt'] as DateTime),
      );
}
