/// Sale status
enum SaleStatus {
  completed,
  refunded,
  pending,
}

extension SaleStatusExtension on SaleStatus {
  String get name {
    switch (this) {
      case SaleStatus.completed:
        return 'COMPLETED';
      case SaleStatus.refunded:
        return 'REFUNDED';
      case SaleStatus.pending:
        return 'PENDING';
    }
  }

  String get displayName {
    switch (this) {
      case SaleStatus.completed:
        return 'Completed';
      case SaleStatus.refunded:
        return 'Refunded';
      case SaleStatus.pending:
        return 'Pending';
    }
  }

  static SaleStatus fromString(String value) {
    return SaleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SaleStatus.completed,
    );
  }
}
