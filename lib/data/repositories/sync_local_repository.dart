import 'dart:convert';
import 'dart:io';

import '../../domain/sync/sync_models.dart';
import '../../domain/sync/sync_repository.dart';
import '../local/app_database.dart';
import '../remote/sync_dtos.dart';

class DriftSyncLocalRepository implements SyncLocalRepository {
  DriftSyncLocalRepository({
    required AppDatabase database,
    this.scopeKey = 'default',
  }) : _database = database;

  final AppDatabase _database;
  final String scopeKey;
  SyncEnvelope? _lastAppliedEnvelope;

  SyncEnvelope? get lastAppliedEnvelope => _lastAppliedEnvelope;

  @override
  Future<void> applyRemoteEnvelope(SyncEnvelope envelope) async {
    await _database.transaction(() async {
      for (final collection in envelope.collections) {
        await _applyRemoteCollection(collection);
      }
      await persistCheckpoint(envelope.checkpoint);
    });
    _lastAppliedEnvelope = envelope;
  }

  @override
  Future<void> acknowledgePushedChanges({
    required SyncEnvelope envelope,
    required SyncPushResult result,
  }) async {
    if (result.conflicts.isNotEmpty || result.acceptedCounts.isEmpty) {
      return;
    }
    await _database.transaction(() async {
      for (final collection in envelope.collections) {
        final acceptedCount = result.acceptedCounts[collection.resource] ?? 0;
        if (acceptedCount <= 0) {
          continue;
        }
        for (final record in collection.records.take(acceptedCount)) {
          await _acknowledgePushedRecord(record);
        }
      }
    });
  }

  @override
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
  }) async {
    final createdAt = DateTime.now().toUtc();
    await _database.customStatement('''
      INSERT INTO sync_run_logs (
        state,
        started_at,
        finished_at,
        pushed_count,
        pulled_count,
        conflict_count,
        trigger_source,
        error_message,
        notes,
        created_at
      )
      VALUES (
        ${sqlString(state.name)},
        ${sqlString(startedAt.toUtc().toIso8601String())},
        ${sqlNullable(finishedAt?.toUtc().toIso8601String())},
        $pushedCount,
        $pulledCount,
        $conflictCount,
        ${sqlString(syncRunTriggerToWireName(trigger))},
        ${sqlNullable(errorMessage)},
        ${sqlNullable(jsonEncode(notes))},
        ${sqlString(createdAt.toIso8601String())}
      );
    ''');
  }

  @override
  Future<List<SyncRunLogEntry>> fetchSyncRunLogs({
    int limit = 10,
    int offset = 0,
    SyncRunState? state,
    DateTime? startedAfter,
    DateTime? startedBefore,
  }) async {
    final safeLimit = limit.clamp(1, 200);
    final safeOffset = offset < 0 ? 0 : offset;
    final conditions = <String>[];
    if (state != null) {
      conditions.add('state = ${sqlString(state.name)}');
    }
    if (startedAfter != null) {
      conditions.add(
        'started_at >= ${sqlString(startedAfter.toUtc().toIso8601String())}',
      );
    }
    if (startedBefore != null) {
      conditions.add(
        'started_at < ${sqlString(startedBefore.toUtc().toIso8601String())}',
      );
    }
    final whereClause =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await _database.selectList('''
      SELECT *
      FROM sync_run_logs
      $whereClause
      ORDER BY created_at DESC, id DESC
      LIMIT $safeLimit OFFSET $safeOffset;
    ''');
    return rows
        .map((row) {
          return SyncRunLogEntry(
            id: (row['id'] as int?) ?? 0,
            state: SyncRunState.values.firstWhere(
              (state) => state.name == row['state'],
              orElse: () => SyncRunState.failed,
            ),
            startedAt:
                _readDateTime(row['started_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            finishedAt: _readDateTime(row['finished_at']),
            pushedCount: (row['pushed_count'] as int?) ?? 0,
            pulledCount: (row['pulled_count'] as int?) ?? 0,
            conflictCount: (row['conflict_count'] as int?) ?? 0,
            trigger: syncRunTriggerFromWireName(
              row['trigger_source'] as String?,
            ),
            errorMessage: row['error_message'] as String?,
            notes: _readStringList(row['notes']),
            createdAt:
                _readDateTime(row['created_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> pruneSyncRunLogs({int retain = 100}) async {
    final safeRetain = retain < 0 ? 0 : retain;
    if (safeRetain == 0) {
      await _database.customStatement('DELETE FROM sync_run_logs;');
      return;
    }
    await _database.customStatement('''
      DELETE FROM sync_run_logs
      WHERE id NOT IN (
        SELECT id
        FROM sync_run_logs
        ORDER BY created_at DESC, id DESC
        LIMIT $safeRetain
      );
    ''');
  }

  @override
  Future<void> clearFailedSyncRunLogs() async {
    await _database.customStatement('''
      DELETE FROM sync_run_logs
      WHERE state = ${sqlString(SyncRunState.failed.name)};
    ''');
  }

  Future<void> _applyRemoteCollection(SyncCollectionDelta collection) async {
    switch (collection.resource) {
      case SyncResourceType.poems:
        await _applyRemotePoems(collection.records);
      case SyncResourceType.favorites:
        await _applyRemoteFavorites(collection.records, collection.mergePolicy);
      case SyncResourceType.studyCardProgress:
        await _applyRemoteStudyCardProgress(
          collection.records,
          collection.mergePolicy,
        );
      case SyncResourceType.wrongQuestions:
        await _applyRemoteWrongQuestions(
          collection.records,
          collection.mergePolicy,
        );
      case SyncResourceType.dailyPoemRecords:
        await _applyRemoteDailyPoemRecords(
          collection.records,
          collection.mergePolicy,
        );
      case SyncResourceType.userPoints:
        await _applyRemoteUserPoints(
          collection.records,
          collection.mergePolicy,
        );
      case SyncResourceType.challengeStageRewards:
        await _applyRemoteChallengeStageRewards(collection.records);
      case SyncResourceType.learningRecords:
        await _applyRemoteLearningRecords(collection.records);
      case SyncResourceType.practiceReports:
        await _applyRemotePracticeReports(collection.records);
      case SyncResourceType.settings:
        await _applyRemoteSettings(collection.records, collection.mergePolicy);
      case SyncResourceType.userProfiles:
        await _applyRemoteUserProfiles(
          collection.records,
          collection.mergePolicy,
        );
      case SyncResourceType.reciteRecords:
        await _applyRemoteReciteRecords(collection.records);
    }
  }

  Future<void> _acknowledgePushedRecord(SyncChangeRecord record) async {
    switch (record.resource) {
      case SyncResourceType.poems:
        final dto = PoemSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'poems',
          whereClause: 'id = ${dto.poemId}',
        );
      case SyncResourceType.favorites:
        final dto = FavoriteSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'favorites',
          whereClause:
              'profile_id = ${dto.profileId} AND poem_id = ${dto.poemId}',
        );
      case SyncResourceType.learningRecords:
        await _markLocalRecordSynced(
          table: 'learning_records',
          whereClause: _identityWhereClause(record),
        );
      case SyncResourceType.studyCardProgress:
        final dto = StudyCardProgressSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'study_card_progress',
          whereClause:
              'profile_id = ${dto.profileId} AND poem_id = ${dto.poemId}',
        );
      case SyncResourceType.reciteRecords:
        await _markLocalRecordSynced(
          table: 'recite_records',
          whereClause: _identityWhereClause(record),
        );
      case SyncResourceType.wrongQuestions:
        await _markLocalRecordSynced(
          table: 'wrong_questions',
          whereClause: _identityWhereClause(record),
        );
      case SyncResourceType.practiceReports:
        await _markLocalRecordSynced(
          table: 'practice_reports',
          whereClause: _identityWhereClause(record),
        );
      case SyncResourceType.dailyPoemRecords:
        final dto = DailyPoemRecordSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'daily_poem_records',
          whereClause:
              'profile_id = ${dto.profileId} AND date_key = ${sqlString(dto.dateKey)}',
        );
      case SyncResourceType.userPoints:
        final dto = UserPointsSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'user_points',
          whereClause: 'id = ${dto.profileId}',
        );
      case SyncResourceType.challengeStageRewards:
        final dto = ChallengeStageRewardSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'challenge_stage_rewards',
          whereClause:
              'profile_id = ${dto.profileId} AND stage_id = ${sqlString(dto.stageId)} AND stars = ${dto.stars}',
        );
      case SyncResourceType.settings:
        await _markLocalRecordSynced(table: 'settings', whereClause: 'id = 1');
      case SyncResourceType.userProfiles:
        final dto = UserProfileSyncDto.fromDomainRecord(record);
        await _markLocalRecordSynced(
          table: 'profile_accounts',
          whereClause: 'id = ${dto.profileId}',
        );
    }
  }

  Future<void> _applyRemotePoems(List<SyncChangeRecord> records) async {
    for (final record in records) {
      final dto = PoemSyncDto.fromDomainRecord(record);
      if (dto.poemId <= 0 || dto.title.isEmpty || dto.content.isEmpty) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt =
          dto.metadata.updatedAt ?? dto.metadata.deletedAt ?? createdAt;
      await _database.customStatement('''
        INSERT INTO poems (
          id,
          title,
          author,
          dynasty,
          grade,
          grade_label,
          category,
          content,
          pinyin,
          annotation,
          translation,
          appreciation,
          author_intro,
          extension_text,
          audio_url,
          image_url,
          difficulty,
          seed_version,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at,
          deleted_at
        )
        VALUES (
          ${dto.poemId},
          ${sqlString(dto.title)},
          ${sqlString(dto.author)},
          ${sqlString(dto.dynasty)},
          ${dto.grade},
          ${sqlNullable(dto.gradeLabel)},
          ${sqlNullable(dto.category)},
          ${sqlString(dto.content)},
          ${sqlNullable(dto.pinyin)},
          ${sqlNullable(dto.annotation)},
          ${sqlNullable(dto.translation)},
          ${sqlNullable(dto.appreciation)},
          ${sqlNullable(dto.authorIntro)},
          ${sqlNullable(dto.extensionText)},
          ${sqlNullable(dto.audioUrl)},
          ${sqlNullable(dto.imageUrl)},
          ${dto.difficulty},
          ${sqlNullable(dto.seedVersion)},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())},
          ${sqlNullable(dto.metadata.deletedAt?.toUtc().toIso8601String())}
        )
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          author = excluded.author,
          dynasty = excluded.dynasty,
          grade = excluded.grade,
          grade_label = excluded.grade_label,
          category = excluded.category,
          content = excluded.content,
          pinyin = excluded.pinyin,
          annotation = excluded.annotation,
          translation = excluded.translation,
          appreciation = excluded.appreciation,
          author_intro = excluded.author_intro,
          extension_text = excluded.extension_text,
          audio_url = excluded.audio_url,
          image_url = excluded.image_url,
          difficulty = excluded.difficulty,
          seed_version = excluded.seed_version,
          cloud_id = COALESCE(excluded.cloud_id, poems.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at;
      ''');
    }
  }

  Future<void> _applyRemoteFavorites(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = FavoriteSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.poemId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? dto.favoritedAt ?? now;
      final updatedAt =
          dto.metadata.updatedAt ??
          dto.metadata.deletedAt ??
          dto.favoritedAt ??
          createdAt;
      final deletedAt =
          dto.metadata.deletedAt ?? (dto.isFavorite ? null : updatedAt);
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'favorites',
        whereClause:
            'profile_id = ${dto.profileId} AND poem_id = ${dto.poemId}',
        remoteUpdatedAt: updatedAt,
        remoteDeletedAt: deletedAt,
        mergePolicy: mergePolicy,
        hasDeletedAt: true,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO favorites (
          profile_id,
          poem_id,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at,
          deleted_at
        )
        VALUES (
          ${dto.profileId},
          ${dto.poemId},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())},
          ${sqlNullable(deletedAt?.toUtc().toIso8601String())}
        )
        ON CONFLICT(profile_id, poem_id) DO UPDATE SET
          cloud_id = COALESCE(excluded.cloud_id, favorites.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at;
      ''');
    }
  }

  Future<void> _applyRemoteStudyCardProgress(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = StudyCardProgressSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.poemId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? createdAt;
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'study_card_progress',
        whereClause:
            'profile_id = ${dto.profileId} AND poem_id = ${dto.poemId}',
        remoteUpdatedAt: updatedAt,
        mergePolicy: mergePolicy,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO study_card_progress (
          profile_id,
          poem_id,
          memory_status,
          review_count,
          next_review_at,
          note,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          ${dto.profileId},
          ${dto.poemId},
          ${sqlString(dto.memoryStatus)},
          ${dto.reviewCount},
          ${sqlNullable(dto.nextReviewAt?.toUtc().toIso8601String())},
          ${sqlNullable(dto.note)},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(profile_id, poem_id) DO UPDATE SET
          memory_status = excluded.memory_status,
          review_count = excluded.review_count,
          next_review_at = excluded.next_review_at,
          note = excluded.note,
          cloud_id = COALESCE(excluded.cloud_id, study_card_progress.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
    }
  }

  Future<void> _applyRemoteLearningRecords(
    List<SyncChangeRecord> records,
  ) async {
    for (final record in records) {
      final dto = LearningRecordSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.poemId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? createdAt;
      final sessionId = dto.sessionId ?? dto.metadata.clientMutationId;
      final existingId = await _findExistingLearningRecordId(dto, sessionId);
      if (existingId == null) {
        await _database.customStatement('''
          INSERT INTO learning_records (
            profile_id,
            poem_id,
            mode,
            duration_minutes,
            score,
            note,
            stage_id,
            cloud_id,
            revision_token,
            client_mutation_id,
            last_actor_device_id,
            sync_status,
            created_at,
            updated_at
          )
          VALUES (
            ${dto.profileId},
            ${dto.poemId},
            ${sqlString(dto.mode)},
            ${dto.durationMinutes},
            ${dto.score ?? 'NULL'},
            ${sqlNullable(dto.note)},
            ${sqlNullable(dto.stageId)},
            ${sqlNullable(dto.metadata.cloudId)},
            ${sqlNullable(dto.metadata.revisionToken)},
            ${sqlNullable(sessionId)},
            ${sqlNullable(dto.metadata.lastActorDeviceId)},
            'local',
            ${sqlString(createdAt.toUtc().toIso8601String())},
            ${sqlString(updatedAt.toUtc().toIso8601String())}
          );
        ''');
      } else {
        await _database.customStatement('''
          UPDATE learning_records
          SET
            profile_id = ${dto.profileId},
            poem_id = ${dto.poemId},
            mode = ${sqlString(dto.mode)},
            duration_minutes = ${dto.durationMinutes},
            score = ${dto.score ?? 'NULL'},
            note = ${sqlNullable(dto.note)},
            stage_id = ${sqlNullable(dto.stageId)},
            cloud_id = COALESCE(${sqlNullable(dto.metadata.cloudId)}, cloud_id),
            revision_token = ${sqlNullable(dto.metadata.revisionToken)},
            client_mutation_id = ${sqlNullable(sessionId)},
            last_actor_device_id = ${sqlNullable(dto.metadata.lastActorDeviceId)},
            sync_status = 'local',
            updated_at = ${sqlString(updatedAt.toUtc().toIso8601String())}
          WHERE id = $existingId;
        ''');
      }
    }
  }

  Future<void> _applyRemoteReciteRecords(List<SyncChangeRecord> records) async {
    for (final record in records) {
      final dto = ReciteRecordSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.poemId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? createdAt;
      final existingId = await _findExistingReciteRecordId(dto);
      if (existingId == null) {
        await _database.customStatement('''
          INSERT INTO recite_records (
            profile_id,
            poem_id,
            score,
            recognized_text,
            cloud_id,
            revision_token,
            client_mutation_id,
            last_actor_device_id,
            sync_status,
            created_at,
            updated_at
          )
          VALUES (
            ${dto.profileId},
            ${dto.poemId},
            ${dto.score ?? 'NULL'},
            ${sqlNullable(dto.recognizedText)},
            ${sqlNullable(dto.metadata.cloudId)},
            ${sqlNullable(dto.metadata.revisionToken)},
            ${sqlNullable(dto.metadata.clientMutationId)},
            ${sqlNullable(dto.metadata.lastActorDeviceId)},
            'local',
            ${sqlString(createdAt.toUtc().toIso8601String())},
            ${sqlString(updatedAt.toUtc().toIso8601String())}
          );
        ''');
      } else {
        await _database.customStatement('''
          UPDATE recite_records
          SET
            profile_id = ${dto.profileId},
            poem_id = ${dto.poemId},
            score = ${dto.score ?? 'NULL'},
            recognized_text = ${sqlNullable(dto.recognizedText)},
            cloud_id = COALESCE(${sqlNullable(dto.metadata.cloudId)}, cloud_id),
            revision_token = ${sqlNullable(dto.metadata.revisionToken)},
            client_mutation_id = ${sqlNullable(dto.metadata.clientMutationId)},
            last_actor_device_id = ${sqlNullable(dto.metadata.lastActorDeviceId)},
            sync_status = 'local',
            updated_at = ${sqlString(updatedAt.toUtc().toIso8601String())}
          WHERE id = $existingId;
        ''');
      }
    }
  }

  Future<void> _applyRemoteDailyPoemRecords(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = DailyPoemRecordSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.dateKey.isEmpty || dto.poemId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? dto.completedAt ?? createdAt;
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'daily_poem_records',
        whereClause:
            'profile_id = ${dto.profileId} AND date_key = ${sqlString(dto.dateKey)}',
        remoteUpdatedAt: updatedAt,
        mergePolicy: mergePolicy,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO daily_poem_records (
          profile_id,
          date_key,
          poem_id,
          is_completed,
          completed_at,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          ${dto.profileId},
          ${sqlString(dto.dateKey)},
          ${dto.poemId},
          ${dto.isCompleted ? 1 : 0},
          ${sqlNullable(dto.completedAt?.toUtc().toIso8601String())},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(profile_id, date_key) DO UPDATE SET
          poem_id = excluded.poem_id,
          is_completed = excluded.is_completed,
          completed_at = excluded.completed_at,
          cloud_id = COALESCE(excluded.cloud_id, daily_poem_records.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
    }
  }

  Future<void> _applyRemoteWrongQuestions(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = WrongQuestionSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.poemId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? dto.reviewedAt ?? createdAt;
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'wrong_questions',
        whereClause:
            'profile_id = ${dto.profileId} AND poem_id = ${dto.poemId} '
            'AND question_type ${_nullableSqlEquals(dto.questionType)} '
            'AND prompt ${_nullableSqlEquals(dto.prompt)} '
            'AND correct_answer ${_nullableSqlEquals(dto.correctAnswer)}',
        remoteUpdatedAt: updatedAt,
        mergePolicy: mergePolicy,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO wrong_questions (
          profile_id,
          poem_id,
          question_type,
          prompt,
          correct_answer,
          user_answer,
          rule_tag,
          severity,
          stage_id,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at,
          reviewed_at
        )
        VALUES (
          ${dto.profileId},
          ${dto.poemId},
          ${sqlNullable(dto.questionType)},
          ${sqlNullable(dto.prompt)},
          ${sqlNullable(dto.correctAnswer)},
          ${sqlNullable(dto.userAnswer)},
          ${sqlNullable(dto.ruleTag)},
          ${sqlString(dto.severity)},
          ${sqlNullable(dto.stageId)},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())},
          ${sqlNullable(dto.reviewedAt?.toUtc().toIso8601String())}
        )
        ON CONFLICT(profile_id, poem_id, question_type, prompt, correct_answer) DO UPDATE SET
          user_answer = excluded.user_answer,
          rule_tag = excluded.rule_tag,
          severity = excluded.severity,
          stage_id = excluded.stage_id,
          cloud_id = COALESCE(excluded.cloud_id, wrong_questions.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at,
          reviewed_at = excluded.reviewed_at;
      ''');
    }
  }

  Future<void> _applyRemotePracticeReports(
    List<SyncChangeRecord> records,
  ) async {
    for (final record in records) {
      final dto = PracticeReportSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.poemId <= 0 || dto.sessionId.isEmpty) {
        continue;
      }
      final createdAt = dto.metadata.createdAt ?? dto.completedAt;
      final updatedAt = dto.metadata.updatedAt ?? dto.completedAt;
      await _database.customStatement('''
        INSERT INTO practice_reports (
          profile_id,
          session_id,
          mode,
          poem_id,
          total_score,
          correct_count,
          total_questions,
          generated_wrong_count,
          suggestions_json,
          stage_id,
          completed_at,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          ${dto.profileId},
          ${sqlString(dto.sessionId)},
          ${sqlString(dto.mode)},
          ${dto.poemId},
          ${dto.totalScore},
          ${dto.correctCount},
          ${dto.totalQuestions},
          ${dto.generatedWrongCount},
          ${sqlString(jsonEncode(dto.suggestions))},
          ${sqlNullable(dto.stageId)},
          ${sqlString(dto.completedAt.toUtc().toIso8601String())},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(profile_id, session_id) DO UPDATE SET
          mode = excluded.mode,
          poem_id = excluded.poem_id,
          total_score = excluded.total_score,
          correct_count = excluded.correct_count,
          total_questions = excluded.total_questions,
          generated_wrong_count = excluded.generated_wrong_count,
          suggestions_json = excluded.suggestions_json,
          stage_id = excluded.stage_id,
          completed_at = excluded.completed_at,
          cloud_id = COALESCE(excluded.cloud_id, practice_reports.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
      final reportRow = await _database.selectSingle('''
        SELECT id
        FROM practice_reports
        WHERE profile_id = ${dto.profileId}
          AND session_id = ${sqlString(dto.sessionId)}
        LIMIT 1;
      ''');
      final reportId = reportRow?['id'] as int?;
      if (reportId == null) {
        continue;
      }
      await _database.customStatement(
        'DELETE FROM practice_report_items WHERE report_id = $reportId;',
      );
      for (var i = 0; i < dto.items.length; i += 1) {
        final item = dto.items[i];
        final lineIndex = (item['lineIndex'] as num?)?.toInt() ?? i;
        final score = (item['score'] as num?)?.toInt() ?? 0;
        await _database.customStatement('''
          INSERT INTO practice_report_items (
            report_id,
            line_index,
            prompt,
            hint,
            expected_answer,
            user_answer,
            is_correct,
            score,
            feedback,
            mistake_type,
            assessment_engine,
            assessment_confidence,
            assessment_accuracy,
            assessment_fluency,
            assessment_integrity,
            assessment_basis,
            assessment_audio_path,
            assessment_payload_json
          )
          VALUES (
            $reportId,
            $lineIndex,
            ${sqlString(item['prompt']?.toString() ?? '')},
            ${sqlNullable(item['hint']?.toString())},
            ${sqlString(item['expectedAnswer']?.toString() ?? '')},
            ${sqlString(item['userAnswer']?.toString() ?? '')},
            ${_readBoolValue(item['isCorrect']) ? 1 : 0},
            $score,
            ${sqlString(item['feedback']?.toString() ?? '')},
            ${sqlNullable(item['mistakeType']?.toString())},
            ${sqlNullable(item['assessmentEngine']?.toString())},
            ${(item['assessmentConfidence'] as num?)?.toDouble() ?? 'NULL'},
            ${(item['assessmentAccuracy'] as num?)?.toInt() ?? 'NULL'},
            ${(item['assessmentFluency'] as num?)?.toInt() ?? 'NULL'},
            ${(item['assessmentIntegrity'] as num?)?.toInt() ?? 'NULL'},
            ${sqlNullable(item['assessmentBasis']?.toString())},
            ${sqlNullable(item['assessmentAudioPath']?.toString())},
            ${sqlNullable(_jsonPayloadOrNull(item['assessmentPayload']))}
          );
        ''');
      }
    }
  }

  Future<void> _applyRemoteUserPoints(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = UserPointsSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? createdAt;
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'user_points',
        whereClause: 'id = ${dto.profileId}',
        remoteUpdatedAt: updatedAt,
        mergePolicy: mergePolicy,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO user_points (
          id,
          total_points,
          current_points,
          total_check_ins,
          consecutive_days,
          last_check_in_date,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          ${dto.profileId},
          ${dto.totalPoints},
          ${dto.currentPoints},
          ${dto.totalCheckIns},
          ${dto.consecutiveDays},
          ${sqlNullable(dto.lastCheckInDate)},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(id) DO UPDATE SET
          total_points = excluded.total_points,
          current_points = excluded.current_points,
          total_check_ins = excluded.total_check_ins,
          consecutive_days = excluded.consecutive_days,
          last_check_in_date = excluded.last_check_in_date,
          cloud_id = COALESCE(excluded.cloud_id, user_points.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
    }
  }

  Future<void> _applyRemoteChallengeStageRewards(
    List<SyncChangeRecord> records,
  ) async {
    for (final record in records) {
      final dto = ChallengeStageRewardSyncDto.fromDomainRecord(record);
      if (dto.stageId.isEmpty || dto.stars <= 0) {
        continue;
      }
      final createdAt = dto.metadata.createdAt ?? dto.claimedAt;
      final updatedAt = dto.metadata.updatedAt ?? dto.claimedAt;
      await _database.customStatement('''
        INSERT INTO challenge_stage_rewards (
          profile_id,
          stage_id,
          stars,
          claimed_at,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          ${dto.profileId},
          ${sqlString(dto.stageId)},
          ${dto.stars},
          ${sqlString(dto.claimedAt.toUtc().toIso8601String())},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(profile_id, stage_id, stars) DO UPDATE SET
          claimed_at = excluded.claimed_at,
          cloud_id = COALESCE(excluded.cloud_id, challenge_stage_rewards.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
    }
  }

  Future<void> _applyRemoteSettings(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = SettingsSyncDto.fromDomainRecord(record);
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? createdAt;
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'settings',
        whereClause: 'id = 1',
        remoteUpdatedAt: updatedAt,
        mergePolicy: mergePolicy,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO settings (
          id,
          theme_mode,
          font_scale,
          speech_rate,
          daily_reminder_enabled,
          notifications_enabled,
          show_pinyin,
          auto_sync_enabled,
          auto_sync_cooldown_minutes,
          auto_sync_allow_mobile_network,
          auto_sync_require_charging,
          reminder_hour,
          reminder_minute,
          active_profile_id,
          seed_version,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          1,
          ${sqlString(dto.themeMode)},
          ${dto.fontScale},
          ${dto.speechRate},
          ${dto.dailyReminderEnabled ? 1 : 0},
          ${dto.notificationsEnabled ? 1 : 0},
          ${dto.showPinyin ? 1 : 0},
          ${dto.autoSyncEnabled ? 1 : 0},
          ${dto.autoSyncCooldownMinutes},
          ${dto.autoSyncAllowMobileNetwork ? 1 : 0},
          ${dto.autoSyncRequireCharging ? 1 : 0},
          ${dto.reminderHour},
          ${dto.reminderMinute},
          ${dto.activeProfileId},
          ${sqlNullable(dto.seedVersion)},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(id) DO UPDATE SET
          theme_mode = excluded.theme_mode,
          font_scale = excluded.font_scale,
          speech_rate = excluded.speech_rate,
          daily_reminder_enabled = excluded.daily_reminder_enabled,
          notifications_enabled = excluded.notifications_enabled,
          show_pinyin = excluded.show_pinyin,
          auto_sync_enabled = excluded.auto_sync_enabled,
          auto_sync_cooldown_minutes = excluded.auto_sync_cooldown_minutes,
          auto_sync_allow_mobile_network = excluded.auto_sync_allow_mobile_network,
          auto_sync_require_charging = excluded.auto_sync_require_charging,
          reminder_hour = excluded.reminder_hour,
          reminder_minute = excluded.reminder_minute,
          active_profile_id = excluded.active_profile_id,
          seed_version = excluded.seed_version,
          cloud_id = COALESCE(excluded.cloud_id, settings.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
    }
  }

  Future<void> _applyRemoteUserProfiles(
    List<SyncChangeRecord> records,
    SyncMergePolicy mergePolicy,
  ) async {
    for (final record in records) {
      final dto = UserProfileSyncDto.fromDomainRecord(record);
      if (dto.profileId <= 0 || dto.nickname.trim().isEmpty) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final createdAt = dto.metadata.createdAt ?? dto.lastActiveAt ?? now;
      final updatedAt = dto.metadata.updatedAt ?? dto.lastActiveAt ?? createdAt;
      final remoteWins = await _remoteWinsAgainstPendingLocal(
        table: 'profile_accounts',
        whereClause: 'id = ${dto.profileId}',
        remoteUpdatedAt: updatedAt,
        mergePolicy: mergePolicy,
      );
      if (!remoteWins) {
        continue;
      }
      await _database.customStatement('''
        INSERT INTO profile_accounts (
          id,
          nickname,
          tagline,
          avatar_seed,
          last_active_at,
          cloud_id,
          revision_token,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          ${dto.profileId},
          ${sqlString(dto.nickname)},
          ${sqlNullable(dto.tagline)},
          ${sqlNullable(dto.avatarSeed)},
          ${sqlNullable(dto.lastActiveAt?.toUtc().toIso8601String())},
          ${sqlNullable(dto.metadata.cloudId)},
          ${sqlNullable(dto.metadata.revisionToken)},
          ${sqlNullable(dto.metadata.clientMutationId)},
          ${sqlNullable(dto.metadata.lastActorDeviceId)},
          'local',
          ${sqlString(createdAt.toUtc().toIso8601String())},
          ${sqlString(updatedAt.toUtc().toIso8601String())}
        )
        ON CONFLICT(id) DO UPDATE SET
          nickname = excluded.nickname,
          tagline = excluded.tagline,
          avatar_seed = excluded.avatar_seed,
          last_active_at = excluded.last_active_at,
          cloud_id = COALESCE(excluded.cloud_id, profile_accounts.cloud_id),
          revision_token = excluded.revision_token,
          client_mutation_id = excluded.client_mutation_id,
          last_actor_device_id = excluded.last_actor_device_id,
          sync_status = 'local',
          updated_at = excluded.updated_at;
      ''');
    }
  }

  Future<int?> _findExistingLearningRecordId(
    LearningRecordSyncDto dto,
    String? sessionId,
  ) async {
    if (dto.metadata.cloudId != null && dto.metadata.cloudId!.isNotEmpty) {
      final row = await _database.selectSingle('''
        SELECT id
        FROM learning_records
        WHERE cloud_id = ${sqlString(dto.metadata.cloudId!)}
        LIMIT 1;
      ''');
      final id = row?['id'] as int?;
      if (id != null) {
        return id;
      }
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      final row = await _database.selectSingle('''
        SELECT id
        FROM learning_records
        WHERE profile_id = ${dto.profileId}
          AND client_mutation_id = ${sqlString(sessionId)}
        LIMIT 1;
      ''');
      return row?['id'] as int?;
    }
    return null;
  }

  Future<int?> _findExistingReciteRecordId(ReciteRecordSyncDto dto) async {
    if (dto.metadata.cloudId != null && dto.metadata.cloudId!.isNotEmpty) {
      final row = await _database.selectSingle('''
        SELECT id
        FROM recite_records
        WHERE cloud_id = ${sqlString(dto.metadata.cloudId!)}
        LIMIT 1;
      ''');
      final id = row?['id'] as int?;
      if (id != null) {
        return id;
      }
    }
    final mutationId = dto.metadata.clientMutationId;
    if (mutationId != null && mutationId.isNotEmpty) {
      final row = await _database.selectSingle('''
        SELECT id
        FROM recite_records
        WHERE profile_id = ${dto.profileId}
          AND client_mutation_id = ${sqlString(mutationId)}
        LIMIT 1;
      ''');
      return row?['id'] as int?;
    }
    return null;
  }

  Future<bool> _remoteWinsAgainstPendingLocal({
    required String table,
    required String whereClause,
    required DateTime remoteUpdatedAt,
    required SyncMergePolicy mergePolicy,
    DateTime? remoteDeletedAt,
    bool hasDeletedAt = false,
  }) async {
    final deletedAtSelect = hasDeletedAt ? ', deleted_at' : '';
    final row = await _database.selectSingle('''
      SELECT sync_status, updated_at$deletedAtSelect
      FROM $table
      WHERE $whereClause
      LIMIT 1;
    ''');
    if (row == null || row['sync_status'] != 'pending_push') {
      return true;
    }

    return switch (mergePolicy) {
      SyncMergePolicy.serverAuthoritative ||
      SyncMergePolicy.serverMergeSuggested ||
      SyncMergePolicy.appendOnly => true,
      SyncMergePolicy.lastWriteWins => _remoteIsAtLeastAsNew(
        row['updated_at'],
        remoteUpdatedAt,
      ),
      SyncMergePolicy.softDelete => _remoteSoftDeleteWins(
        row: row,
        remoteUpdatedAt: remoteUpdatedAt,
        remoteDeletedAt: remoteDeletedAt,
      ),
    };
  }

  Future<void> _markLocalRecordSynced({
    required String table,
    required String whereClause,
  }) async {
    if (whereClause.trim().isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.customStatement('''
      UPDATE $table
      SET sync_status = 'local',
          updated_at = ${sqlString(now)}
      WHERE sync_status = 'pending_push'
        AND $whereClause;
    ''');
  }

  String _identityWhereClause(SyncChangeRecord record) {
    final metadata = record.metadata;
    if (metadata.localId != null && metadata.localId!.isNotEmpty) {
      final localId = int.tryParse(metadata.localId!);
      if (localId != null) {
        return 'id = $localId';
      }
    }
    if (metadata.cloudId != null && metadata.cloudId!.isNotEmpty) {
      return 'cloud_id = ${sqlString(metadata.cloudId!)}';
    }
    if (metadata.clientMutationId != null &&
        metadata.clientMutationId!.isNotEmpty) {
      return 'client_mutation_id = ${sqlString(metadata.clientMutationId!)}';
    }
    return '1 = 0';
  }

  @override
  Future<SyncEnvelope> collectPendingChanges({
    SyncRunOptions options = const SyncRunOptions(),
  }) async {
    final checkpoint = await loadCheckpoint();
    final collections = <SyncCollectionDelta>[];

    for (final policy in defaultSyncResourcePolicies) {
      final resource = policy.resource;
      if (!options.includes(resource)) {
        continue;
      }
      if (resource == SyncResourceType.poems &&
          !options.includePoemCatalog &&
          !options.scope.contains(SyncResourceType.poems)) {
        continue;
      }

      final records = await _collectResourceRecords(
        resource: resource,
        options: options,
      );
      if (records.isEmpty && !options.fullResync) {
        continue;
      }

      collections.add(
        SyncCollectionDelta(
          resource: resource,
          mergePolicy: policy.defaultMergePolicy,
          records: records,
          nextCursor: checkpoint.cursorFor(resource),
          resetCollection: options.fullResync && policy.softDeleteEnabled,
        ),
      );
    }

    if (collections.isEmpty) {
      return SyncEnvelope.empty(
        device: _deviceInfo,
        checkpoint: checkpoint,
        requestId: _requestId('empty'),
      );
    }

    return SyncEnvelope(
      requestId: _requestId('push'),
      device: _deviceInfo,
      checkpoint: checkpoint,
      collections: collections,
      generatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<SyncCheckpoint> loadCheckpoint() async {
    final row = await _database.loadSyncCheckpoint(scopeKey);
    if (row == null) {
      return const SyncCheckpoint(schemaVersion: 2);
    }

    final resourceCursors = <SyncResourceType, String>{};
    final rawJson = row['resource_cursors_json'] as String? ?? '{}';
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        resourceCursors[syncResourceTypeFromWireName(entry.key)] =
            entry.value.toString();
      }
    } else if (decoded is Map) {
      for (final entry in decoded.entries) {
        resourceCursors[syncResourceTypeFromWireName(entry.key.toString())] =
            entry.value.toString();
      }
    }

    return SyncCheckpoint(
      globalCursor: row['global_cursor'] as String?,
      collectionCursors: resourceCursors,
      lastSuccessfulSyncAt: _readDateTime(row['last_successful_sync_at']),
      schemaVersion: (row['schema_version'] as int?) ?? 2,
    );
  }

  @override
  Future<Map<SyncResourceType, int>> pendingCounts() async {
    return {
      SyncResourceType.poems: await _countPending('poems'),
      SyncResourceType.favorites: await _countPending('favorites'),
      SyncResourceType.learningRecords: await _countPending('learning_records'),
      SyncResourceType.studyCardProgress: await _countPending(
        'study_card_progress',
      ),
      SyncResourceType.reciteRecords: await _countPending('recite_records'),
      SyncResourceType.wrongQuestions: await _countPending('wrong_questions'),
      SyncResourceType.practiceReports: await _countPending('practice_reports'),
      SyncResourceType.dailyPoemRecords: await _countPending(
        'daily_poem_records',
      ),
      SyncResourceType.userPoints: await _countPending('user_points'),
      SyncResourceType.challengeStageRewards: await _countPending(
        'challenge_stage_rewards',
      ),
      SyncResourceType.settings: await _countPending('settings'),
      SyncResourceType.userProfiles: await _countPending('profile_accounts'),
    };
  }

  @override
  Future<void> persistCheckpoint(SyncCheckpoint checkpoint) {
    final resourceCursors = {
      for (final entry in checkpoint.collectionCursors.entries)
        syncResourceTypeToWireName(entry.key): entry.value,
    };

    return _database.saveSyncCheckpoint(
      scopeKey: scopeKey,
      globalCursor: checkpoint.globalCursor,
      resourceCursors: resourceCursors,
      lastSuccessfulSyncAt: checkpoint.lastSuccessfulSyncAt,
      schemaVersion: checkpoint.schemaVersion,
    );
  }

  Future<int> _countPending(String table) async {
    final row = await _database.selectSingle('''
      SELECT COUNT(*) AS count
      FROM $table
      WHERE ${_pendingWhereClause()};
    ''');
    return (row?['count'] as int?) ?? 0;
  }

  Future<List<SyncChangeRecord>> _collectResourceRecords({
    required SyncResourceType resource,
    required SyncRunOptions options,
  }) async {
    return switch (resource) {
      SyncResourceType.poems => _collectPoemRecords(
        includeAll: options.fullResync,
      ),
      SyncResourceType.favorites => _collectFavoriteRecords(),
      SyncResourceType.learningRecords => _collectLearningRecords(),
      SyncResourceType.studyCardProgress => _collectStudyCardProgressRecords(),
      SyncResourceType.reciteRecords => _collectReciteRecords(),
      SyncResourceType.wrongQuestions => _collectWrongQuestionRecords(),
      SyncResourceType.practiceReports => _collectPracticeReportRecords(),
      SyncResourceType.dailyPoemRecords => _collectDailyPoemRecords(),
      SyncResourceType.userPoints => _collectUserPointsRecords(),
      SyncResourceType.challengeStageRewards =>
        _collectChallengeStageRewardRecords(),
      SyncResourceType.settings => _collectSettingsRecords(),
      SyncResourceType.userProfiles => _collectUserProfileRecords(),
    };
  }

  Future<List<SyncChangeRecord>> _collectPoemRecords({
    required bool includeAll,
  }) async {
    final rows = await _database.selectList('''
      SELECT *
      FROM poems
      WHERE ${includeAll ? 'deleted_at IS NULL' : _pendingWhereClause()}
      ORDER BY id ASC;
    ''');

    return rows
        .map(
          (row) => PoemSyncDto(
            poemId: (row['id'] as int?) ?? 0,
            title: row['title'] as String? ?? '',
            author: row['author'] as String? ?? '',
            dynasty: row['dynasty'] as String? ?? '',
            grade: (row['grade'] as int?) ?? 0,
            gradeLabel: row['grade_label'] as String? ?? '',
            category: row['category'] as String? ?? '',
            content: row['content'] as String? ?? '',
            pinyin: row['pinyin'] as String? ?? '',
            annotation: row['annotation'] as String? ?? '',
            translation: row['translation'] as String? ?? '',
            appreciation: row['appreciation'] as String? ?? '',
            authorIntro: row['author_intro'] as String? ?? '',
            extensionText: row['extension_text'] as String? ?? '',
            audioUrl: row['audio_url'] as String?,
            imageUrl: row['image_url'] as String?,
            difficulty: (row['difficulty'] as int?) ?? 1,
            seedVersion: row['seed_version'] as String? ?? '',
            metadata: _metadataFromRow(
              row,
              localId: ((row['id'] as int?) ?? 0).toString(),
            ),
          ).toDomain(SyncResourceType.poems),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectFavoriteRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM favorites
      WHERE ${_pendingWhereClause()}
      ORDER BY updated_at DESC;
    ''');

    return rows
        .map(
          (row) => FavoriteSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            poemId: (row['poem_id'] as int?) ?? 0,
            isFavorite: row['deleted_at'] == null,
            favoritedAt: _readDateTime(row['created_at']),
            source: 'local-first',
            metadata: _metadataFromRow(
              row,
              localId:
                  ((row['id'] as int?) ?? (row['poem_id'] as int?) ?? 0)
                      .toString(),
            ),
          ).toDomain(SyncResourceType.favorites),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectLearningRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM learning_records
      WHERE ${_pendingWhereClause()}
      ORDER BY created_at ASC;
    ''');

    return rows
        .map(
          (row) => LearningRecordSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            poemId: (row['poem_id'] as int?) ?? 0,
            mode: row['mode'] as String? ?? 'review',
            durationMinutes: (row['duration_minutes'] as int?) ?? 0,
            score: row['score'] as int?,
            note: row['note'] as String?,
            sessionId: row['client_mutation_id'] as String?,
            stageId: row['stage_id'] as String?,
            metadata: _metadataFromRow(
              row,
              localId: ((row['id'] as int?) ?? 0).toString(),
            ),
          ).toDomain(SyncResourceType.learningRecords),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectReciteRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM recite_records
      WHERE ${_pendingWhereClause()}
      ORDER BY created_at ASC;
    ''');

    return rows
        .map(
          (row) => ReciteRecordSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            poemId: (row['poem_id'] as int?) ?? 0,
            score: row['score'] as int?,
            recognizedText: row['recognized_text'] as String?,
            transcriptVersion: 'v1',
            metadata: _metadataFromRow(
              row,
              localId: ((row['id'] as int?) ?? 0).toString(),
            ),
          ).toDomain(SyncResourceType.reciteRecords),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectStudyCardProgressRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM study_card_progress
      WHERE ${_pendingWhereClause()}
      ORDER BY updated_at ASC;
    ''');

    return rows
        .map(
          (row) => StudyCardProgressSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            poemId: (row['poem_id'] as int?) ?? 0,
            memoryStatus: row['memory_status'] as String? ?? 'new',
            reviewCount: (row['review_count'] as int?) ?? 0,
            nextReviewAt: _readDateTime(row['next_review_at']),
            note: row['note'] as String?,
            metadata: _metadataFromRow(
              row,
              localId:
                  '${(row['profile_id'] as int?) ?? 1}:${(row['poem_id'] as int?) ?? 0}',
            ),
          ).toDomain(SyncResourceType.studyCardProgress),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectWrongQuestionRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM wrong_questions
      WHERE ${_pendingWhereClause()}
      ORDER BY created_at ASC;
    ''');

    return rows
        .map(
          (row) => WrongQuestionSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            poemId: (row['poem_id'] as int?) ?? 0,
            questionType: row['question_type'] as String?,
            prompt: row['prompt'] as String?,
            correctAnswer: row['correct_answer'] as String?,
            userAnswer: row['user_answer'] as String?,
            ruleTag: row['rule_tag'] as String?,
            stageId: row['stage_id'] as String?,
            severity: row['severity'] as String? ?? 'medium',
            reviewedAt: _readDateTime(row['reviewed_at']),
            isResolved: row['reviewed_at'] != null,
            metadata: _metadataFromRow(
              row,
              localId: ((row['id'] as int?) ?? 0).toString(),
            ),
          ).toDomain(SyncResourceType.wrongQuestions),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectPracticeReportRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM practice_reports
      WHERE ${_pendingWhereClause()}
      ORDER BY completed_at ASC, id ASC;
    ''');
    final records = <SyncChangeRecord>[];

    for (final row in rows) {
      final reportId = (row['id'] as int?) ?? 0;
      final itemRows = await _database.selectList('''
        SELECT
          line_index AS lineIndex,
          prompt,
          hint,
          expected_answer AS expectedAnswer,
          user_answer AS userAnswer,
          is_correct AS isCorrect,
          score,
          feedback,
          mistake_type AS mistakeType
        FROM practice_report_items
        WHERE report_id = $reportId
        ORDER BY line_index ASC, id ASC;
      ''');
      records.add(
        PracticeReportSyncDto(
          profileId: (row['profile_id'] as int?) ?? 1,
          sessionId: row['session_id'] as String? ?? '',
          mode: row['mode'] as String? ?? 'dictation',
          poemId: (row['poem_id'] as int?) ?? 0,
          totalScore: (row['total_score'] as int?) ?? 0,
          correctCount: (row['correct_count'] as int?) ?? 0,
          totalQuestions: (row['total_questions'] as int?) ?? 0,
          generatedWrongCount: (row['generated_wrong_count'] as int?) ?? 0,
          suggestions: _readStringList(row['suggestions_json']),
          stageId: row['stage_id'] as String?,
          completedAt:
              _readDateTime(row['completed_at']) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          items: itemRows
              .map(
                (item) => {
                  ...item,
                  'isCorrect': ((item['isCorrect'] as int?) ?? 0) == 1,
                },
              )
              .toList(growable: false),
          metadata: _metadataFromRow(row, localId: reportId.toString()),
        ).toDomain(SyncResourceType.practiceReports),
      );
    }

    return records;
  }

  Future<List<SyncChangeRecord>> _collectDailyPoemRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM daily_poem_records
      WHERE ${_pendingWhereClause()}
      ORDER BY date_key ASC;
    ''');

    return rows
        .map(
          (row) => DailyPoemRecordSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            dateKey: row['date_key'] as String? ?? '',
            poemId: (row['poem_id'] as int?) ?? 0,
            isCompleted: ((row['is_completed'] as int?) ?? 0) == 1,
            completedAt: _readDateTime(row['completed_at']),
            metadata: _metadataFromRow(
              row,
              localId:
                  '${(row['profile_id'] as int?) ?? 1}:${row['date_key'] as String? ?? ''}',
              encryptedField: false,
            ),
          ).toDomain(SyncResourceType.dailyPoemRecords),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectSettingsRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM settings
      WHERE ${_pendingWhereClause()}
      LIMIT 1;
    ''');

    return rows
        .map(
          (row) => SettingsSyncDto(
            themeMode: row['theme_mode'] as String? ?? 'system',
            fontScale: (row['font_scale'] as num?)?.toDouble() ?? 1.0,
            speechRate: (row['speech_rate'] as num?)?.toDouble() ?? 1.0,
            dailyReminderEnabled:
                ((row['daily_reminder_enabled'] as int?) ?? 1) == 1,
            notificationsEnabled:
                ((row['notifications_enabled'] as int?) ?? 1) == 1,
            showPinyin: ((row['show_pinyin'] as int?) ?? 1) == 1,
            autoSyncEnabled: ((row['auto_sync_enabled'] as int?) ?? 0) == 1,
            autoSyncCooldownMinutes:
                (row['auto_sync_cooldown_minutes'] as int?) ?? 5,
            autoSyncAllowMobileNetwork:
                ((row['auto_sync_allow_mobile_network'] as int?) ?? 1) == 1,
            autoSyncRequireCharging:
                ((row['auto_sync_require_charging'] as int?) ?? 0) == 1,
            reminderHour: (row['reminder_hour'] as int?) ?? 20,
            reminderMinute: (row['reminder_minute'] as int?) ?? 0,
            activeProfileId: (row['active_profile_id'] as int?) ?? 1,
            seedVersion: row['seed_version'] as String? ?? '',
            metadata: _metadataFromRow(
              row,
              localId: '1',
              encryptedField: false,
            ),
          ).toDomain(SyncResourceType.settings),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectUserPointsRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM user_points
      WHERE ${_pendingWhereClause()}
      ORDER BY updated_at ASC;
    ''');

    return rows
        .map(
          (row) => UserPointsSyncDto(
            profileId: (row['id'] as int?) ?? 1,
            totalPoints: (row['total_points'] as int?) ?? 0,
            currentPoints: (row['current_points'] as int?) ?? 0,
            totalCheckIns: (row['total_check_ins'] as int?) ?? 0,
            consecutiveDays: (row['consecutive_days'] as int?) ?? 0,
            lastCheckInDate: row['last_check_in_date'] as String?,
            metadata: _metadataFromRow(
              row,
              localId: ((row['id'] as int?) ?? 1).toString(),
              encryptedField: false,
            ),
          ).toDomain(SyncResourceType.userPoints),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectChallengeStageRewardRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM challenge_stage_rewards
      WHERE ${_pendingWhereClause()}
      ORDER BY claimed_at ASC, id ASC;
    ''');

    return rows
        .map(
          (row) => ChallengeStageRewardSyncDto(
            profileId: (row['profile_id'] as int?) ?? 1,
            stageId: row['stage_id'] as String? ?? '',
            stars: (row['stars'] as int?) ?? 0,
            claimedAt:
                _readDateTime(row['claimed_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            metadata: _metadataFromRow(
              row,
              localId:
                  '${(row['profile_id'] as int?) ?? 1}:${row['stage_id'] as String? ?? ''}:${(row['stars'] as int?) ?? 0}',
              encryptedField: false,
            ),
          ).toDomain(SyncResourceType.challengeStageRewards),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeRecord>> _collectUserProfileRecords() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM profile_accounts
      WHERE ${_pendingWhereClause()}
      ORDER BY updated_at ASC;
    ''');

    return rows
        .map(
          (row) => UserProfileSyncDto(
            profileId: (row['id'] as int?) ?? 1,
            nickname: row['nickname'] as String? ?? '',
            tagline: row['tagline'] as String? ?? '',
            avatarSeed: row['avatar_seed'] as String?,
            lastActiveAt: _readDateTime(row['last_active_at']),
            metadata: _metadataFromRow(
              row,
              localId: ((row['id'] as int?) ?? 1).toString(),
              encryptedField: false,
            ),
          ).toDomain(SyncResourceType.userProfiles),
        )
        .toList(growable: false);
  }

  SyncRecordMetadataDto _metadataFromRow(
    Map<String, Object?> row, {
    required String localId,
    bool encryptedField = true,
  }) {
    final deletedAt = _readDateTime(row['deleted_at']);
    return SyncRecordMetadataDto(
      localId: localId,
      cloudId: row['cloud_id'] as String?,
      revisionToken: row['revision_token'] as String?,
      clientMutationId: row['client_mutation_id'] as String?,
      lastActorDeviceId: row['last_actor_device_id'] as String?,
      createdAt: _readDateTime(row['created_at']),
      updatedAt: _readDateTime(row['updated_at']),
      deletedAt: deletedAt,
      isDeleted: deletedAt != null,
      isEncrypted: encryptedField && ((row['is_encrypted'] as int?) ?? 0) == 1,
      schemaVersion: 2,
    );
  }

  String _pendingWhereClause() {
    return "sync_status = 'pending_push'";
  }

  SyncDeviceInfo get _deviceInfo => SyncDeviceInfo(
    deviceId: currentActorDeviceId(),
    platform: Platform.operatingSystem,
    appVersion: '0.1.0+1',
    schemaVersion: 2,
  );

  String _requestId(String prefix) {
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '$prefix-$stamp';
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

List<String> _readStringList(Object? value) {
  if (value == null) {
    return const [];
  }
  try {
    final decoded = jsonDecode(value.toString());
    if (decoded is! List) {
      return const [];
    }
    return decoded.map((item) => item.toString()).toList(growable: false);
  } catch (_) {
    return const [];
  }
}

bool _readBoolValue(Object? value) {
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

String? _jsonPayloadOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  return jsonEncode(value);
}

bool _remoteIsAtLeastAsNew(Object? localUpdatedAt, DateTime remoteUpdatedAt) {
  final local = _readDateTime(localUpdatedAt);
  return local == null || !local.toUtc().isAfter(remoteUpdatedAt.toUtc());
}

bool _remoteSoftDeleteWins({
  required Map<String, Object?> row,
  required DateTime remoteUpdatedAt,
  DateTime? remoteDeletedAt,
}) {
  final localDeletedAt = _readDateTime(row['deleted_at']);
  final localUpdatedAt = _readDateTime(row['updated_at']);
  final localMutationAt = (localDeletedAt ?? localUpdatedAt)?.toUtc();
  final remoteMutationAt = (remoteDeletedAt ?? remoteUpdatedAt).toUtc();
  if (localDeletedAt != null || remoteDeletedAt != null) {
    return localMutationAt == null ||
        !localMutationAt.isAfter(remoteMutationAt);
  }
  return _remoteIsAtLeastAsNew(row['updated_at'], remoteUpdatedAt);
}

String _nullableSqlEquals(String? value) {
  if (value == null || value.isEmpty) {
    return 'IS NULL';
  }
  return '= ${sqlString(value)}';
}
