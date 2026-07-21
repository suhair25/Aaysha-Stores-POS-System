/// Utility functions for profit and business calculations
class ProfitCalculator {
  /// Calculate profit per unit
  /// profit = sellingPrice - costPrice
  static double calculateProfitPerUnit(double sellingPrice, double costPrice) {
    return sellingPrice - costPrice;
  }

  /// Calculate total profit for items sold
  /// totalProfit = profitPerUnit * quantity
  static double calculateTotalProfit(double sellingPrice, double costPrice, int quantity) {
    final profitPerUnit = calculateProfitPerUnit(sellingPrice, costPrice);
    return profitPerUnit * quantity;
  }

  /// Calculate profit percentage
  /// profitPercentage = (profit / costPrice) * 100
  static double calculateProfitPercentage(double sellingPrice, double costPrice) {
    if (costPrice == 0) return 0;
    final profit = calculateProfitPerUnit(sellingPrice, costPrice);
    return (profit / costPrice) * 100;
  }

  /// Calculate margin percentage
  /// margin = (profit / sellingPrice) * 100
  static double calculateMarginPercentage(double sellingPrice, double costPrice) {
    if (sellingPrice == 0) return 0;
    final profit = calculateProfitPerUnit(sellingPrice, costPrice);
    return (profit / sellingPrice) * 100;
  }

  /// Calculate net profit after expenses
  /// netProfit = totalSales - totalCost - totalExpenses
  static double calculateNetProfit(double totalSales, double totalCost, double totalExpenses) {
    return totalSales - totalCost - totalExpenses;
  }

  /// Calculate total cost from cost price and quantity
  static double calculateTotalCost(double costPrice, int quantity) {
    return costPrice * quantity;
  }

  /// Calculate total revenue from selling price and quantity
  static double calculateTotalRevenue(double sellingPrice, int quantity) {
    return sellingPrice * quantity;
  }

  /// Calculate break-even selling price
  /// costPrice + desiredProfitPercentage
  static double calculateBreakEvenPrice(double costPrice, double desiredProfitPercentage) {
    return costPrice + (costPrice * desiredProfitPercentage / 100);
  }

  /// Calculate profit margin
  static double calculateProfitMargin(double sellingPrice, double costPrice) {
    return sellingPrice - costPrice;
  }

  /// Check if selling price is profitable
  static bool isProfitable(double sellingPrice, double costPrice) {
    return sellingPrice > costPrice;
  }

  /// Format profit with color indicator
  /// Returns profit information for display
  static Map<String, dynamic> getProfitInfo(double sellingPrice, double costPrice) {
    final profitPerUnit = calculateProfitPerUnit(sellingPrice, costPrice);
    final profitPercentage = calculateProfitPercentage(sellingPrice, costPrice);
    final isProfitable = profitPerUnit > 0;

    return {
      'profitPerUnit': profitPerUnit,
      'profitPercentage': profitPercentage,
      'isProfitable': isProfitable,
      'isLoss': !isProfitable,
    };
  }
}
