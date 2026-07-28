import 'sync_models.dart';

abstract class SyncRemoteRepository {
  Future<SyncRemoteCapabilities> fetchCapabilities();

  Future<SyncPushResult> pushChanges(SyncEnvelope envelope);

  Future<SyncPullResult> pullChanges({
    required SyncCheckpoint checkpoint,
    SyncRunOptions options = const SyncRunOptions(),
  });

  Future<List<SyncConflict>> previewConflicts(SyncEnvelope envelope);
}

abstract class SyncLocalRepository {
  Future<SyncCheckpoint> loadCheckpoint();

  Future<void> persistCheckpoint(SyncCheckpoint checkpoint);

  Future<SyncEnvelope> collectPendingChanges({
    SyncRunOptions options = const SyncRunOptions(),
  });

  Future<void> applyRemoteEnvelope(SyncEnvelope envelope);

  Future<void> acknowledgePushedChanges({
    required SyncEnvelope envelope,
    required SyncPushResult result,
  });

  Future<void> recordSyncRunLog({
    required SyncRunState state,
    required DateTime startedAt,
    DateTime? finishedAt,
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
    int pushedCount = 0,
    int pulledCount = 0,
    int conflictCount = 0,
    String? errorMessage,
    List<String> notes = const [],
  });

  Future<List<SyncRunLogEntry>> fetchSyncRunLogs({
    int limit = 10,
    int offset = 0,
    SyncRunState? state,
    DateTime? startedAfter,
    DateTime? startedBefore,
  });

  Future<void> pruneSyncRunLogs({int retain = 100});

  Future<void> clearFailedSyncRunLogs();

  Future<Map<SyncResourceType, int>> pendingCounts();
}

abstract class SyncCoordinator {
  Future<SyncRunReport> synchronize({
    SyncRunOptions options = const SyncRunOptions(),
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
  });
}

abstract class SyncConflictResolver {
  SyncConflict resolve({
    required SyncResourcePolicy policy,
    required SyncChangeRecord localRecord,
    required SyncChangeRecord remoteRecord,
  });
}
