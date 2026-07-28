import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../core/service_status.dart';
import '../data/local/app_database.dart';
import '../data/local/local_seed_loader.dart';
import '../data/remote/cloud_sync_api.dart';
import '../data/repositories/local_learning_repository.dart';
import '../data/repositories/local_poem_repository.dart';
import '../data/repositories/local_practice_repository.dart';
import '../data/repositories/local_settings_repository.dart';
import '../data/repositories/sync_cloud_repository.dart';
import '../data/repositories/sync_local_repository.dart';
import '../domain/app_settings.dart';
import '../domain/learning_models.dart';
import '../domain/poem.dart';
import '../domain/practice_models.dart';
import '../domain/repositories/learning_repository.dart';
import '../domain/repositories/poem_repository.dart';
import '../domain/repositories/practice_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/sync/sync_models.dart';
import '../domain/sync/sync_repository.dart';
import '../domain/user_profile.dart';
import '../services/audio/audio_player_service.dart';
import '../services/game/challenge_progress_service.dart';
import '../services/game/feihualing_service.dart';
import '../services/game/poetry_jielong_service.dart';
import '../services/notification/notification_service.dart';
import '../services/purchase/purchase_service.dart';
import '../services/record/recorder_service.dart';
import '../services/speech/speech_assessment_service.dart';
import '../services/speech/speech_recognition_service.dart';
import '../services/speech/speech_scoring_service.dart';
import '../services/speech/text_to_speech_service.dart';
import '../services/sync/sync_coordinator.dart';
import '../services/sync/sync_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final seedLoaderProvider = Provider<LocalSeedLoader>((ref) {
  return const LocalSeedLoader();
});

final cloudSyncApiProvider = Provider<CloudSyncApi>((ref) {
  const enableNetwork = bool.fromEnvironment('GSC_SYNC_ENABLE_NETWORK');
  const baseUrl = String.fromEnvironment('GSC_SYNC_BASE_URL');
  const authToken = String.fromEnvironment('GSC_SYNC_AUTH_TOKEN');
  const accountId = String.fromEnvironment('GSC_SYNC_ACCOUNT_ID');
  const deviceId = String.fromEnvironment(
    'GSC_SYNC_DEVICE_ID',
    defaultValue: 'gscappall-local-device',
  );
  const appVersion = String.fromEnvironment(
    'GSC_SYNC_APP_VERSION',
    defaultValue: '0.1.0-dev',
  );
  if (enableNetwork && baseUrl.isNotEmpty) {
    return CloudSyncApi(
      config: CloudSyncApiConfig(
        baseUri: Uri.parse(baseUrl),
        authToken: authToken,
        accountId: accountId,
        deviceId: deviceId,
        platform: Platform.operatingSystem,
        appVersion: appVersion,
        schemaVersion: 10,
        enableNetwork: true,
      ),
      deviceIdResolver:
          () => ref.read(settingsRepositoryProvider).loadSyncDeviceId(),
      authTokenResolver: () async {
        final settings =
            await ref.read(settingsRepositoryProvider).loadSettings();
        return settings.syncAuthToken.trim().isEmpty
            ? null
            : settings.syncAuthToken.trim();
      },
      accountIdResolver: () async {
        final settings =
            await ref.read(settingsRepositoryProvider).loadSettings();
        return settings.syncAccountId.trim().isEmpty
            ? null
            : settings.syncAccountId.trim();
      },
      profileIdsResolver: () async {
        final profiles =
            await ref.read(settingsRepositoryProvider).loadProfiles();
        return profiles.map((profile) => profile.id).toList(growable: false);
      },
    );
  }
  return const CloudSyncApi();
});

final poemRepositoryProvider = Provider<PoemRepository>((ref) {
  return LocalPoemRepository(
    database: ref.watch(appDatabaseProvider),
    seedLoader: ref.watch(seedLoaderProvider),
    remoteApi: ref.watch(cloudSyncApiProvider),
  );
});

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LocalLearningRepository(database: ref.watch(appDatabaseProvider));
});

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  return LocalPracticeRepository(
    database: ref.watch(appDatabaseProvider),
    poemRepository: ref.watch(poemRepositoryProvider),
  );
});

final poetryJielongServiceProvider = Provider<PoetryJielongService>((ref) {
  return const PoetryJielongService();
});

final feihualingServiceProvider = Provider<FeihualingService>((ref) {
  return const FeihualingService();
});

final challengeProgressServiceProvider = Provider<ChallengeProgressService>((
  ref,
) {
  return const ChallengeProgressService();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository(database: ref.watch(appDatabaseProvider));
});

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  return const StubAudioPlayerService();
});

final recorderServiceProvider = Provider<RecorderService>((ref) {
  return const StubRecorderService();
});

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  return const PlatformSpeechRecognitionService();
});

final speechScoringServiceProvider = Provider<SpeechScoringService>((ref) {
  return const LocalHeuristicSpeechScoringService();
});

final speechAssessmentProvider = Provider<SpeechAssessmentProvider>((ref) {
  return MockSpeechAssessmentProvider(
    heuristicScoringService: ref.watch(speechScoringServiceProvider),
  );
});

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) {
  return const PlatformTextToSpeechService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return const StubNotificationService();
});

final syncRemoteRepositoryProvider = Provider<SyncRemoteRepository>((ref) {
  return CloudSyncRemoteRepository(api: ref.watch(cloudSyncApiProvider));
});

final syncLocalRepositoryProvider = Provider<SyncLocalRepository>((ref) {
  return DriftSyncLocalRepository(database: ref.watch(appDatabaseProvider));
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return LocalFirstSyncCoordinator(
    localRepository: ref.watch(syncLocalRepositoryProvider),
    remoteRepository: ref.watch(syncRemoteRepositoryProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return CloudReadySyncService(
    coordinator: ref.watch(syncCoordinatorProvider),
    remoteRepository: ref.watch(syncRemoteRepositoryProvider),
  );
});

final syncStatusProvider =
    AsyncNotifierProvider<SyncStatusNotifier, SyncStatusSnapshot>(
      SyncStatusNotifier.new,
    );

typedef SyncRunLogPageQuery =
    ({
      int limit,
      int offset,
      SyncRunState? state,
      DateTime? startedAfter,
      DateTime? startedBefore,
    });

final syncRunLogPageProvider =
    FutureProvider.family<List<SyncRunLogEntry>, SyncRunLogPageQuery>((
      ref,
      query,
    ) async {
      return ref
          .watch(syncLocalRepositoryProvider)
          .fetchSyncRunLogs(
            limit: query.limit,
            offset: query.offset,
            state: query.state,
            startedAfter: query.startedAfter,
            startedBefore: query.startedBefore,
          );
    });

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return const StubPurchaseService();
});

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.checkpoint,
    required this.pendingCounts,
    this.logs = const [],
    this.lastReport,
    this.lastErrorMessage,
    this.isRunning = false,
  });

  final SyncCheckpoint checkpoint;
  final Map<SyncResourceType, int> pendingCounts;
  final List<SyncRunLogEntry> logs;
  final SyncRunReport? lastReport;
  final String? lastErrorMessage;
  final bool isRunning;

  int get pendingTotal {
    return pendingCounts.values.fold<int>(0, (sum, count) => sum + count);
  }

  bool get hasConflicts => (lastReport?.conflicts.isNotEmpty ?? false);

  bool get hasFailure => lastErrorMessage != null;

  DateTime? get lastSuccessfulSyncAt => checkpoint.lastSuccessfulSyncAt;

  SyncRunState? get lastRunState => lastReport?.state;

  SyncStatusSnapshot copyWith({
    SyncCheckpoint? checkpoint,
    Map<SyncResourceType, int>? pendingCounts,
    List<SyncRunLogEntry>? logs,
    SyncRunReport? lastReport,
    String? lastErrorMessage,
    bool clearLastErrorMessage = false,
    bool? isRunning,
  }) {
    return SyncStatusSnapshot(
      checkpoint: checkpoint ?? this.checkpoint,
      pendingCounts: pendingCounts ?? this.pendingCounts,
      logs: logs ?? this.logs,
      lastReport: lastReport ?? this.lastReport,
      lastErrorMessage:
          clearLastErrorMessage
              ? null
              : (lastErrorMessage ?? this.lastErrorMessage),
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class SyncStatusNotifier extends AsyncNotifier<SyncStatusSnapshot> {
  Future<SyncRunReport?>? _runningSync;

  @override
  Future<SyncStatusSnapshot> build() => _loadSnapshot();

  Future<void> refresh() async {
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isRunning: true));
    } else {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() async {
      final snapshot = await _loadSnapshot();
      return snapshot.copyWith(
        lastReport: previous?.lastReport,
        isRunning: false,
      );
    });
  }

  Future<SyncRunReport?> synchronize({
    SyncRunTrigger trigger = SyncRunTrigger.unknown,
  }) async {
    final runningSync = _runningSync;
    if (runningSync != null) {
      return runningSync;
    }
    final future = _synchronizeOnce(trigger: trigger);
    _runningSync = future;
    try {
      return await future;
    } finally {
      _runningSync = null;
    }
  }

  Future<SyncRunReport?> _synchronizeOnce({
    required SyncRunTrigger trigger,
  }) async {
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isRunning: true));
    }
    try {
      final loginMessage = await _syncLoginRequiredMessage();
      if (loginMessage != null) {
        final fallback = previous ?? await _loadSnapshot();
        state = AsyncData(
          fallback.copyWith(lastErrorMessage: loginMessage, isRunning: false),
        );
        return null;
      }
      final report = await ref
          .read(syncServiceProvider)
          .synchronize(trigger: trigger);
      invalidateProfileScopedProviderContainer(ref.container);
      final checkpoint =
          await ref.read(syncLocalRepositoryProvider).loadCheckpoint();
      final pendingCounts =
          await ref.read(syncLocalRepositoryProvider).pendingCounts();
      final logs =
          await ref.read(syncLocalRepositoryProvider).fetchSyncRunLogs();
      final snapshot = SyncStatusSnapshot(
        checkpoint: checkpoint,
        pendingCounts: pendingCounts,
        logs: logs,
        lastReport: report,
      );
      state = AsyncData(snapshot);
      return report;
    } catch (error) {
      var effectiveError = error;
      if (_isTokenExpired(error) && await _refreshExpiredAccessToken()) {
        try {
          final report = await ref
              .read(syncServiceProvider)
              .synchronize(trigger: trigger);
          invalidateProfileScopedProviderContainer(ref.container);
          final checkpoint =
              await ref.read(syncLocalRepositoryProvider).loadCheckpoint();
          final pendingCounts =
              await ref.read(syncLocalRepositoryProvider).pendingCounts();
          final logs =
              await ref.read(syncLocalRepositoryProvider).fetchSyncRunLogs();
          final snapshot = SyncStatusSnapshot(
            checkpoint: checkpoint,
            pendingCounts: pendingCounts,
            logs: logs,
            lastReport: report,
          );
          state = AsyncData(snapshot);
          return report;
        } catch (retryError) {
          effectiveError = retryError;
        }
      }
      final fallback = previous ?? await _loadSnapshot();
      state = AsyncData(
        fallback.copyWith(
          lastErrorMessage: _friendlySyncError(effectiveError),
          isRunning: false,
        ),
      );
      return null;
    }
  }

  bool _isTokenExpired(Object error) {
    return error is CloudSyncHttpException && error.isAuthExpired;
  }

  Future<String?> _syncLoginRequiredMessage() async {
    final api = ref.read(cloudSyncApiProvider);
    if (!api.config.enableNetwork) {
      return null;
    }
    final settings = await ref.read(settingsRepositoryProvider).loadSettings();
    if (settings.syncAccountId.trim().isEmpty ||
        settings.syncAuthToken.trim().isEmpty ||
        settings.syncRefreshToken.trim().isEmpty) {
      return '请先到“我的 -> 家长与高级设置 -> 备份账号”登录后再备份。';
    }
    return null;
  }

  Future<bool> _refreshExpiredAccessToken() async {
    final settings = await ref.read(settingsRepositoryProvider).loadSettings();
    final accountId = settings.syncAccountId.trim();
    final refreshToken = settings.syncRefreshToken.trim();
    if (accountId.isEmpty || refreshToken.isEmpty) {
      return false;
    }
    try {
      final profiles =
          await ref.read(settingsRepositoryProvider).loadProfiles();
      final result = await ref
          .read(cloudSyncApiProvider)
          .refreshAuthToken(
            accountId: accountId,
            refreshToken: refreshToken,
            profileIds: profiles.map((profile) => profile.id).toList(),
          );
      final token = result['accessToken'] as String?;
      final nextRefreshToken = result['refreshToken'] as String?;
      if (token == null || token.isEmpty) {
        return false;
      }
      await ref
          .read(settingsRepositoryProvider)
          .saveSettings(
            settings.copyWith(
              syncAuthToken: token,
              syncRefreshToken:
                  nextRefreshToken == null || nextRefreshToken.isEmpty
                      ? refreshToken
                      : nextRefreshToken,
            ),
          );
      ref.invalidate(settingsProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> pruneLogs({int retain = 100}) async {
    await ref
        .read(syncLocalRepositoryProvider)
        .pruneSyncRunLogs(retain: retain);
    ref.invalidate(syncRunLogPageProvider);
    state = await AsyncValue.guard(_loadSnapshot);
  }

  Future<void> clearFailedLogs() async {
    await ref.read(syncLocalRepositoryProvider).clearFailedSyncRunLogs();
    ref.invalidate(syncRunLogPageProvider);
    state = await AsyncValue.guard(_loadSnapshot);
  }

  Future<SyncStatusSnapshot> _loadSnapshot() async {
    final localRepository = ref.read(syncLocalRepositoryProvider);
    final checkpoint = await localRepository.loadCheckpoint();
    final pendingCounts = await localRepository.pendingCounts();
    final logs = await localRepository.fetchSyncRunLogs();
    return SyncStatusSnapshot(
      checkpoint: checkpoint,
      pendingCounts: pendingCounts,
      logs: logs,
    );
  }
}

String _friendlySyncError(Object error) {
  final raw = error.toString();
  if (error is CloudSyncHttpException) {
    if (error.statusCode == 401) {
      return '账号登录状态已失效，请重新登录后再备份。';
    }
    if (error.statusCode == 403) {
      return '当前账号没有访问该资料的权限，请检查备份账号或资料授权。';
    }
    if (error.retryable) {
      return '备份服务暂时不可用，请稍后重试。';
    }
  }
  if (raw.contains('SocketException') ||
      raw.contains('HandshakeException') ||
      raw.contains('Failed host lookup')) {
    return '网络不可用，请稍后重试。';
  }
  if (raw.contains('Unauthorized') ||
      raw.contains('401') ||
      raw.contains('403')) {
    return '账号登录状态已失效，请重新登录后再备份。';
  }
  if (raw.contains('timeout') || raw.contains('TimeoutException')) {
    return '备份请求超时，请检查网络后重试。';
  }
  if (raw.contains('UnsupportedError')) {
    return '备份服务暂时不可用。';
  }
  return '备份失败，请稍后重试。';
}

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsRepositoryProvider).loadSettings();
});

final pinyinVisibleProvider = Provider<bool>((ref) {
  return ref
      .watch(settingsProvider)
      .maybeWhen(data: (settings) => settings.showPinyin, orElse: () => true);
});

final profileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.watch(settingsRepositoryProvider).loadProfile();
});

final profilesProvider = FutureProvider<List<UserProfile>>((ref) async {
  return ref.watch(settingsRepositoryProvider).loadProfiles();
});

final poemStatsProvider = FutureProvider<PoemStats>((ref) async {
  return ref.watch(poemRepositoryProvider).fetchStats();
});

final learningSummaryProvider = FutureProvider<LearningSummary>((ref) async {
  return ref.watch(learningRepositoryProvider).fetchSummary();
});

final learningGrowthReportProvider =
    FutureProvider.family<LearningGrowthReport, GrowthReportPeriod>((
      ref,
      period,
    ) async {
      return ref
          .watch(learningRepositoryProvider)
          .fetchGrowthReport(period: period);
    });

final todayPoemProvider = FutureProvider<DailyPoemBundle>((ref) async {
  return ref.watch(poemRepositoryProvider).getDailyPoem(DateTime.now());
});

final dailyPoemProgressProvider = FutureProvider<DailyPoemProgress>((
  ref,
) async {
  return ref.watch(learningRepositoryProvider).fetchDailyPoemProgress();
});

final dailyPoemHistoryProvider = FutureProvider<List<DailyPoemHistoryEntry>>((
  ref,
) async {
  return ref.watch(learningRepositoryProvider).fetchDailyPoemHistory();
});

final favoritesProvider = FutureProvider<List<Poem>>((ref) async {
  return ref.watch(poemRepositoryProvider).fetchFavorites();
});

final studyCardDeckProvider = FutureProvider.family<
  List<StudyCardDeckEntry>,
  StudyCardQuery
>((ref, query) async {
  return ref.watch(learningRepositoryProvider).fetchStudyCardDeck(query: query);
});

final studyCardFilterOptionsProvider = FutureProvider<StudyCardFilterOptions>((
  ref,
) async {
  return ref.watch(learningRepositoryProvider).fetchStudyCardFilterOptions();
});

final poemLibraryQueryProvider =
    NotifierProvider<PoemLibraryQueryNotifier, PoemQuery>(
      PoemLibraryQueryNotifier.new,
    );

final recentLearningRecordsProvider = FutureProvider<List<LearningRecord>>((
  ref,
) async {
  return ref.watch(learningRepositoryProvider).fetchRecentRecords();
});

final learningHistoryProvider =
    FutureProvider.family<List<LearningRecord>, int>((ref, limit) async {
      return ref
          .watch(learningRepositoryProvider)
          .fetchRecentRecords(limit: limit);
    });

final practiceReportSummariesProvider =
    FutureProvider.family<List<PracticeReportSummary>, int>((ref, limit) async {
      return ref
          .watch(practiceRepositoryProvider)
          .fetchPracticeReportSummaries(limit: limit);
    });

final practiceReportOverviewProvider =
    FutureProvider.family<PracticeReportOverview, PracticeReportQuery>((
      ref,
      query,
    ) async {
      return ref
          .watch(practiceRepositoryProvider)
          .fetchPracticeReportOverview(query: query);
    });

final practiceReportDetailProvider =
    FutureProvider.family<PracticeReportDetail?, int>((ref, reportId) async {
      return ref
          .watch(practiceRepositoryProvider)
          .fetchPracticeReportDetail(reportId);
    });

class PoemLibraryQueryNotifier extends Notifier<PoemQuery> {
  @override
  PoemQuery build() => const PoemQuery();

  void setQuery(PoemQuery query) {
    state = query;
  }
}

final wrongQuestionEntriesProvider =
    FutureProvider.family<List<WrongQuestionEntry>, WrongQuestionQuery>((
      ref,
      query,
    ) async {
      return ref
          .watch(practiceRepositoryProvider)
          .fetchWrongQuestions(query: query);
    });

void invalidateProfileScopedProviders(WidgetRef ref) {
  invalidateProfileScopedProviderContainer(ref.container);
}

void invalidateProfileScopedProviderContainer(ProviderContainer container) {
  container.invalidate(settingsProvider);
  container.invalidate(profileProvider);
  container.invalidate(profilesProvider);
  container.invalidate(learningSummaryProvider);
  container.invalidate(learningGrowthReportProvider);
  container.invalidate(todayPoemProvider);
  container.invalidate(dailyPoemProgressProvider);
  container.invalidate(dailyPoemHistoryProvider);
  container.invalidate(favoritesProvider);
  container.invalidate(studyCardDeckProvider);
  container.invalidate(studyCardFilterOptionsProvider);
  container.invalidate(recentLearningRecordsProvider);
  container.invalidate(learningHistoryProvider);
  container.invalidate(practiceReportSummariesProvider);
  container.invalidate(practiceReportOverviewProvider);
  container.invalidate(practiceReportDetailProvider);
  container.invalidate(wrongQuestionEntriesProvider);
}

final serviceCatalogProvider = Provider<List<ServiceDescriptor>>((ref) {
  return [
    ServiceDescriptor(
      name: '音频播放',
      description: '用于播放示范朗读和自己的录音。',
      capability: ref.watch(audioPlayerServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '录音',
      description: '用于朗读、背诵和回放自己的声音。',
      capability: ref.watch(recorderServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '语音识别',
      description: '用于把朗读和背诵内容转成文字，部分设备可能需要手动输入。',
      capability: ref.watch(speechRecognitionServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '朗读评分',
      description: '当前用于练习反馈，正式发音评测仍会继续完善。',
      capability: ref.watch(speechScoringServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '示范朗读',
      description: '没有真人音频时，可提供基础示范朗读。',
      capability: ref.watch(textToSpeechServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '通知提醒',
      description: '按设置提醒孩子完成每日一诗。',
      capability: ref.watch(notificationServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '数据备份',
      description: '用于家长备份学习记录和多设备恢复。',
      capability: ref.watch(syncServiceProvider).capability,
    ),
    ServiceDescriptor(
      name: '付费能力',
      description: '当前不在学习主流程中。',
      capability: ref.watch(purchaseServiceProvider).capability,
    ),
  ];
});

class BootstrapReport {
  const BootstrapReport({required this.poemCount, required this.seedVersion});

  final int poemCount;
  final String seedVersion;
}

final bootstrapProvider = FutureProvider<BootstrapReport>((ref) async {
  final settingsRepository = ref.read(settingsRepositoryProvider);
  final poemRepository = ref.read(poemRepositoryProvider);
  final notificationService = ref.read(notificationServiceProvider);

  await settingsRepository.ensureDefaults();
  await poemRepository.importSeedIfNeeded(
    seedVersion: AppConstants.seedVersion,
  );
  await notificationService.initialize();
  await notificationService.syncWithSettings(
    await settingsRepository.loadSettings(),
  );
  final stats = await poemRepository.fetchStats();
  return BootstrapReport(
    poemCount: stats.total,
    seedVersion: AppConstants.seedVersion,
  );
});
