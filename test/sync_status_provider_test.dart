import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/remote/cloud_sync_api.dart';
import 'package:gscappall/data/remote/sync_payload_dtos.dart';
import 'package:gscappall/data/repositories/local_settings_repository.dart';
import 'package:gscappall/data/repositories/sync_local_repository.dart';
import 'package:gscappall/domain/sync/sync_models.dart';
import 'package:gscappall/domain/sync/sync_repository.dart';
import 'package:gscappall/features/profile/sync_log_detail_page.dart';

void main() {
  test('sync log detail extracts push and pull request ids from notes', () {
    expect(
      extractSyncRequestIds(const [
        'Local-first sync pass started.',
        'Push request id: push-123',
        'Pull request id: pull-456',
      ]),
      {'push': 'push-123', 'pull': 'pull-456'},
    );
  });

  test(
    'sync status provider exposes pending counts and manual sync report',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.selectList('SELECT 1;');

      final now = DateTime.utc(2026, 5, 11, 8, 9, 10);
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES (
        1, 'Sync Poem', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
        '', '', '', '', '', '', 1, 'test', 'local',
        '${now.toIso8601String()}', '${now.toIso8601String()}'
      );
    ''');
      await database.customStatement('''
      INSERT INTO favorites (
        profile_id, poem_id, sync_status, created_at, updated_at
      )
      VALUES (
        1, 1, 'pending_push',
        '${now.toIso8601String()}', '${now.toIso8601String()}'
      );
    ''');

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final initial = await container.read(syncStatusProvider.future);
      expect(initial.pendingTotal, 1);
      expect(initial.pendingCounts[SyncResourceType.favorites], 1);
      expect(initial.lastSuccessfulSyncAt, isNull);

      final report = await container
          .read(syncStatusProvider.notifier)
          .synchronize(trigger: SyncRunTrigger.manual);
      expect(report?.state, SyncRunState.success);
      expect(report?.trigger, SyncRunTrigger.manual);

      final synced = await container.read(syncStatusProvider.future);
      expect(synced.lastRunState, SyncRunState.success);
      expect(synced.lastSuccessfulSyncAt, isNotNull);
      expect(synced.pendingCounts[SyncResourceType.favorites], 0);
      expect(synced.logs, isNotEmpty);
      expect(synced.logs.first.state, SyncRunState.success);
      expect(synced.logs.first.trigger, SyncRunTrigger.manual);
    },
  );

  test('network sync prompts login before manual synchronize', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        cloudSyncApiProvider.overrideWithValue(
          CloudSyncApi(
            config: CloudSyncApiConfig(
              baseUri: Uri.parse('https://sync.example.test'),
              enableNetwork: true,
            ),
            transport: _FakeCloudSyncTransport(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final report =
        await container.read(syncStatusProvider.notifier).synchronize();
    final status = await container.read(syncStatusProvider.future);

    expect(report, isNull);
    expect(status.lastErrorMessage, contains('备份账号'));
  });

  test('push ack only clears resources accepted by the server', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final now = DateTime.utc(2026, 5, 11, 9, 10, 11);
    await _insertPoem(database, now);
    await database.customStatement('''
      INSERT INTO favorites (
        profile_id, poem_id, sync_status, created_at, updated_at
      )
      VALUES (
        1, 1, 'pending_push',
        '${now.toIso8601String()}', '${now.toIso8601String()}'
      );
    ''');
    await database.customStatement('''
      INSERT INTO study_card_progress (
        profile_id, poem_id, memory_status, review_count, note, sync_status,
        created_at, updated_at
      )
      VALUES (
        1, 1, 'new', 1, 'pending note', 'pending_push',
        '${now.toIso8601String()}', '${now.toIso8601String()}'
      );
    ''');

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        syncRemoteRepositoryProvider.overrideWithValue(
          _FakeSyncRemoteRepository(
            acceptedCounts: const {SyncResourceType.favorites: 1},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final report =
        await container.read(syncStatusProvider.notifier).synchronize();
    expect(report?.state, SyncRunState.success);

    final favorite = await database.selectSingle('''
      SELECT sync_status FROM favorites WHERE profile_id = 1 AND poem_id = 1;
    ''');
    final studyCard = await database.selectSingle('''
      SELECT sync_status
      FROM study_card_progress
      WHERE profile_id = 1 AND poem_id = 1;
    ''');
    expect(favorite?['sync_status'], 'local');
    expect(studyCard?['sync_status'], 'pending_push');

    final status = await container.read(syncStatusProvider.future);
    expect(status.pendingCounts[SyncResourceType.favorites], 0);
    expect(status.pendingCounts[SyncResourceType.studyCardProgress], 1);
  });

  test('sync status notifier coalesces concurrent synchronize calls', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        syncRemoteRepositoryProvider.overrideWithValue(
          _FakeSyncRemoteRepository(
            acceptedCounts: const {},
            delay: const Duration(milliseconds: 30),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await Future.wait([
      container.read(syncStatusProvider.notifier).synchronize(),
      container.read(syncStatusProvider.notifier).synchronize(),
    ]);

    final logs = await DriftSyncLocalRepository(
      database: database,
    ).fetchSyncRunLogs(limit: 10);
    expect(logs, hasLength(1));
  });

  test('push conflicts keep pending rows and surface conflict state', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final now = DateTime.utc(2026, 5, 11, 10, 11, 12);
    await _insertPoem(database, now);
    await database.customStatement('''
      INSERT INTO favorites (
        profile_id, poem_id, sync_status, created_at, updated_at
      )
      VALUES (
        1, 1, 'pending_push',
        '${now.toIso8601String()}', '${now.toIso8601String()}'
      );
    ''');

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        syncRemoteRepositoryProvider.overrideWithValue(
          _FakeSyncRemoteRepository(
            acceptedCounts: const {SyncResourceType.favorites: 1},
            conflicts: const [
              SyncConflict(
                resource: SyncResourceType.favorites,
                recordKey: 'favorite:1:1',
                mergePolicy: SyncMergePolicy.softDelete,
                recommendedWinner: SyncConflictWinner.none,
                reason: 'remote conflict',
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final report =
        await container.read(syncStatusProvider.notifier).synchronize();
    expect(report?.state, SyncRunState.conflict);

    final favorite = await database.selectSingle('''
      SELECT sync_status FROM favorites WHERE profile_id = 1 AND poem_id = 1;
    ''');
    expect(favorite?['sync_status'], 'pending_push');

    final status = await container.read(syncStatusProvider.future);
    expect(status.hasConflicts, isTrue);
    expect(status.pendingCounts[SyncResourceType.favorites], 1);
    expect(status.logs.first.state, SyncRunState.conflict);
    expect(status.logs.first.conflictCount, 1);
  });

  test(
    'cloud sync api uses injected HTTP transport when network is enabled',
    () async {
      final api = CloudSyncApi(
        config: CloudSyncApiConfig(
          baseUri: Uri.parse('https://sync.example.test'),
          authToken: 'test-token',
          accountId: 'account-a',
          deviceId: 'test-device',
          platform: 'test-platform',
          appVersion: '0.1-test',
          schemaVersion: 10,
          enableNetwork: true,
        ),
        transport: _FakeCloudSyncTransport(),
      );
      final capabilities = await api.fetchCapabilities();
      expect(capabilities.maxBatchSize, 20);

      final checkpoint = SyncCheckpointDto.fromDomain(const SyncCheckpoint());
      final push = await api.pushChanges(
        SyncUpstreamPayloadDto(
          requestId: 'http-push',
          device: SyncDeviceContextDto.fromDomain(const SyncDeviceInfo()),
          checkpoint: checkpoint,
          batch: const SyncBatchPayloadDto(),
          generatedAt: DateTime.utc(2026, 5, 11),
        ),
      );
      expect(push.acceptedCounts['favorites'], 1);

      final pull = await api.pullChanges(
        SyncPullRequestDto(
          requestId: 'http-pull',
          device: SyncDeviceContextDto.fromDomain(const SyncDeviceInfo()),
          checkpoint: checkpoint,
          requestedAt: DateTime.utc(2026, 5, 11),
        ),
      );
      expect(pull.receivedCounts['settings'], 1);
      expect(pull.requestId, 'http-pull');
    },
  );

  test('local settings repository persists generated sync device id', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final repository = LocalSettingsRepository(database: database);
    final first = await repository.loadSyncDeviceId();
    final second = await repository.loadSyncDeviceId();

    expect(first, startsWith('gscappall-'));
    expect(second, first);
    final row = await database.selectSingle(
      'SELECT sync_device_id FROM settings WHERE id = 1 LIMIT 1;',
    );
    expect(row?['sync_device_id'], first);
  });

  test('sync run logs support pagination and pruning', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final repository = DriftSyncLocalRepository(database: database);
    final startedAt = DateTime.utc(2026, 5, 11, 12);
    for (var index = 0; index < 5; index += 1) {
      await repository.recordSyncRunLog(
        state: SyncRunState.success,
        startedAt: startedAt.add(Duration(minutes: index)),
        finishedAt: startedAt.add(Duration(minutes: index, seconds: 1)),
        pushedCount: index,
        notes: ['log-$index'],
      );
    }

    final firstPage = await repository.fetchSyncRunLogs(limit: 2);
    final secondPage = await repository.fetchSyncRunLogs(limit: 2, offset: 2);
    expect(firstPage, hasLength(2));
    expect(secondPage, hasLength(2));
    expect(firstPage.first.notes, ['log-4']);
    expect(secondPage.first.notes, ['log-2']);

    await repository.pruneSyncRunLogs(retain: 3);
    final retained = await repository.fetchSyncRunLogs(limit: 10);
    expect(retained, hasLength(3));
    expect(retained.map((log) => log.notes.single), [
      'log-4',
      'log-3',
      'log-2',
    ]);
  });

  test('sync run logs can be filtered by state and started time', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final repository = DriftSyncLocalRepository(database: database);
    await repository.recordSyncRunLog(
      state: SyncRunState.success,
      startedAt: DateTime.utc(2026, 5, 10, 10),
      notes: const ['success-old'],
    );
    await repository.recordSyncRunLog(
      state: SyncRunState.failed,
      startedAt: DateTime.utc(2026, 5, 11, 10),
      errorMessage: 'network failed',
      notes: const ['failed-new'],
    );
    await repository.recordSyncRunLog(
      state: SyncRunState.conflict,
      startedAt: DateTime.utc(2026, 5, 11, 11),
      conflictCount: 1,
      notes: const ['conflict-new'],
    );

    final failed = await repository.fetchSyncRunLogs(
      state: SyncRunState.failed,
      startedAfter: DateTime.utc(2026, 5, 11),
      startedBefore: DateTime.utc(2026, 5, 12),
    );
    expect(failed, hasLength(1));
    expect(failed.single.notes, ['failed-new']);

    final today = await repository.fetchSyncRunLogs(
      startedAfter: DateTime.utc(2026, 5, 11),
      startedBefore: DateTime.utc(2026, 5, 12),
    );
    expect(today.map((log) => log.notes.single), [
      'conflict-new',
      'failed-new',
    ]);
  });
}

Future<void> _insertPoem(AppDatabase database, DateTime now) {
  return database.customStatement('''
    INSERT INTO poems (
      id, title, author, dynasty, grade, grade_label, category, content,
      pinyin, annotation, translation, appreciation, author_intro,
      extension_text, difficulty, seed_version, sync_status, created_at,
      updated_at
    )
    VALUES (
      1, 'Sync Poem', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
      '', '', '', '', '', '', 1, 'test', 'local',
      '${now.toIso8601String()}', '${now.toIso8601String()}'
    );
  ''');
}

class _FakeSyncRemoteRepository implements SyncRemoteRepository {
  const _FakeSyncRemoteRepository({
    required this.acceptedCounts,
    this.conflicts = const [],
    this.delay = Duration.zero,
  });

  final Map<SyncResourceType, int> acceptedCounts;
  final List<SyncConflict> conflicts;
  final Duration delay;

  @override
  Future<SyncRemoteCapabilities> fetchCapabilities() async {
    return SyncRemoteCapabilities(
      supportsPoemCatalog: true,
      supportsSoftDelete: true,
      supportsFieldMerge: true,
      maxBatchSize: 500,
      supportedPolicies: {
        for (final policy in defaultSyncResourcePolicies)
          policy.resource: policy.defaultMergePolicy,
      },
    );
  }

  @override
  Future<List<SyncConflict>> previewConflicts(SyncEnvelope envelope) async {
    return conflicts;
  }

  @override
  Future<SyncPullResult> pullChanges({
    required SyncCheckpoint checkpoint,
    SyncRunOptions options = const SyncRunOptions(),
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final now = DateTime.now().toUtc();
    return SyncPullResult(
      envelope: SyncEnvelope.empty(checkpoint: checkpoint),
      checkpoint: checkpoint,
      receivedCounts: const {},
      conflicts: const [],
      serverTime: now,
    );
  }

  @override
  Future<SyncPushResult> pushChanges(SyncEnvelope envelope) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final now = DateTime.now().toUtc();
    return SyncPushResult(
      requestId: envelope.requestId,
      checkpoint: envelope.checkpoint,
      acceptedCounts: acceptedCounts,
      conflicts: conflicts,
      serverTime: now,
    );
  }
}

class _FakeCloudSyncTransport implements CloudSyncTransport {
  @override
  Future<JsonMap> getJson(
    Uri endpoint, {
    Map<String, String> headers = const {},
  }) async {
    expect(endpoint.path, '/sync/capabilities');
    expect(headers['authorization'], 'Bearer test-token');
    expect(headers['X-GSC-Account-Id'], 'account-a');
    expect(headers['X-GSC-Device-Id'], 'test-device');
    expect(headers['X-GSC-Platform'], 'test-platform');
    expect(headers['X-GSC-App-Version'], '0.1-test');
    expect(headers['X-GSC-Schema-Version'], '10');
    return {
      'supportsPoemCatalog': true,
      'supportsSoftDelete': true,
      'supportsFieldMerge': true,
      'maxBatchSize': 20,
      'supportedPolicies': {'favorites': 'soft_delete'},
    };
  }

  @override
  Future<JsonMap> postJson(
    Uri endpoint,
    JsonMap body, {
    Map<String, String> headers = const {},
  }) async {
    if (endpoint.path == '/sync/push') {
      expect(headers['authorization'], 'Bearer test-token');
      expect(headers['X-GSC-Account-Id'], 'account-a');
      expect(headers['X-GSC-Device-Id'], 'test-device');
      expect(headers['X-GSC-Request-Id'], 'http-push');
      return {
        'requestId': body['requestId'],
        'checkpoint': body['checkpoint'],
        'acceptedCounts': {'favorites': 1},
        'conflicts': [],
        'serverTime': DateTime.utc(2026, 5, 11).toIso8601String(),
      };
    }
    expect(endpoint.path, '/sync/pull');
    expect(headers['X-GSC-Request-Id'], 'http-pull');
    return {
      'requestId': body['requestId'],
      'checkpoint': body['checkpoint'],
      'batch': const {},
      'receivedCounts': {'settings': 1},
      'conflicts': [],
      'serverTime': DateTime.utc(2026, 5, 11).toIso8601String(),
    };
  }
}
