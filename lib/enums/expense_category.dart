/// Expense categories
enum ExpenseCategory {
  electricity,
  salary,
  rent,
  transport,
  other,
}

extension ExpenseCategoryExtension on ExpenseCategory {
  String get name {
    switch (this) {
      case ExpenseCategory.electricity:
        return 'ELECTRICITY';
      case ExpenseCategory.salary:
        return 'SALARY';
      case ExpenseCategory.rent:
        return 'RENT';
      case ExpenseCategory.transport:
        return 'TRANSPORT';
      case ExpenseCategory.other:
        return 'OTHER';
    }
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.electricity:
        return 'Electricity';
      case ExpenseCategory.salary:
        return 'Salary';
      case ExpenseCategory.rent:
        return 'Rent';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ExpenseCategory.electricity:
        return '⚡';
      case ExpenseCategory.salary:
        return '👤';
      case ExpenseCategory.rent:
        return '🏠';
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.other:
        return '💰';
    }
  }

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }

  static List<ExpenseCategory> getAllCategories() {
    return ExpenseCategory.values;
  }
}
