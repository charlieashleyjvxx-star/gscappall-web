// ignore_for_file: sort_constructors_first

typedef JsonMap = Map<String, dynamic>;

enum SyncResourceType {
  poems,
  favorites,
  learningRecords,
  studyCardProgress,
  reciteRecords,
  wrongQuestions,
  practiceReports,
  dailyPoemRecords,
  userPoints,
  challengeStageRewards,
  settings,
  userProfiles,
}

String syncResourceTypeToWireName(SyncResourceType value) {
  switch (value) {
    case SyncResourceType.poems:
      return 'poems';
    case SyncResourceType.favorites:
      return 'favorites';
    case SyncResourceType.learningRecords:
      return 'learning_records';
    case SyncResourceType.studyCardProgress:
      return 'study_card_progress';
    case SyncResourceType.reciteRecords:
      return 'recite_records';
    case SyncResourceType.wrongQuestions:
      return 'wrong_questions';
    case SyncResourceType.practiceReports:
      return 'practice_reports';
    case SyncResourceType.dailyPoemRecords:
      return 'daily_poem_records';
    case SyncResourceType.userPoints:
      return 'user_points';
    case SyncResourceType.challengeStageRewards:
      return 'challenge_stage_rewards';
    case SyncResourceType.settings:
      return 'settings';
    case SyncResourceType.userProfiles:
      return 'user_profiles';
  }
}

SyncResourceType syncResourceTypeFromWireName(String value) {
  switch (value) {
    case 'poems':
      return SyncResourceType.poems;
    case 'favorites':
      return SyncResourceType.favorites;
    case 'learning_records':
      return SyncResourceType.learningRecords;
    case 'study_card_progress':
      return SyncResourceType.studyCardProgress;
    case 'recite_records':
      return SyncResourceType.reciteRecords;
    case 'wrong_questions':
      return SyncResourceType.wrongQuestions;
    case 'practice_reports':
      return SyncResourceType.practiceReports;
    case 'daily_poem_records':
      return SyncResourceType.dailyPoemRecords;
    case 'user_points':
      return SyncResourceType.userPoints;
    case 'challenge_stage_rewards':
      return SyncResourceType.challengeStageRewards;
    case 'settings':
      return SyncResourceType.settings;
    case 'user_profiles':
      return SyncResourceType.userProfiles;
    default:
      return SyncResourceType.poems;
  }
}

enum SyncMergePolicy {
  serverAuthoritative,
  lastWriteWins,
  appendOnly,
  softDelete,
  serverMergeSuggested,
}

String syncMergePolicyToWireName(SyncMergePolicy value) {
  switch (value) {
    case SyncMergePolicy.serverAuthoritative:
      return 'server_authoritative';
    case SyncMergePolicy.lastWriteWins:
      return 'last_write_wins';
    case SyncMergePolicy.appendOnly:
      return 'append_only';
    case SyncMergePolicy.softDelete:
      return 'soft_delete';
    case SyncMergePolicy.serverMergeSuggested:
      return 'server_merge_suggested';
  }
}

SyncMergePolicy syncMergePolicyFromWireName(String value) {
  switch (value) {
    case 'server_authoritative':
      return SyncMergePolicy.serverAuthoritative;
    case 'append_only':
      return SyncMergePolicy.appendOnly;
    case 'soft_delete':
      return SyncMergePolicy.softDelete;
    case 'server_merge_suggested':
      return SyncMergePolicy.serverMergeSuggested;
    case 'last_write_wins':
    default:
      return SyncMergePolicy.lastWriteWins;
  }
}

enum SyncRunState {
  idle,
  placeholder,
  success,
  partialSuccess,
  conflict,
  failed,
}

enum SyncRunTrigger {
  unknown,
  manual,
  loginInitial,
  foregroundAuto,
  startupAuto,
}

String syncRunTriggerToWireName(SyncRunTrigger value) {
  switch (value) {
    case SyncRunTrigger.manual:
      return 'manual';
    case SyncRunTrigger.loginInitial:
      return 'login_initial';
    case SyncRunTrigger.foregroundAuto:
      return 'foreground_auto';
    case SyncRunTrigger.startupAuto:
      return 'startup_auto';
    case SyncRunTrigger.unknown:
      return 'unknown';
  }
}

SyncRunTrigger syncRunTriggerFromWireName(String? value) {
  switch (value) {
    case 'manual':
      return SyncRunTrigger.manual;
    case 'login_initial':
      return SyncRunTrigger.loginInitial;
    case 'foreground_auto':
      return SyncRunTrigger.foregroundAuto;
    case 'startup_auto':
      return SyncRunTrigger.startupAuto;
    case 'unknown':
    default:
      return SyncRunTrigger.unknown;
  }
}

enum SyncConflictWinner { local, remote, merged, none }

class SyncDeviceInfo {
  const SyncDeviceInfo({
    this.deviceId = 'local-device',
    this.platform = 'unknown',
    this.appVersion = 'dev',
    this.schemaVersion = 1,
  });

  final String deviceId;
  final String platform;
  final String appVersion;
  final int schemaVersion;

  JsonMap toJson() {
    return {
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
    };
  }

  factory SyncDeviceInfo.fromJson(Map<String, dynamic>? json) {
    return SyncDeviceInfo(
      deviceId: json?['deviceId'] as String? ?? 'local-device',
      platform: json?['platform'] as String? ?? 'unknown',
      appVersion: json?['appVersion'] as String? ?? 'dev',
      schemaVersion: (json?['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

class SyncCheckpoint {
  const SyncCheckpoint({
    this.globalCursor,
    this.collectionCursors = const {},
    this.lastSuccessfulSyncAt,
    this.schemaVersion = 1,
  });

  final String? globalCursor;
  final Map<SyncResourceType, String> collectionCursors;
  final DateTime? lastSuccessfulSyncAt;
  final int schemaVersion;

  String? cursorFor(SyncResourceType resource) => collectionCursors[resource];

  SyncCheckpoint copyWith({
    String? globalCursor,
    Map<SyncResourceType, String>? collectionCursors,
    DateTime? lastSuccessfulSyncAt,
    bool clearLastSuccessfulSyncAt = false,
    int? schemaVersion,
  }) {
    return SyncCheckpoint(
      globalCursor: globalCursor ?? this.globalCursor,
      collectionCursors: collectionCursors ?? this.collectionCursors,
      lastSuccessfulSyncAt:
          clearLastSuccessfulSyncAt
              ? null
              : (lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt),
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  JsonMap toJson() {
    return {
      'globalCursor': globalCursor,
      'collectionCursors': {
        for (final entry in collectionCursors.entries)
          syncResourceTypeToWireName(entry.key): entry.value,
      },
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }

  factory SyncCheckpoint.fromJson(Map<String, dynamic>? json) {
    final rawCursors = Map<String, dynamic>.from(
      json?['collectionCursors'] as Map? ?? const {},
    );

    return SyncCheckpoint(
      globalCursor: json?['globalCursor'] as String?,
      collectionCursors: {
        for (final entry in rawCursors.entries)
          syncResourceTypeFromWireName(entry.key): entry.value as String,
      },
      lastSuccessfulSyncAt: _readDateTime(json?['lastSuccessfulSyncAt']),
      schemaVersion: (json?['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

class SyncChangeMetadata {
  const SyncChangeMetadata({
    this.localId,
    this.cloudId,
    this.revisionToken,
    this.clientMutationId,
    this.lastActorDeviceId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.isEncrypted = false,
    this.schemaVersion = 1,
    this.extras = const {},
  });

  final String? localId;
  final String? cloudId;
  final String? revisionToken;
  final String? clientMutationId;
  final String? lastActorDeviceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final bool isEncrypted;
  final int schemaVersion;
  final JsonMap extras;

  String get identity => cloudId ?? localId ?? clientMutationId ?? 'unknown';

  DateTime? get effectiveUpdatedAt => updatedAt ?? deletedAt ?? createdAt;

  JsonMap toJson() {
    return {
      'localId': localId,
      'cloudId': cloudId,
      'revisionToken': revisionToken,
      'clientMutationId': clientMutationId,
      'lastActorDeviceId': lastActorDeviceId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'isEncrypted': isEncrypted,
      'schemaVersion': schemaVersion,
      'extras': extras,
    };
  }

  factory SyncChangeMetadata.fromJson(Map<String, dynamic>? json) {
    return SyncChangeMetadata(
      localId: json?['localId'] as String?,
      cloudId: json?['cloudId'] as String?,
      revisionToken: json?['revisionToken'] as String?,
      clientMutationId: json?['clientMutationId'] as String?,
      lastActorDeviceId: json?['lastActorDeviceId'] as String?,
      createdAt: _readDateTime(json?['createdAt']),
      updatedAt: _readDateTime(json?['updatedAt']),
      deletedAt: _readDateTime(json?['deletedAt']),
      isDeleted: _readBool(json?['isDeleted']),
      isEncrypted: _readBool(json?['isEncrypted']),
      schemaVersion: (json?['schemaVersion'] as num?)?.toInt() ?? 1,
      extras: Map<String, dynamic>.from(json?['extras'] as Map? ?? const {}),
    );
  }
}

class SyncChangeRecord {
  const SyncChangeRecord({
    required this.resource,
    required this.recordKey,
    required this.data,
    required this.metadata,
  });

  final SyncResourceType resource;
  final String recordKey;
  final JsonMap data;
  final SyncChangeMetadata metadata;

  JsonMap toJson() {
    return {
      'resource': syncResourceTypeToWireName(resource),
      'recordKey': recordKey,
      'data': data,
      'metadata': metadata.toJson(),
    };
  }

  factory SyncChangeRecord.fromJson(Map<String, dynamic> json) {
    return SyncChangeRecord(
      resource: syncResourceTypeFromWireName(
        json['resource'] as String? ?? 'poems',
      ),
      recordKey: json['recordKey'] as String? ?? 'unknown',
      data: Map<String, dynamic>.from(json['data'] as Map? ?? const {}),
      metadata: SyncChangeMetadata.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class SyncCollectionDelta {
  const SyncCollectionDelta({
    required this.resource,
    required this.mergePolicy,
    required this.records,
    this.nextCursor,
    this.resetCollection = false,
  });

  final SyncResourceType resource;
  final SyncMergePolicy mergePolicy;
  final List<SyncChangeRecord> records;
  final String? nextCursor;
  final bool resetCollection;

  int get count => records.length;

  JsonMap toJson() {
    return {
      'resource': syncResourceTypeToWireName(resource),
      'mergePolicy': syncMergePolicyToWireName(mergePolicy),
      'records': records.map((record) => record.toJson()).toList(),
      'nextCursor': nextCursor,
      'resetCollection': resetCollection,
    };
  }

  factory SyncCollectionDelta.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List? ?? const [];
    return SyncCollectionDelta(
      resource: syncResourceTypeFromWireName(
        json['resource'] as String? ?? 'poems',
      ),
      mergePolicy: syncMergePolicyFromWireName(
        json['mergePolicy'] as String? ?? 'last_write_wins',
      ),
      records: rawRecords
          .map(
            (item) => SyncChangeRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      resetCollection: _readBool(json['resetCollection']),
    );
  }
}

class SyncEnvelope {
  const SyncEnvelope({
    required this.requestId,
    required this.device,
    required this.checkpoint,
    required this.collections,
    required this.generatedAt,
  });

  final String requestId;
  final SyncDeviceInfo device;
  final SyncCheckpoint checkpoint;
  final List<SyncCollectionDelta> collections;
  final DateTime generatedAt;

  int get totalRecords =>
      collections.fold<int>(0, (total, collection) => total + collection.count);

  bool get isEmpty => totalRecords == 0;

  JsonMap toJson() {
    return {
      'requestId': requestId,
      'device': device.toJson(),
      'checkpoint': checkpoint.toJson(),
      'collections': collections.map((item) => item.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory SyncEnvelope.empty({
    SyncDeviceInfo device = const SyncDeviceInfo(),
    SyncCheckpoint checkpoint = const SyncCheckpoint(),
    String requestId = 'local-empty-sync',
  }) {
    return SyncEnvelope(
      requestId: requestId,
      device: device,
      checkpoint: checkpoint,
      collections: const [],
      generatedAt: DateTime.now().toUtc(),
    );
  }

  factory SyncEnvelope.fromJson(Map<String, dynamic> json) {
    final rawCollections = json['collections'] as List? ?? const [];
    return SyncEnvelope(
      requestId: json['requestId'] as String? ?? 'local-empty-sync',
      device: SyncDeviceInfo.fromJson(
        Map<String, dynamic>.from(json['device'] as Map? ?? const {}),
      ),
      checkpoint: SyncCheckpoint.fromJson(
        Map<String, dynamic>.from(json['checkpoint'] as Map? ?? const {}),
      ),
      collections: rawCollections
          .map(
            (item) => SyncCollectionDelta.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      generatedAt: _readDateTime(json['generatedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

class SyncConflict {
  const SyncConflict({
    required this.resource,
    required this.recordKey,
    required this.mergePolicy,
    required this.recommendedWinner,
    required this.reason,
    this.localPayload,
    this.remotePayload,
    this.mergedPayload,
    this.fieldsInConflict = const [],
  });

  final SyncResourceType resource;
  final String recordKey;
  final SyncMergePolicy mergePolicy;
  final SyncConflictWinner recommendedWinner;
  final String reason;
  final JsonMap? localPayload;
  final JsonMap? remotePayload;
  final JsonMap? mergedPayload;
  final List<String> fieldsInConflict;
}

class SyncPushResult {
  const SyncPushResult({
    required this.requestId,
    required this.checkpoint,
    required this.acceptedCounts,
    required this.conflicts,
    required this.serverTime,
    this.notes = const [],
  });

  final String requestId;
  final SyncCheckpoint checkpoint;
  final Map<SyncResourceType, int> acceptedCounts;
  final List<SyncConflict> conflicts;
  final DateTime serverTime;
  final List<String> notes;
}

class SyncPullResult {
  const SyncPullResult({
    required this.envelope,
    required this.checkpoint,
    required this.receivedCounts,
    required this.conflicts,
    required this.serverTime,
    this.notes = const [],
  });

  final SyncEnvelope envelope;
  final SyncCheckpoint checkpoint;
  final Map<SyncResourceType, int> receivedCounts;
  final List<SyncConflict> conflicts;
  final DateTime serverTime;
  final List<String> notes;
}

class SyncRunOptions {
  const SyncRunOptions({
    this.pushChanges = true,
    this.pullChanges = true,
    this.fullResync = false,
    this.includePoemCatalog = false,
    this.scope = const <SyncResourceType>{},
  });

  final bool pushChanges;
  final bool pullChanges;
  final bool fullResync;
  final bool includePoemCatalog;
  final Set<SyncResourceType> scope;

  bool includes(SyncResourceType resource) {
    return scope.isEmpty || scope.contains(resource);
  }

  SyncRunOptions copyWith({
    bool? pushChanges,
    bool? pullChanges,
    bool? fullResync,
    bool? includePoemCatalog,
    Set<SyncResourceType>? scope,
  }) {
    return SyncRunOptions(
      pushChanges: pushChanges ?? this.pushChanges,
      pullChanges: pullChanges ?? this.pullChanges,
      fullResync: fullResync ?? this.fullResync,
      includePoemCatalog: includePoemCatalog ?? this.includePoemCatalog,
      scope: scope ?? this.scope,
    );
  }
}

class SyncRunReport {
  const SyncRunReport({
    required this.state,
    required this.startedAt,
    required this.finishedAt,
    required this.pushedCounts,
    required this.pulledCounts,
    required this.conflicts,
    required this.checkpoint,
    this.trigger = SyncRunTrigger.unknown,
    this.notes = const [],
  });

  final SyncRunState state;
  final DateTime startedAt;
  final DateTime finishedAt;
  final Map<SyncResourceType, int> pushedCounts;
  final Map<SyncResourceType, int> pulledCounts;
  final List<SyncConflict> conflicts;
  final SyncCheckpoint checkpoint;
  final SyncRunTrigger trigger;
  final List<String> notes;
}

class SyncRunLogEntry {
  const SyncRunLogEntry({
    required this.id,
    required this.state,
    required this.startedAt,
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictCount,
    required this.createdAt,
    this.trigger = SyncRunTrigger.unknown,
    this.finishedAt,
    this.errorMessage,
    this.notes = const [],
  });

  final int id;
  final SyncRunState state;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int pushedCount;
  final int pulledCount;
  final int conflictCount;
  final SyncRunTrigger trigger;
  final String? errorMessage;
  final List<String> notes;
  final DateTime createdAt;
}

class SyncRemoteCapabilities {
  const SyncRemoteCapabilities({
    required this.supportsPoemCatalog,
    required this.supportsSoftDelete,
    required this.supportsFieldMerge,
    required this.maxBatchSize,
    required this.supportedPolicies,
    this.notes = const [],
  });

  final bool supportsPoemCatalog;
  final bool supportsSoftDelete;
  final bool supportsFieldMerge;
  final int maxBatchSize;
  final Map<SyncResourceType, SyncMergePolicy> supportedPolicies;
  final List<String> notes;
}

class SyncResourcePolicy {
  const SyncResourcePolicy({
    required this.resource,
    required this.defaultMergePolicy,
    required this.softDeleteEnabled,
    required this.appendOnly,
    required this.serverAuthoritative,
    required this.supportsFieldMerge,
    required this.notes,
  });

  final SyncResourceType resource;
  final SyncMergePolicy defaultMergePolicy;
  final bool softDeleteEnabled;
  final bool appendOnly;
  final bool serverAuthoritative;
  final bool supportsFieldMerge;
  final String notes;
}

const List<SyncResourcePolicy> defaultSyncResourcePolicies = [
  SyncResourcePolicy(
    resource: SyncResourceType.poems,
    defaultMergePolicy: SyncMergePolicy.serverAuthoritative,
    softDeleteEnabled: true,
    appendOnly: false,
    serverAuthoritative: true,
    supportsFieldMerge: false,
    notes: '内容主数据以服务端种子和审核版为准，客户端仅缓存和灰度覆盖。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.favorites,
    defaultMergePolicy: SyncMergePolicy.softDelete,
    softDeleteEnabled: true,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: false,
    notes: '收藏切换使用软删除 tombstone，按 updated_at 做最终态收敛。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.learningRecords,
    defaultMergePolicy: SyncMergePolicy.appendOnly,
    softDeleteEnabled: false,
    appendOnly: true,
    serverAuthoritative: false,
    supportsFieldMerge: false,
    notes: '学习记录按事件流上报，不回写覆盖旧记录。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.studyCardProgress,
    defaultMergePolicy: SyncMergePolicy.serverMergeSuggested,
    softDeleteEnabled: false,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes: '学习卡复习状态和笔记按 profile+poem 合并，笔记字段保留用户最新编辑。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.reciteRecords,
    defaultMergePolicy: SyncMergePolicy.appendOnly,
    softDeleteEnabled: false,
    appendOnly: true,
    serverAuthoritative: false,
    supportsFieldMerge: false,
    notes: '背诵记录视为尝试流水，后续报告可在服务端聚合。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.wrongQuestions,
    defaultMergePolicy: SyncMergePolicy.serverMergeSuggested,
    softDeleteEnabled: true,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes: '错题需要保留做题历史，同时允许服务端做题型和严重度修正。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.practiceReports,
    defaultMergePolicy: SyncMergePolicy.appendOnly,
    softDeleteEnabled: false,
    appendOnly: true,
    serverAuthoritative: false,
    supportsFieldMerge: false,
    notes: '练习报告作为完成事件上报，服务端按 profile 聚合历史和明细。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.dailyPoemRecords,
    defaultMergePolicy: SyncMergePolicy.lastWriteWins,
    softDeleteEnabled: false,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes: '每日一诗完成状态按时间戳收敛，完成态优先于未完成态。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.userPoints,
    defaultMergePolicy: SyncMergePolicy.serverMergeSuggested,
    softDeleteEnabled: false,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes: 'Points and streak counters are profile-scoped and merged by field.',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.challengeStageRewards,
    defaultMergePolicy: SyncMergePolicy.serverMergeSuggested,
    softDeleteEnabled: false,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes:
        'Challenge reward claim markers are profile-scoped and merged by stage/star key.',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.settings,
    defaultMergePolicy: SyncMergePolicy.serverMergeSuggested,
    softDeleteEnabled: false,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes: '设置建议做字段级合并，避免整条记录互相覆盖。',
  ),
  SyncResourcePolicy(
    resource: SyncResourceType.userProfiles,
    defaultMergePolicy: SyncMergePolicy.serverMergeSuggested,
    softDeleteEnabled: true,
    appendOnly: false,
    serverAuthoritative: false,
    supportsFieldMerge: true,
    notes: '昵称/签名冲突优先给服务端合并建议，必要时回退到 LWW。',
  ),
];

SyncResourcePolicy syncPolicyForResource(SyncResourceType resource) {
  return defaultSyncResourcePolicies.firstWhere(
    (policy) => policy.resource == resource,
  );
}

DateTime? _readDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.tryParse(value.toString());
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value == 'true' || value == '1';
  }
  return false;
}
