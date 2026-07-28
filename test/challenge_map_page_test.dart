import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/core/service_status.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/repositories/local_learning_repository.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/learning_repository.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/domain/sync/sync_models.dart';
import 'package:gscappall/domain/sync/sync_repository.dart';
import 'package:gscappall/features/game/challenge_map_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';
import 'package:gscappall/services/game/challenge_progress_service.dart';
import 'package:gscappall/services/sync/sync_service.dart';

const _challengeService = ChallengeProgressService();

void main() {
  testWidgets('recent stage record filter tabs report selected segment', (
    tester,
  ) async {
    var selected = RecentStageRecordFilterValue.all;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder:
              (context, setState) => Scaffold(
                body: Center(
                  child: RecentStageRecordFilterTabs(
                    selected: selected,
                    onChanged: (value) => setState(() => selected = value),
                  ),
                ),
              ),
        ),
      ),
    );

    expect(selected, RecentStageRecordFilterValue.all);
    await tester.tap(find.text('\u5206\u6570\u63d0\u5347'));
    await tester.pumpAndSettle();
    expect(selected, RecentStageRecordFilterValue.score);

    await tester.tap(find.text('完成句数'));
    await tester.pumpAndSettle();
    expect(selected, RecentStageRecordFilterValue.lines);
  });

  testWidgets('locks stages until the previous route node is completed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeLearningRepository();
    await tester.pumpChallengeMap(repository);
    expect(find.text('\u0032. \u540c\u97f3\u63a5\u9f99'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('\u0032. \u540c\u97f3\u63a5\u9f99'),
      320,
    );
    await tester.tap(find.text('\u0032. \u540c\u97f3\u63a5\u9f99'));
    await tester.pump();

    expect(
      find.text(
        '\u5148\u5b8c\u6210\u4e0a\u4e00\u5173\uff0c\u624d\u80fd\u89e3\u9501\u8fd9\u4e00\u5173\u3002',
      ),
      findsOneWidget,
    );
  });

  testWidgets('persists reward prompt so reopening completed detail is quiet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rule = _challengeService.defaultRules().first;
    final stage = _challengeService.evaluate(
      rule: rule,
      bestScore: 80,
      completedLines: 3,
      totalSessions: 1,
    );
    final repository = _FakeLearningRepository();

    await tester.pumpDetail(stage, repository);
    await tester.pumpAndSettle();
    expect(find.text('\u95ef\u5173\u5956\u52b1'), findsOneWidget);
    expect(repository.claimedRewardKeys, contains('jielong_entry:2'));
    await tester.tap(find.text('\u77e5\u9053\u4e86'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('查看怎么得星星'), 220);
    await tester.tap(find.text('查看怎么得星星'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开说明'));
    await tester.pumpAndSettle();
    expect(find.text('星级奖励进度'), findsOneWidget);
    expect(find.text('点亮关卡'), findsOneWidget);
    expect(find.text('三星挑战'), findsOneWidget);
    Navigator.of(tester.element(find.text('星星奖励'))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpDetail(stage, repository);
    await tester.pumpAndSettle();

    expect(find.text('\u95ef\u5173\u5956\u52b1'), findsNothing);
  });

  testWidgets('shows mode history in challenge detail', (tester) async {
    final rule = _challengeService.defaultRules().first;
    final stage = _challengeService.evaluate(
      rule: rule,
      bestScore: 80,
      completedLines: 3,
      totalSessions: 1,
    );
    final repository = _FakeLearningRepository(
      claimedRewardKeys: {'jielong_entry:2'},
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 1,
            poemId: 1,
            poemTitle: '\u9759\u591c\u601d',
            poemAuthor: '\u674e\u767d',
            mode: 'poetry_jielong',
            durationMinutes: 8,
            score: 88,
            studiedAt: DateTime(2026, 5, 9, 8),
            stageId: rule.id,
          ),
        ],
      },
    );

    await tester.pumpDetail(stage, repository);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('最近练习'), 220);
    expect(find.text('最近练习'), findsOneWidget);
    expect(find.text('\u9759\u591c\u601d'), findsWidgets);
    expect(find.text('本次练习'), findsWidgets);
    expect(find.textContaining('这次接龙约完成 4 句'), findsWidgets);
    expect(find.textContaining('完成句数'), findsWidgets);
    expect(find.textContaining('分数进步'), findsWidgets);
    expect(find.text('\u0038\u0038 \u5206'), findsOneWidget);
    expect(find.text('查看相关记录'), findsWidgets);
    expect(find.text('查看练习记录'), findsWidgets);
  });

  testWidgets('refreshes route stars after returning from practice', (
    tester,
  ) async {
    final repository = _FakeLearningRepository();
    var openedPractice = false;

    await tester.pumpChallengeMap(
      repository,
      onOpenJielong: () async {
        openedPractice = true;
        repository
            .progressByMode['poetry_jielong'] = const ChallengeModeProgress(
          mode: 'poetry_jielong',
          totalSessions: 1,
          bestScore: 80,
          completedLines: 3,
        );
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('\u0031. \u63a5\u9f99\u5165\u95e8'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('\u5f00\u59cb\u7ec3\u4e60'), 220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u5f00\u59cb\u7ec3\u4e60'));
    await tester.pumpAndSettle();

    expect(openedPractice, isTrue);
    expect(find.textContaining('\u5df2\u70b9\u4eae'), findsWidgets);
    expect(find.textContaining('本次练习已记录'), findsWidgets);
    expect(find.textContaining('星级提升 +2 星'), findsWidgets);
    expect(find.textContaining('最好成绩 +80 分'), findsWidgets);
    expect(find.textContaining('完成句数 +3'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('星级提升 +2 星'), findsNothing);
  });

  testWidgets('manual refresh explains discovered route changes', (
    tester,
  ) async {
    final repository = _FakeLearningRepository();

    await tester.pumpChallengeMap(repository);
    await tester.pumpAndSettle();

    repository.progressByMode['poetry_jielong'] = const ChallengeModeProgress(
      mode: 'poetry_jielong',
      totalSessions: 1,
      bestScore: 72,
      completedLines: 2,
    );
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('手动刷新发现变化'), findsWidgets);
    expect(find.textContaining('最好成绩 +72 分'), findsWidgets);
    expect(find.textContaining('完成句数 +2'), findsWidgets);
  });

  testWidgets('sync replay refresh explains remotely restored progress', (
    tester,
  ) async {
    final repository = _FakeLearningRepository();
    final syncLocalRepository = _FakeSyncLocalRepository();
    final syncService = _FakeSyncService(
      onSynchronize: ({required trigger}) {
        repository
            .progressByMode['poetry_jielong'] = const ChallengeModeProgress(
          mode: 'poetry_jielong',
          totalSessions: 1,
          bestScore: 76,
          completedLines: 2,
        );
        final now = DateTime.utc(2026, 5, 11, 9, 30);
        return SyncRunReport(
          state: SyncRunState.success,
          startedAt: now,
          finishedAt: now.add(const Duration(milliseconds: 120)),
          pushedCounts: const {},
          pulledCounts: const {
            SyncResourceType.learningRecords: 1,
            SyncResourceType.challengeStageRewards: 1,
          },
          conflicts: const [],
          checkpoint: SyncCheckpoint(lastSuccessfulSyncAt: now),
          trigger: trigger,
        );
      },
    );

    await tester.pumpChallengeMap(
      repository,
      syncLocalRepository: syncLocalRepository,
      syncService: syncService,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChallengeMapPage)),
    );
    await container
        .read(syncStatusProvider.notifier)
        .synchronize(trigger: SyncRunTrigger.foregroundAuto);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('进度已更新'), findsWidgets);
    expect(find.text('更新记录'), findsWidgets);
    expect(find.text('本次提升'), findsWidgets);
    expect(find.textContaining('学习记录已更新 1 条'), findsWidgets);
    expect(find.textContaining('星星奖励已更新 1 条'), findsWidgets);
    expect(find.textContaining('最好成绩 +76 分'), findsWidgets);
    expect(find.textContaining('完成句数 +2'), findsWidgets);
    expect(find.textContaining('本次练习已记录'), findsNothing);
  });

  testWidgets('sync replay details distinguish reports and wrong questions', (
    tester,
  ) async {
    final repository = _FakeLearningRepository();
    final syncLocalRepository = _FakeSyncLocalRepository();
    final syncService = _FakeSyncService(
      onSynchronize: ({required trigger}) {
        repository
            .progressByMode['poetry_jielong'] = const ChallengeModeProgress(
          mode: 'poetry_jielong',
          totalSessions: 3,
          bestScore: 82,
          completedLines: 3,
        );
        final now = DateTime.utc(2026, 5, 11, 10, 30);
        return SyncRunReport(
          state: SyncRunState.success,
          startedAt: now,
          finishedAt: now.add(const Duration(milliseconds: 120)),
          pushedCounts: const {},
          pulledCounts: const {
            SyncResourceType.practiceReports: 2,
            SyncResourceType.wrongQuestions: 1,
          },
          conflicts: const [],
          checkpoint: SyncCheckpoint(lastSuccessfulSyncAt: now),
          trigger: trigger,
        );
      },
    );

    await tester.pumpChallengeMap(
      repository,
      syncLocalRepository: syncLocalRepository,
      syncService: syncService,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChallengeMapPage)),
    );
    await container
        .read(syncStatusProvider.notifier)
        .synchronize(trigger: SyncRunTrigger.foregroundAuto);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('进度已更新'), findsWidgets);
    expect(find.textContaining('练习报告已更新 2 条'), findsWidgets);
    expect(find.textContaining('错题记录已更新 1 条'), findsWidgets);
    expect(find.textContaining('最好成绩 +82 分'), findsWidgets);
  });

  testWidgets('stage detail opens latest contributing learning record', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rule = _challengeService.defaultRules().first;
    final stage = _challengeService.evaluate(
      rule: rule,
      bestScore: 88,
      completedLines: 3,
      totalSessions: 1,
    );
    final repository = _FakeLearningRepository(
      claimedRewardKeys: {'${rule.id}:2'},
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 42,
            poemId: 1,
            poemTitle: '\u9759\u591c\u601d',
            poemAuthor: '\u674e\u767d',
            mode: 'poetry_jielong',
            durationMinutes: 8,
            score: 88,
            studiedAt: DateTime(2026, 5, 9, 8),
            stageId: rule.id,
          ),
          LearningRecord(
            id: 41,
            poemId: 2,
            poemTitle: '\u6625\u6653',
            poemAuthor: '\u5b5f\u6d69\u7136',
            mode: 'poetry_jielong',
            durationMinutes: 6,
            score: 82,
            studiedAt: DateTime(2026, 5, 8, 8),
            stageId: rule.id,
          ),
          LearningRecord(
            id: 40,
            poemId: 3,
            poemTitle: '\u767b\u9e73\u96c0\u697c',
            poemAuthor: '\u738b\u4e4b\u6da3',
            mode: 'poetry_jielong',
            durationMinutes: 4,
            score: 78,
            studiedAt: DateTime(2026, 5, 7, 8),
            stageId: rule.id,
          ),
        ],
      },
    );
    final pushedSettings = <RouteSettings>[];

    await tester.pumpDetail(
      stage,
      repository,
      onGenerateRoute: (settings) {
        pushedSettings.add(settings);
        final args = StageScopeRouteArgs.fromSettings(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder:
              (_) => Scaffold(
                body: Text(
                  '${settings.name}:${args?.learningRecordId}:${args?.stageId}',
                ),
              ),
        );
      },
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('\u767b\u9e73\u96c0\u697c').last,
      220,
    );
    expect(find.text('最近练习'), findsOneWidget);
    expect(find.text('\u9759\u591c\u601d'), findsWidgets);
    expect(find.text('\u6625\u6653'), findsWidgets);
    expect(find.text('\u767b\u9e73\u96c0\u697c'), findsWidgets);

    await tester.tap(find.text('查看练习记录').first);
    await tester.pumpAndSettle();

    expect(pushedSettings.last.name, '/learning-record-detail');
    final args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(args?.learningRecordId, 42);
    expect(args?.stageId, rule.id);
    expect(find.text('/learning-record-detail:42:${rule.id}'), findsOneWidget);
  });

  testWidgets('shows chapter completion summary on challenge map', (
    tester,
  ) async {
    final repository = _FakeLearningRepository();
    repository.progressByMode['poetry_jielong'] = const ChallengeModeProgress(
      mode: 'poetry_jielong',
      totalSessions: 1,
      bestScore: 80,
      completedLines: 3,
    );

    await tester.pumpChallengeMap(repository);
    await tester.pumpAndSettle();

    expect(find.textContaining('章节完成度'), findsWidgets);
    expect(find.textContaining('星'), findsWidgets);
    expect(find.textContaining('章节已通关'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('shows source hint when map opens from backup log', (
    tester,
  ) async {
    final repository = _FakeLearningRepository();

    await tester.pumpChallengeMap(
      repository,
      initialStageId: 'jielong_entry',
      initialSource: 'sync-log',
    );
    await tester.pumpAndSettle();

    expect(find.text('已找到相关进度'), findsWidgets);
    expect(find.textContaining('已找到 接龙入门'), findsWidgets);
    expect(find.textContaining('相关进度会在地图中短暂高亮'), findsWidgets);
    expect(find.textContaining('接龙入门'), findsWidgets);
  });

  testWidgets('chapter detail shows recommendation rewards and history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rules = _challengeService
        .defaultRules()
        .where((rule) => rule.mode == 'poetry_jielong')
        .take(2)
        .toList(growable: false);
    final stages = [
      _challengeService.evaluate(
        rule: rules.first,
        bestScore: 80,
        completedLines: 3,
        totalSessions: 1,
      ),
      _challengeService.evaluate(
        rule: rules.last,
        bestScore: 0,
        completedLines: 0,
      ),
    ];
    final repository = _FakeLearningRepository(
      claimedRewardKeys: {
        '${rules.first.id}:2',
        '${rules.last.id}:1',
        'chapter:基础路线 · 接龙路线:1',
      },
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 1,
            poemId: 1,
            poemTitle: '\u9759\u591c\u601d',
            poemAuthor: '\u674e\u767d',
            mode: 'poetry_jielong',
            durationMinutes: 5,
            score: 80,
            studiedAt: DateTime(2026, 5, 11, 8),
            stageId: rules.first.id,
          ),
          LearningRecord(
            id: 2,
            poemId: 2,
            poemTitle: '\u6625\u6653',
            poemAuthor: '\u5b5f\u6d69\u7136',
            mode: 'poetry_jielong',
            durationMinutes: 8,
            score: 90,
            studiedAt: DateTime(2026, 5, 12, 8),
            stageId: rules.last.id,
          ),
        ],
      },
    );
    String? continuedMode;

    await tester.pumpChapterDetail(
      stages,
      repository,
      initialStageId: rules.first.id,
      onStartPractice: (mode) async => continuedMode = mode,
    );
    await tester.pumpAndSettle();

    expect(find.text('当前聚焦关卡'), findsOneWidget);
    expect(find.textContaining('继续练这一关'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('继续练这一关'), 120);
    await tester.tap(find.textContaining('继续练这一关'));
    await tester.pumpAndSettle();
    expect(continuedMode, 'poetry_jielong');
    expect(find.text('最近练习'), findsWidgets);
    expect(find.text('最近练习变化'), findsWidgets);
    expect(find.textContaining('最高分'), findsWidgets);
    expect(find.textContaining('完成句数'), findsWidgets);
    await tester.scrollUntilVisible(find.text('章节路线'), 220);
    expect(find.text('章节路线'), findsOneWidget);
    await tester.tap(find.text('展开路线'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('路线节点状态'), 220);
    expect(find.text('路线节点状态'), findsOneWidget);
    expect(find.textContaining('已点亮'), findsWidgets);
    expect(find.textContaining('待解锁'), findsWidgets);
    await tester.scrollUntilVisible(find.text('推荐练习'), 220);
    expect(find.text('推荐练习'), findsOneWidget);
    expect(find.text('同音接龙'), findsWidgets);
    expect(find.text('还差 3 星到三星'), findsOneWidget);
    expect(find.text('最好 0/85 分，优先提分'), findsOneWidget);
    expect(find.text('完成 0/4 句，先补完成量'), findsOneWidget);
    expect(find.text('开始接龙练习'), findsOneWidget);
    continuedMode = null;
    await tester.tap(find.text('开始接龙练习'));
    await tester.pumpAndSettle();
    expect(continuedMode, 'poetry_jielong');
    await tester.scrollUntilVisible(find.text('星星奖励'), 220);
    expect(find.text('星星奖励'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('更多练习'), 220);
    expect(find.text('更多练习'), findsOneWidget);
    await tester.tap(find.text('查看练过的内容'));
    await tester.pumpAndSettle();
    expect(find.textContaining('关卡：接龙入门'), findsWidgets);
    expect(find.textContaining('80 分'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('当前关卡'), 360);
    await tester.ensureVisible(find.text('当前关卡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前关卡'));
    await tester.pumpAndSettle();
    expect(find.text('静夜思'), findsWidgets);
    expect(find.text('春晓'), findsNothing);
    await tester.scrollUntilVisible(find.text('本关复习').last, 220);
    expect(find.text('本关复习'), findsWidgets);
    await tester.tap(find.text('展开本关记录').last);
    await tester.pumpAndSettle();
    expect(find.text('本关错题'), findsWidgets);
    expect(find.text('练习结果'), findsWidgets);
    expect(find.text('\u9759\u591c\u601d'), findsWidgets);
  });

  testWidgets('chapter recommendation prioritizes real unreviewed wrongs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rules = _challengeService.defaultRules();
    final jielong = rules.firstWhere((rule) => rule.id == 'jielong_entry');
    final dictation = rules.firstWhere(
      (rule) => rule.id == 'dictation_checkpoint',
    );
    final stages = [
      _challengeService.evaluate(
        rule: jielong,
        bestScore: 70,
        completedLines: 3,
        totalSessions: 1,
      ),
      _challengeService.evaluate(
        rule: dictation,
        bestScore: 76,
        completedLines: 0,
        totalSessions: 0,
      ),
    ];
    String? continuedMode;

    await tester.pumpChapterDetail(
      stages,
      _FakeLearningRepository(),
      onStartPractice: (mode) async => continuedMode = mode,
      practiceRepository: _FakePracticeRepository(
        unreviewedWrongCounts: const {'dictation_checkpoint': 4},
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('推荐练习'), 220);
    expect(find.text('听写关卡'), findsWidgets);
    expect(find.text('未改善错题 4 个，优先复盘'), findsOneWidget);
    expect(find.text('开始听写复盘'), findsOneWidget);

    final startButton = find.widgetWithText(FilledButton, '开始听写复盘');
    await tester.ensureVisible(startButton);
    await tester.pump();
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(continuedMode, 'dictation');
  });

  testWidgets('chapter detail shows source hint from growth report', (
    tester,
  ) async {
    final rules = _challengeService
        .defaultRules()
        .where((rule) => rule.mode == 'poetry_jielong')
        .take(2)
        .toList(growable: false);
    final stages = [
      _challengeService.evaluate(
        rule: rules.first,
        bestScore: 80,
        completedLines: 3,
        totalSessions: 1,
      ),
      _challengeService.evaluate(
        rule: rules.last,
        bestScore: 0,
        completedLines: 0,
      ),
    ];
    final repository = _FakeLearningRepository(
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 7,
            poemId: 1,
            poemTitle: '静夜思',
            poemAuthor: '李白',
            mode: 'poetry_jielong',
            durationMinutes: 6,
            score: 88,
            studiedAt: DateTime(2026, 5, 21, 8),
            stageId: rules.first.id,
          ),
        ],
      },
    );

    await tester.pumpChapterDetail(
      stages,
      repository,
      initialStageId: rules.first.id,
      initialSource: 'growth-report',
    );
    await tester.pumpAndSettle();

    expect(find.text('已帮你找到这一关'), findsWidgets);
    expect(find.textContaining('已帮你找到 接龙入门'), findsWidgets);
    expect(find.text('当前关卡与最近练习'), findsOneWidget);
    expect(find.text('最近练习'), findsWidgets);
    expect(find.text('最近练习变化'), findsWidgets);
    expect(find.text('静夜思'), findsWidgets);
    await tester.scrollUntilVisible(find.text('章节路线'), 360);
    expect(find.text('章节路线'), findsOneWidget);
    await tester.tap(find.text('展开路线'));
    await tester.pumpAndSettle();
    expect(find.text('章节路线连接'), findsOneWidget);
    expect(find.text('路线节点状态'), findsOneWidget);
  });

  testWidgets('chapter recent record actions keep stage scope', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rules = _challengeService
        .defaultRules()
        .where((rule) => rule.mode == 'poetry_jielong')
        .take(2)
        .toList(growable: false);
    final stages = [
      _challengeService.evaluate(
        rule: rules.first,
        bestScore: 88,
        completedLines: 3,
        totalSessions: 1,
      ),
      _challengeService.evaluate(
        rule: rules.last,
        bestScore: 0,
        completedLines: 0,
      ),
    ];
    final repository = _FakeLearningRepository(
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 7,
            poemId: 1,
            poemTitle: '静夜思',
            poemAuthor: '李白',
            mode: 'poetry_jielong',
            durationMinutes: 6,
            score: 88,
            studiedAt: DateTime(2026, 5, 21, 8),
            stageId: rules.first.id,
          ),
        ],
      },
    );
    final pushedSettings = <RouteSettings>[];

    await tester.pumpChapterDetail(
      stages,
      repository,
      initialStageId: rules.first.id,
      initialSource: 'growth-report',
      onGenerateRoute: (settings) {
        pushedSettings.add(settings);
        final args = StageScopeRouteArgs.fromSettings(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder:
              (_) => Scaffold(
                body: Text(
                  '${settings.name}:${args?.learningRecordId}:${args?.stageId}:${args?.source}',
                ),
              ),
        );
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('分数提升'), findsWidgets);
    expect(find.text('完成句数'), findsWidgets);
    await tester.tap(find.text('分数提升').first);
    await tester.pumpAndSettle();
    expect(find.text('静夜思'), findsWidgets);
    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('88').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('88').first);
    await tester.pumpAndSettle();
    var args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/learning-record-detail');
    expect(args?.learningRecordId, 7);
    expect(args?.stageId, rules.first.id);
    expect(args?.source, 'chapter-detail');

    Navigator.of(
      tester.element(
        find.text('/learning-record-detail:7:${rules.first.id}:chapter-detail'),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('查看练习记录').first, 220);
    await tester.tap(find.text('查看练习记录').first);
    await tester.pumpAndSettle();
    args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/learning-record-detail');
    expect(args?.learningRecordId, 7);
    expect(args?.stageId, rules.first.id);
    expect(args?.source, 'chapter-detail');

    Navigator.of(
      tester.element(
        find.text('/learning-record-detail:7:${rules.first.id}:chapter-detail'),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('已回到'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pumpAndSettle();
    expect(find.textContaining('已回到'), findsNothing);

    await tester.tap(find.text('查看练习结果').first);
    await tester.pumpAndSettle();
    args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/practice-reports');
    expect(args?.stageId, rules.first.id);
    expect(args?.source, 'chapter-detail');

    Navigator.of(
      tester.element(
        find.text('/practice-reports:null:${rules.first.id}:chapter-detail'),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('已回到'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看错题').first);
    await tester.pumpAndSettle();
    args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/wrong-book');
    expect(args?.stageId, rules.first.id);
    expect(args?.source, 'chapter-detail');

    Navigator.of(
      tester.element(
        find.text('/wrong-book:null:${rules.first.id}:chapter-detail'),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('已回到'), findsOneWidget);
  });

  testWidgets('chapter recent record filters show clear empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rule =
        _challengeService
            .defaultRules()
            .where((rule) => rule.mode == 'poetry_jielong')
            .first;
    final stages = [
      _challengeService.evaluate(rule: rule, bestScore: 0, completedLines: 0),
    ];
    final repository = _FakeLearningRepository(
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 21,
            poemId: 1,
            poemTitle: '静夜思',
            poemAuthor: '李白',
            mode: 'practice',
            durationMinutes: 3,
            score: null,
            studiedAt: DateTime(2026, 5, 21, 8),
            stageId: rule.id,
          ),
        ],
      },
    );
    String? continuedMode;

    await tester.pumpChapterDetail(
      stages,
      repository,
      initialStageId: rule.id,
      initialSource: 'growth-report',
      onStartPractice: (mode) async => continuedMode = mode,
    );
    await tester.pumpAndSettle();

    expect(find.text('全部练习 · 1 条'), findsWidgets);
    expect(find.text('继续练这一关'), findsNothing);
    await tester.tap(find.text('分数提升').first);
    await tester.pumpAndSettle();
    expect(find.text('去做一次练习'), findsOneWidget);
    expect(find.text('先练一次'), findsOneWidget);
    expect(find.text('看全部练习'), findsOneWidget);
    expect(find.text('回到这一关的全部练习'), findsOneWidget);
    await tester.tap(find.text('去做一次练习'));
    await tester.pumpAndSettle();
    expect(continuedMode, 'poetry_jielong');

    await tester.tap(find.text('看全部练习'));
    await tester.pumpAndSettle();

    expect(find.text('全部练习 · 1 条'), findsWidgets);
    expect(find.text('看全部练习'), findsNothing);
  });

  testWidgets(
    'chapter recent record shows helpful empty state without records',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rule =
          _challengeService
              .defaultRules()
              .where((rule) => rule.mode == 'poetry_jielong')
              .first;
      final stages = [
        _challengeService.evaluate(rule: rule, bestScore: 0, completedLines: 0),
      ];
      String? continuedMode;

      await tester.pumpChapterDetail(
        stages,
        _FakeLearningRepository(),
        initialStageId: rule.id,
        initialSource: 'growth-report',
        onStartPractice: (mode) async => continuedMode = mode,
      );
      await tester.pumpAndSettle();

      expect(find.text('本关还没有练习记录'), findsWidgets);
      expect(find.textContaining('最近练了什么'), findsWidgets);
      expect(find.text('继续练这一关'), findsWidgets);
      await tester.tap(find.text('继续练这一关').first);
      await tester.pumpAndSettle();
      expect(continuedMode, 'poetry_jielong');
    },
  );

  test('chapter history filters by exact stage id', () async {
    final rules = _challengeService
        .defaultRules()
        .where((rule) => rule.mode == 'poetry_jielong')
        .take(2)
        .toList(growable: false);
    final repository = _FakeLearningRepository(
      historyByMode: {
        'poetry_jielong': [
          LearningRecord(
            id: 1,
            poemId: 1,
            poemTitle: '\u9759\u591c\u601d',
            poemAuthor: '\u674e\u767d',
            mode: 'poetry_jielong',
            durationMinutes: 5,
            score: 80,
            studiedAt: DateTime(2026, 5, 11, 8),
            stageId: rules.first.id,
          ),
          LearningRecord(
            id: 2,
            poemId: 2,
            poemTitle: '\u6625\u6653',
            poemAuthor: '\u5b5f\u6d69\u7136',
            mode: 'poetry_jielong',
            durationMinutes: 8,
            score: 90,
            studiedAt: DateTime(2026, 5, 12, 8),
            stageId: rules.last.id,
          ),
        ],
      },
    );

    final entryHistory = await repository.fetchChallengeModeHistory(
      mode: 'poetry_jielong',
      stageId: rules.first.id,
    );
    final advancedHistory = await repository.fetchChallengeModeHistory(
      mode: 'poetry_jielong',
      stageId: rules.last.id,
    );

    expect(entryHistory.map((record) => record.poemTitle), [
      '\u9759\u591c\u601d',
    ]);
    expect(advancedHistory.map((record) => record.poemTitle), ['\u6625\u6653']);
  });

  testWidgets('chapter reward is persisted and does not repeat', (
    tester,
  ) async {
    final rules = _challengeService
        .defaultRules()
        .where((rule) => rule.mode == 'poetry_jielong')
        .take(2)
        .toList(growable: false);
    final stages = [
      _challengeService.evaluate(
        rule: rules.first,
        bestScore: 80,
        completedLines: 3,
        totalSessions: 1,
      ),
      _challengeService.evaluate(
        rule: rules.last,
        bestScore: 80,
        completedLines: 6,
        totalSessions: 2,
      ),
    ];
    final repository = _FakeLearningRepository();

    await tester.pumpChapterDetail(stages, repository);
    await tester.pumpAndSettle();

    expect(find.text('\u7ae0\u8282\u901a\u5173\u5956\u52b1'), findsOneWidget);
    expect(repository.claimedRewardKeys, contains('chapter:基础路线 · 接龙路线:1'));

    await tester.tap(find.text('\u77e5\u9053\u4e86'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpChapterDetail(stages, repository);
    await tester.pumpAndSettle();

    expect(find.text('\u7ae0\u8282\u901a\u5173\u5956\u52b1'), findsNothing);
  });

  test('local repository persists claimed challenge reward keys', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = LocalLearningRepository(database: database);
    addTearDown(database.close);
    await database.ensureDefaults();
    await database.replaceSeed(poems: [_poem], seedVersion: 'test');

    expect(
      await repository.markChallengeRewardClaimed(
        stageId: 'jielong_entry',
        stars: 1,
      ),
      isTrue,
    );
    expect(
      await repository.markChallengeRewardClaimed(
        stageId: 'jielong_entry',
        stars: 1,
      ),
      isFalse,
    );
    expect(
      await repository.fetchClaimedChallengeRewardKeys(),
      contains('jielong_entry:1'),
    );
    expect(
      await repository.markChallengeRewardClaimed(
        stageId: 'chapter:基础路线 · 接龙路线',
        stars: 1,
      ),
      isTrue,
    );
    expect(
      await repository.markChallengeRewardClaimed(
        stageId: 'chapter:基础路线 · 接龙路线',
        stars: 1,
      ),
      isFalse,
    );
    expect(
      await repository.fetchClaimedChallengeRewardKeys(),
      contains('chapter:基础路线 · 接龙路线:1'),
    );
  });

  test(
    'local repository filters challenge history by exact stage id',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = LocalLearningRepository(database: database);
      addTearDown(database.close);
      await database.ensureDefaults();
      await database.replaceSeed(poems: [_poem], seedVersion: 'test');

      await repository.logLearningRecord(
        poemId: _poem.id,
        mode: 'poetry_jielong',
        score: 80,
        stageId: 'jielong_entry',
      );
      await repository.logLearningRecord(
        poemId: _poem.id,
        mode: 'poetry_jielong',
        score: 92,
        stageId: 'jielong_master',
      );

      final allHistory = await repository.fetchChallengeModeHistory(
        mode: 'poetry_jielong',
      );
      final masterHistory = await repository.fetchChallengeModeHistory(
        mode: 'poetry_jielong',
        stageId: 'jielong_master',
      );

      expect(allHistory, hasLength(2));
      expect(masterHistory, hasLength(1));
      expect(masterHistory.single.stageId, 'jielong_master');
      expect(masterHistory.single.score, 92);
    },
  );

  test('challenge rules include extended P3 routes for all game modes', () {
    final rules = _challengeService.defaultRules();

    expect(rules.map((rule) => rule.id), contains('jielong_master'));
    expect(rules.map((rule) => rule.id), contains('feihualing_speed'));
    expect(rules.map((rule) => rule.id), contains('dictation_review'));
    expect(
      rules.map((rule) => rule.chapter),
      containsAll(['基础路线', '进阶路线', '复盘路线']),
    );
    expect(
      rules.where((rule) => rule.mode == 'poetry_jielong'),
      hasLength(greaterThanOrEqualTo(3)),
    );
    expect(
      rules.where((rule) => rule.mode == 'feihualing'),
      hasLength(greaterThanOrEqualTo(3)),
    );
    expect(
      rules.where((rule) => rule.mode == 'dictation'),
      hasLength(greaterThanOrEqualTo(2)),
    );
  });

  testWidgets('challenge map stage scope routes carry stage args', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeLearningRepository();
    final pushedSettings = <RouteSettings>[];
    final stages = _challengeService
        .defaultRules()
        .where((rule) => rule.mode == 'poetry_jielong')
        .take(2)
        .map(
          (rule) => _challengeService.evaluate(
            rule: rule,
            bestScore: 0,
            completedLines: 0,
            totalSessions: 0,
          ),
        )
        .toList(growable: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: ChallengeChapterDetailPage(
            title: 'route-test',
            stages: stages,
            initialStageId: 'jielong_entry',
            onStartPractice: (_) async {},
          ),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            final stageId = StageScopeRouteArgs.fromSettings(settings)?.stageId;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('${settings.name}:$stageId')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('本关复习').first, 220);
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开本关记录').first);
    await tester.pumpAndSettle();
    final reportButton = find.text('练习结果').first;
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    expect(pushedSettings.last.name, '/practice-reports');
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.stageId,
      'jielong_entry',
    );
    expect(find.text('/practice-reports:jielong_entry'), findsOneWidget);
  });
}

extension on WidgetTester {
  Future<void> pumpChallengeMap(
    _FakeLearningRepository repository, {
    Future<void> Function()? onOpenJielong,
    String? initialStageId,
    String? initialSource,
    SyncLocalRepository? syncLocalRepository,
    SyncService? syncService,
  }) {
    final stages = _challengeService
        .defaultRules()
        .map((rule) {
          final progress = repository.progressByMode[rule.mode];
          return _challengeService.evaluate(
            rule: rule,
            bestScore: progress?.bestScore ?? 0,
            completedLines: progress?.completedLines ?? 0,
            totalSessions: progress?.totalSessions ?? 0,
          );
        })
        .toList(growable: false);
    return pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWithValue(repository),
          syncLocalRepositoryProvider.overrideWithValue(
            syncLocalRepository ?? _FakeSyncLocalRepository(),
          ),
          if (syncService != null)
            syncServiceProvider.overrideWithValue(syncService),
        ],
        child: MaterialApp(
          home: ChallengeMapPage(
            stages: stages,
            initialStageId: initialStageId,
            initialSource: initialSource,
            onOpenJielong: onOpenJielong ?? () async {},
            onOpenFeihualing: () async {},
            onOpenDictation: () async {},
          ),
        ),
      ),
    );
  }

  Future<void> pumpDetail(
    ChallengeStageProgress stage,
    _FakeLearningRepository repository, {
    RouteFactory? onGenerateRoute,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          onGenerateRoute: onGenerateRoute,
          home: ChallengeStageDetailPage(
            stage: stage,
            onStartPractice: () async {},
          ),
        ),
      ),
    );
  }

  Future<void> pumpChapterDetail(
    List<ChallengeStageProgress> stages,
    _FakeLearningRepository repository, {
    String? initialStageId,
    String? initialSource,
    Future<void> Function(String mode)? onStartPractice,
    Route<dynamic>? Function(RouteSettings settings)? onGenerateRoute,
    PracticeRepository? practiceRepository,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWithValue(repository),
          practiceRepositoryProvider.overrideWithValue(
            practiceRepository ?? _FakePracticeRepository(),
          ),
        ],
        child: MaterialApp(
          onGenerateRoute: onGenerateRoute,
          home: ChallengeChapterDetailPage(
            title: '基础路线 · 接龙路线',
            stages: stages,
            initialStageId: initialStageId,
            initialSource: initialSource,
            onStartPractice: onStartPractice ?? (_) async {},
          ),
        ),
      ),
    );
  }
}

typedef _FakeSyncRunFactory =
    SyncRunReport Function({required SyncRunTrigger trigger});

class _FakeSyncService implements SyncService {
  const _FakeSyncService({required _FakeSyncRunFactory onSynchronize})
    : _onSynchronize = onSynchronize;

  final _FakeSyncRunFactory _onSynchronize;

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.available,
    message: 'fake sync service',
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
    return _onSynchronize(trigger: trigger);
  }
}

class _FakeSyncLocalRepository implements SyncLocalRepository {
  SyncCheckpoint checkpoint = const SyncCheckpoint();
  final List<SyncRunLogEntry> logs = [];

  @override
  Future<void> acknowledgePushedChanges({
    required SyncEnvelope envelope,
    required SyncPushResult result,
  }) async {}

  @override
  Future<void> applyRemoteEnvelope(SyncEnvelope envelope) async {}

  @override
  Future<void> clearFailedSyncRunLogs() async {}

  @override
  Future<SyncEnvelope> collectPendingChanges({
    SyncRunOptions options = const SyncRunOptions(),
  }) async {
    return SyncEnvelope.empty();
  }

  @override
  Future<List<SyncRunLogEntry>> fetchSyncRunLogs({
    int limit = 10,
    int offset = 0,
    SyncRunState? state,
    DateTime? startedAfter,
    DateTime? startedBefore,
  }) async {
    return logs.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<SyncCheckpoint> loadCheckpoint() async => checkpoint;

  @override
  Future<Map<SyncResourceType, int>> pendingCounts() async => const {};

  @override
  Future<void> persistCheckpoint(SyncCheckpoint checkpoint) async {
    this.checkpoint = checkpoint;
  }

  @override
  Future<void> pruneSyncRunLogs({int retain = 100}) async {
    if (logs.length <= retain) {
      return;
    }
    logs.removeRange(retain, logs.length);
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
    logs.insert(
      0,
      SyncRunLogEntry(
        id: logs.length + 1,
        state: state,
        startedAt: startedAt,
        finishedAt: finishedAt,
        pushedCount: pushedCount,
        pulledCount: pulledCount,
        conflictCount: conflictCount,
        trigger: trigger,
        errorMessage: errorMessage,
        notes: notes,
        createdAt: DateTime.utc(2026, 5, 11, 9, 31),
      ),
    );
  }
}

class _FakePracticeRepository implements PracticeRepository {
  _FakePracticeRepository({Map<String, int>? unreviewedWrongCounts})
    : unreviewedWrongCounts = unreviewedWrongCounts ?? const {};

  final Map<String, int> unreviewedWrongCounts;

  @override
  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  }) async {
    final stageId = query.stageId;
    if (!query.onlyUnreviewed || stageId == null) {
      return const [];
    }
    final count = unreviewedWrongCounts[stageId] ?? 0;
    return List.generate(
      count,
      (index) => WrongQuestionEntry(
        id: index + 1,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        questionType: PracticeMode.dictation,
        prompt: '错题 ${index + 1}',
        correctAnswer: '床前明月光',
        userAnswer: '床前月光',
        mistakeType: PracticeMistakeType.missingCharacters,
        severity: 'medium',
        createdAt: DateTime(2026, 5, 21, 8),
        stageId: stageId,
      ),
    );
  }

  @override
  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id) async => null;

  @override
  Future<void> markWrongQuestionReviewed(int id) async {}

  @override
  Future<PracticeReport> completeSession({
    required PracticeSession session,
    required Map<int, String> answers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeSession> createSession({
    required PracticeMode mode,
    int? poemId,
    DictationDifficulty difficulty = DictationDifficulty.standard,
    DictationAnswerMode answerMode = DictationAnswerMode.fullText,
  }) {
    throw UnimplementedError();
  }

  @override
  PracticeLineResult evaluateAnswer({
    required PracticeQuestion question,
    required String answer,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Poem>> fetchPracticePoems({int limit = 60}) async => const [];

  @override
  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id) async => null;

  @override
  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PracticeReportSummary>> fetchPracticeReportSummaries({
    int limit = 100,
  }) async => const [];

  @override
  Future<PracticeReport> saveAssessmentReport({
    required Poem poem,
    required PracticeMode mode,
    required List<PracticeLineResult> results,
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }
}

class _FakeLearningRepository implements LearningRepository {
  _FakeLearningRepository({
    Set<String>? claimedRewardKeys,
    Map<String, List<LearningRecord>>? historyByMode,
  }) : claimedRewardKeys = claimedRewardKeys ?? <String>{},
       historyByMode = historyByMode ?? <String, List<LearningRecord>>{};

  final Set<String> claimedRewardKeys;
  final Map<String, List<LearningRecord>> historyByMode;
  final Map<String, ChallengeModeProgress> progressByMode = {};

  @override
  Future<Map<String, ChallengeModeProgress>>
  fetchChallengeModeProgress() async {
    return progressByMode;
  }

  @override
  Future<List<LearningRecord>> fetchChallengeModeHistory({
    required String mode,
    int limit = 10,
    String? stageId,
  }) async {
    final records = historyByMode[mode] ?? const <LearningRecord>[];
    final filtered =
        stageId == null
            ? records
            : records.where((record) => record.stageId == stageId);
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<Set<String>> fetchClaimedChallengeRewardKeys() async {
    return claimedRewardKeys;
  }

  @override
  Future<bool> markChallengeRewardClaimed({
    required String stageId,
    required int stars,
  }) async {
    final key = '$stageId:$stars';
    if (stars <= 0 || claimedRewardKeys.contains(key)) {
      return false;
    }
    claimedRewardKeys.add(key);
    return true;
  }

  @override
  Future<bool> awardActivityPoints({
    required String activityType,
    required int points,
  }) async {
    return false;
  }

  @override
  Future<void> completeDailyPoem(DateTime date) async {}

  @override
  Future<List<DailyPoemHistoryEntry>> fetchDailyPoemHistory({
    int limit = 14,
  }) async {
    return const [];
  }

  @override
  Future<DailyPoemProgress> fetchDailyPoemProgress({DateTime? date}) async {
    return const DailyPoemProgress(
      totalPoints: 0,
      currentPoints: 0,
      totalCheckIns: 0,
      consecutiveDays: 0,
      todayCompleted: false,
      todayPoints: 0,
      todayReviewCount: 0,
    );
  }

  @override
  Future<LearningGrowthReport> fetchGrowthReport({
    GrowthReportPeriod period = GrowthReportPeriod.weekly,
  }) {
    return Future.value(
      LearningGrowthReport(
        period: period,
        startAt: DateTime.utc(2026, 5, 5),
        endAt: DateTime.utc(2026, 5, 11),
        totalSessions: 0,
        totalMinutes: 0,
        uniquePoems: 0,
        averageScore: null,
        dailyPoemCompletions: 0,
        studyCardReviews: 0,
        practiceReportCount: 0,
        wrongQuestionCount: 0,
        reviewedWrongQuestionCount: 0,
        activeDays: 0,
        longestLearningStreak: 0,
        previousWrongQuestionCount: 0,
        previousReviewedWrongQuestionCount: 0,
        previousAverageScore: null,
        modeStats: const [],
        previousModeStats: const [],
        stageStats: const [],
        previousStageStats: const [],
        scoreTrend: const [],
      ),
    );
  }

  @override
  Future<List<LearningRecord>> fetchRecentRecords({int limit = 12}) async {
    return const [];
  }

  @override
  Future<LearningSummary> fetchSummary() async {
    return const LearningSummary(
      totalLearnedPoems: 0,
      totalFavorites: 0,
      totalMinutes: 0,
      streakDays: 0,
      dailyPoemCompleted: false,
    );
  }

  @override
  Future<StudyCardFilterOptions> fetchStudyCardFilterOptions() {
    throw UnimplementedError();
  }

  @override
  Future<List<StudyCardDeckEntry>> fetchStudyCardDeck({
    StudyCardQuery query = const StudyCardQuery(),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logLearningRecord({
    required int poemId,
    required String mode,
    int durationMinutes = 0,
    int? score,
    String? note,
    String? stageId,
  }) async {}

  @override
  Future<void> markStudyCardReview({
    required int poemId,
    required bool remembered,
  }) async {}

  @override
  Future<void> reviewDailyPoem(DateTime date) async {}

  @override
  Future<void> saveStudyCardNote({
    required int poemId,
    required String? note,
  }) async {}
}

const _poem = Poem(
  id: 1,
  title: '\u9759\u591c\u601d',
  author: '\u674e\u767d',
  dynasty: '\u5510',
  grade: 1,
  gradeLabel: '\u4e00\u5e74\u7ea7',
  category: '\u601d\u4e61',
  content:
      '\u5e8a\u524d\u660e\u6708\u5149\uff0c\n\u7591\u662f\u5730\u4e0a\u971c\u3002',
  pinyin: 'chuang qian ming yue guang\nyi shi di shang shuang',
  annotation: '',
  translation: '',
  appreciation: '',
  authorIntro: '',
  extension: '',
  audioUrl: null,
  imageUrl: null,
  difficulty: 1,
);
