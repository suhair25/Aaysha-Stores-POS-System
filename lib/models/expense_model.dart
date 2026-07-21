import 'package:aaysha_stores/enums/expense_category.dart';

/// Expense model
class ExpenseModel {
  final String id;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final DateTime expenseDate;
  final String addedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
    required this.expenseDate,
    required this.addedBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert ExpenseModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'amount': amount,
      'description': description,
      'expenseDate': expenseDate.toIso8601String(),
      'addedBy': addedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create ExpenseModel from JSON
  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      category: ExpenseCategoryExtension.fromString(json['category'] as String? ?? 'OTHER'),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      expenseDate: json['expenseDate'] is String
          ? DateTime.parse(json['expenseDate'] as String)
          : (json['expenseDate'] as DateTime),
      addedBy: json['addedBy'] as String,
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : (json['createdAt'] as DateTime),
      updatedAt: json['updatedAt'] != null
          ? json['updatedAt'] is String
              ? DateTime.parse(json['updatedAt'] as String)
              : (json['updatedAt'] as DateTime)
          : null,
    );
  }

  /// Create a copy with modifications
  ExpenseModel copyWith({
    String? id,
    ExpenseCategory? category,
    double? amount,
    String? description,
    DateTime? expenseDate,
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ExpenseModel(category: ${category.displayName}, amount: $amount)';
}
