import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/data/remote/cloud_sync_api.dart';
import 'package:gscappall/data/remote/sync_dtos.dart';
import 'package:gscappall/data/remote/sync_payload_dtos.dart';
import 'package:gscappall/domain/sync/sync_models.dart';

void main() {
  group('sync profile scope', () {
    test('profile-scoped entities keep separate record keys', () {
      const metadata = SyncRecordMetadataDto();

      final firstProfileFavorite = FavoriteSyncDto(
        profileId: 1,
        poemId: 8,
        isFavorite: true,
        metadata: metadata,
      );
      final secondProfileFavorite = FavoriteSyncDto(
        profileId: 2,
        poemId: 8,
        isFavorite: true,
        metadata: metadata,
      );
      final firstProfileDaily = DailyPoemRecordSyncDto(
        profileId: 1,
        dateKey: '2026-05-08',
        poemId: 8,
        isCompleted: true,
        metadata: metadata,
      );
      final secondProfileDaily = DailyPoemRecordSyncDto(
        profileId: 2,
        dateKey: '2026-05-08',
        poemId: 8,
        isCompleted: true,
        metadata: metadata,
      );
      final firstProfilePoints = UserPointsSyncDto(
        profileId: 1,
        totalPoints: 10,
        currentPoints: 10,
        totalCheckIns: 1,
        consecutiveDays: 1,
        metadata: metadata,
      );
      final secondProfilePoints = UserPointsSyncDto(
        profileId: 2,
        totalPoints: 20,
        currentPoints: 15,
        totalCheckIns: 2,
        consecutiveDays: 2,
        metadata: metadata,
      );
      final secondProfileReward = ChallengeStageRewardSyncDto(
        profileId: 2,
        stageId: 'jielong_entry',
        stars: 2,
        claimedAt: DateTime.utc(2026, 5, 8),
        metadata: metadata,
      );

      expect(firstProfileFavorite.recordKey, 'favorite:1:8');
      expect(secondProfileFavorite.recordKey, 'favorite:2:8');
      expect(firstProfileDaily.recordKey, 'daily:1:2026-05-08');
      expect(secondProfileDaily.recordKey, 'daily:2:2026-05-08');
      expect(firstProfilePoints.recordKey, 'points:1');
      expect(secondProfilePoints.recordKey, 'points:2');
      expect(secondProfileReward.recordKey, 'reward:2:jielong_entry:2');
    });

    test('payload conversion preserves profile ids', () {
      final createdAt = DateTime.utc(2026, 5, 8, 1, 2, 3);
      final createdAtIso = createdAt.toIso8601String();
      final payload = SyncBatchPayloadDto.fromCollections([
        SyncCollectionDelta(
          resource: SyncResourceType.studyCardProgress,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.studyCardProgress,
              recordKey: 'study_card:2:8',
              data: {
                'profileId': 2,
                'poemId': 8,
                'memoryStatus': 'learning',
                'reviewCount': 2,
                'nextReviewAt': createdAtIso,
                'note': 'Keep this note scoped to profile two',
              },
              metadata: SyncChangeMetadata(
                revisionToken: 'rev-study-card-1',
                clientMutationId: 'study-card-mut-1',
                lastActorDeviceId: 'device-a',
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.wrongQuestions,
          mergePolicy: SyncMergePolicy.lastWriteWins,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.wrongQuestions,
              recordKey: 'wrong:2:8:$createdAtIso',
              data: {
                'profileId': 2,
                'poemId': 8,
                'questionType': 'dictation',
                'severity': 'high',
                'isResolved': false,
              },
              metadata: SyncChangeMetadata(createdAt: createdAt),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.practiceReports,
          mergePolicy: SyncMergePolicy.appendOnly,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.practiceReports,
              recordKey: 'report:2:session-8',
              data: {
                'profileId': 2,
                'sessionId': 'session-8',
                'mode': 'evaluation',
                'poemId': 8,
                'totalScore': 66,
                'correctCount': 1,
                'totalQuestions': 2,
                'generatedWrongCount': 1,
                'suggestions': ['review', 'retry-line-1'],
                'completedAt': createdAtIso,
                'items': [
                  {
                    'lineIndex': 0,
                    'prompt': 'p',
                    'hint': 'h',
                    'expectedAnswer': 'a',
                    'userAnswer': 'b',
                    'isCorrect': false,
                    'score': 60,
                    'feedback': 'retry',
                    'mistakeType': 'line_mismatch',
                  },
                ],
              },
              metadata: SyncChangeMetadata(
                revisionToken: 'rev-report-1',
                clientMutationId: 'report-mut-1',
                lastActorDeviceId: 'device-a',
                createdAt: createdAt,
                updatedAt: createdAt,
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
                'totalPoints': 35,
                'currentPoints': 30,
                'totalCheckIns': 3,
                'consecutiveDays': 2,
                'lastCheckInDate': '2026-05-08',
              },
              metadata: SyncChangeMetadata(
                revisionToken: 'rev-points-2',
                clientMutationId: 'points-mut-2',
                lastActorDeviceId: 'device-a',
                createdAt: createdAt,
                updatedAt: createdAt,
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
              recordKey: 'reward:2:jielong_entry:2',
              data: {
                'profileId': 2,
                'stageId': 'jielong_entry',
                'stars': 2,
                'claimedAt': createdAtIso,
              },
              metadata: SyncChangeMetadata(
                revisionToken: 'rev-reward-2',
                clientMutationId: 'reward-mut-2',
                lastActorDeviceId: 'device-a',
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            ),
          ],
        ),
        SyncCollectionDelta(
          resource: SyncResourceType.settings,
          mergePolicy: SyncMergePolicy.serverMergeSuggested,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.settings,
              recordKey: 'settings:1',
              data: {
                'activeProfileId': 2,
                'showPinyin': false,
                'themeMode': 'system',
                'fontScale': 1.0,
                'speechRate': 1.0,
                'dailyReminderEnabled': true,
                'notificationsEnabled': false,
                'reminderHour': 7,
                'reminderMinute': 30,
                'seedVersion': 'seed-v1',
              },
              metadata: SyncChangeMetadata(
                revisionToken: 'rev-settings-1',
                clientMutationId: 'settings-mut-1',
                lastActorDeviceId: 'device-a',
                createdAt: createdAt,
                updatedAt: createdAt,
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
                'nickname': 'Profile Two',
                'tagline': 'Isolation validation profile',
                'avatarSeed': 'profile-2',
                'lastActiveAt': createdAtIso,
              },
              metadata: SyncChangeMetadata(
                revisionToken: 'rev-profile-2',
                clientMutationId: 'profile-mut-2',
                lastActorDeviceId: 'device-a',
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            ),
          ],
        ),
      ]);

      expect(payload.wrongQuestions.single.profileId, 2);
      expect(payload.studyCardProgress.single.profileId, 2);
      expect(payload.studyCardProgress.single.recordKey, 'study_card:2:8');
      expect(payload.studyCardProgress.single.nextReviewAt, createdAt);
      expect(payload.studyCardProgress.single.note, contains('profile two'));
      expect(
        payload.studyCardProgress.single.metadata.revisionToken,
        'rev-study-card-1',
      );
      expect(
        payload.studyCardProgress.single.metadata.clientMutationId,
        'study-card-mut-1',
      );
      expect(payload.practiceReports.single.profileId, 2);
      expect(payload.practiceReports.single.recordKey, 'report:2:session-8');
      expect(payload.practiceReports.single.suggestions, hasLength(2));
      expect(
        payload.practiceReports.single.items.single['mistakeType'],
        'line_mismatch',
      );
      expect(
        payload.practiceReports.single.metadata.revisionToken,
        'rev-report-1',
      );
      expect(payload.userPoints.single.profileId, 2);
      expect(payload.userPoints.single.recordKey, 'points:2');
      expect(payload.userPoints.single.totalPoints, 35);
      expect(payload.userPoints.single.currentPoints, 30);
      expect(payload.userPoints.single.lastCheckInDate, '2026-05-08');
      expect(payload.userPoints.single.metadata.revisionToken, 'rev-points-2');
      expect(payload.challengeStageRewards.single.profileId, 2);
      expect(
        payload.challengeStageRewards.single.recordKey,
        'reward:2:jielong_entry:2',
      );
      expect(payload.challengeStageRewards.single.stageId, 'jielong_entry');
      expect(payload.challengeStageRewards.single.stars, 2);
      expect(payload.challengeStageRewards.single.claimedAt, createdAt);
      expect(payload.settings.single.activeProfileId, 2);
      expect(payload.settings.single.showPinyin, isFalse);
      expect(payload.settings.single.notificationsEnabled, isFalse);
      expect(payload.settings.single.reminderHour, 7);
      expect(payload.settings.single.reminderMinute, 30);
      expect(payload.settings.single.seedVersion, 'seed-v1');
      expect(
        payload.settings.single.metadata.clientMutationId,
        'settings-mut-1',
      );
      expect(
        payload.wrongQuestions.single.recordKey,
        'wrong:2:8:$createdAtIso',
      );
      expect(payload.userProfiles.single.profileId, 2);
      expect(payload.userProfiles.single.recordKey, 'profile:2');
      expect(payload.userProfiles.single.lastActiveAt, createdAt);
      expect(
        payload.userProfiles.single.metadata.revisionToken,
        'rev-profile-2',
      );

      final roundTripped = SyncBatchPayloadDto.fromJson(payload.toJson());
      expect(roundTripped.wrongQuestions.single.profileId, 2);
      expect(roundTripped.studyCardProgress.single.profileId, 2);
      expect(
        roundTripped.studyCardProgress.single.metadata.clientMutationId,
        'study-card-mut-1',
      );
      expect(roundTripped.practiceReports.single.profileId, 2);
      expect(roundTripped.practiceReports.single.items.single['hint'], 'h');
      expect(roundTripped.userPoints.single.profileId, 2);
      expect(roundTripped.userPoints.single.currentPoints, 30);
      expect(roundTripped.challengeStageRewards.single.profileId, 2);
      expect(roundTripped.challengeStageRewards.single.claimedAt, createdAt);
      expect(
        roundTripped.userPoints.single.metadata.clientMutationId,
        'points-mut-2',
      );
      expect(roundTripped.settings.single.showPinyin, isFalse);
      expect(roundTripped.userProfiles.single.profileId, 2);
    });

    test('tombstone metadata survives payload round trip', () {
      final deletedAt = DateTime.utc(2026, 5, 8, 2, 3, 4);
      final payload = SyncBatchPayloadDto.fromCollections([
        SyncCollectionDelta(
          resource: SyncResourceType.favorites,
          mergePolicy: SyncMergePolicy.softDelete,
          records: [
            SyncChangeRecord(
              resource: SyncResourceType.favorites,
              recordKey: 'favorite:2:8',
              data: {'profileId': 2, 'poemId': 8, 'isFavorite': false},
              metadata: SyncChangeMetadata(
                localId: '2:8',
                revisionToken: 'rev-favorite-1',
                clientMutationId: 'favorite-delete-mut-1',
                lastActorDeviceId: 'device-a',
                deletedAt: deletedAt,
                isDeleted: true,
              ),
            ),
          ],
        ),
      ]);

      final favorite = payload.favorites.single;
      expect(favorite.isFavorite, isFalse);
      expect(favorite.metadata.isDeleted, isTrue);
      expect(favorite.metadata.deletedAt, deletedAt);
      expect(favorite.metadata.revisionToken, 'rev-favorite-1');
      expect(favorite.metadata.clientMutationId, 'favorite-delete-mut-1');

      final roundTripped = SyncBatchPayloadDto.fromJson(payload.toJson());
      expect(roundTripped.favorites.single.metadata.isDeleted, isTrue);
      expect(roundTripped.favorites.single.metadata.deletedAt, deletedAt);
    });

    test('CloudSyncApi exposes adapter shape without network', () async {
      const api = CloudSyncApi();
      final config = CloudSyncApiConfig(
        baseUri: Uri.parse('https://example.invalid/api'),
      );

      expect(api.config.enableNetwork, isFalse);
      expect(
        config.endpoint(config.pushPath).toString(),
        'https://example.invalid/sync/push',
      );
      await expectLater(api.fetchCapabilities(), completes);
    });

    test('legacy profile-free records default to primary profile', () {
      final favorite = FavoriteSyncDto.fromJson({
        'poemId': 8,
        'isFavorite': true,
      });

      expect(favorite.profileId, 1);
      expect(favorite.recordKey, 'favorite:1:8');
    });
  });
}
