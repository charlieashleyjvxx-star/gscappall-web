import '../../core/user_facing_error.dart';
import '../../domain/sync/sync_models.dart';
import '../../domain/sync/sync_repository.dart';

class LocalFirstSyncCoordinator implements SyncCoordinator {
  const LocalFirstSyncCoordinator({
    required SyncLocalRepository localRepository,
    required SyncRemoteRepository remoteRepository,
  }) : _localRepository = localRepository,
       _remoteRepository = remoteRepository;

  final SyncLocalRepository _localRepository;
  final SyncRemoteRepository _remoteRepository;

  @override
  Future<SyncRunReport> synchronize({
    SyncRunOptions options = const SyncRunOptions(),
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
  }) async {
    final startedAt = DateTime.now().toUtc();
    try {
      final report = await _synchronizeStartedAt(
        startedAt: startedAt,
        options: options,
        trigger: trigger,
      );
      await _localRepository.recordSyncRunLog(
        state: report.state,
        startedAt: report.startedAt,
        finishedAt: report.finishedAt,
        trigger: report.trigger,
        pushedCount: report.pushedCounts.values.fold<int>(
          0,
          (sum, value) => sum + value,
        ),
        pulledCount: report.pulledCounts.values.fold<int>(
          0,
          (sum, value) => sum + value,
        ),
        conflictCount: report.conflicts.length,
        notes: report.notes,
      );
      return report;
    } catch (error) {
      await _localRepository.recordSyncRunLog(
        state: SyncRunState.failed,
        startedAt: startedAt,
        finishedAt: DateTime.now().toUtc(),
        trigger: trigger,
        errorMessage: UserFacingErrorMapper.parentMessage(
          error,
          fallbackMessage: '备份失败，请稍后重试。',
        ),
      );
      rethrow;
    }
  }

  Future<SyncRunReport> _synchronizeStartedAt({
    required DateTime startedAt,
    required SyncRunOptions options,
    required SyncRunTrigger trigger,
  }) async {
    final existingCheckpoint = await _localRepository.loadCheckpoint();
    final pending = await _localRepository.pendingCounts();

    SyncPushResult? pushResult;
    SyncPullResult? pullResult;
    var checkpoint = existingCheckpoint;
    final notes = <String>[
      'Local-first sync pass started.',
      'Pending snapshot: ${_formatCounts(pending)}',
    ];

    if (options.pushChanges) {
      final pendingEnvelope = await _localRepository.collectPendingChanges(
        options: options.copyWith(pullChanges: false),
      );
      if (!pendingEnvelope.isEmpty || options.fullResync) {
        pushResult = await _remoteRepository.pushChanges(pendingEnvelope);
        await _localRepository.acknowledgePushedChanges(
          envelope: pendingEnvelope,
          result: pushResult,
        );
        checkpoint = pushResult.checkpoint;
        notes.add(
          'Push completed for ${pendingEnvelope.totalRecords} records.',
        );
        notes.add('Push request id: ${pushResult.requestId}');
      } else {
        notes.add('Push skipped because no pending local changes were found.');
      }
    }

    if (options.pullChanges) {
      pullResult = await _remoteRepository.pullChanges(
        checkpoint: checkpoint,
        options: options,
      );
      await _localRepository.applyRemoteEnvelope(pullResult.envelope);
      checkpoint = pullResult.checkpoint;
      notes.add(
        'Pull completed for ${pullResult.envelope.totalRecords} records.',
      );
      notes.add('Pull request id: ${pullResult.envelope.requestId}');
    }

    checkpoint = checkpoint.copyWith(
      lastSuccessfulSyncAt: DateTime.now().toUtc(),
    );
    await _localRepository.persistCheckpoint(checkpoint);

    final conflicts = <SyncConflict>[
      ...?pushResult?.conflicts,
      ...?pullResult?.conflicts,
    ];
    final state =
        conflicts.isNotEmpty ? SyncRunState.conflict : SyncRunState.success;

    return SyncRunReport(
      state: state,
      startedAt: startedAt,
      finishedAt: DateTime.now().toUtc(),
      pushedCounts: pushResult?.acceptedCounts ?? const {},
      pulledCounts: pullResult?.receivedCounts ?? const {},
      conflicts: conflicts,
      checkpoint: checkpoint,
      trigger: trigger,
      notes: [...notes, ...?pushResult?.notes, ...?pullResult?.notes],
    );
  }
}

String _formatCounts(Map<SyncResourceType, int> counts) {
  if (counts.isEmpty) {
    return 'none';
  }

  return counts.entries
      .map((entry) => '${syncResourceTypeToWireName(entry.key)}=${entry.value}')
      .join(', ');
}
