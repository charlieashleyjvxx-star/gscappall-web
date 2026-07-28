import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/user_facing_error.dart';
import '../domain/app_settings.dart';
import '../domain/learning_models.dart';
import '../domain/sync/sync_models.dart';
import '../features/daily_poem/daily_poem_page.dart';
import '../features/dictation/dictation_page.dart';
import '../features/evaluation/evaluation_placeholder_page.dart';
import '../features/evaluation/practice_report_detail_page.dart';
import '../features/game/challenge_map_page.dart';
import '../features/game/feihualing_page.dart';
import '../features/game/poetry_jielong_page.dart';
import '../features/profile/learning_history_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/sync_log_detail_page.dart';
import '../features/profile/sync_log_list_page.dart';
import '../features/shared/stage_scope_route_args.dart';
import '../features/wrong_book/wrong_book_placeholder_page.dart';
import '../features/wrong_book/wrong_question_detail_page.dart';
import '../services/game/challenge_progress_service.dart';
import '../services/notification/notification_service.dart';
import 'app_providers.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'notification_route_payload.dart';

class GscApp extends ConsumerStatefulWidget {
  const GscApp({super.key});

  @override
  ConsumerState<GscApp> createState() => _GscAppState();
}

class _GscAppState extends ConsumerState<GscApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _startupAutoSyncRequested = false;
  bool _autoSyncInFlight = false;
  DateTime? _lastAutoSyncAt;

  @override
  void initState() {
    super.initState();
    StubNotificationService.setNotificationResponseHandler(
      _handleNotificationPayload,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    StubNotificationService.setNotificationResponseHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runAutoSyncIfEnabled(trigger: SyncRunTrigger.foregroundAuto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(bootstrapProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.asData?.value ?? const AppSettings();
    if (bootstrapAsync.hasValue &&
        settings.autoSyncEnabled &&
        !_startupAutoSyncRequested) {
      _startupAutoSyncRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAutoSyncIfEnabled(trigger: SyncRunTrigger.startupAuto);
      });
    }

    return MaterialApp(
      title: '古诗词学堂',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeModeFrom(settings.themeMode),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(1);
        final effectiveScale = (systemScale * settings.fontScale).clamp(
          0.9,
          1.6,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor:
                        Theme.of(context).colorScheme.surface,
                    systemNavigationBarIconBrightness: Brightness.dark,
                  ),
          child: MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(effectiveScale)),
            child: child!,
          ),
        );
      },
      onGenerateRoute: _onGenerateRoute,
      home: bootstrapAsync.when(
        loading: () => const _SplashScreen(),
        error:
            (error, stackTrace) => _BootstrapErrorView(
              message: UserFacingErrorMapper.parentMessage(
                error,
                fallbackMessage: '应用初始化失败，请重新尝试。',
              ),
              onRetry: () {
                ref.invalidate(bootstrapProvider);
                ref.invalidate(settingsProvider);
              },
            ),
        data: (_) => const AppShell(),
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final args = StageScopeRouteArgs.fromSettings(settings);
    final stageId = args?.stageId;
    final growthPeriod = _growthPeriodFromRoute(args?.growthPeriod);
    switch (settings.name) {
      case '/wrong-book':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WrongBookPlaceholderPage(initialStageId: stageId),
        );
      case '/practice-reports':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PracticeReportHistoryPage(initialStageId: stageId),
        );
      case '/practice-report-detail':
        final reportId = args?.reportId;
        if (reportId == null) {
          return null;
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => CleanPracticeReportDetailPage(reportId: reportId),
        );
      case '/learning-history':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LearningHistoryPage(initialStageId: stageId),
        );
      case '/learning-record-detail':
        final recordId = args?.learningRecordId;
        if (recordId == null) {
          return null;
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => LearningRecordDetailPage(recordId: recordId),
        );
      case '/growth-report':
        return MaterialPageRoute<void>(
          settings: settings,
          builder:
              (_) => GrowthReportDetailPage(
                initialPeriod: growthPeriod,
                initialStageId: stageId,
              ),
        );
      case '/challenge-map':
        return MaterialPageRoute<void>(
          settings: settings,
          builder:
              (_) => _ChallengeMapRoutePage(
                initialStageId: stageId,
                initialSource: args?.source,
              ),
        );
      case '/daily-poem':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DailyPoemPage(),
        );
      case '/sync-logs':
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SyncLogListPage(),
        );
      case '/sync-log-detail':
        final log = settings.arguments;
        if (log is SyncRunLogEntry) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => SyncLogDetailPage(log: log),
          );
        }
      case '/wrong-question-detail':
        final wrongQuestionId = args?.wrongQuestionId;
        if (wrongQuestionId == null) {
          return null;
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder:
              (_) => CleanWrongQuestionDetailPage(
                wrongQuestionId: wrongQuestionId,
              ),
        );
    }
    return null;
  }

  void _handleNotificationPayload(String? payload) {
    final route = routeFromNotificationPayload(payload);
    if (route == null) {
      return;
    }
    _navigatorKey.currentState?.pushNamed(
      route.name,
      arguments: route.routeArgs,
    );
  }

  ThemeMode _themeModeFrom(String mode) {
    return switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  GrowthReportPeriod _growthPeriodFromRoute(String? value) {
    return switch (value) {
      'monthly' => GrowthReportPeriod.monthly,
      _ => GrowthReportPeriod.weekly,
    };
  }

  Future<void> _runAutoSyncIfEnabled({required SyncRunTrigger trigger}) async {
    if (_autoSyncInFlight) {
      return;
    }
    final now = DateTime.now();
    final settings = await ref.read(settingsProvider.future);
    if (!settings.autoSyncEnabled) {
      return;
    }
    final autoSyncCooldown = Duration(
      minutes: settings.autoSyncCooldownMinutes.clamp(1, 120),
    );
    final lastAutoSyncAt = _lastAutoSyncAt;
    if (lastAutoSyncAt != null &&
        now.difference(lastAutoSyncAt) < autoSyncCooldown) {
      return;
    }
    final checkpoint =
        await ref.read(syncLocalRepositoryProvider).loadCheckpoint();
    final lastSuccessfulSyncAt = checkpoint.lastSuccessfulSyncAt?.toLocal();
    if (lastSuccessfulSyncAt != null &&
        now.difference(lastSuccessfulSyncAt) < autoSyncCooldown) {
      return;
    }
    _autoSyncInFlight = true;
    _lastAutoSyncAt = now;
    try {
      await ref.read(syncStatusProvider.notifier).synchronize(trigger: trigger);
    } finally {
      _autoSyncInFlight = false;
    }
  }
}

class _ChallengeMapRoutePage extends ConsumerWidget {
  const _ChallengeMapRoutePage({this.initialStageId, this.initialSource});

  final String? initialStageId;
  final String? initialSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ChallengeStageProgress>>(
      future: _loadStages(ref),
      builder: (context, snapshot) {
        final stages = snapshot.data;
        if (stages == null) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('闯关地图')),
              body: Center(
                child: Text(
                  UserFacingErrorMapper.message(
                    snapshot.error!,
                    fallbackMessage: '闯关地图加载失败，请稍后重试。',
                  ),
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('闯关地图')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return ChallengeMapPage(
          stages: stages,
          initialStageId: initialStageId,
          initialSource: initialSource,
          onOpenJielong:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PoetryJielongPage(),
                ),
              ),
          onOpenFeihualing:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FeihualingPage()),
              ),
          onOpenDictation:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DictationPage()),
              ),
          onOpenGrowthReport:
              () => Navigator.of(context).pushNamed(
                '/growth-report',
                arguments: StageScopeRouteArgs(stageId: initialStageId),
              ),
        );
      },
    );
  }

  Future<List<ChallengeStageProgress>> _loadStages(WidgetRef ref) async {
    final service = ref.read(challengeProgressServiceProvider);
    final progress =
        await ref.read(learningRepositoryProvider).fetchChallengeModeProgress();
    return service
        .defaultRules()
        .map((rule) {
          final modeProgress = progress[rule.mode];
          return service.evaluate(
            rule: rule,
            bestScore: modeProgress?.bestScore ?? 0,
            completedLines: modeProgress?.completedLines ?? 0,
            totalSessions: modeProgress?.totalSessions ?? 0,
          );
        })
        .toList(growable: false);
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8E2BC), Color(0xFFF8F1E5)],
        ),
      ),
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 64,
                color: Color(0xFFAF6A11),
              ),
              SizedBox(height: 16),
              Text(
                '古诗词学堂',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B3F12),
                ),
              ),
              SizedBox(height: 10),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 16),
              const Text(
                '初始化失败',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('重新初始化')),
            ],
          ),
        ),
      ),
    );
  }
}
