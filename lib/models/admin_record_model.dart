/// Admin Record model - contains detailed profit information (owner only)
class AdminRecordModel {
  final String id;
  final String saleId;
  final String productId;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final double profitPerItem;
  final double totalProfit;
  final DateTime createdAt;

  AdminRecordModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.profitPerItem,
    required this.totalProfit,
    required this.createdAt,
  });

  /// Convert AdminRecordModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'profitPerItem': profitPerItem,
      'totalProfit': totalProfit,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create AdminRecordModel from JSON
  factory AdminRecordModel.fromJson(Map<String, dynamic> json) {
    return AdminRecordModel(
      id: json['id'] as String,
      saleId: json['saleId'] as String,
      productId: json['productId'] as String,
      costPrice: (json['costPrice'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
      profitPerItem: (json['profitPerItem'] as num).toDouble(),
      totalProfit: (json['totalProfit'] as num).toDouble(),
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : (json['createdAt'] as DateTime),
    );
  }

  /// Create a copy with modifications
  AdminRecordModel copyWith({
    String? id,
    String? saleId,
    String? productId,
    double? costPrice,
    double? sellingPrice,
    int? quantity,
    double? profitPerItem,
    double? totalProfit,
    DateTime? createdAt,
  }) {
    return AdminRecordModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      profitPerItem: profitPerItem ?? this.profitPerItem,
      totalProfit: totalProfit ?? this.totalProfit,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'AdminRecordModel(profit: $totalProfit, item: $productId)';
}
