import '../../core/service_status.dart';
import '../../domain/sync/sync_models.dart';
import '../../domain/sync/sync_repository.dart';

abstract class SyncService {
  ServiceCapability get capability;

  List<SyncResourcePolicy> get resourcePolicies;

  Future<void> pushLocalChanges();
  Future<void> pullRemoteChanges();

  Future<SyncRunReport> synchronize({
    SyncRunOptions options = const SyncRunOptions(),
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
  });

  Future<SyncRemoteCapabilities> fetchCapabilities();
}

class StubSyncService implements SyncService {
  const StubSyncService();

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.placeholder,
    message: '云同步仅预留边界与冲突策略，当前阶段仍以本地优先为主。',
  );

  @override
  List<SyncResourcePolicy> get resourcePolicies => defaultSyncResourcePolicies;

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
      notes: const ['当前仍为占位同步能力，待远端 API 实装后替换。'],
    );
  }

  @override
  Future<void> pullRemoteChanges() async {}

  @override
  Future<void> pushLocalChanges() async {}

  @override
  Future<SyncRunReport> synchronize({
    SyncRunOptions options = const SyncRunOptions(),
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
  }) async {
    final now = DateTime.now().toUtc();
    return SyncRunReport(
      state: SyncRunState.placeholder,
      startedAt: now,
      finishedAt: now,
      pushedCounts: const {},
      pulledCounts: const {},
      conflicts: const [],
      checkpoint: const SyncCheckpoint(),
      trigger: trigger,
      notes: const ['StubSyncService 未接真实后端，仅返回占位同步报告。'],
    );
  }
}

class CloudReadySyncService implements SyncService {
  const CloudReadySyncService({
    required SyncCoordinator coordinator,
    required SyncRemoteRepository remoteRepository,
    this.resourcePolicies = defaultSyncResourcePolicies,
  }) : _coordinator = coordinator,
       _remoteRepository = remoteRepository;

  final SyncCoordinator _coordinator;
  final SyncRemoteRepository _remoteRepository;

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.placeholder,
    message: '同步主流程已预留，待接入远端 API 与本地 delta repository 后可切换为可用。',
  );

  @override
  final List<SyncResourcePolicy> resourcePolicies;

  @override
  Future<SyncRemoteCapabilities> fetchCapabilities() {
    return _remoteRepository.fetchCapabilities();
  }

  @override
  Future<void> pullRemoteChanges() async {
    await _coordinator.synchronize(
      options: const SyncRunOptions(pushChanges: false, pullChanges: true),
      trigger: SyncRunTrigger.manual,
    );
  }

  @override
  Future<void> pushLocalChanges() async {
    await _coordinator.synchronize(
      options: const SyncRunOptions(pushChanges: true, pullChanges: false),
      trigger: SyncRunTrigger.manual,
    );
  }

  @override
  Future<SyncRunReport> synchronize({
    SyncRunOptions options = const SyncRunOptions(),
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
  }) {
    return _coordinator.synchronize(options: options, trigger: trigger);
  }
}
