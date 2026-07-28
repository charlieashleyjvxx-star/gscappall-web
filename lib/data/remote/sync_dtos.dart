// ignore_for_file: sort_constructors_first

import '../../domain/sync/sync_models.dart';

abstract class SyncEntityDto {
  const SyncEntityDto();

  String get recordKey;
  SyncRecordMetadataDto get metadata;

  JsonMap toJson();

  SyncChangeRecord toDomain(SyncResourceType resource) {
    final json = Map<String, dynamic>.from(toJson());
    json.remove('metadata');
    return SyncChangeRecord(
      resource: resource,
      recordKey: recordKey,
      data: json,
      metadata: metadata.toDomain(),
    );
  }
}

class SyncRecordMetadataDto {
  const SyncRecordMetadataDto({
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

  SyncChangeMetadata toDomain() {
    return SyncChangeMetadata(
      localId: localId,
      cloudId: cloudId,
      revisionToken: revisionToken,
      clientMutationId: clientMutationId,
      lastActorDeviceId: lastActorDeviceId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      isDeleted: isDeleted,
      isEncrypted: isEncrypted,
      schemaVersion: schemaVersion,
      extras: extras,
    );
  }

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

  factory SyncRecordMetadataDto.fromDomain(SyncChangeMetadata metadata) {
    return SyncRecordMetadataDto(
      localId: metadata.localId,
      cloudId: metadata.cloudId,
      revisionToken: metadata.revisionToken,
      clientMutationId: metadata.clientMutationId,
      lastActorDeviceId: metadata.lastActorDeviceId,
      createdAt: metadata.createdAt,
      updatedAt: metadata.updatedAt,
      deletedAt: metadata.deletedAt,
      isDeleted: metadata.isDeleted,
      isEncrypted: metadata.isEncrypted,
      schemaVersion: metadata.schemaVersion,
      extras: metadata.extras,
    );
  }

  factory SyncRecordMetadataDto.fromJson(Map<String, dynamic>? json) {
    return SyncRecordMetadataDto(
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

class PoemSyncDto extends SyncEntityDto {
  const PoemSyncDto({
    required this.poemId,
    required this.title,
    required this.author,
    required this.dynasty,
    required this.grade,
    required this.gradeLabel,
    required this.category,
    required this.content,
    required this.pinyin,
    required this.annotation,
    required this.translation,
    required this.appreciation,
    required this.authorIntro,
    required this.extensionText,
    required this.difficulty,
    required this.seedVersion,
    required this.metadata,
    this.audioUrl,
    this.imageUrl,
  });

  final int poemId;
  final String title;
  final String author;
  final String dynasty;
  final int grade;
  final String gradeLabel;
  final String category;
  final String content;
  final String pinyin;
  final String annotation;
  final String translation;
  final String appreciation;
  final String authorIntro;
  final String extensionText;
  final String? audioUrl;
  final String? imageUrl;
  final int difficulty;
  final String seedVersion;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey => metadata.cloudId ?? poemId.toString();

  @override
  JsonMap toJson() {
    return {
      'poemId': poemId,
      'title': title,
      'author': author,
      'dynasty': dynasty,
      'grade': grade,
      'gradeLabel': gradeLabel,
      'category': category,
      'content': content,
      'pinyin': pinyin,
      'annotation': annotation,
      'translation': translation,
      'appreciation': appreciation,
      'authorIntro': authorIntro,
      'extensionText': extensionText,
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'difficulty': difficulty,
      'seedVersion': seedVersion,
      'metadata': metadata.toJson(),
    };
  }

  factory PoemSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return PoemSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory PoemSyncDto.fromJson(Map<String, dynamic> json) {
    return PoemSyncDto(
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      dynasty: json['dynasty'] as String? ?? '',
      grade: (json['grade'] as num?)?.toInt() ?? 0,
      gradeLabel: json['gradeLabel'] as String? ?? '',
      category: json['category'] as String? ?? '',
      content: json['content'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      annotation: json['annotation'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      appreciation: json['appreciation'] as String? ?? '',
      authorIntro: json['authorIntro'] as String? ?? '',
      extensionText: json['extensionText'] as String? ?? '',
      audioUrl: json['audioUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      seedVersion: json['seedVersion'] as String? ?? '',
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class FavoriteSyncDto extends SyncEntityDto {
  const FavoriteSyncDto({
    required this.profileId,
    required this.poemId,
    required this.isFavorite,
    required this.metadata,
    this.favoritedAt,
    this.source,
  });

  final int profileId;
  final int poemId;
  final bool isFavorite;
  final DateTime? favoritedAt;
  final String? source;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey => metadata.cloudId ?? 'favorite:$profileId:$poemId';

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'poemId': poemId,
      'isFavorite': isFavorite,
      'favoritedAt': favoritedAt?.toIso8601String(),
      'source': source,
      'metadata': metadata.toJson(),
    };
  }

  factory FavoriteSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return FavoriteSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory FavoriteSyncDto.fromJson(Map<String, dynamic> json) {
    return FavoriteSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      isFavorite: _readBool(json['isFavorite'], fallback: true),
      favoritedAt: _readDateTime(json['favoritedAt']),
      source: json['source'] as String?,
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class LearningRecordSyncDto extends SyncEntityDto {
  const LearningRecordSyncDto({
    required this.profileId,
    required this.poemId,
    required this.mode,
    required this.durationMinutes,
    required this.metadata,
    this.score,
    this.note,
    this.sessionId,
    this.stageId,
  });

  final int profileId;
  final int poemId;
  final String mode;
  final int durationMinutes;
  final int? score;
  final String? note;
  final String? sessionId;
  final String? stageId;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey {
    return metadata.cloudId ??
        metadata.localId ??
        'learning:$profileId:$poemId:${metadata.createdAt?.toIso8601String() ?? 'unknown'}';
  }

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'poemId': poemId,
      'mode': mode,
      'durationMinutes': durationMinutes,
      'score': score,
      'note': note,
      'sessionId': sessionId,
      'stageId': stageId,
      'metadata': metadata.toJson(),
    };
  }

  factory LearningRecordSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return LearningRecordSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory LearningRecordSyncDto.fromJson(Map<String, dynamic> json) {
    return LearningRecordSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      mode: json['mode'] as String? ?? 'review',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt(),
      note: json['note'] as String?,
      sessionId: json['sessionId'] as String?,
      stageId: json['stageId'] as String?,
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class ReciteRecordSyncDto extends SyncEntityDto {
  const ReciteRecordSyncDto({
    required this.profileId,
    required this.poemId,
    required this.metadata,
    this.score,
    this.recognizedText,
    this.transcriptVersion,
  });

  final int profileId;
  final int poemId;
  final int? score;
  final String? recognizedText;
  final String? transcriptVersion;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey {
    return metadata.cloudId ??
        metadata.localId ??
        'recite:$profileId:$poemId:${metadata.createdAt?.toIso8601String() ?? 'unknown'}';
  }

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'poemId': poemId,
      'score': score,
      'recognizedText': recognizedText,
      'transcriptVersion': transcriptVersion,
      'metadata': metadata.toJson(),
    };
  }

  factory ReciteRecordSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return ReciteRecordSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory ReciteRecordSyncDto.fromJson(Map<String, dynamic> json) {
    return ReciteRecordSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt(),
      recognizedText: json['recognizedText'] as String?,
      transcriptVersion: json['transcriptVersion'] as String?,
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class StudyCardProgressSyncDto extends SyncEntityDto {
  const StudyCardProgressSyncDto({
    required this.profileId,
    required this.poemId,
    required this.memoryStatus,
    required this.reviewCount,
    required this.metadata,
    this.nextReviewAt,
    this.note,
  });

  final int profileId;
  final int poemId;
  final String memoryStatus;
  final int reviewCount;
  final DateTime? nextReviewAt;
  final String? note;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey {
    return metadata.cloudId ?? 'study_card:$profileId:$poemId';
  }

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'poemId': poemId,
      'memoryStatus': memoryStatus,
      'reviewCount': reviewCount,
      'nextReviewAt': nextReviewAt?.toIso8601String(),
      'note': note,
      'metadata': metadata.toJson(),
    };
  }

  factory StudyCardProgressSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return StudyCardProgressSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory StudyCardProgressSyncDto.fromJson(Map<String, dynamic> json) {
    return StudyCardProgressSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      memoryStatus: json['memoryStatus'] as String? ?? 'new',
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      nextReviewAt: _readDateTime(json['nextReviewAt']),
      note: json['note'] as String?,
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class WrongQuestionSyncDto extends SyncEntityDto {
  const WrongQuestionSyncDto({
    required this.profileId,
    required this.poemId,
    required this.severity,
    required this.metadata,
    this.questionType,
    this.prompt,
    this.correctAnswer,
    this.userAnswer,
    this.ruleTag,
    this.stageId,
    this.reviewedAt,
    this.isResolved = false,
  });

  final int profileId;
  final int poemId;
  final String? questionType;
  final String? prompt;
  final String? correctAnswer;
  final String? userAnswer;
  final String? ruleTag;
  final String? stageId;
  final String severity;
  final DateTime? reviewedAt;
  final bool isResolved;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey {
    return metadata.cloudId ??
        metadata.localId ??
        'wrong:$profileId:$poemId:${metadata.createdAt?.toIso8601String() ?? 'unknown'}';
  }

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'poemId': poemId,
      'questionType': questionType,
      'prompt': prompt,
      'correctAnswer': correctAnswer,
      'userAnswer': userAnswer,
      'ruleTag': ruleTag,
      'stageId': stageId,
      'severity': severity,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'isResolved': isResolved,
      'metadata': metadata.toJson(),
    };
  }

  factory WrongQuestionSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return WrongQuestionSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory WrongQuestionSyncDto.fromJson(Map<String, dynamic> json) {
    return WrongQuestionSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      questionType: json['questionType'] as String?,
      prompt: json['prompt'] as String?,
      correctAnswer: json['correctAnswer'] as String?,
      userAnswer: json['userAnswer'] as String?,
      ruleTag: json['ruleTag'] as String?,
      stageId: json['stageId'] as String?,
      severity: json['severity'] as String? ?? 'medium',
      reviewedAt: _readDateTime(json['reviewedAt']),
      isResolved: _readBool(json['isResolved']),
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class DailyPoemRecordSyncDto extends SyncEntityDto {
  const DailyPoemRecordSyncDto({
    required this.profileId,
    required this.dateKey,
    required this.poemId,
    required this.isCompleted,
    required this.metadata,
    this.completedAt,
  });

  final int profileId;
  final String dateKey;
  final int poemId;
  final bool isCompleted;
  final DateTime? completedAt;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey => metadata.cloudId ?? 'daily:$profileId:$dateKey';

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'dateKey': dateKey,
      'poemId': poemId,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'metadata': metadata.toJson(),
    };
  }

  factory DailyPoemRecordSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return DailyPoemRecordSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory DailyPoemRecordSyncDto.fromJson(Map<String, dynamic> json) {
    return DailyPoemRecordSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      dateKey: json['dateKey'] as String? ?? '',
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      isCompleted: _readBool(json['isCompleted']),
      completedAt: _readDateTime(json['completedAt']),
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class UserPointsSyncDto extends SyncEntityDto {
  const UserPointsSyncDto({
    required this.profileId,
    required this.totalPoints,
    required this.currentPoints,
    required this.totalCheckIns,
    required this.consecutiveDays,
    required this.metadata,
    this.lastCheckInDate,
  });

  final int profileId;
  final int totalPoints;
  final int currentPoints;
  final int totalCheckIns;
  final int consecutiveDays;
  final String? lastCheckInDate;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey => metadata.cloudId ?? 'points:$profileId';

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'totalPoints': totalPoints,
      'currentPoints': currentPoints,
      'totalCheckIns': totalCheckIns,
      'consecutiveDays': consecutiveDays,
      'lastCheckInDate': lastCheckInDate,
      'metadata': metadata.toJson(),
    };
  }

  factory UserPointsSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return UserPointsSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory UserPointsSyncDto.fromJson(Map<String, dynamic> json) {
    return UserPointsSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      currentPoints: (json['currentPoints'] as num?)?.toInt() ?? 0,
      totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
      consecutiveDays: (json['consecutiveDays'] as num?)?.toInt() ?? 0,
      lastCheckInDate: json['lastCheckInDate'] as String?,
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class ChallengeStageRewardSyncDto extends SyncEntityDto {
  const ChallengeStageRewardSyncDto({
    required this.profileId,
    required this.stageId,
    required this.stars,
    required this.claimedAt,
    required this.metadata,
  });

  final int profileId;
  final String stageId;
  final int stars;
  final DateTime claimedAt;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey {
    return metadata.cloudId ?? 'reward:$profileId:$stageId:$stars';
  }

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'stageId': stageId,
      'stars': stars,
      'claimedAt': claimedAt.toIso8601String(),
      'metadata': metadata.toJson(),
    };
  }

  factory ChallengeStageRewardSyncDto.fromDomainRecord(
    SyncChangeRecord record,
  ) {
    return ChallengeStageRewardSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory ChallengeStageRewardSyncDto.fromJson(Map<String, dynamic> json) {
    return ChallengeStageRewardSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      stageId: json['stageId'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      claimedAt: _readDateTime(json['claimedAt']) ?? DateTime(1970),
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class PracticeReportSyncDto extends SyncEntityDto {
  const PracticeReportSyncDto({
    required this.profileId,
    required this.sessionId,
    required this.mode,
    required this.poemId,
    required this.totalScore,
    required this.correctCount,
    required this.totalQuestions,
    required this.generatedWrongCount,
    required this.suggestions,
    required this.completedAt,
    required this.items,
    required this.metadata,
    this.stageId,
  });

  final int profileId;
  final String sessionId;
  final String mode;
  final int poemId;
  final int totalScore;
  final int correctCount;
  final int totalQuestions;
  final int generatedWrongCount;
  final List<String> suggestions;
  final DateTime completedAt;
  final List<JsonMap> items;
  final String? stageId;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey {
    return metadata.cloudId ??
        metadata.localId ??
        'report:$profileId:$sessionId';
  }

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'sessionId': sessionId,
      'mode': mode,
      'poemId': poemId,
      'totalScore': totalScore,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'generatedWrongCount': generatedWrongCount,
      'suggestions': suggestions,
      'completedAt': completedAt.toIso8601String(),
      'items': items,
      'stageId': stageId,
      'metadata': metadata.toJson(),
    };
  }

  factory PracticeReportSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return PracticeReportSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory PracticeReportSyncDto.fromJson(Map<String, dynamic> json) {
    return PracticeReportSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      sessionId: json['sessionId'] as String? ?? '',
      mode: json['mode'] as String? ?? 'dictation',
      poemId: (json['poemId'] as num?)?.toInt() ?? 0,
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      generatedWrongCount: (json['generatedWrongCount'] as num?)?.toInt() ?? 0,
      suggestions: (json['suggestions'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      completedAt: _readDateTime(json['completedAt']) ?? DateTime(1970),
      items: (json['items'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      stageId: json['stageId'] as String?,
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class SettingsSyncDto extends SyncEntityDto {
  const SettingsSyncDto({
    required this.themeMode,
    required this.fontScale,
    required this.speechRate,
    required this.dailyReminderEnabled,
    required this.notificationsEnabled,
    this.showPinyin = true,
    this.autoSyncEnabled = false,
    this.autoSyncCooldownMinutes = 5,
    this.autoSyncAllowMobileNetwork = true,
    this.autoSyncRequireCharging = false,
    required this.reminderHour,
    required this.reminderMinute,
    required this.activeProfileId,
    required this.seedVersion,
    required this.metadata,
  });

  final String themeMode;
  final double fontScale;
  final double speechRate;
  final bool dailyReminderEnabled;
  final bool notificationsEnabled;
  final bool showPinyin;
  final bool autoSyncEnabled;
  final int autoSyncCooldownMinutes;
  final bool autoSyncAllowMobileNetwork;
  final bool autoSyncRequireCharging;
  final int reminderHour;
  final int reminderMinute;
  final int activeProfileId;
  final String seedVersion;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey => metadata.cloudId ?? 'settings:1';

  @override
  JsonMap toJson() {
    return {
      'themeMode': themeMode,
      'fontScale': fontScale,
      'speechRate': speechRate,
      'dailyReminderEnabled': dailyReminderEnabled,
      'notificationsEnabled': notificationsEnabled,
      'showPinyin': showPinyin,
      'autoSyncEnabled': autoSyncEnabled,
      'autoSyncCooldownMinutes': autoSyncCooldownMinutes,
      'autoSyncAllowMobileNetwork': autoSyncAllowMobileNetwork,
      'autoSyncRequireCharging': autoSyncRequireCharging,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'activeProfileId': activeProfileId,
      'seedVersion': seedVersion,
      'metadata': metadata.toJson(),
    };
  }

  factory SettingsSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return SettingsSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory SettingsSyncDto.fromJson(Map<String, dynamic> json) {
    return SettingsSyncDto(
      themeMode: json['themeMode'] as String? ?? 'system',
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1.0,
      dailyReminderEnabled: _readBool(
        json['dailyReminderEnabled'],
        fallback: true,
      ),
      notificationsEnabled: _readBool(
        json['notificationsEnabled'],
        fallback: true,
      ),
      showPinyin: _readBool(json['showPinyin'], fallback: true),
      autoSyncEnabled: _readBool(json['autoSyncEnabled']),
      autoSyncCooldownMinutes:
          (json['autoSyncCooldownMinutes'] as num?)?.toInt() ?? 5,
      autoSyncAllowMobileNetwork: _readBool(
        json['autoSyncAllowMobileNetwork'],
        fallback: true,
      ),
      autoSyncRequireCharging: _readBool(json['autoSyncRequireCharging']),
      reminderHour: (json['reminderHour'] as num?)?.toInt() ?? 20,
      reminderMinute: (json['reminderMinute'] as num?)?.toInt() ?? 0,
      activeProfileId: (json['activeProfileId'] as num?)?.toInt() ?? 1,
      seedVersion: json['seedVersion'] as String? ?? '',
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
}

class UserProfileSyncDto extends SyncEntityDto {
  const UserProfileSyncDto({
    required this.profileId,
    required this.nickname,
    required this.tagline,
    required this.metadata,
    this.avatarSeed,
    this.lastActiveAt,
  });

  final int profileId;
  final String nickname;
  final String tagline;
  final String? avatarSeed;
  final DateTime? lastActiveAt;
  @override
  final SyncRecordMetadataDto metadata;

  @override
  String get recordKey => metadata.cloudId ?? 'profile:$profileId';

  @override
  JsonMap toJson() {
    return {
      'profileId': profileId,
      'nickname': nickname,
      'tagline': tagline,
      'avatarSeed': avatarSeed,
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'metadata': metadata.toJson(),
    };
  }

  factory UserProfileSyncDto.fromDomainRecord(SyncChangeRecord record) {
    return UserProfileSyncDto.fromJson({
      ...record.data,
      'metadata': record.metadata.toJson(),
    });
  }

  factory UserProfileSyncDto.fromJson(Map<String, dynamic> json) {
    return UserProfileSyncDto(
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
      nickname: json['nickname'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      avatarSeed: json['avatarSeed'] as String?,
      lastActiveAt: _readDateTime(json['lastActiveAt']),
      metadata: SyncRecordMetadataDto.fromJson(
        Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      ),
    );
  }
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

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value == 'true' || value == '1';
  }
  return fallback;
}
