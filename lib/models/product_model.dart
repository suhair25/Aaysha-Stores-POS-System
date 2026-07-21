/// Product model
class ProductModel {
  final String id;
  final String name;
  final String? barcode;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final String supplierName;
  final String? productImageUrl;
  final DateTime? expiryDate;
  final int lowStockThreshold;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool synced;

  ProductModel({
    required this.id,
    required this.name,
    this.barcode,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.supplierName,
    this.productImageUrl,
    this.expiryDate,
    required this.lowStockThreshold,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.synced = false,
  });

  /// Calculate profit per unit
  double get profitPerUnit => sellingPrice - costPrice;

  /// Check if product is low stock
  bool get isLowStock {
    if (lowStockThreshold == 0) return false;
    return quantity <= lowStockThreshold;
  }

  /// Check if product is out of stock
  bool get isOutOfStock => quantity <= 0;

  /// Check if product is expired
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Check if product is expiring soon (7 days)
  bool get isExpiringsoon {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final difference = expiryDate!.difference(now).inDays;
    return difference > 0 && difference <= 7;
  }

  /// Convert ProductModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'category': category,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'supplierName': supplierName,
      'productImageUrl': productImageUrl,
      'expiryDate': expiryDate?.toIso8601String(),
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'synced': synced,
    };
  }

  /// Create ProductModel from JSON
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      category: json['category'] as String,
      costPrice: (json['costPrice'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      quantity: json['quantity'] as int,
      supplierName: json['supplierName'] as String,
      productImageUrl: json['productImageUrl'] as String?,
      expiryDate: json['expiryDate'] != null
          ? json['expiryDate'] is String
              ? DateTime.parse(json['expiryDate'] as String)
              : (json['expiryDate'] as DateTime)
          : null,
      lowStockThreshold: json['lowStockThreshold'] as int? ?? 10,
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : (json['createdAt'] as DateTime),
      updatedAt: json['updatedAt'] != null
          ? json['updatedAt'] is String
              ? DateTime.parse(json['updatedAt'] as String)
              : (json['updatedAt'] as DateTime)
          : null,
      isDeleted: json['isDeleted'] is int
          ? (json['isDeleted'] as int) == 1
          : json['isDeleted'] as bool? ?? false,
      synced: json['synced'] is int
          ? (json['synced'] as int) == 1
          : json['synced'] as bool? ?? false,
    );
  }

  /// Create a copy with modifications
  ProductModel copyWith({
    String? id,
    String? name,
    String? barcode,
    String? category,
    double? costPrice,
    double? sellingPrice,
    int? quantity,
    String? supplierName,
    String? productImageUrl,
    DateTime? expiryDate,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? synced,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      supplierName: supplierName ?? this.supplierName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      expiryDate: expiryDate ?? this.expiryDate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() => 'ProductModel(id: $id, name: $name, qty: $quantity)';
}
