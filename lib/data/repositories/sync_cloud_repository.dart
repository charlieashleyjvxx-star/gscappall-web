import '../../domain/sync/sync_models.dart';
import '../../domain/sync/sync_repository.dart';
import '../remote/cloud_sync_api.dart';
import '../remote/sync_payload_dtos.dart';

class CloudSyncRemoteRepository implements SyncRemoteRepository {
  const CloudSyncRemoteRepository({required CloudSyncApi api}) : _api = api;

  final CloudSyncApi _api;

  @override
  Future<SyncRemoteCapabilities> fetchCapabilities() async {
    final capabilities = await _api.fetchCapabilities();
    return capabilities.toDomain();
  }

  @override
  Future<SyncPushResult> pushChanges(SyncEnvelope envelope) async {
    final payload = SyncUpstreamPayloadDto.fromDomainEnvelope(envelope);
    final response = await _api.pushChanges(payload);
    return response.toDomain();
  }

  @override
  Future<SyncPullResult> pullChanges({
    required SyncCheckpoint checkpoint,
    SyncRunOptions options = const SyncRunOptions(),
  }) async {
    final device = await _api.resolveDeviceInfo();
    final request = SyncPullRequestDto.fromDomain(
      device: device,
      checkpoint: checkpoint,
      options: options,
    );
    final response = await _api.pullChanges(request);
    return response.toDomain(device: request.device.toDomain());
  }

  @override
  Future<List<SyncConflict>> previewConflicts(SyncEnvelope envelope) async {
    final payload = SyncUpstreamPayloadDto.fromDomainEnvelope(envelope);
    final response = await _api.previewConflicts(payload);
    return response.map((item) => item.toDomain()).toList(growable: false);
  }
}
