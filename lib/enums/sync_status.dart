/// Sync status for offline/online operations
enum SyncStatus {
  idle,
  syncing,
  success,
  failure,
  pending,
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return 'Ready';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.failure:
        return 'Sync Failed';
      case SyncStatus.pending:
        return 'Pending';
    }
  }

  bool get isSyncing => this == SyncStatus.syncing;
  bool get isSuccess => this == SyncStatus.success;
  bool get isFailure => this == SyncStatus.failure;
  bool get isPending => this == SyncStatus.pending;
}
