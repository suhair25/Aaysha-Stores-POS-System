import 'package:aaysha_stores/enums/payment_method.dart';
import 'package:aaysha_stores/enums/sale_status.dart';

/// Sale model - represents a billing transaction
class SaleModel {
  final String id;
  final DateTime saleDate;
  final double totalAmount;
  final double discount;
  final PaymentMethod paymentMethod;
  final String cashierId;
  final String? customerId;
  final double creditAmount;
  final String? adminRecordId;
  final SaleStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<SaleItemModel> items;

  SaleModel({
    required this.id,
    required this.saleDate,
    required this.totalAmount,
    required this.discount,
    required this.paymentMethod,
    required this.cashierId,
    this.customerId,
    this.creditAmount = 0.0,
    this.adminRecordId,
    this.status = SaleStatus.completed,
    required this.createdAt,
    this.updatedAt,
    required this.items,
  });

  /// Calculate net total after discount
  double get netTotal => totalAmount - discount;

  /// Convert SaleModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saleDate': saleDate.toIso8601String(),
      'totalAmount': totalAmount,
      'discount': discount,
      'paymentMethod': paymentMethod.name,
      'cashierId': cashierId,
      'customerId': customerId,
      'creditAmount': creditAmount,
      'adminRecordId': adminRecordId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Create SaleModel from JSON
  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] as String,
      saleDate: json['saleDate'] is String
          ? DateTime.parse(json['saleDate'] as String)
          : (json['saleDate'] as DateTime),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      paymentMethod: PaymentMethodExtension.fromString(json['paymentMethod'] as String? ?? 'CASH'),
      cashierId: json['cashierId'] as String,
      customerId: json['customerId'] as String?,
      creditAmount: (json['creditAmount'] as num?)?.toDouble() ?? 0.0,
      adminRecordId: json['adminRecordId'] as String?,
      status: SaleStatusExtension.fromString(json['status'] as String? ?? 'COMPLETED'),
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : (json['createdAt'] as DateTime),
      updatedAt: json['updatedAt'] != null
          ? json['updatedAt'] is String
              ? DateTime.parse(json['updatedAt'] as String)
              : (json['updatedAt'] as DateTime)
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SaleItemModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Create a copy with modifications
  SaleModel copyWith({
    String? id,
    DateTime? saleDate,
    double? totalAmount,
    double? discount,
    PaymentMethod? paymentMethod,
    String? cashierId,
    String? customerId,
    double? creditAmount,
    String? adminRecordId,
    SaleStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SaleItemModel>? items,
  }) {
    return SaleModel(
      id: id ?? this.id,
      saleDate: saleDate ?? this.saleDate,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashierId: cashierId ?? this.cashierId,
      customerId: customerId ?? this.customerId,
      creditAmount: creditAmount ?? this.creditAmount,
      adminRecordId: adminRecordId ?? this.adminRecordId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  String toString() => 'SaleModel(id: $id, amount: $totalAmount, items: ${items.length})';
}

/// Sale Item model - represents individual items in a sale
class SaleItemModel {
  final String id;
  final String saleId;
  final String productId;
  final String? productName;
  final int quantity;
  final double sellingPrice;
  final double discount;

  SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.sellingPrice,
    required this.discount,
  });

  /// Calculate total for this item
  double get total => (sellingPrice * quantity) - discount;

  /// Convert SaleItemModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'sellingPrice': sellingPrice,
      'discount': discount,
    };
  }

  /// Create SaleItemModel from JSON
  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    return SaleItemModel(
      id: json['id'] as String,
      saleId: json['saleId'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String?,
      quantity: json['quantity'] as int,
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
    );
  }

  /// Create a copy with modifications
  SaleItemModel copyWith({
    String? id,
    String? saleId,
    String? productId,
    String? productName,
    int? quantity,
    double? sellingPrice,
    double? discount,
  }) {
    return SaleItemModel(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      discount: discount ?? this.discount,
    );
  }

  @override
  String toString() => 'SaleItemModel(productId: $productId, qty: $quantity, total: $total)';
}
