/// Report time range filter
enum ReportTimeRange {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  custom,
}

extension ReportTimeRangeExtension on ReportTimeRange {
  String get displayName {
    switch (this) {
      case ReportTimeRange.today:
        return 'Today';
      case ReportTimeRange.yesterday:
        return 'Yesterday';
      case ReportTimeRange.thisWeek:
        return 'This Week';
      case ReportTimeRange.lastWeek:
        return 'Last Week';
      case ReportTimeRange.thisMonth:
        return 'This Month';
      case ReportTimeRange.lastMonth:
        return 'Last Month';
      case ReportTimeRange.custom:
        return 'Custom Range';
    }
  }
}
