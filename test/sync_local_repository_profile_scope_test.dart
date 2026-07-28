import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/remote/sync_payload_dtos.dart';
import 'package:gscappall/data/repositories/local_learning_repository.dart';
import 'package:gscappall/data/repositories/sync_local_repository.dart';
import 'package:gscappall/domain/sync/sync_models.dart';

void main() {
  test(
    'apply remote challenge rewards writes profile scoped rows locally',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.selectList('SELECT 1;');

      final claimedAt = DateTime.utc(2026, 5, 9, 1, 2, 3);
      final repository = DriftSyncLocalRepository(database: database);
      final envelope = SyncEnvelope(
        requestId: 'pull-rewards',
        device: const SyncDeviceInfo(deviceId: 'remote-device'),
        checkpoint: SyncCheckpoint(
          globalCursor: 'cursor-1',
          collectionCursors: const {
            SyncResourceType.challengeStageRewards: 'reward-cursor-1',
          },
          lastSuccessfulSyncAt: claimedAt,
          schemaVersion: 2,
        ),
        generatedAt: claimedAt,
        collections: [
          SyncCollectionDelta(
            resource: SyncResourceType.challengeStageRewards,
            mergePolicy: SyncMergePolicy.serverMergeSuggested,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.challengeStageRewards,
                recordKey: 'reward:2:jielong_entry:2',
                data: {
                  'profileId': 2,
                  'stageId': 'jielong_entry',
                  'stars': 2,
                  'claimedAt': claimedAt.toIso8601String(),
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-reward-2',
                  revisionToken: 'rev-reward-2',
                  clientMutationId: 'remote-mut-2',
                  lastActorDeviceId: 'remote-device',
                  createdAt: claimedAt,
                  updatedAt: claimedAt,
                ),
              ),
              SyncChangeRecord(
                resource: SyncResourceType.challengeStageRewards,
                recordKey: 'reward:2:chapter:基础路线 · 接龙路线:1',
                data: {
                  'profileId': 2,
                  'stageId': 'chapter:基础路线 · 接龙路线',
                  'stars': 1,
                  'claimedAt': claimedAt.toIso8601String(),
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-chapter-reward-1',
                  revisionToken: 'rev-chapter-reward-1',
                  clientMutationId: 'remote-mut-chapter-1',
                  lastActorDeviceId: 'remote-device',
                  createdAt: claimedAt,
                  updatedAt: claimedAt,
                ),
              ),
            ],
          ),
        ],
      );

      await repository.applyRemoteEnvelope(envelope);

      final row = await database.selectSingle('''
      SELECT *
      FROM challenge_stage_rewards
      WHERE profile_id = 2
        AND stage_id = 'jielong_entry'
        AND stars = 2
      LIMIT 1;
    ''');
      expect(row, isNotNull);
      expect(row?['claimed_at'], claimedAt.toIso8601String());
      expect(row?['cloud_id'], 'cloud-reward-2');
      expect(row?['revision_token'], 'rev-reward-2');
      expect(row?['client_mutation_id'], 'remote-mut-2');
      expect(row?['last_actor_device_id'], 'remote-device');
      expect(row?['sync_status'], 'local');
      final chapterRow = await database.selectSingle('''
      SELECT *
      FROM challenge_stage_rewards
      WHERE profile_id = 2
        AND stage_id = 'chapter:基础路线 · 接龙路线'
        AND stars = 1
      LIMIT 1;
    ''');
      expect(chapterRow, isNotNull);
      expect(chapterRow?['cloud_id'], 'cloud-chapter-reward-1');
      await database.ensureDefaults();
      await database.customStatement('''
      INSERT OR IGNORE INTO profile_accounts (
        id, nickname, tagline, sync_status, created_at, updated_at
      )
      VALUES (
        2, 'Profile Two', 'remote reward holder', 'local',
        '${claimedAt.toIso8601String()}', '${claimedAt.toIso8601String()}'
      );
    ''');
      await database.customStatement('''
      UPDATE settings
      SET active_profile_id = 2
      WHERE id = 1;
    ''');
      final learningRepository = LocalLearningRepository(database: database);
      expect(
        await learningRepository.markChallengeRewardClaimed(
          stageId: 'jielong_entry',
          stars: 2,
        ),
        isFalse,
      );
      expect(
        await learningRepository.markChallengeRewardClaimed(
          stageId: 'chapter:基础路线 · 接龙路线',
          stars: 1,
        ),
        isFalse,
      );

      final pendingEnvelope = await repository.collectPendingChanges(
        options: const SyncRunOptions(
          scope: {SyncResourceType.challengeStageRewards},
        ),
      );
      expect(pendingEnvelope.collections, isEmpty);
      expect(repository.lastAppliedEnvelope?.requestId, 'pull-rewards');

      final checkpoint = await repository.loadCheckpoint();
      expect(checkpoint.globalCursor, 'cursor-1');
      expect(
        checkpoint.cursorFor(SyncResourceType.challengeStageRewards),
        'reward-cursor-1',
      );
    },
  );

  test(
    'apply remote learning progress resources writes profile scoped rows locally',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.selectList('SELECT 1;');

      final remoteAt = DateTime.utc(2026, 5, 9, 2, 3, 4);
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'Poem One', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
          '', '', '', '', '', '', 1, 'test', 'local',
          '${remoteAt.toIso8601String()}', '${remoteAt.toIso8601String()}'),
        (2, 'Poem Two', 'Author B', 'Tang', 1, 'G1', 'cat', 'line two',
          '', '', '', '', '', '', 1, 'test', 'local',
          '${remoteAt.toIso8601String()}', '${remoteAt.toIso8601String()}');
    ''');

      final repository = DriftSyncLocalRepository(database: database);
      final envelope = SyncEnvelope(
        requestId: 'pull-learning-progress',
        device: const SyncDeviceInfo(deviceId: 'remote-device'),
        checkpoint: SyncCheckpoint(
          globalCursor: 'cursor-progress',
          collectionCursors: const {
            SyncResourceType.studyCardProgress: 'study-cursor',
            SyncResourceType.dailyPoemRecords: 'daily-cursor',
            SyncResourceType.userPoints: 'points-cursor',
          },
          lastSuccessfulSyncAt: remoteAt,
          schemaVersion: 2,
        ),
        generatedAt: remoteAt,
        collections: [
          SyncCollectionDelta(
            resource: SyncResourceType.studyCardProgress,
            mergePolicy: SyncMergePolicy.serverMergeSuggested,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.studyCardProgress,
                recordKey: 'study_card:2:1',
                data: {
                  'profileId': 2,
                  'poemId': 1,
                  'memoryStatus': 'mastered',
                  'reviewCount': 4,
                  'nextReviewAt':
                      remoteAt.add(const Duration(days: 7)).toIso8601String(),
                  'note': 'remote note',
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-study-2-1',
                  revisionToken: 'rev-study-2-1',
                  clientMutationId: 'remote-study-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: remoteAt,
                ),
              ),
            ],
          ),
          SyncCollectionDelta(
            resource: SyncResourceType.dailyPoemRecords,
            mergePolicy: SyncMergePolicy.lastWriteWins,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.dailyPoemRecords,
                recordKey: 'daily:2:2026-05-09',
                data: {
                  'profileId': 2,
                  'dateKey': '2026-05-09',
                  'poemId': 2,
                  'isCompleted': true,
                  'completedAt': remoteAt.toIso8601String(),
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-daily-2',
                  revisionToken: 'rev-daily-2',
                  clientMutationId: 'remote-daily-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: remoteAt,
                ),
              ),
            ],
          ),
          SyncCollectionDelta(
            resource: SyncResourceType.userPoints,
            mergePolicy: SyncMergePolicy.serverMergeSuggested,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.userPoints,
                recordKey: 'points:2',
                data: {
                  'profileId': 2,
                  'totalPoints': 88,
                  'currentPoints': 66,
                  'totalCheckIns': 7,
                  'consecutiveDays': 3,
                  'lastCheckInDate': '2026-05-09',
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-points-2',
                  revisionToken: 'rev-points-2',
                  clientMutationId: 'remote-points-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: remoteAt,
                ),
              ),
            ],
          ),
        ],
      );

      await repository.applyRemoteEnvelope(envelope);

      final studyRow = await database.selectSingle('''
      SELECT *
      FROM study_card_progress
      WHERE profile_id = 2 AND poem_id = 1
      LIMIT 1;
    ''');
      expect(studyRow?['memory_status'], 'mastered');
      expect(studyRow?['review_count'], 4);
      expect(studyRow?['note'], 'remote note');
      expect(studyRow?['cloud_id'], 'cloud-study-2-1');
      expect(studyRow?['sync_status'], 'local');

      final dailyRow = await database.selectSingle('''
      SELECT *
      FROM daily_poem_records
      WHERE profile_id = 2 AND date_key = '2026-05-09'
      LIMIT 1;
    ''');
      expect(dailyRow?['poem_id'], 2);
      expect(dailyRow?['is_completed'], 1);
      expect(dailyRow?['completed_at'], remoteAt.toIso8601String());
      expect(dailyRow?['revision_token'], 'rev-daily-2');
      expect(dailyRow?['sync_status'], 'local');

      final pointsRow = await database.selectSingle('''
      SELECT *
      FROM user_points
      WHERE id = 2
      LIMIT 1;
    ''');
      expect(pointsRow?['total_points'], 88);
      expect(pointsRow?['current_points'], 66);
      expect(pointsRow?['total_check_ins'], 7);
      expect(pointsRow?['consecutive_days'], 3);
      expect(pointsRow?['last_check_in_date'], '2026-05-09');
      expect(pointsRow?['sync_status'], 'local');

      final pendingEnvelope = await repository.collectPendingChanges(
        options: const SyncRunOptions(
          scope: {
            SyncResourceType.studyCardProgress,
            SyncResourceType.dailyPoemRecords,
            SyncResourceType.userPoints,
          },
        ),
      );
      expect(pendingEnvelope.collections, isEmpty);

      final checkpoint = await repository.loadCheckpoint();
      expect(checkpoint.globalCursor, 'cursor-progress');
      expect(
        checkpoint.cursorFor(SyncResourceType.studyCardProgress),
        'study-cursor',
      );
      expect(
        checkpoint.cursorFor(SyncResourceType.dailyPoemRecords),
        'daily-cursor',
      );
      expect(
        checkpoint.cursorFor(SyncResourceType.userPoints),
        'points-cursor',
      );
    },
  );

  test(
    'apply remote favorites and wrong questions writes profile scoped rows locally',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.selectList('SELECT 1;');

      final remoteAt = DateTime.utc(2026, 5, 9, 3, 4, 5);
      final reviewedAt = remoteAt.add(const Duration(minutes: 30));
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'Poem One', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
          '', '', '', '', '', '', 1, 'test', 'local',
          '${remoteAt.toIso8601String()}', '${remoteAt.toIso8601String()}'),
        (2, 'Poem Two', 'Author B', 'Tang', 1, 'G1', 'cat', 'line two',
          '', '', '', '', '', '', 1, 'test', 'local',
          '${remoteAt.toIso8601String()}', '${remoteAt.toIso8601String()}');
    ''');

      final repository = DriftSyncLocalRepository(database: database);
      final envelope = SyncEnvelope(
        requestId: 'pull-favorites-wrong',
        device: const SyncDeviceInfo(deviceId: 'remote-device'),
        checkpoint: SyncCheckpoint(
          globalCursor: 'cursor-favorites-wrong',
          collectionCursors: const {
            SyncResourceType.favorites: 'favorite-cursor',
            SyncResourceType.wrongQuestions: 'wrong-cursor',
          },
          lastSuccessfulSyncAt: remoteAt,
          schemaVersion: 2,
        ),
        generatedAt: remoteAt,
        collections: [
          SyncCollectionDelta(
            resource: SyncResourceType.favorites,
            mergePolicy: SyncMergePolicy.softDelete,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.favorites,
                recordKey: 'favorite:2:1',
                data: {
                  'profileId': 2,
                  'poemId': 1,
                  'isFavorite': true,
                  'favoritedAt': remoteAt.toIso8601String(),
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-favorite-2-1',
                  revisionToken: 'rev-favorite-2-1',
                  clientMutationId: 'remote-favorite-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: remoteAt,
                ),
              ),
              SyncChangeRecord(
                resource: SyncResourceType.favorites,
                recordKey: 'favorite:2:2',
                data: {
                  'profileId': 2,
                  'poemId': 2,
                  'isFavorite': false,
                  'favoritedAt': remoteAt.toIso8601String(),
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-favorite-2-2',
                  revisionToken: 'rev-favorite-2-2',
                  clientMutationId: 'remote-favorite-delete-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: remoteAt,
                  deletedAt: reviewedAt,
                  isDeleted: true,
                ),
              ),
            ],
          ),
          SyncCollectionDelta(
            resource: SyncResourceType.wrongQuestions,
            mergePolicy: SyncMergePolicy.serverMergeSuggested,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.wrongQuestions,
                recordKey: 'wrong:2:1:${remoteAt.toIso8601String()}',
                data: {
                  'profileId': 2,
                  'poemId': 1,
                  'questionType': 'dictation',
                  'prompt': 'remote prompt',
                  'correctAnswer': 'right',
                  'userAnswer': 'wrong',
                  'ruleTag': 'missing_characters',
                  'severity': 'high',
                  'reviewedAt': reviewedAt.toIso8601String(),
                  'isResolved': true,
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-wrong-2-1',
                  revisionToken: 'rev-wrong-2-1',
                  clientMutationId: 'remote-wrong-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: reviewedAt,
                ),
              ),
            ],
          ),
        ],
      );

      await repository.applyRemoteEnvelope(envelope);

      final favoriteRow = await database.selectSingle('''
      SELECT *
      FROM favorites
      WHERE profile_id = 2 AND poem_id = 1
      LIMIT 1;
    ''');
      expect(favoriteRow?['deleted_at'], isNull);
      expect(favoriteRow?['cloud_id'], 'cloud-favorite-2-1');
      expect(favoriteRow?['sync_status'], 'local');

      final deletedFavoriteRow = await database.selectSingle('''
      SELECT *
      FROM favorites
      WHERE profile_id = 2 AND poem_id = 2
      LIMIT 1;
    ''');
      expect(deletedFavoriteRow?['deleted_at'], reviewedAt.toIso8601String());
      expect(deletedFavoriteRow?['revision_token'], 'rev-favorite-2-2');
      expect(deletedFavoriteRow?['sync_status'], 'local');

      final wrongRow = await database.selectSingle('''
      SELECT *
      FROM wrong_questions
      WHERE profile_id = 2
        AND poem_id = 1
        AND question_type = 'dictation'
      LIMIT 1;
    ''');
      expect(wrongRow?['prompt'], 'remote prompt');
      expect(wrongRow?['correct_answer'], 'right');
      expect(wrongRow?['user_answer'], 'wrong');
      expect(wrongRow?['rule_tag'], 'missing_characters');
      expect(wrongRow?['severity'], 'high');
      expect(wrongRow?['reviewed_at'], reviewedAt.toIso8601String());
      expect(wrongRow?['cloud_id'], 'cloud-wrong-2-1');
      expect(wrongRow?['sync_status'], 'local');

      final pendingEnvelope = await repository.collectPendingChanges(
        options: const SyncRunOptions(
          scope: {SyncResourceType.favorites, SyncResourceType.wrongQuestions},
        ),
      );
      expect(pendingEnvelope.collections, isEmpty);

      final checkpoint = await repository.loadCheckpoint();
      expect(checkpoint.globalCursor, 'cursor-favorites-wrong');
      expect(
        checkpoint.cursorFor(SyncResourceType.favorites),
        'favorite-cursor',
      );
      expect(
        checkpoint.cursorFor(SyncResourceType.wrongQuestions),
        'wrong-cursor',
      );
    },
  );

  test(
    'apply remote learning records reports settings and profiles locally',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.selectList('SELECT 1;');

      final remoteAt = DateTime.utc(2026, 5, 9, 4, 5, 6);
      final completedAt = remoteAt.add(const Duration(minutes: 8));
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'Report Poem', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
          '', '', '', '', '', '', 1, 'test', 'local',
          '${remoteAt.toIso8601String()}', '${remoteAt.toIso8601String()}');
    ''');

      final repository = DriftSyncLocalRepository(database: database);
      final envelope = SyncEnvelope(
        requestId: 'pull-full-profile-loop',
        device: const SyncDeviceInfo(deviceId: 'remote-device'),
        checkpoint: SyncCheckpoint(
          globalCursor: 'cursor-full-loop',
          collectionCursors: const {
            SyncResourceType.learningRecords: 'learning-cursor',
            SyncResourceType.practiceReports: 'report-cursor',
            SyncResourceType.settings: 'settings-cursor',
            SyncResourceType.userProfiles: 'profile-cursor',
          },
          lastSuccessfulSyncAt: completedAt,
          schemaVersion: 2,
        ),
        generatedAt: completedAt,
        collections: [
          SyncCollectionDelta(
            resource: SyncResourceType.userProfiles,
            mergePolicy: SyncMergePolicy.lastWriteWins,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.userProfiles,
                recordKey: 'profile:2',
                data: {
                  'profileId': 2,
                  'nickname': 'Remote Child',
                  'tagline': 'Synced learner',
                  'avatarSeed': 'bamboo',
                  'lastActiveAt': completedAt.toIso8601String(),
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-profile-2',
                  revisionToken: 'rev-profile-2',
                  clientMutationId: 'remote-profile-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: completedAt,
                ),
              ),
            ],
          ),
          SyncCollectionDelta(
            resource: SyncResourceType.settings,
            mergePolicy: SyncMergePolicy.lastWriteWins,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.settings,
                recordKey: 'settings:1',
                data: {
                  'themeMode': 'dark',
                  'fontScale': 1.2,
                  'speechRate': 0.85,
                  'dailyReminderEnabled': false,
                  'notificationsEnabled': true,
                  'showPinyin': false,
                  'reminderHour': 19,
                  'reminderMinute': 30,
                  'activeProfileId': 2,
                  'seedVersion': 'remote-seed',
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-settings',
                  revisionToken: 'rev-settings',
                  clientMutationId: 'remote-settings-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: completedAt,
                ),
              ),
            ],
          ),
          SyncCollectionDelta(
            resource: SyncResourceType.learningRecords,
            mergePolicy: SyncMergePolicy.serverMergeSuggested,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.learningRecords,
                recordKey: 'learning:2:1:dictation-session',
                data: {
                  'profileId': 2,
                  'poemId': 1,
                  'mode': 'dictation',
                  'durationMinutes': 6,
                  'score': 86,
                  'note': 'remote learning note',
                  'sessionId': 'dictation-session',
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-learning-2-1',
                  revisionToken: 'rev-learning-2-1',
                  clientMutationId: 'dictation-session',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: completedAt,
                ),
              ),
            ],
          ),
          SyncCollectionDelta(
            resource: SyncResourceType.practiceReports,
            mergePolicy: SyncMergePolicy.serverMergeSuggested,
            records: [
              SyncChangeRecord(
                resource: SyncResourceType.practiceReports,
                recordKey: 'report:2:report-session',
                data: {
                  'profileId': 2,
                  'sessionId': 'report-session',
                  'mode': 'dictation',
                  'poemId': 1,
                  'totalScore': 91,
                  'correctCount': 3,
                  'totalQuestions': 4,
                  'generatedWrongCount': 1,
                  'suggestions': ['复习易错字'],
                  'completedAt': completedAt.toIso8601String(),
                  'items': [
                    {
                      'lineIndex': 0,
                      'prompt': 'remote prompt',
                      'hint': 'hint',
                      'expectedAnswer': 'right',
                      'userAnswer': 'wrong',
                      'isCorrect': false,
                      'score': 70,
                      'feedback': '注意错字',
                      'mistakeType': 'typo',
                      'assessmentEngine': 'mock',
                      'assessmentAccuracy': 70,
                    },
                  ],
                },
                metadata: SyncChangeMetadata(
                  cloudId: 'cloud-report-2-1',
                  revisionToken: 'rev-report-2-1',
                  clientMutationId: 'remote-report-mut',
                  lastActorDeviceId: 'remote-device',
                  createdAt: remoteAt,
                  updatedAt: completedAt,
                ),
              ),
            ],
          ),
        ],
      );

      await repository.applyRemoteEnvelope(envelope);

      final profileRow = await database.selectSingle('''
      SELECT *
      FROM profile_accounts
      WHERE id = 2
      LIMIT 1;
    ''');
      expect(profileRow?['nickname'], 'Remote Child');
      expect(profileRow?['avatar_seed'], 'bamboo');
      expect(profileRow?['cloud_id'], 'cloud-profile-2');
      expect(profileRow?['sync_status'], 'local');

      final settingsRow = await database.selectSingle('''
      SELECT *
      FROM settings
      WHERE id = 1
      LIMIT 1;
    ''');
      expect(settingsRow?['theme_mode'], 'dark');
      expect(settingsRow?['show_pinyin'], 0);
      expect(settingsRow?['active_profile_id'], 2);
      expect(settingsRow?['revision_token'], 'rev-settings');
      expect(settingsRow?['sync_status'], 'local');

      final learningRow = await database.selectSingle('''
      SELECT *
      FROM learning_records
      WHERE profile_id = 2 AND client_mutation_id = 'dictation-session'
      LIMIT 1;
    ''');
      expect(learningRow?['mode'], 'dictation');
      expect(learningRow?['duration_minutes'], 6);
      expect(learningRow?['score'], 86);
      expect(learningRow?['cloud_id'], 'cloud-learning-2-1');
      expect(learningRow?['sync_status'], 'local');

      final reportRow = await database.selectSingle('''
      SELECT *
      FROM practice_reports
      WHERE profile_id = 2 AND session_id = 'report-session'
      LIMIT 1;
    ''');
      expect(reportRow?['total_score'], 91);
      expect(reportRow?['generated_wrong_count'], 1);
      expect(reportRow?['cloud_id'], 'cloud-report-2-1');
      expect(reportRow?['sync_status'], 'local');

      final itemRow = await database.selectSingle('''
      SELECT *
      FROM practice_report_items
      WHERE report_id = ${reportRow?['id'] as int}
      LIMIT 1;
    ''');
      expect(itemRow?['prompt'], 'remote prompt');
      expect(itemRow?['is_correct'], 0);
      expect(itemRow?['mistake_type'], 'typo');
      expect(itemRow?['assessment_engine'], 'mock');
      expect(itemRow?['assessment_accuracy'], 70);

      final pendingEnvelope = await repository.collectPendingChanges(
        options: const SyncRunOptions(
          scope: {
            SyncResourceType.learningRecords,
            SyncResourceType.practiceReports,
            SyncResourceType.settings,
            SyncResourceType.userProfiles,
          },
        ),
      );
      expect(pendingEnvelope.collections, isEmpty);

      final checkpoint = await repository.loadCheckpoint();
      expect(checkpoint.globalCursor, 'cursor-full-loop');
      expect(
        checkpoint.cursorFor(SyncResourceType.learningRecords),
        'learning-cursor',
      );
      expect(
        checkpoint.cursorFor(SyncResourceType.practiceReports),
        'report-cursor',
      );
      expect(
        checkpoint.cursorFor(SyncResourceType.settings),
        'settings-cursor',
      );
      expect(
        checkpoint.cursorFor(SyncResourceType.userProfiles),
        'profile-cursor',
      );
    },
  );

  test('apply full remote envelope restores a profile on a new device', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.selectList('SELECT 1;');

    final remoteAt = DateTime.utc(2026, 5, 9, 5, 6, 7);
    final laterAt = remoteAt.add(const Duration(minutes: 12));
    final repository = DriftSyncLocalRepository(database: database);
    final allResources = SyncResourceType.values.toSet();
    final envelope = SyncEnvelope(
      requestId: 'pull-full-restore',
      device: const SyncDeviceInfo(deviceId: 'remote-device'),
      checkpoint: SyncCheckpoint(
        globalCursor: 'cursor-full-restore',
        collectionCursors: {
          for (final resource in allResources)
            resource: '${resource.name}-cursor',
        },
        lastSuccessfulSyncAt: laterAt,
        schemaVersion: 2,
      ),
      generatedAt: laterAt,
      collections: [
        SyncCollectionDelta(
          resource: SyncResourceType.poems,
          mergePolicy: SyncMergePolicy.lastWriteWins,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.poems,
              recordKey: 'poem:101',
              data: {
                'poemId': 101,
                'title': 'Remote Poem',
                'author': 'Remote Author',
                'dynasty': 'Tang',
                'grade': 2,
                'gradeLabel': '二年级',
                'category': '思乡',
                'content': '床前明月光',
                'pinyin': 'chuang qian ming yue guang',
                'annotation': 'remote annotation',
                'translation': 'remote translation',
                'appreciation': 'remote appreciation',
                'authorIntro': 'remote intro',
                'extensionText': 'remote extension',
                'audioUrl': 'https://example.test/audio.mp3',
                'imageUrl': 'https://example.test/image.png',
                'difficulty': 2,
                'seedVersion': 'remote-seed',
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-poem-101',
                revisionToken: 'rev-poem-101',
                clientMutationId: 'remote-poem-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.userProfiles,
          mergePolicy: SyncMergePolicy.lastWriteWins,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.userProfiles,
              recordKey: 'profile:2',
              data: {
                'profileId': 2,
                'nickname': 'Full Restore',
                'tagline': 'Cross device learner',
                'avatarSeed': 'lotus',
                'lastActiveAt': laterAt.toIso8601String(),
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-profile-full',
                revisionToken: 'rev-profile-full',
                clientMutationId: 'remote-profile-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.settings,
          mergePolicy: SyncMergePolicy.lastWriteWins,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.settings,
              recordKey: 'settings:1',
              data: {
                'themeMode': 'light',
                'fontScale': 1.1,
                'speechRate': 0.9,
                'dailyReminderEnabled': true,
                'notificationsEnabled': false,
                'showPinyin': true,
                'reminderHour': 18,
                'reminderMinute': 15,
                'activeProfileId': 2,
                'seedVersion': 'remote-seed',
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-settings-full',
                revisionToken: 'rev-settings-full',
                clientMutationId: 'remote-settings-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.favorites,
          mergePolicy: SyncMergePolicy.softDelete,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.favorites,
              recordKey: 'favorite:2:101',
              data: {
                'profileId': 2,
                'poemId': 101,
                'isFavorite': true,
                'favoritedAt': laterAt.toIso8601String(),
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-fav-full',
                revisionToken: 'rev-fav-full',
                clientMutationId: 'remote-fav-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.learningRecords,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.learningRecords,
              recordKey: 'learning:2:101',
              data: {
                'profileId': 2,
                'poemId': 101,
                'mode': 'poetry_jielong',
                'durationMinutes': 5,
                'score': 95,
                'note': 'full restore learning',
                'sessionId': 'full-learning-session',
                'stageId': 'jielong_master',
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-learning-full',
                revisionToken: 'rev-learning-full',
                clientMutationId: 'full-learning-session',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.reciteRecords,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.reciteRecords,
              recordKey: 'recite:2:101',
              data: {
                'profileId': 2,
                'poemId': 101,
                'score': 88,
                'recognizedText': '床前明月光',
                'transcriptVersion': 'v1',
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-recite-full',
                revisionToken: 'rev-recite-full',
                clientMutationId: 'remote-recite-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.studyCardProgress,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.studyCardProgress,
              recordKey: 'study:2:101',
              data: {
                'profileId': 2,
                'poemId': 101,
                'memoryStatus': 'reviewing',
                'reviewCount': 2,
                'nextReviewAt':
                    laterAt.add(const Duration(days: 3)).toIso8601String(),
                'note': 'full restore note',
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-study-full',
                revisionToken: 'rev-study-full',
                clientMutationId: 'remote-study-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.wrongQuestions,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.wrongQuestions,
              recordKey: 'wrong:2:101',
              data: {
                'profileId': 2,
                'poemId': 101,
                'questionType': 'dictation',
                'prompt': '明月',
                'correctAnswer': '明月',
                'userAnswer': '名月',
                'ruleTag': 'homophone',
                'severity': 'medium',
                'reviewedAt': laterAt.toIso8601String(),
                'isResolved': true,
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-wrong-full',
                revisionToken: 'rev-wrong-full',
                clientMutationId: 'remote-wrong-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.practiceReports,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.practiceReports,
              recordKey: 'report:2:full-report-session',
              data: {
                'profileId': 2,
                'sessionId': 'full-report-session',
                'mode': 'dictation',
                'poemId': 101,
                'totalScore': 90,
                'correctCount': 2,
                'totalQuestions': 3,
                'generatedWrongCount': 1,
                'stageId': 'dictation_checkpoint',
                'suggestions': ['继续复习错字'],
                'completedAt': laterAt.toIso8601String(),
                'items': [
                  {
                    'lineIndex': 0,
                    'prompt': '床前',
                    'expectedAnswer': '床前',
                    'userAnswer': '床前',
                    'isCorrect': true,
                    'score': 100,
                    'feedback': '很好',
                  },
                ],
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-report-full',
                revisionToken: 'rev-report-full',
                clientMutationId: 'remote-report-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.dailyPoemRecords,
          mergePolicy: SyncMergePolicy.lastWriteWins,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.dailyPoemRecords,
              recordKey: 'daily:2:2026-05-09',
              data: {
                'profileId': 2,
                'dateKey': '2026-05-09',
                'poemId': 101,
                'isCompleted': true,
                'completedAt': laterAt.toIso8601String(),
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-daily-full',
                revisionToken: 'rev-daily-full',
                clientMutationId: 'remote-daily-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.userPoints,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.userPoints,
              recordKey: 'points:2',
              data: {
                'profileId': 2,
                'totalPoints': 120,
                'currentPoints': 80,
                'totalCheckIns': 12,
                'consecutiveDays': 4,
                'lastCheckInDate': '2026-05-09',
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-points-full',
                revisionToken: 'rev-points-full',
                clientMutationId: 'remote-points-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.challengeStageRewards,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.challengeStageRewards,
              recordKey: 'reward:2:jielong_entry:3',
              data: {
                'profileId': 2,
                'stageId': 'jielong_entry',
                'stars': 3,
                'claimedAt': laterAt.toIso8601String(),
              },
              metadata: SyncChangeMetadata(
                cloudId: 'cloud-reward-full',
                revisionToken: 'rev-reward-full',
                clientMutationId: 'remote-reward-full-mut',
                lastActorDeviceId: 'remote-device',
                createdAt: remoteAt,
                updatedAt: laterAt,
              ),
            ),
          ],
        ),
      ],
    );

    await repository.applyRemoteEnvelope(envelope);

    expect(
      await database.selectSingle('SELECT title FROM poems WHERE id = 101;'),
      containsPair('title', 'Remote Poem'),
    );
    expect(
      await database.selectSingle(
        'SELECT nickname FROM profile_accounts WHERE id = 2;',
      ),
      containsPair('nickname', 'Full Restore'),
    );
    expect(
      await database.selectSingle('SELECT active_profile_id FROM settings;'),
      containsPair('active_profile_id', 2),
    );
    expect(
      await database.selectSingle(
        'SELECT deleted_at FROM favorites WHERE profile_id = 2 AND poem_id = 101;',
      ),
      containsPair('deleted_at', null),
    );
    expect(
      await database.selectSingle(
        'SELECT score FROM recite_records WHERE profile_id = 2 AND poem_id = 101;',
      ),
      containsPair('score', 88),
    );
    expect(
      await database.selectSingle(
        'SELECT mode, stage_id FROM learning_records WHERE profile_id = 2 AND poem_id = 101;',
      ),
      containsPair('mode', 'poetry_jielong'),
    );
    expect(
      await database.selectSingle(
        'SELECT stage_id FROM learning_records WHERE profile_id = 2 AND poem_id = 101;',
      ),
      containsPair('stage_id', 'jielong_master'),
    );
    expect(
      await database.selectSingle(
        'SELECT total_score FROM practice_reports WHERE profile_id = 2 AND session_id = \'full-report-session\';',
      ),
      containsPair('total_score', 90),
    );
    expect(
      await database.selectSingle(
        'SELECT stage_id FROM practice_reports WHERE profile_id = 2 AND session_id = \'full-report-session\';',
      ),
      containsPair('stage_id', 'dictation_checkpoint'),
    );
    expect(
      await database.selectSingle(
        'SELECT severity FROM wrong_questions WHERE profile_id = 2 AND poem_id = 101;',
      ),
      containsPair('severity', 'medium'),
    );
    expect(
      await database.selectSingle(
        'SELECT memory_status FROM study_card_progress WHERE profile_id = 2 AND poem_id = 101;',
      ),
      containsPair('memory_status', 'reviewing'),
    );
    expect(
      await database.selectSingle(
        'SELECT is_completed FROM daily_poem_records WHERE profile_id = 2 AND date_key = \'2026-05-09\';',
      ),
      containsPair('is_completed', 1),
    );
    expect(
      await database.selectSingle(
        'SELECT total_points FROM user_points WHERE id = 2;',
      ),
      containsPair('total_points', 120),
    );
    expect(
      await database.selectSingle(
        'SELECT stars FROM challenge_stage_rewards WHERE profile_id = 2 AND stage_id = \'jielong_entry\';',
      ),
      containsPair('stars', 3),
    );

    final pendingEnvelope = await repository.collectPendingChanges(
      options: SyncRunOptions(scope: allResources),
    );
    expect(pendingEnvelope.collections, isEmpty);

    final checkpoint = await repository.loadCheckpoint();
    expect(checkpoint.globalCursor, 'cursor-full-restore');
    for (final resource in allResources) {
      expect(checkpoint.cursorFor(resource), '${resource.name}-cursor');
    }
  });

  test(
    'remote apply resolves pending local conflicts by merge policy',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.selectList('SELECT 1;');

      final baseAt = DateTime.utc(2026, 5, 9, 6, 7, 8);
      final olderRemoteAt = baseAt.subtract(const Duration(minutes: 5));
      final newerRemoteAt = baseAt.add(const Duration(minutes: 5));
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'Conflict Poem', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
          '', '', '', '', '', '', 1, 'test', 'local',
          '${baseAt.toIso8601String()}', '${baseAt.toIso8601String()}');
    ''');
      await database.customStatement('''
      INSERT INTO settings (
        id, theme_mode, font_scale, speech_rate, daily_reminder_enabled,
        notifications_enabled, show_pinyin, reminder_hour, reminder_minute,
        active_profile_id, seed_version, sync_status, created_at, updated_at
      )
      VALUES (
        1, 'dark', 1.4, 1.0, 1, 1, 0, 21, 0, 1, 'local-seed',
        'pending_push', '${baseAt.toIso8601String()}',
        '${baseAt.toIso8601String()}'
      );
    ''');
      await database.customStatement('''
      INSERT INTO favorites (
        profile_id, poem_id, sync_status, created_at, updated_at, deleted_at
      )
      VALUES (
        2, 1, 'pending_push', '${baseAt.toIso8601String()}',
        '${baseAt.toIso8601String()}', '${baseAt.toIso8601String()}'
      );
    ''');
      await database.customStatement('''
      INSERT INTO study_card_progress (
        profile_id, poem_id, memory_status, review_count, note, sync_status,
        created_at, updated_at
      )
      VALUES (
        2, 1, 'new', 1, 'local pending note', 'pending_push',
        '${baseAt.toIso8601String()}', '${baseAt.toIso8601String()}'
      );
    ''');

      final repository = DriftSyncLocalRepository(database: database);
      await repository.applyRemoteEnvelope(
        SyncEnvelope(
          requestId: 'pull-conflict-policy',
          device: const SyncDeviceInfo(deviceId: 'remote-device'),
          checkpoint: SyncCheckpoint(
            globalCursor: 'cursor-conflict',
            lastSuccessfulSyncAt: newerRemoteAt,
            schemaVersion: 2,
          ),
          generatedAt: newerRemoteAt,
          collections: [
            SyncCollectionDelta(
              resource: SyncResourceType.settings,
              mergePolicy: SyncMergePolicy.lastWriteWins,
              records: [
                SyncChangeRecord(
                  resource: SyncResourceType.settings,
                  recordKey: 'settings:1',
                  data: {
                    'themeMode': 'light',
                    'fontScale': 0.8,
                    'speechRate': 1.0,
                    'dailyReminderEnabled': true,
                    'notificationsEnabled': true,
                    'showPinyin': true,
                    'reminderHour': 18,
                    'reminderMinute': 30,
                    'activeProfileId': 1,
                    'seedVersion': 'remote-old',
                  },
                  metadata: SyncChangeMetadata(
                    revisionToken: 'rev-settings-old',
                    createdAt: olderRemoteAt,
                    updatedAt: olderRemoteAt,
                  ),
                ),
              ],
            ),
            SyncCollectionDelta(
              resource: SyncResourceType.favorites,
              mergePolicy: SyncMergePolicy.softDelete,
              records: [
                SyncChangeRecord(
                  resource: SyncResourceType.favorites,
                  recordKey: 'favorite:2:1',
                  data: {
                    'profileId': 2,
                    'poemId': 1,
                    'isFavorite': true,
                    'favoritedAt': olderRemoteAt.toIso8601String(),
                  },
                  metadata: SyncChangeMetadata(
                    revisionToken: 'rev-favorite-old',
                    createdAt: olderRemoteAt,
                    updatedAt: olderRemoteAt,
                  ),
                ),
              ],
            ),
            SyncCollectionDelta(
              resource: SyncResourceType.studyCardProgress,
              mergePolicy: SyncMergePolicy.serverMergeSuggested,
              records: [
                SyncChangeRecord(
                  resource: SyncResourceType.studyCardProgress,
                  recordKey: 'study:2:1',
                  data: {
                    'profileId': 2,
                    'poemId': 1,
                    'memoryStatus': 'mastered',
                    'reviewCount': 5,
                    'note': 'server merged note',
                  },
                  metadata: SyncChangeMetadata(
                    revisionToken: 'rev-study-merged',
                    createdAt: olderRemoteAt,
                    updatedAt: olderRemoteAt,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      var settingsRow = await database.selectSingle('SELECT * FROM settings;');
      expect(settingsRow?['theme_mode'], 'dark');
      expect(settingsRow?['sync_status'], 'pending_push');

      var favoriteRow = await database.selectSingle('''
      SELECT *
      FROM favorites
      WHERE profile_id = 2 AND poem_id = 1;
    ''');
      expect(favoriteRow?['deleted_at'], baseAt.toIso8601String());
      expect(favoriteRow?['sync_status'], 'pending_push');

      final studyRow = await database.selectSingle('''
      SELECT *
      FROM study_card_progress
      WHERE profile_id = 2 AND poem_id = 1;
    ''');
      expect(studyRow?['memory_status'], 'mastered');
      expect(studyRow?['review_count'], 5);
      expect(studyRow?['note'], 'server merged note');
      expect(studyRow?['sync_status'], 'local');

      await repository.applyRemoteEnvelope(
        SyncEnvelope(
          requestId: 'pull-conflict-newer-remote',
          device: const SyncDeviceInfo(deviceId: 'remote-device'),
          checkpoint: SyncCheckpoint(
            globalCursor: 'cursor-conflict-2',
            lastSuccessfulSyncAt: newerRemoteAt,
            schemaVersion: 2,
          ),
          generatedAt: newerRemoteAt,
          collections: [
            SyncCollectionDelta(
              resource: SyncResourceType.settings,
              mergePolicy: SyncMergePolicy.lastWriteWins,
              records: [
                SyncChangeRecord(
                  resource: SyncResourceType.settings,
                  recordKey: 'settings:1',
                  data: {
                    'themeMode': 'light',
                    'fontScale': 1.1,
                    'speechRate': 0.9,
                    'dailyReminderEnabled': false,
                    'notificationsEnabled': false,
                    'showPinyin': true,
                    'reminderHour': 19,
                    'reminderMinute': 15,
                    'activeProfileId': 1,
                    'seedVersion': 'remote-new',
                  },
                  metadata: SyncChangeMetadata(
                    revisionToken: 'rev-settings-new',
                    createdAt: olderRemoteAt,
                    updatedAt: newerRemoteAt,
                  ),
                ),
              ],
            ),
            SyncCollectionDelta(
              resource: SyncResourceType.favorites,
              mergePolicy: SyncMergePolicy.softDelete,
              records: [
                SyncChangeRecord(
                  resource: SyncResourceType.favorites,
                  recordKey: 'favorite:2:1',
                  data: {
                    'profileId': 2,
                    'poemId': 1,
                    'isFavorite': true,
                    'favoritedAt': olderRemoteAt.toIso8601String(),
                  },
                  metadata: SyncChangeMetadata(
                    revisionToken: 'rev-favorite-new-delete',
                    createdAt: olderRemoteAt,
                    updatedAt: newerRemoteAt,
                    deletedAt: newerRemoteAt,
                    isDeleted: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      settingsRow = await database.selectSingle('SELECT * FROM settings;');
      expect(settingsRow?['theme_mode'], 'light');
      expect(settingsRow?['seed_version'], 'remote-new');
      expect(settingsRow?['sync_status'], 'local');

      favoriteRow = await database.selectSingle('''
      SELECT *
      FROM favorites
      WHERE profile_id = 2 AND poem_id = 1;
    ''');
      expect(favoriteRow?['deleted_at'], newerRemoteAt.toIso8601String());
      expect(favoriteRow?['revision_token'], 'rev-favorite-new-delete');
      expect(favoriteRow?['sync_status'], 'local');
    },
  );

  test(
    'local sync collection preserves profile ids from sqlite rows',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      const now = '2026-05-08T10:00:00.000Z';
      await database.selectList('SELECT 1;');
      await database.customStatement('''
      INSERT INTO poems (
        id, title, author, dynasty, grade, grade_label, category, content,
        pinyin, annotation, translation, appreciation, author_intro,
        extension_text, difficulty, seed_version, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'Poem One', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
          '', '', '', '', '', '', 1, 'test', 'local', '$now', '$now'),
        (2, 'Poem Two', 'Author B', 'Tang', 1, 'G1', 'cat', 'line two',
          '', '', '', '', '', '', 1, 'test', 'local', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO profile_accounts (
        id, nickname, tagline, avatar_seed, last_active_at, revision_token,
        client_mutation_id, last_actor_device_id, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'Profile One', 'first', 'one', '$now', 'rev-profile-1',
          'mut-profile-1', 'device-a', 'pending_push', '$now', '$now'),
        (2, 'Profile Two', 'second', 'two', '$now', 'rev-profile-2',
          'mut-profile-2', 'device-b', 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO settings (
        id, theme_mode, font_scale, speech_rate, daily_reminder_enabled,
        notifications_enabled, show_pinyin, reminder_hour, reminder_minute,
        active_profile_id, seed_version, revision_token, client_mutation_id,
        last_actor_device_id, sync_status, created_at, updated_at
      )
      VALUES (
        1, 'system', 1.0, 1.0, 1, 1, 0, 20, 0, 2, 'test',
        'rev-settings-1', 'mut-settings-1', 'device-a', 'pending_push',
        '$now', '$now'
      );
    ''');
      await database.customStatement('''
      INSERT INTO favorites (
        profile_id, poem_id, revision_token, client_mutation_id,
        last_actor_device_id, sync_status, created_at, updated_at, deleted_at
      )
      VALUES
        (1, 1, 'rev-favorite-1', 'mut-favorite-1', 'device-a',
          'pending_push', '$now', '$now', NULL),
        (2, 2, 'rev-favorite-2', 'mut-favorite-delete-2', 'device-b',
          'pending_push', '$now', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO learning_records (
        profile_id, poem_id, mode, duration_minutes, score, note,
        stage_id, sync_status, created_at, updated_at
      )
      VALUES
        (1, 1, 'dictation', 3, 90, 'p1', 'dictation_checkpoint',
          'pending_push', '$now', '$now'),
        (2, 2, 'evaluation', 5, 70, 'p2', NULL, 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO study_card_progress (
        profile_id, poem_id, memory_status, review_count, next_review_at, note,
        revision_token, client_mutation_id, last_actor_device_id, sync_status,
        created_at, updated_at
      )
      VALUES
        (1, 1, 'learning', 1, '$now', 'p1 note', 'rev-study-1',
          'mut-study-1', 'device-a', 'pending_push', '$now', '$now'),
        (2, 2, 'mastered', 3, '$now', 'p2 note', 'rev-study-2',
          'mut-study-2', 'device-b', 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO wrong_questions (
        profile_id, poem_id, question_type, prompt, correct_answer,
        user_answer, rule_tag, severity, sync_status, created_at, updated_at
      )
      VALUES
        (1, 1, 'dictation', 'p1 prompt', 'a', 'b', 'missing_characters',
          'medium', 'pending_push', '$now', '$now'),
        (2, 2, 'evaluation', 'p2 prompt', 'c', 'd', 'line_mismatch',
          'high', 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO daily_poem_records (
        profile_id, date_key, poem_id, is_completed, completed_at,
        sync_status, created_at, updated_at
      )
      VALUES
        (1, '2026-05-08', 1, 1, '$now', 'pending_push', '$now', '$now'),
        (2, '2026-05-09', 2, 1, '$now', 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO user_points (
        id, total_points, current_points, total_check_ins, consecutive_days,
        last_check_in_date, revision_token, client_mutation_id,
        last_actor_device_id, sync_status, created_at, updated_at
      )
      VALUES
        (1, 20, 10, 2, 2, '2026-05-08', 'rev-points-1',
          'mut-points-1', 'device-a', 'pending_push', '$now', '$now'),
        (2, 35, 30, 3, 1, '2026-05-09', 'rev-points-2',
          'mut-points-2', 'device-b', 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO challenge_stage_rewards (
        profile_id, stage_id, stars, claimed_at, revision_token,
        client_mutation_id, last_actor_device_id, sync_status, created_at,
        updated_at
      )
      VALUES
        (1, 'jielong_entry', 1, '$now', 'rev-reward-1',
          'mut-reward-1', 'device-a', 'pending_push', '$now', '$now'),
        (2, 'feihualing_theme', 3, '$now', 'rev-reward-2',
          'mut-reward-2', 'device-b', 'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO practice_reports (
        profile_id, session_id, mode, poem_id, total_score, correct_count,
        total_questions, generated_wrong_count, suggestions_json, stage_id,
        completed_at, revision_token, client_mutation_id,
        last_actor_device_id, sync_status, created_at, updated_at
      )
      VALUES
        (1, 'session-p1', 'dictation', 1, 80, 1, 2, 1, '["retry"]',
          'dictation_checkpoint',
          '$now', 'rev-report-1', 'mut-report-1', 'device-a',
          'pending_push', '$now', '$now'),
        (2, 'session-p2', 'evaluation', 2, 60, 0, 1, 1, '["review"]',
          NULL,
          '$now', 'rev-report-2', 'mut-report-2', 'device-b',
          'pending_push', '$now', '$now');
    ''');
      await database.customStatement('''
      INSERT INTO practice_report_items (
        report_id, line_index, prompt, expected_answer, user_answer,
        is_correct, score, feedback, mistake_type
      )
      VALUES
        (1, 0, 'p1 prompt', 'a', 'a', 1, 100, 'ok', NULL),
        (2, 0, 'p2 prompt', 'c', 'd', 0, 60, 'retry', 'line_mismatch');
    ''');

      final repository = DriftSyncLocalRepository(database: database);
      final envelope = await repository.collectPendingChanges(
        options: const SyncRunOptions(
          scope: {
            SyncResourceType.favorites,
            SyncResourceType.learningRecords,
            SyncResourceType.studyCardProgress,
            SyncResourceType.wrongQuestions,
            SyncResourceType.practiceReports,
            SyncResourceType.dailyPoemRecords,
            SyncResourceType.userPoints,
            SyncResourceType.challengeStageRewards,
            SyncResourceType.settings,
            SyncResourceType.userProfiles,
          },
        ),
      );
      final payload = SyncBatchPayloadDto.fromCollections(envelope.collections);

      expect(
        payload.favorites.map((item) => item.profileId),
        containsAll([1, 2]),
      );
      expect(
        payload.favorites.map((item) => item.recordKey),
        containsAll(['favorite:1:1', 'favorite:2:2']),
      );
      final deletedFavorite = payload.favorites.singleWhere(
        (item) => item.profileId == 2,
      );
      expect(deletedFavorite.isFavorite, isFalse);
      expect(deletedFavorite.metadata.isDeleted, isTrue);
      expect(deletedFavorite.metadata.deletedAt, DateTime.parse(now));
      expect(deletedFavorite.metadata.revisionToken, 'rev-favorite-2');
      expect(
        deletedFavorite.metadata.clientMutationId,
        'mut-favorite-delete-2',
      );
      expect(
        payload.learningRecords.map((item) => item.profileId),
        containsAll([1, 2]),
      );
      expect(
        payload.learningRecords.map((item) => item.mode),
        containsAll(['dictation', 'evaluation']),
      );
      expect(
        payload.learningRecords
            .singleWhere((item) => item.profileId == 1)
            .stageId,
        'dictation_checkpoint',
      );
      expect(
        payload.studyCardProgress.map((item) => item.profileId),
        containsAll([1, 2]),
      );
      expect(
        payload.studyCardProgress.map((item) => item.recordKey),
        containsAll(['study_card:1:1', 'study_card:2:2']),
      );
      expect(
        payload.studyCardProgress
            .singleWhere((item) => item.profileId == 2)
            .note,
        'p2 note',
      );
      final secondStudyCard = payload.studyCardProgress.singleWhere(
        (item) => item.profileId == 2,
      );
      expect(secondStudyCard.nextReviewAt, DateTime.parse(now));
      expect(secondStudyCard.metadata.revisionToken, 'rev-study-2');
      expect(secondStudyCard.metadata.clientMutationId, 'mut-study-2');
      expect(
        payload.wrongQuestions.map((item) => item.profileId),
        containsAll([1, 2]),
      );
      expect(
        payload.practiceReports.map((item) => item.profileId),
        containsAll([1, 2]),
      );
      final secondReport = payload.practiceReports.singleWhere(
        (item) => item.profileId == 2,
      );
      expect(secondReport.recordKey, '2');
      expect(secondReport.mode, 'evaluation');
      expect(secondReport.generatedWrongCount, 1);
      expect(secondReport.suggestions, ['review']);
      expect(secondReport.metadata.revisionToken, 'rev-report-2');
      expect(secondReport.metadata.clientMutationId, 'mut-report-2');
      expect(secondReport.items.single['mistakeType'], 'line_mismatch');
      expect(
        payload.dailyPoemRecords.map((item) => item.recordKey),
        containsAll(['daily:1:2026-05-08', 'daily:2:2026-05-09']),
      );
      expect(
        payload.userPoints.map((item) => item.recordKey),
        containsAll(['points:1', 'points:2']),
      );
      final secondPoints = payload.userPoints.singleWhere(
        (item) => item.profileId == 2,
      );
      expect(secondPoints.totalPoints, 35);
      expect(secondPoints.currentPoints, 30);
      expect(secondPoints.totalCheckIns, 3);
      expect(secondPoints.consecutiveDays, 1);
      expect(secondPoints.lastCheckInDate, '2026-05-09');
      expect(secondPoints.metadata.revisionToken, 'rev-points-2');
      expect(secondPoints.metadata.clientMutationId, 'mut-points-2');
      expect(
        payload.challengeStageRewards.map((item) => item.recordKey),
        containsAll([
          'reward:1:jielong_entry:1',
          'reward:2:feihualing_theme:3',
        ]),
      );
      final secondReward = payload.challengeStageRewards.singleWhere(
        (item) => item.profileId == 2,
      );
      expect(secondReward.stageId, 'feihualing_theme');
      expect(secondReward.stars, 3);
      expect(secondReward.claimedAt, DateTime.parse(now));
      expect(secondReward.metadata.revisionToken, 'rev-reward-2');
      expect(secondReward.metadata.clientMutationId, 'mut-reward-2');
      final firstPracticeReport = payload.practiceReports.singleWhere(
        (item) => item.profileId == 1,
      );
      expect(firstPracticeReport.stageId, 'dictation_checkpoint');
      expect(firstPracticeReport.metadata.revisionToken, 'rev-report-1');
      expect(payload.settings.single.activeProfileId, 2);
      expect(payload.settings.single.showPinyin, isFalse);
      expect(payload.settings.single.metadata.revisionToken, 'rev-settings-1');
      expect(
        payload.settings.single.metadata.clientMutationId,
        'mut-settings-1',
      );
      expect(
        payload.userProfiles.map((item) => item.recordKey),
        containsAll(['profile:1', 'profile:2']),
      );
      final secondProfile = payload.userProfiles.singleWhere(
        (item) => item.profileId == 2,
      );
      expect(secondProfile.metadata.revisionToken, 'rev-profile-2');
      expect(secondProfile.metadata.clientMutationId, 'mut-profile-2');
    },
  );

  test(
    'full resource replay stress keeps profiles isolated rewards idempotent and pending safe',
    () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(source.close);

      const now = '2026-05-10T08:00:00.000Z';
      await source.selectList('SELECT 1;');
      await _seedFullResourcePendingRows(source, now);

      final sourceRepository = DriftSyncLocalRepository(database: source);
      final sourceEnvelope = await sourceRepository.collectPendingChanges(
        options: SyncRunOptions(scope: SyncResourceType.values.toSet()),
      );
      expect(sourceEnvelope.totalRecords, greaterThanOrEqualTo(18));
      await source.close();

      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.selectList('SELECT 1;');
      await _seedPoems(target, now);
      final targetRepository = DriftSyncLocalRepository(database: target);

      final remoteEnvelope = SyncEnvelope(
        requestId: 'stress-full-resource-replay',
        device: const SyncDeviceInfo(deviceId: 'device-a'),
        checkpoint: SyncCheckpoint(
          globalCursor: 'stress-cursor',
          collectionCursors: {
            for (final resource in SyncResourceType.values)
              resource: 'stress-${resource.name}',
          },
          lastSuccessfulSyncAt: DateTime.parse(now),
          schemaVersion: 10,
        ),
        generatedAt: DateTime.parse(now),
        collections: sourceEnvelope.collections,
      );

      await targetRepository.applyRemoteEnvelope(remoteEnvelope);
      await targetRepository.applyRemoteEnvelope(remoteEnvelope);

      final profileOneFavorites = await target.selectList('''
        SELECT profile_id, poem_id
        FROM favorites
        WHERE profile_id = 1
        ORDER BY poem_id;
      ''');
      final profileTwoFavorites = await target.selectList('''
        SELECT profile_id, poem_id
        FROM favorites
        WHERE profile_id = 2
        ORDER BY poem_id;
      ''');
      expect(profileOneFavorites.map((row) => row['poem_id']), [1]);
      expect(profileTwoFavorites.map((row) => row['poem_id']), [2]);

      final rewardRows = await target.selectList('''
        SELECT profile_id, stage_id, stars
        FROM challenge_stage_rewards
        ORDER BY profile_id, stage_id, stars;
      ''');
      expect(rewardRows, hasLength(2));
      expect(
        rewardRows.map(
          (row) => '${row['profile_id']}:${row['stage_id']}:${row['stars']}',
        ),
        containsAll(['1:jielong_entry:1', '2:feihualing_theme:3']),
      );

      final wrongRows = await target.selectList('''
        SELECT profile_id, question_type
        FROM wrong_questions
        ORDER BY profile_id;
      ''');
      expect(wrongRows.map((row) => row['profile_id']), [1, 2]);
      expect(
        wrongRows.map((row) => row['question_type']),
        containsAll(['dictation', 'evaluation']),
      );

      const pendingAt = '2026-05-10T09:00:00.000Z';
      await target.customStatement('''
        UPDATE settings
        SET theme_mode = 'dark',
            seed_version = 'target-pending',
            sync_status = 'pending_push',
            updated_at = '$pendingAt'
        WHERE id = 1;
      ''');
      await targetRepository.applyRemoteEnvelope(
        SyncEnvelope(
          requestId: 'stress-older-settings',
          device: const SyncDeviceInfo(deviceId: 'device-a'),
          checkpoint: const SyncCheckpoint(globalCursor: 'older-settings'),
          generatedAt: DateTime.parse(now),
          collections: [
            SyncCollectionDelta(
              resource: SyncResourceType.settings,
              mergePolicy: SyncMergePolicy.lastWriteWins,
              records: [
                SyncChangeRecord(
                  resource: SyncResourceType.settings,
                  recordKey: 'settings:1',
                  data: {
                    'themeMode': 'light',
                    'fontScale': 1.0,
                    'speechRate': 1.0,
                    'dailyReminderEnabled': true,
                    'notificationsEnabled': true,
                    'showPinyin': true,
                    'autoSyncEnabled': true,
                    'autoSyncCooldownMinutes': 5,
                    'autoSyncAllowMobileNetwork': true,
                    'autoSyncRequireCharging': false,
                    'reminderHour': 20,
                    'reminderMinute': 0,
                    'activeProfileId': 1,
                    'seedVersion': 'remote-older',
                  },
                  metadata: SyncChangeMetadata(
                    revisionToken: 'older-settings-rev',
                    createdAt: DateTime.parse(now),
                    updatedAt: DateTime.parse(now),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final settingsRow = await target.selectSingle('SELECT * FROM settings;');
      expect(settingsRow?['theme_mode'], 'dark');
      expect(settingsRow?['seed_version'], 'target-pending');
      expect(settingsRow?['sync_status'], 'pending_push');

      final targetPending = await targetRepository.collectPendingChanges(
        options: const SyncRunOptions(scope: {SyncResourceType.settings}),
      );
      expect(
        targetPending.collections.single.records.single.recordKey,
        'settings:1',
      );
    },
  );
}

Future<void> _seedPoems(AppDatabase database, String now) async {
  await database.customStatement('''
    INSERT OR IGNORE INTO poems (
      id, title, author, dynasty, grade, grade_label, category, content,
      pinyin, annotation, translation, appreciation, author_intro,
      extension_text, difficulty, seed_version, sync_status, created_at,
      updated_at
    )
    VALUES
      (1, 'Poem One', 'Author A', 'Tang', 1, 'G1', 'cat', 'line one',
        '', '', '', '', '', '', 1, 'test', 'local', '$now', '$now'),
      (2, 'Poem Two', 'Author B', 'Tang', 1, 'G1', 'cat', 'line two',
        '', '', '', '', '', '', 1, 'test', 'local', '$now', '$now');
  ''');
}

Future<void> _seedFullResourcePendingRows(
  AppDatabase database,
  String now,
) async {
  await _seedPoems(database, now);
  await database.customStatement('''
    INSERT INTO profile_accounts (
      id, nickname, tagline, avatar_seed, last_active_at, revision_token,
      client_mutation_id, last_actor_device_id, sync_status, created_at,
      updated_at
    )
    VALUES
      (1, 'Profile One', 'first', 'one', '$now', 'rev-profile-1',
        'mut-profile-1', 'device-a', 'pending_push', '$now', '$now'),
      (2, 'Profile Two', 'second', 'two', '$now', 'rev-profile-2',
        'mut-profile-2', 'device-a', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO settings (
      id, theme_mode, font_scale, speech_rate, daily_reminder_enabled,
      notifications_enabled, show_pinyin, auto_sync_enabled,
      auto_sync_cooldown_minutes, auto_sync_allow_mobile_network,
      auto_sync_require_charging, reminder_hour, reminder_minute,
      active_profile_id, seed_version, revision_token, client_mutation_id,
      last_actor_device_id, sync_status, created_at, updated_at
    )
    VALUES (
      1, 'system', 1.0, 1.0, 1, 1, 0, 1, 7, 0, 1, 20, 0, 2, 'stress',
      'rev-settings-1', 'mut-settings-1', 'device-a', 'pending_push',
      '$now', '$now'
    );
  ''');
  await database.customStatement('''
    INSERT INTO favorites (
      profile_id, poem_id, revision_token, client_mutation_id,
      last_actor_device_id, sync_status, created_at, updated_at
    )
    VALUES
      (1, 1, 'rev-favorite-1', 'mut-favorite-1', 'device-a',
        'pending_push', '$now', '$now'),
      (2, 2, 'rev-favorite-2', 'mut-favorite-2', 'device-a',
        'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO learning_records (
      profile_id, poem_id, mode, duration_minutes, score, note,
      sync_status, created_at, updated_at
    )
    VALUES
      (1, 1, 'poetry_jielong', 3, 90, 'p1', 'pending_push', '$now', '$now'),
      (2, 2, 'feihualing', 5, 70, 'p2', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO study_card_progress (
      profile_id, poem_id, memory_status, review_count, next_review_at, note,
      sync_status, created_at, updated_at
    )
    VALUES
      (1, 1, 'learning', 1, '$now', 'p1 note', 'pending_push', '$now', '$now'),
      (2, 2, 'mastered', 3, '$now', 'p2 note', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO wrong_questions (
      profile_id, poem_id, question_type, prompt, correct_answer,
      user_answer, rule_tag, severity, sync_status, created_at, updated_at
    )
    VALUES
      (1, 1, 'dictation', 'p1 prompt', 'a', 'b', 'missing_characters',
        'medium', 'pending_push', '$now', '$now'),
      (2, 2, 'evaluation', 'p2 prompt', 'c', 'd', 'line_mismatch',
        'high', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO daily_poem_records (
      profile_id, date_key, poem_id, is_completed, completed_at,
      sync_status, created_at, updated_at
    )
    VALUES
      (1, '2026-05-10', 1, 1, '$now', 'pending_push', '$now', '$now'),
      (2, '2026-05-11', 2, 1, '$now', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO user_points (
      id, total_points, current_points, total_check_ins, consecutive_days,
      last_check_in_date, sync_status, created_at, updated_at
    )
    VALUES
      (1, 20, 10, 2, 2, '2026-05-10', 'pending_push', '$now', '$now'),
      (2, 35, 30, 3, 1, '2026-05-11', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO challenge_stage_rewards (
      profile_id, stage_id, stars, claimed_at, sync_status, created_at,
      updated_at
    )
    VALUES
      (1, 'jielong_entry', 1, '$now', 'pending_push', '$now', '$now'),
      (2, 'feihualing_theme', 3, '$now', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO practice_reports (
      profile_id, session_id, mode, poem_id, total_score, correct_count,
      total_questions, generated_wrong_count, suggestions_json, completed_at,
      sync_status, created_at, updated_at
    )
    VALUES
      (1, 'session-p1', 'dictation', 1, 80, 1, 2, 1, '["retry"]',
        '$now', 'pending_push', '$now', '$now'),
      (2, 'session-p2', 'evaluation', 2, 60, 0, 1, 1, '["review"]',
        '$now', 'pending_push', '$now', '$now');
  ''');
  await database.customStatement('''
    INSERT INTO practice_report_items (
      report_id, line_index, prompt, expected_answer, user_answer,
      is_correct, score, feedback, mistake_type
    )
    VALUES
      (1, 0, 'p1 prompt', 'a', 'a', 1, 100, 'ok', NULL),
      (2, 0, 'p2 prompt', 'c', 'd', 0, 60, 'retry', 'line_mismatch');
  ''');
}
