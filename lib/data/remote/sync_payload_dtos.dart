// ignore_for_file: sort_constructors_first

import '../../domain/sync/sync_models.dart';
import 'sync_dtos.dart';

class SyncDeviceContextDto {
  const SyncDeviceContextDto({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.schemaVersion,
  });

  final String deviceId;
  final String platform;
  final String appVersion;
  final int schemaVersion;

  SyncDeviceInfo toDomain() {
    return SyncDeviceInfo(
      deviceId: deviceId,
      platform: platform,
      appVersion: appVersion,
      schemaVersion: schemaVersion,
    );
  }

  JsonMap toJson() {
    return {
      'deviceId': deviceId,
      'platform': platform,
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
    };
  }

  factory SyncDeviceContextDto.fromDomain(SyncDeviceInfo device) {
    return SyncDeviceContextDto(
      deviceId: device.deviceId,
      platform: device.platform,
      appVersion: device.appVersion,
      schemaVersion: device.schemaVersion,
    );
  }

  factory SyncDeviceContextDto.fromJson(Map<String, dynamic>? json) {
    return SyncDeviceContextDto(
      deviceId: json?['deviceId'] as String? ?? 'local-device',
      platform: json?['platform'] as String? ?? 'unknown',
      appVersion: json?['appVersion'] as String? ?? 'dev',
      schemaVersion: (json?['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

class SyncCheckpointDto {
  const SyncCheckpointDto({
    this.globalCursor,
    this.collectionCursors = const {},
    this.lastSuccessfulSyncAt,
    this.schemaVersion = 1,
  });

  final String? globalCursor;
  final Map<String, String> collectionCursors;
  final DateTime? lastSuccessfulSyncAt;
  final int schemaVersion;

  SyncCheckpoint toDomain() {
    return SyncCheckpoint(
      globalCursor: globalCursor,
      collectionCursors: {
        for (final entry in collectionCursors.entries)
          syncResourceTypeFromWireName(entry.key): entry.value,
      },
      lastSuccessfulSyncAt: lastSuccessfulSyncAt,
      schemaVersion: schemaVersion,
    );
  }

  SyncCheckpointDto copyWith({
    String? globalCursor,
    Map<String, String>? collectionCursors,
    DateTime? lastSuccessfulSyncAt,
    bool clearLastSuccessfulSyncAt = false,
    int? schemaVersion,
  }) {
    return SyncCheckpointDto(
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
      'collectionCursors': collectionCursors,
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
      'schemaVersion': schemaVersion,
    };
  }

  factory SyncCheckpointDto.fromDomain(SyncCheckpoint checkpoint) {
    return SyncCheckpointDto(
      globalCursor: checkpoint.globalCursor,
      collectionCursors: {
        for (final entry in checkpoint.collectionCursors.entries)
          syncResourceTypeToWireName(entry.key): entry.value,
      },
      lastSuccessfulSyncAt: checkpoint.lastSuccessfulSyncAt,
      schemaVersion: checkpoint.schemaVersion,
    );
  }

  factory SyncCheckpointDto.fromJson(Map<String, dynamic>? json) {
    return SyncCheckpointDto(
      globalCursor: json?['globalCursor'] as String?,
      collectionCursors: {
        for (final entry
            in Map<String, dynamic>.from(
              json?['collectionCursors'] as Map? ?? const {},
            ).entries)
          entry.key: entry.value as String,
      },
      lastSuccessfulSyncAt: _readDateTime(json?['lastSuccessfulSyncAt']),
      schemaVersion: (json?['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

class SyncBatchPayloadDto {
  const SyncBatchPayloadDto({
    this.poems = const [],
    this.favorites = const [],
    this.learningRecords = const [],
    this.studyCardProgress = const [],
    this.reciteRecords = const [],
    this.wrongQuestions = const [],
    this.practiceReports = const [],
    this.dailyPoemRecords = const [],
    this.userPoints = const [],
    this.challengeStageRewards = const [],
    this.settings = const [],
    this.userProfiles = const [],
  });

  final List<PoemSyncDto> poems;
  final List<FavoriteSyncDto> favorites;
  final List<LearningRecordSyncDto> learningRecords;
  final List<StudyCardProgressSyncDto> studyCardProgress;
  final List<ReciteRecordSyncDto> reciteRecords;
  final List<WrongQuestionSyncDto> wrongQuestions;
  final List<PracticeReportSyncDto> practiceReports;
  final List<DailyPoemRecordSyncDto> dailyPoemRecords;
  final List<UserPointsSyncDto> userPoints;
  final List<ChallengeStageRewardSyncDto> challengeStageRewards;
  final List<SettingsSyncDto> settings;
  final List<UserProfileSyncDto> userProfiles;

  Map<SyncResourceType, int> get counts {
    return {
      SyncResourceType.poems: poems.length,
      SyncResourceType.favorites: favorites.length,
      SyncResourceType.learningRecords: learningRecords.length,
      SyncResourceType.studyCardProgress: studyCardProgress.length,
      SyncResourceType.reciteRecords: reciteRecords.length,
      SyncResourceType.wrongQuestions: wrongQuestions.length,
      SyncResourceType.practiceReports: practiceReports.length,
      SyncResourceType.dailyPoemRecords: dailyPoemRecords.length,
      SyncResourceType.userPoints: userPoints.length,
      SyncResourceType.challengeStageRewards: challengeStageRewards.length,
      SyncResourceType.settings: settings.length,
      SyncResourceType.userProfiles: userProfiles.length,
    };
  }

  List<SyncCollectionDelta> toCollections() {
    return [
      _collectionFromDtoList(resource: SyncResourceType.poems, dtos: poems),
      _collectionFromDtoList(
        resource: SyncResourceType.favorites,
        dtos: favorites,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.learningRecords,
        dtos: learningRecords,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.studyCardProgress,
        dtos: studyCardProgress,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.reciteRecords,
        dtos: reciteRecords,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.wrongQuestions,
        dtos: wrongQuestions,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.practiceReports,
        dtos: practiceReports,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.dailyPoemRecords,
        dtos: dailyPoemRecords,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.userPoints,
        dtos: userPoints,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.challengeStageRewards,
        dtos: challengeStageRewards,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.settings,
        dtos: settings,
      ),
      _collectionFromDtoList(
        resource: SyncResourceType.userProfiles,
        dtos: userProfiles,
      ),
    ].where((item) => item.records.isNotEmpty).toList(growable: false);
  }

  JsonMap toJson() {
    return {
      'poems': poems.map((item) => item.toJson()).toList(),
      'favorites': favorites.map((item) => item.toJson()).toList(),
      'learningRecords': learningRecords.map((item) => item.toJson()).toList(),
      'studyCardProgress':
          studyCardProgress.map((item) => item.toJson()).toList(),
      'reciteRecords': reciteRecords.map((item) => item.toJson()).toList(),
      'wrongQuestions': wrongQuestions.map((item) => item.toJson()).toList(),
      'practiceReports': practiceReports.map((item) => item.toJson()).toList(),
      'dailyPoemRecords':
          dailyPoemRecords.map((item) => item.toJson()).toList(),
      'userPoints': userPoints.map((item) => item.toJson()).toList(),
      'challengeStageRewards':
          challengeStageRewards.map((item) => item.toJson()).toList(),
      'settings': settings.map((item) => item.toJson()).toList(),
      'userProfiles': userProfiles.map((item) => item.toJson()).toList(),
    };
  }

  factory SyncBatchPayloadDto.fromCollections(
    List<SyncCollectionDelta> collections,
  ) {
    final poems = <PoemSyncDto>[];
    final favorites = <FavoriteSyncDto>[];
    final learningRecords = <LearningRecordSyncDto>[];
    final studyCardProgress = <StudyCardProgressSyncDto>[];
    final reciteRecords = <ReciteRecordSyncDto>[];
    final wrongQuestions = <WrongQuestionSyncDto>[];
    final practiceReports = <PracticeReportSyncDto>[];
    final dailyPoemRecords = <DailyPoemRecordSyncDto>[];
    final userPoints = <UserPointsSyncDto>[];
    final challengeStageRewards = <ChallengeStageRewardSyncDto>[];
    final settings = <SettingsSyncDto>[];
    final userProfiles = <UserProfileSyncDto>[];

    for (final collection in collections) {
      if (collection.resource == SyncResourceType.poems) {
        poems.addAll(collection.records.map(PoemSyncDto.fromDomainRecord));
        continue;
      }
      if (collection.resource == SyncResourceType.favorites) {
        favorites.addAll(
          collection.records.map(FavoriteSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.learningRecords) {
        learningRecords.addAll(
          collection.records.map(LearningRecordSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.studyCardProgress) {
        studyCardProgress.addAll(
          collection.records.map(StudyCardProgressSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.reciteRecords) {
        reciteRecords.addAll(
          collection.records.map(ReciteRecordSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.wrongQuestions) {
        wrongQuestions.addAll(
          collection.records.map(WrongQuestionSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.practiceReports) {
        practiceReports.addAll(
          collection.records.map(PracticeReportSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.dailyPoemRecords) {
        dailyPoemRecords.addAll(
          collection.records.map(DailyPoemRecordSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.userPoints) {
        userPoints.addAll(
          collection.records.map(UserPointsSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.challengeStageRewards) {
        challengeStageRewards.addAll(
          collection.records.map(ChallengeStageRewardSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.settings) {
        settings.addAll(
          collection.records.map(SettingsSyncDto.fromDomainRecord),
        );
        continue;
      }
      if (collection.resource == SyncResourceType.userProfiles) {
        userProfiles.addAll(
          collection.records.map(UserProfileSyncDto.fromDomainRecord),
        );
      }
    }

    return SyncBatchPayloadDto(
      poems: poems,
      favorites: favorites,
      learningRecords: learningRecords,
      studyCardProgress: studyCardProgress,
      reciteRecords: reciteRecords,
      wrongQuestions: wrongQuestions,
      practiceReports: practiceReports,
      dailyPoemRecords: dailyPoemRecords,
      userPoints: userPoints,
      challengeStageRewards: challengeStageRewards,
      settings: settings,
      userProfiles: userProfiles,
    );
  }

  factory SyncBatchPayloadDto.fromJson(Map<String, dynamic>? json) {
    return SyncBatchPayloadDto(
      poems: _listFromJson(json?['poems']).map(PoemSyncDto.fromJson).toList(),
      favorites:
          _listFromJson(
            json?['favorites'],
          ).map(FavoriteSyncDto.fromJson).toList(),
      learningRecords:
          _listFromJson(
            json?['learningRecords'],
          ).map(LearningRecordSyncDto.fromJson).toList(),
      studyCardProgress:
          _listFromJson(
            json?['studyCardProgress'],
          ).map(StudyCardProgressSyncDto.fromJson).toList(),
      reciteRecords:
          _listFromJson(
            json?['reciteRecords'],
          ).map(ReciteRecordSyncDto.fromJson).toList(),
      wrongQuestions:
          _listFromJson(
            json?['wrongQuestions'],
          ).map(WrongQuestionSyncDto.fromJson).toList(),
      practiceReports:
          _listFromJson(
            json?['practiceReports'],
          ).map(PracticeReportSyncDto.fromJson).toList(),
      dailyPoemRecords:
          _listFromJson(
            json?['dailyPoemRecords'],
          ).map(DailyPoemRecordSyncDto.fromJson).toList(),
      userPoints:
          _listFromJson(
            json?['userPoints'],
          ).map(UserPointsSyncDto.fromJson).toList(),
      challengeStageRewards:
          _listFromJson(
            json?['challengeStageRewards'],
          ).map(ChallengeStageRewardSyncDto.fromJson).toList(),
      settings:
          _listFromJson(
            json?['settings'],
          ).map(SettingsSyncDto.fromJson).toList(),
      userProfiles:
          _listFromJson(
            json?['userProfiles'],
          ).map(UserProfileSyncDto.fromJson).toList(),
    );
  }
}

class SyncUpstreamPayloadDto {
  const SyncUpstreamPayloadDto({
    required this.requestId,
    required this.device,
    required this.checkpoint,
    required this.batch,
    required this.generatedAt,
    this.fullResync = false,
    this.scope = const [],
  });

  final String requestId;
  final SyncDeviceContextDto device;
  final SyncCheckpointDto checkpoint;
  final SyncBatchPayloadDto batch;
  final DateTime generatedAt;
  final bool fullResync;
  final List<String> scope;

  JsonMap toJson() {
    return {
      'requestId': requestId,
      'device': device.toJson(),
      'checkpoint': checkpoint.toJson(),
      'batch': batch.toJson(),
      'generatedAt': generatedAt.toIso8601String(),
      'fullResync': fullResync,
      'scope': scope,
    };
  }

  factory SyncUpstreamPayloadDto.fromDomainEnvelope(
    SyncEnvelope envelope, {
    SyncRunOptions options = const SyncRunOptions(),
  }) {
    return SyncUpstreamPayloadDto(
      requestId: envelope.requestId,
      device: SyncDeviceContextDto.fromDomain(envelope.device),
      checkpoint: SyncCheckpointDto.fromDomain(envelope.checkpoint),
      batch: SyncBatchPayloadDto.fromCollections(envelope.collections),
      generatedAt: envelope.generatedAt,
      fullResync: options.fullResync,
      scope: options.scope
          .map(syncResourceTypeToWireName)
          .toList(growable: false),
    );
  }

  factory SyncUpstreamPayloadDto.fromJson(Map<String, dynamic>? json) {
    return SyncUpstreamPayloadDto(
      requestId: json?['requestId'] as String? ?? 'local-empty-sync',
      device: SyncDeviceContextDto.fromJson(
        Map<String, dynamic>.from(json?['device'] as Map? ?? const {}),
      ),
      checkpoint: SyncCheckpointDto.fromJson(
        Map<String, dynamic>.from(json?['checkpoint'] as Map? ?? const {}),
      ),
      batch: SyncBatchPayloadDto.fromJson(
        Map<String, dynamic>.from(json?['batch'] as Map? ?? const {}),
      ),
      generatedAt:
          _readDateTime(json?['generatedAt']) ?? DateTime.now().toUtc(),
      fullResync: _readBool(json?['fullResync']),
      scope: (json?['scope'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class SyncPullRequestDto {
  const SyncPullRequestDto({
    required this.requestId,
    required this.device,
    required this.checkpoint,
    required this.requestedAt,
    this.fullResync = false,
    this.includePoemCatalog = false,
    this.scope = const [],
  });

  final String requestId;
  final SyncDeviceContextDto device;
  final SyncCheckpointDto checkpoint;
  final DateTime requestedAt;
  final bool fullResync;
  final bool includePoemCatalog;
  final List<String> scope;

  JsonMap toJson() {
    return {
      'requestId': requestId,
      'device': device.toJson(),
      'checkpoint': checkpoint.toJson(),
      'requestedAt': requestedAt.toIso8601String(),
      'fullResync': fullResync,
      'includePoemCatalog': includePoemCatalog,
      'scope': scope,
    };
  }

  factory SyncPullRequestDto.fromDomain({
    required SyncDeviceInfo device,
    required SyncCheckpoint checkpoint,
    SyncRunOptions options = const SyncRunOptions(),
  }) {
    return SyncPullRequestDto(
      requestId: 'pull-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      device: SyncDeviceContextDto.fromDomain(device),
      checkpoint: SyncCheckpointDto.fromDomain(checkpoint),
      requestedAt: DateTime.now().toUtc(),
      fullResync: options.fullResync,
      includePoemCatalog: options.includePoemCatalog,
      scope: options.scope
          .map(syncResourceTypeToWireName)
          .toList(growable: false),
    );
  }

  factory SyncPullRequestDto.fromJson(Map<String, dynamic>? json) {
    return SyncPullRequestDto(
      requestId: json?['requestId'] as String? ?? 'local-pull-sync',
      device: SyncDeviceContextDto.fromJson(
        Map<String, dynamic>.from(json?['device'] as Map? ?? const {}),
      ),
      checkpoint: SyncCheckpointDto.fromJson(
        Map<String, dynamic>.from(json?['checkpoint'] as Map? ?? const {}),
      ),
      requestedAt:
          _readDateTime(json?['requestedAt']) ?? DateTime.now().toUtc(),
      fullResync: _readBool(json?['fullResync']),
      includePoemCatalog: _readBool(json?['includePoemCatalog']),
      scope: (json?['scope'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class SyncConflictSuggestionDto {
  const SyncConflictSuggestionDto({
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

  final String resource;
  final String recordKey;
  final String mergePolicy;
  final String recommendedWinner;
  final JsonMap? localPayload;
  final JsonMap? remotePayload;
  final JsonMap? mergedPayload;
  final List<String> fieldsInConflict;
  final String reason;

  SyncConflict toDomain() {
    return SyncConflict(
      resource: syncResourceTypeFromWireName(resource),
      recordKey: recordKey,
      mergePolicy: syncMergePolicyFromWireName(mergePolicy),
      recommendedWinner: SyncConflictWinner.values.firstWhere(
        (value) => value.name == recommendedWinner,
        orElse: () => SyncConflictWinner.none,
      ),
      reason: reason,
      localPayload: localPayload,
      remotePayload: remotePayload,
      mergedPayload: mergedPayload,
      fieldsInConflict: fieldsInConflict,
    );
  }

  JsonMap toJson() {
    return {
      'resource': resource,
      'recordKey': recordKey,
      'mergePolicy': mergePolicy,
      'recommendedWinner': recommendedWinner,
      'localPayload': localPayload,
      'remotePayload': remotePayload,
      'mergedPayload': mergedPayload,
      'fieldsInConflict': fieldsInConflict,
      'reason': reason,
    };
  }

  factory SyncConflictSuggestionDto.fromJson(Map<String, dynamic>? json) {
    return SyncConflictSuggestionDto(
      resource: json?['resource'] as String? ?? 'poems',
      recordKey: json?['recordKey'] as String? ?? 'unknown',
      mergePolicy: json?['mergePolicy'] as String? ?? 'last_write_wins',
      recommendedWinner: json?['recommendedWinner'] as String? ?? 'none',
      localPayload:
          json?['localPayload'] == null
              ? null
              : Map<String, dynamic>.from(json?['localPayload'] as Map),
      remotePayload:
          json?['remotePayload'] == null
              ? null
              : Map<String, dynamic>.from(json?['remotePayload'] as Map),
      mergedPayload:
          json?['mergedPayload'] == null
              ? null
              : Map<String, dynamic>.from(json?['mergedPayload'] as Map),
      fieldsInConflict: (json?['fieldsInConflict'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      reason: json?['reason'] as String? ?? 'No reason provided.',
    );
  }
}

class SyncPushResponseDto {
  const SyncPushResponseDto({
    required this.requestId,
    required this.checkpoint,
    required this.acceptedCounts,
    required this.conflicts,
    required this.serverTime,
    this.notes = const [],
  });

  final String requestId;
  final SyncCheckpointDto checkpoint;
  final Map<String, int> acceptedCounts;
  final List<SyncConflictSuggestionDto> conflicts;
  final DateTime serverTime;
  final List<String> notes;

  SyncPushResult toDomain() {
    return SyncPushResult(
      requestId: requestId,
      checkpoint: checkpoint.toDomain(),
      acceptedCounts: {
        for (final entry in acceptedCounts.entries)
          syncResourceTypeFromWireName(entry.key): entry.value,
      },
      conflicts: conflicts
          .map((item) => item.toDomain())
          .toList(growable: false),
      serverTime: serverTime,
      notes: notes,
    );
  }

  factory SyncPushResponseDto.placeholder({
    required String requestId,
    required SyncCheckpointDto checkpoint,
    Map<String, int> acceptedCounts = const {},
    List<String> notes = const [],
  }) {
    return SyncPushResponseDto(
      requestId: requestId,
      checkpoint: checkpoint.copyWith(
        lastSuccessfulSyncAt: DateTime.now().toUtc(),
      ),
      acceptedCounts: acceptedCounts,
      conflicts: const [],
      serverTime: DateTime.now().toUtc(),
      notes: notes,
    );
  }

  factory SyncPushResponseDto.fromJson(Map<String, dynamic>? json) {
    return SyncPushResponseDto(
      requestId: json?['requestId'] as String? ?? 'remote-push',
      checkpoint: SyncCheckpointDto.fromJson(
        Map<String, dynamic>.from(json?['checkpoint'] as Map? ?? const {}),
      ),
      acceptedCounts: {
        for (final entry
            in Map<String, dynamic>.from(
              json?['acceptedCounts'] as Map? ?? const {},
            ).entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      },
      conflicts: _listFromJson(
        json?['conflicts'],
      ).map(SyncConflictSuggestionDto.fromJson).toList(growable: false),
      serverTime: _readDateTime(json?['serverTime']) ?? DateTime.now().toUtc(),
      notes: (json?['notes'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class SyncPullResponseDto {
  const SyncPullResponseDto({
    required this.requestId,
    required this.checkpoint,
    required this.batch,
    required this.receivedCounts,
    required this.conflicts,
    required this.serverTime,
    this.notes = const [],
  });

  final String requestId;
  final SyncCheckpointDto checkpoint;
  final SyncBatchPayloadDto batch;
  final Map<String, int> receivedCounts;
  final List<SyncConflictSuggestionDto> conflicts;
  final DateTime serverTime;
  final List<String> notes;

  SyncPullResult toDomain({required SyncDeviceInfo device}) {
    final envelope = SyncEnvelope(
      requestId: requestId,
      device: device,
      checkpoint: checkpoint.toDomain(),
      collections: batch.toCollections(),
      generatedAt: serverTime,
    );

    return SyncPullResult(
      envelope: envelope,
      checkpoint: checkpoint.toDomain(),
      receivedCounts: {
        for (final entry in receivedCounts.entries)
          syncResourceTypeFromWireName(entry.key): entry.value,
      },
      conflicts: conflicts
          .map((item) => item.toDomain())
          .toList(growable: false),
      serverTime: serverTime,
      notes: notes,
    );
  }

  factory SyncPullResponseDto.empty({
    required SyncCheckpointDto checkpoint,
    List<String> notes = const [],
  }) {
    return SyncPullResponseDto(
      requestId: 'local-empty-pull',
      checkpoint: checkpoint.copyWith(
        lastSuccessfulSyncAt: DateTime.now().toUtc(),
      ),
      batch: const SyncBatchPayloadDto(),
      receivedCounts: const {},
      conflicts: const [],
      serverTime: DateTime.now().toUtc(),
      notes: notes,
    );
  }

  factory SyncPullResponseDto.fromJson(Map<String, dynamic>? json) {
    return SyncPullResponseDto(
      requestId: json?['requestId'] as String? ?? 'remote-pull',
      checkpoint: SyncCheckpointDto.fromJson(
        Map<String, dynamic>.from(json?['checkpoint'] as Map? ?? const {}),
      ),
      batch: SyncBatchPayloadDto.fromJson(
        Map<String, dynamic>.from(json?['batch'] as Map? ?? const {}),
      ),
      receivedCounts: {
        for (final entry
            in Map<String, dynamic>.from(
              json?['receivedCounts'] as Map? ?? const {},
            ).entries)
          entry.key: (entry.value as num?)?.toInt() ?? 0,
      },
      conflicts: _listFromJson(
        json?['conflicts'],
      ).map(SyncConflictSuggestionDto.fromJson).toList(growable: false),
      serverTime: _readDateTime(json?['serverTime']) ?? DateTime.now().toUtc(),
      notes: (json?['notes'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class SyncServerCapabilitiesDto {
  const SyncServerCapabilitiesDto({
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
  final Map<String, String> supportedPolicies;
  final List<String> notes;

  SyncRemoteCapabilities toDomain() {
    return SyncRemoteCapabilities(
      supportsPoemCatalog: supportsPoemCatalog,
      supportsSoftDelete: supportsSoftDelete,
      supportsFieldMerge: supportsFieldMerge,
      maxBatchSize: maxBatchSize,
      supportedPolicies: {
        for (final entry in supportedPolicies.entries)
          syncResourceTypeFromWireName(entry.key): syncMergePolicyFromWireName(
            entry.value,
          ),
      },
      notes: notes,
    );
  }

  factory SyncServerCapabilitiesDto.placeholder() {
    return SyncServerCapabilitiesDto(
      supportsPoemCatalog: true,
      supportsSoftDelete: true,
      supportsFieldMerge: true,
      maxBatchSize: 500,
      supportedPolicies: {
        for (final policy in defaultSyncResourcePolicies)
          syncResourceTypeToWireName(
            policy.resource,
          ): syncMergePolicyToWireName(policy.defaultMergePolicy),
      },
      notes: const ['当前为占位握手结果，待后续 NestJS 同步端点接入后替换。'],
    );
  }

  factory SyncServerCapabilitiesDto.fromJson(Map<String, dynamic>? json) {
    return SyncServerCapabilitiesDto(
      supportsPoemCatalog: _readBool(json?['supportsPoemCatalog']),
      supportsSoftDelete: _readBool(json?['supportsSoftDelete']),
      supportsFieldMerge: _readBool(json?['supportsFieldMerge']),
      maxBatchSize: (json?['maxBatchSize'] as num?)?.toInt() ?? 500,
      supportedPolicies: {
        for (final entry
            in Map<String, dynamic>.from(
              json?['supportedPolicies'] as Map? ?? const {},
            ).entries)
          entry.key: entry.value.toString(),
      },
      notes: (json?['notes'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

SyncCollectionDelta _collectionFromDtoList({
  required SyncResourceType resource,
  required List<SyncEntityDto> dtos,
}) {
  return SyncCollectionDelta(
    resource: resource,
    mergePolicy: syncPolicyForResource(resource).defaultMergePolicy,
    records: dtos
        .map((item) => item.toDomain(resource))
        .toList(growable: false),
  );
}

List<Map<String, dynamic>> _listFromJson(Object? value) {
  return (value as List? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList(growable: false);
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
