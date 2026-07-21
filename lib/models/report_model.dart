/// Report model - aggregated daily/weekly/monthly reports
class ReportModel {
  final String id;
  final DateTime date;
  final double totalSales;
  final int totalBills;
  final double totalExpenses;
  final double totalProfit;
  final double netProfit;
  final List<BestSellingProductModel> bestSellingProducts;
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.date,
    required this.totalSales,
    required this.totalBills,
    required this.totalExpenses,
    required this.totalProfit,
    required this.netProfit,
    required this.bestSellingProducts,
    required this.createdAt,
  });

  /// Convert ReportModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'totalSales': totalSales,
      'totalBills': totalBills,
      'totalExpenses': totalExpenses,
      'totalProfit': totalProfit,
      'netProfit': netProfit,
      'bestSellingProducts': bestSellingProducts.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create ReportModel from JSON
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      date: json['date'] is String
          ? DateTime.parse(json['date'] as String)
          : (json['date'] as DateTime),
      totalSales: (json['totalSales'] as num).toDouble(),
      totalBills: json['totalBills'] as int,
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      totalProfit: (json['totalProfit'] as num).toDouble(),
      netProfit: (json['netProfit'] as num).toDouble(),
      bestSellingProducts: (json['bestSellingProducts'] as List<dynamic>?)
              ?.map((p) => BestSellingProductModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'] as String)
          : (json['createdAt'] as DateTime),
    );
  }

  /// Create a copy with modifications
  ReportModel copyWith({
    String? id,
    DateTime? date,
    double? totalSales,
    int? totalBills,
    double? totalExpenses,
    double? totalProfit,
    double? netProfit,
    List<BestSellingProductModel>? bestSellingProducts,
    DateTime? createdAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      date: date ?? this.date,
      totalSales: totalSales ?? this.totalSales,
      totalBills: totalBills ?? this.totalBills,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      totalProfit: totalProfit ?? this.totalProfit,
      netProfit: netProfit ?? this.netProfit,
      bestSellingProducts: bestSellingProducts ?? this.bestSellingProducts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ReportModel(date: $date, netProfit: $netProfit)';
}

/// Best selling product model used in reports
class BestSellingProductModel {
  final String productId;
  final String productName;
  final int quantitySold;
  final double totalRevenue;

  BestSellingProductModel({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantitySold': quantitySold,
      'totalRevenue': totalRevenue,
    };
  }

  /// Create from JSON
  factory BestSellingProductModel.fromJson(Map<String, dynamic> json) {
    return BestSellingProductModel(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantitySold: json['quantitySold'] as int,
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'BestSellingProduct($productName: $quantitySold units)';
}
