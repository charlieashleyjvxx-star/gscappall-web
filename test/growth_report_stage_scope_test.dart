import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/domain/learning_models.dart';
import 'package:gscappall/domain/poem.dart';
import 'package:gscappall/domain/practice_models.dart';
import 'package:gscappall/domain/repositories/learning_repository.dart';
import 'package:gscappall/domain/repositories/practice_repository.dart';
import 'package:gscappall/features/game/challenge_map_page.dart';
import 'package:gscappall/features/profile/profile_page.dart';
import 'package:gscappall/features/shared/stage_scope_route_args.dart';
import 'package:gscappall/services/game/challenge_progress_service.dart';

void main() {
  testWidgets('growth report shows stage scope from constructor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeLearningRepository();
    final pushedSettings = <RouteSettings>[];
    final challengeService = const ChallengeProgressService();
    final mapStages = challengeService
        .defaultRules()
        .map((rule) {
          final progress =
              rule.id == 'jielong_entry'
                  ? const ChallengeModeProgress(
                    mode: 'poetry_jielong',
                    totalSessions: 1,
                    bestScore: 82,
                    completedLines: 3,
                  )
                  : rule.id == 'dictation_checkpoint'
                  ? const ChallengeModeProgress(
                    mode: 'dictation',
                    totalSessions: 1,
                    bestScore: 88,
                    completedLines: 3,
                  )
                  : const ChallengeModeProgress(
                    mode: 'feihualing',
                    totalSessions: 0,
                    bestScore: 0,
                    completedLines: 0,
                  );
          return challengeService.evaluate(
            rule: rule,
            bestScore: progress.bestScore,
            completedLines: progress.completedLines,
            totalSessions: progress.totalSessions,
          );
        })
        .toList(growable: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWithValue(repository),
          practiceRepositoryProvider.overrideWithValue(
            _FakePracticeRepository(),
          ),
        ],
        child: MaterialApp(
          home: const GrowthReportDetailPage(
            initialPeriod: GrowthReportPeriod.weekly,
            initialStageId: 'jielong_entry',
          ),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            final args = StageScopeRouteArgs.fromSettings(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) {
                switch (settings.name) {
                  case '/challenge-map':
                    return ChallengeMapPage(
                      stages: mapStages,
                      initialStageId: args?.stageId,
                      initialSource: args?.source,
                      onOpenJielong: () async {},
                      onOpenFeihualing: () async {},
                      onOpenDictation: () async {},
                    );
                  case '/practice-report-detail':
                  case '/learning-record-detail':
                  case '/wrong-question-detail':
                    return Scaffold(
                      body: Text('${settings.name}:${args?.stageId}'),
                    );
                }
                return Scaffold(
                  body: Text('${settings.name}:${args?.stageId}'),
                );
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('练习进度').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('查看星星和练习变化'), findsOneWidget);
    await tester.tap(find.text('查看星星和练习变化'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('诗词接龙'), findsOneWidget);
    expect(find.textContaining('想细看时再展开'), findsOneWidget);
    expect(find.textContaining('2 次 · 88 分'), findsWidgets);
    expect(find.text('关卡变化'), findsOneWidget);
    expect(find.text('接龙入门'), findsWidgets);
    expect(find.textContaining('接龙句数约 6 句，表现 88 分，这次多练了 1 次'), findsOneWidget);
    expect(find.text('练习次数'), findsWidgets);
    expect(find.text('练习表现'), findsWidgets);
    expect(find.text('星级参考'), findsWidgets);
    expect(find.text('逐日变化'), findsWidgets);
    expect(find.text('周/月关卡变化图'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('周月关卡变化图')), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('家长关注关卡'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('家长关注关卡'), findsOneWidget);
    expect(find.text('查看关注关卡'), findsOneWidget);
    expect(find.text('未改善错题 3 个'), findsOneWidget);
    expect(find.textContaining('关注这一关是因为还有 3 个未改善错题'), findsOneWidget);
    final pendingWrongChip = find.widgetWithText(ActionChip, '未改善错题 3 个');
    await tester.ensureVisible(pendingWrongChip);
    await tester.pump();
    await tester.tap(pendingWrongChip);
    await tester.pumpAndSettle();
    expect(pushedSettings.last.name, '/wrong-book');
    var focusWrongArgs = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(focusWrongArgs?.stageId, 'jielong_entry');
    expect(focusWrongArgs?.source, 'growth-report');
    Navigator.of(tester.element(find.text('/wrong-book:jielong_entry'))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('练习进度').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('查看星星和练习变化'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('查看星星和练习变化'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('逐日变化').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('05-09'), findsWidgets);
    await tester.ensureVisible(find.text('05-09'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05-09'));
    await tester.pumpAndSettle();
    expect(find.textContaining('接龙入门 · 2026-05-09'), findsOneWidget);
    expect(find.text('当天练习'), findsOneWidget);
    expect(find.text('错题复习'), findsWidgets);
    expect(find.text('当天练习记录'), findsOneWidget);
    expect(find.text('练习记录卡'), findsWidgets);
    expect(find.text('更多记录'), findsOneWidget);
    expect(find.text('共 4 条'), findsWidgets);
    expect(find.text('练习结果'), findsOneWidget);
    expect(find.text('错题复习'), findsWidgets);
    expect(find.text('练习记录'), findsOneWidget);
    expect(find.textContaining('练习结果 #77'), findsOneWidget);
    expect(find.textContaining('练习结果 #79'), findsOneWidget);
    expect(find.textContaining('错题 #78'), findsOneWidget);
    expect(find.textContaining('错题 #80'), findsOneWidget);
    expect(find.textContaining('练习记录 #9'), findsOneWidget);
    expect(find.textContaining('练习记录 #10'), findsOneWidget);
    expect(find.text('本次练习'), findsWidgets);
    expect(find.textContaining('这次接龙约完成'), findsWidgets);
    expect(find.textContaining('完成句数'), findsWidgets);
    expect(find.textContaining('分数进步'), findsWidgets);
    expect(find.textContaining('练习结果 #82'), findsNothing);
    expect(find.textContaining('错题 #82'), findsNothing);
    expect(find.textContaining('练习记录 #12'), findsNothing);
    expect(find.text('展开全部，另有 1 条'), findsWidgets);
    await tester.ensureVisible(find.text('展开全部，另有 1 条').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开全部，另有 1 条').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('练习结果 #82'), findsOneWidget);
    expect(find.text('查看当天学习记录'), findsOneWidget);
    expect(find.text('查看练习结果'), findsOneWidget);
    expect(find.text('查看本关错题'), findsOneWidget);
    await tester.ensureVisible(find.bySemanticsLabel(RegExp('练习结果 #79')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('练习结果 #79')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(pushedSettings.last.name, '/practice-report-detail');
    var detailArgs = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(detailArgs?.stageId, 'jielong_entry');
    expect(detailArgs?.dateKey, '2026-05-09');
    expect(detailArgs?.reportId, 79);
    expect(detailArgs?.source, 'growth-report');
    Navigator.of(
      tester.element(find.text('/practice-report-detail:jielong_entry')),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('接龙入门 · 2026-05-09'), findsOneWidget);
    expect(find.textContaining('练习结果 #79'), findsOneWidget);
    expect(find.textContaining('已回到这条记录'), findsWidgets);
    await tester.ensureVisible(find.bySemanticsLabel(RegExp('练习记录 #10')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('练习记录 #10')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(pushedSettings.last.name, '/learning-record-detail');
    detailArgs = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(detailArgs?.stageId, 'jielong_entry');
    expect(detailArgs?.dateKey, '2026-05-09');
    expect(detailArgs?.learningRecordId, 10);
    expect(detailArgs?.source, 'growth-report');
    Navigator.of(
      tester.element(find.text('/learning-record-detail:jielong_entry')),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('接龙入门 · 2026-05-09'), findsOneWidget);
    expect(find.textContaining('练习记录 #10'), findsOneWidget);
    expect(find.textContaining('已回到这条记录'), findsWidgets);
    await tester.ensureVisible(find.bySemanticsLabel(RegExp('错题 #80')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('错题 #80')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(pushedSettings.last.name, '/wrong-question-detail');
    detailArgs = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(detailArgs?.stageId, 'jielong_entry');
    expect(detailArgs?.dateKey, '2026-05-09');
    expect(detailArgs?.wrongQuestionId, 80);
    expect(detailArgs?.source, 'growth-report');
    Navigator.of(
      tester.element(find.text('/wrong-question-detail:jielong_entry')),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.textContaining('接龙入门 · 2026-05-09'), findsOneWidget);
    expect(find.textContaining('错题 #80'), findsOneWidget);
    expect(find.textContaining('已回到这条记录'), findsWidgets);
    await tester.ensureVisible(find.text('查看当天学习记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看当天学习记录'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(pushedSettings.last.name, '/learning-history');
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.stageId,
      'jielong_entry',
    );
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.dateKey,
      '2026-05-09',
    );
    Navigator.of(
      tester.element(find.text('/learning-history:jielong_entry')),
    ).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('建议继续练'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('建议继续练'), findsOneWidget);
    expect(find.textContaining('完成句数'), findsWidgets);
    expect(find.textContaining('分数进步'), findsWidgets);
    await tester.ensureVisible(find.text('查看本关练习记录').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看本关练习记录').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(pushedSettings.last.name, '/challenge-map');
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.stageId,
      'dictation_checkpoint',
    );
    expect(
      StageScopeRouteArgs.fromSettings(pushedSettings.last)?.source,
      'growth-report',
    );
    expect(find.text('已帮你找到这一关'), findsWidgets);
    expect(find.text('查看所在章节详情'), findsOneWidget);

    await tester.tap(find.text('查看所在章节详情'));
    await tester.pumpAndSettle();

    expect(find.text('当前关卡与最近练习'), findsOneWidget);
    expect(find.text('最近练习'), findsWidgets);
    expect(find.textContaining('分数进步'), findsWidgets);
  });

  testWidgets('growth report reads stage scope from route settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeLearningRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/growth-report',
          onGenerateRoute:
              (settings) => MaterialPageRoute(
                settings: StageScopeRouteArgs(
                  stageId: 'jielong_entry',
                ).toRouteSettings(name: settings.name),
                builder:
                    (_) => const GrowthReportDetailPage(
                      initialPeriod: GrowthReportPeriod.weekly,
                    ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('本关成长视角').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('本关成长视角'), findsOneWidget);
    expect(find.textContaining('jielong_entry'), findsNothing);
  });

  testWidgets('growth trend point shows clear empty detail actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWithValue(
            _FakeLearningRepository(),
          ),
          practiceRepositoryProvider.overrideWithValue(
            const _FakePracticeRepository(hasDetails: false),
          ),
        ],
        child: const MaterialApp(
          home: GrowthReportDetailPage(
            initialPeriod: GrowthReportPeriod.weekly,
            initialStageId: 'jielong_entry',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('练习进度').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('查看星星和练习变化'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('05-09'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('05-09'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05-09'));
    await tester.pumpAndSettle();

    expect(find.text('更多记录'), findsOneWidget);
    expect(find.text('练习结果'), findsOneWidget);
    expect(find.text('错题复习'), findsWidgets);
    expect(find.text('练习记录'), findsOneWidget);
    expect(find.text('暂无练习结果'), findsOneWidget);
    expect(find.textContaining('当天还没有练习结果'), findsOneWidget);
    expect(find.text('暂无错题'), findsOneWidget);
    expect(find.textContaining('当天还没有本关错题'), findsOneWidget);
    expect(find.textContaining('练习记录 #9'), findsOneWidget);
    expect(find.textContaining('练习结果 #'), findsNothing);
    expect(find.textContaining('错题 #'), findsNothing);
  });

  testWidgets('growth trend low-data card can open practice and history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pushedSettings = <RouteSettings>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWithValue(
            _FakeLearningRepository(recentRecords: const []),
          ),
          practiceRepositoryProvider.overrideWithValue(
            const _FakePracticeRepository(hasDetails: false),
          ),
        ],
        child: MaterialApp(
          home: const GrowthReportDetailPage(
            initialPeriod: GrowthReportPeriod.weekly,
            initialStageId: 'jielong_entry',
          ),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            final args = StageScopeRouteArgs.fromSettings(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder:
                  (_) =>
                      Scaffold(body: Text('${settings.name}:${args?.stageId}')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('练习进度').first,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('查看星星和练习变化'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('05-09'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('05-09'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05-09'));
    await tester.pumpAndSettle();

    expect(find.text('当天还没有可展开练习'), findsOneWidget);
    expect(find.text('去练这一关'), findsOneWidget);
    expect(find.text('查看学习历史'), findsOneWidget);

    await tester.tap(find.text('去练这一关'));
    await tester.pumpAndSettle();
    var args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/challenge-map');
    expect(args?.stageId, 'jielong_entry');
    expect(args?.dateKey, '2026-05-09');
    expect(args?.source, 'growth-report');

    Navigator.of(
      tester.element(find.text('/challenge-map:jielong_entry')),
    ).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('05-09'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05-09'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看学习历史'));
    await tester.pumpAndSettle();
    args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/learning-history');
    expect(args?.stageId, 'jielong_entry');
    expect(args?.dateKey, '2026-05-09');
    expect(args?.source, 'growth-report');
  });

  testWidgets('growth report can open monthly period from route args', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeLearningRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          initialRoute: '/growth-report',
          onGenerateRoute: (settings) {
            final args = StageScopeRouteArgs(
              stageId: 'jielong_entry',
              growthPeriod: 'monthly',
            );
            final period =
                args.growthPeriod == 'monthly'
                    ? GrowthReportPeriod.monthly
                    : GrowthReportPeriod.weekly;
            return MaterialPageRoute(
              settings: args.toRouteSettings(name: settings.name),
              builder:
                  (_) => GrowthReportDetailPage(
                    initialPeriod: period,
                    initialStageId: args.stageId,
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedPeriods.last, GrowthReportPeriod.monthly);
  });

  testWidgets(
    'parent focus stage shows low-data copy when samples are sparse',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakeLearningRepository(stageStats: const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [learningRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: GrowthReportDetailPage(
              initialPeriod: GrowthReportPeriod.weekly,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('\u5bb6\u957f\u5173\u6ce8\u5173\u5361'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('\u5bb6\u957f\u5173\u6ce8\u5173\u5361'), findsOneWidget);
      expect(find.textContaining('这段时间练得还不多'), findsOneWidget);
      expect(find.text('\u67e5\u770b\u5173\u6ce8\u5173\u5361'), findsNothing);
    },
  );

  testWidgets(
    'parent low-data focus stage offers practice and history actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakeLearningRepository(
        stageStats: const [
          LearningStageStat(
            stageId: 'dictation_checkpoint',
            count: 1,
            minutes: 6,
            averageScore: 82,
          ),
        ],
        previousStageStats: const [],
      );
      final pushedSettings = <RouteSettings>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [learningRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            home: const GrowthReportDetailPage(
              initialPeriod: GrowthReportPeriod.weekly,
            ),
            onGenerateRoute: (settings) {
              pushedSettings.add(settings);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('target')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('去练关注关卡'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('再练一两次'), findsOneWidget);
      expect(find.text('去练关注关卡'), findsOneWidget);
      expect(find.text('查看学习历史'), findsOneWidget);

      await tester.ensureVisible(find.text('去练关注关卡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('去练关注关卡'));
      await tester.pumpAndSettle();
      var args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
      expect(pushedSettings.last.name, '/challenge-map');
      expect(args?.stageId, 'dictation_checkpoint');
      expect(args?.source, 'growth-report');

      Navigator.of(tester.element(find.text('target'))).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('查看学习历史'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('查看学习历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看学习历史'));
      await tester.pumpAndSettle();
      args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
      expect(pushedSettings.last.name, '/learning-history');
      expect(args?.stageId, 'dictation_checkpoint');
      expect(args?.source, 'growth-report');
    },
  );

  testWidgets('parent focus stage button opens challenge map with stage args', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeLearningRepository();
    final pushedSettings = <RouteSettings>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [learningRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: const GrowthReportDetailPage(
            initialPeriod: GrowthReportPeriod.weekly,
          ),
          onGenerateRoute: (settings) {
            pushedSettings.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('map')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('\u67e5\u770b\u5173\u6ce8\u5173\u5361'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.text('\u67e5\u770b\u5173\u6ce8\u5173\u5361'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u67e5\u770b\u5173\u6ce8\u5173\u5361'));
    await tester.pumpAndSettle();

    final args = StageScopeRouteArgs.fromSettings(pushedSettings.last);
    expect(pushedSettings.last.name, '/challenge-map');
    expect(args?.stageId, 'jielong_entry');
    expect(args?.source, 'growth-report');
  });
}

class _FakeLearningRepository implements LearningRepository {
  _FakeLearningRepository({
    List<LearningStageStat>? stageStats,
    List<LearningStageStat>? previousStageStats,
    List<LearningRecord>? recentRecords,
  }) : stageStats =
           stageStats ??
           const [
             LearningStageStat(
               stageId: 'jielong_entry',
               count: 2,
               minutes: 12,
               averageScore: 88,
             ),
             LearningStageStat(
               stageId: 'dictation_checkpoint',
               count: 1,
               minutes: 6,
               averageScore: 82,
             ),
           ],
       previousStageStats =
           previousStageStats ??
           const [
             LearningStageStat(
               stageId: 'jielong_entry',
               count: 1,
               minutes: 6,
               averageScore: 80,
             ),
           ],
       recentRecords = recentRecords ?? _defaultRecentRecords;

  final List<GrowthReportPeriod> requestedPeriods = [];
  final List<LearningStageStat> stageStats;
  final List<LearningStageStat> previousStageStats;
  final List<LearningRecord> recentRecords;

  @override
  Future<LearningGrowthReport> fetchGrowthReport({
    GrowthReportPeriod period = GrowthReportPeriod.weekly,
  }) async {
    requestedPeriods.add(period);
    return LearningGrowthReport(
      period: period,
      startAt: DateTime.utc(2026, 5, 5),
      endAt: DateTime.utc(2026, 5, 11),
      totalSessions: 3,
      totalMinutes: 18,
      uniquePoems: 2,
      averageScore: 86,
      dailyPoemCompletions: 1,
      studyCardReviews: 3,
      practiceReportCount: 1,
      wrongQuestionCount: 1,
      reviewedWrongQuestionCount: 1,
      activeDays: 2,
      longestLearningStreak: 2,
      previousWrongQuestionCount: 2,
      previousReviewedWrongQuestionCount: 1,
      previousAverageScore: 80,
      modeStats: const [
        LearningModeStat(
          mode: 'poetry_jielong',
          count: 2,
          minutes: 12,
          averageScore: 88,
        ),
        LearningModeStat(
          mode: 'feihualing',
          count: 1,
          minutes: 6,
          averageScore: 82,
        ),
      ],
      previousModeStats: const [
        LearningModeStat(
          mode: 'poetry_jielong',
          count: 1,
          minutes: 6,
          averageScore: 80,
        ),
      ],
      stageStats: stageStats,
      previousStageStats: previousStageStats,
      scoreTrend: const [],
      stageTrend: const [
        LearningStageTrendPoint(
          stageId: 'jielong_entry',
          dateKey: '2026-05-09',
          count: 2,
          minutes: 12,
          averageScore: 88,
        ),
        LearningStageTrendPoint(
          stageId: 'dictation_checkpoint',
          dateKey: '2026-05-10',
          count: 1,
          minutes: 6,
          averageScore: 82,
        ),
      ],
    );
  }

  @override
  Future<LearningSummary> fetchSummary() {
    throw UnimplementedError();
  }

  @override
  Future<List<LearningRecord>> fetchRecentRecords({int limit = 12}) async {
    return recentRecords.take(limit).toList(growable: false);
  }

  @override
  Future<Map<String, ChallengeModeProgress>>
  fetchChallengeModeProgress() async {
    return const {
      'poetry_jielong': ChallengeModeProgress(
        mode: 'poetry_jielong',
        totalSessions: 1,
        bestScore: 82,
        completedLines: 3,
      ),
      'dictation': ChallengeModeProgress(
        mode: 'dictation',
        totalSessions: 1,
        bestScore: 88,
        completedLines: 3,
      ),
    };
  }

  @override
  Future<List<LearningRecord>> fetchChallengeModeHistory({
    required String mode,
    int limit = 10,
    String? stageId,
  }) async {
    final records = [
      LearningRecord(
        id: 1,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        mode: 'poetry_jielong',
        durationMinutes: 6,
        score: 88,
        studiedAt: DateTime(2026, 5, 21, 8),
        stageId: 'jielong_entry',
      ),
      LearningRecord(
        id: 2,
        poemId: 2,
        poemTitle: '春晓',
        poemAuthor: '孟浩然',
        mode: 'dictation',
        durationMinutes: 5,
        score: 82,
        studiedAt: DateTime(2026, 5, 21, 9),
        stageId: 'dictation_checkpoint',
      ),
    ].where((record) => record.mode == mode);
    final scoped =
        stageId == null
            ? records
            : records.where((record) => record.stageId == stageId);
    return scoped.take(limit).toList(growable: false);
  }

  @override
  Future<Set<String>> fetchClaimedChallengeRewardKeys() async {
    return const {};
  }

  @override
  Future<bool> markChallengeRewardClaimed({
    required String stageId,
    required int stars,
  }) async {
    return false;
  }

  @override
  Future<void> logLearningRecord({
    required int poemId,
    required String mode,
    int durationMinutes = 0,
    int? score,
    String? note,
    String? stageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> completeDailyPoem(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<DailyPoemProgress> fetchDailyPoemProgress({DateTime? date}) {
    throw UnimplementedError();
  }

  @override
  Future<List<DailyPoemHistoryEntry>> fetchDailyPoemHistory({int limit = 14}) {
    throw UnimplementedError();
  }

  @override
  Future<void> reviewDailyPoem(DateTime date) {
    throw UnimplementedError();
  }

  @override
  Future<List<StudyCardDeckEntry>> fetchStudyCardDeck({
    StudyCardQuery query = const StudyCardQuery(),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<StudyCardFilterOptions> fetchStudyCardFilterOptions() {
    throw UnimplementedError();
  }

  @override
  Future<void> markStudyCardReview({
    required int poemId,
    required bool remembered,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveStudyCardNote({required int poemId, required String? note}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> awardActivityPoints({
    required String activityType,
    required int points,
  }) {
    throw UnimplementedError();
  }
}

final _defaultRecentRecords = [
  LearningRecord(
    id: 9,
    poemId: 1,
    poemTitle: '静夜思',
    poemAuthor: '李白',
    mode: 'poetry_jielong',
    durationMinutes: 6,
    score: 88,
    studiedAt: DateTime(2026, 5, 9, 9),
    stageId: 'jielong_entry',
  ),
  LearningRecord(
    id: 10,
    poemId: 2,
    poemTitle: '春晓',
    poemAuthor: '孟浩然',
    mode: 'poetry_jielong',
    durationMinutes: 6,
    score: 92,
    studiedAt: DateTime(2026, 5, 9, 11),
    stageId: 'jielong_entry',
  ),
  LearningRecord(
    id: 11,
    poemId: 3,
    poemTitle: '登鹳雀楼',
    poemAuthor: '王之涣',
    mode: 'poetry_jielong',
    durationMinutes: 7,
    score: 90,
    studiedAt: DateTime(2026, 5, 9, 12),
    stageId: 'jielong_entry',
  ),
  LearningRecord(
    id: 12,
    poemId: 4,
    poemTitle: '江雪',
    poemAuthor: '柳宗元',
    mode: 'poetry_jielong',
    durationMinutes: 8,
    score: 95,
    studiedAt: DateTime(2026, 5, 9, 13),
    stageId: 'jielong_entry',
  ),
];

class _FakePracticeRepository implements PracticeRepository {
  const _FakePracticeRepository({this.hasDetails = true});

  final bool hasDetails;

  @override
  Future<PracticeReportOverview> fetchPracticeReportOverview({
    PracticeReportQuery query = const PracticeReportQuery(),
  }) async {
    if (!hasDetails) {
      return const PracticeReportOverview(
        summaries: [],
        stats: PracticeReportStats(
          totalReports: 0,
          dictationCount: 0,
          evaluationCount: 0,
          readingCount: 0,
          recitationCount: 0,
          averageScore: 0,
          scoreBands: {},
          mistakeTypes: {},
        ),
      );
    }
    final summaries = [
      PracticeReportSummary(
        id: 77,
        sessionId: 'trend-report-77',
        mode: PracticeMode.dictation,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        totalScore: 91,
        correctCount: 1,
        totalQuestions: 1,
        generatedWrongCount: 1,
        completedAt: DateTime(2026, 5, 9, 10),
        stageId: 'jielong_entry',
      ),
      PracticeReportSummary(
        id: 79,
        sessionId: 'trend-report-79',
        mode: PracticeMode.evaluation,
        poemId: 2,
        poemTitle: '春晓',
        poemAuthor: '孟浩然',
        totalScore: 94,
        correctCount: 1,
        totalQuestions: 1,
        generatedWrongCount: 0,
        completedAt: DateTime(2026, 5, 9, 11),
        stageId: 'jielong_entry',
      ),
      PracticeReportSummary(
        id: 81,
        sessionId: 'trend-report-81',
        mode: PracticeMode.evaluation,
        poemId: 3,
        poemTitle: '登鹳雀楼',
        poemAuthor: '王之涣',
        totalScore: 90,
        correctCount: 1,
        totalQuestions: 1,
        generatedWrongCount: 0,
        completedAt: DateTime(2026, 5, 9, 12),
        stageId: 'jielong_entry',
      ),
      PracticeReportSummary(
        id: 82,
        sessionId: 'trend-report-82',
        mode: PracticeMode.dictation,
        poemId: 4,
        poemTitle: '江雪',
        poemAuthor: '柳宗元',
        totalScore: 95,
        correctCount: 1,
        totalQuestions: 1,
        generatedWrongCount: 0,
        completedAt: DateTime(2026, 5, 9, 13),
        stageId: 'jielong_entry',
      ),
    ].where(
      (report) => query.stageId == null || report.stageId == query.stageId,
    );
    return PracticeReportOverview(
      summaries: summaries.take(query.limit).toList(growable: false),
      stats: const PracticeReportStats(
        totalReports: 1,
        dictationCount: 1,
        evaluationCount: 0,
        readingCount: 0,
        recitationCount: 0,
        averageScore: 91,
        scoreBands: {},
        mistakeTypes: {},
      ),
    );
  }

  @override
  Future<List<WrongQuestionEntry>> fetchWrongQuestions({
    WrongQuestionQuery query = const WrongQuestionQuery(),
  }) async {
    if (!hasDetails) {
      return const [];
    }
    final entries = [
      WrongQuestionEntry(
        id: 78,
        poemId: 1,
        poemTitle: '静夜思',
        poemAuthor: '李白',
        questionType: PracticeMode.dictation,
        prompt: '床前明月光',
        correctAnswer: '床前明月光',
        userAnswer: '床前明月',
        mistakeType: PracticeMistakeType.missingCharacters,
        severity: 'medium',
        createdAt: DateTime(2026, 5, 9, 10),
        stageId: 'jielong_entry',
        reviewedAt: DateTime(2026, 5, 9, 11),
      ),
      WrongQuestionEntry(
        id: 80,
        poemId: 2,
        poemTitle: '春晓',
        poemAuthor: '孟浩然',
        questionType: PracticeMode.evaluation,
        prompt: '春眠不觉晓',
        correctAnswer: '春眠不觉晓',
        userAnswer: '春眠不晓',
        mistakeType: PracticeMistakeType.missingCharacters,
        severity: 'medium',
        createdAt: DateTime(2026, 5, 9, 11),
        stageId: 'jielong_entry',
      ),
      WrongQuestionEntry(
        id: 81,
        poemId: 3,
        poemTitle: '登鹳雀楼',
        poemAuthor: '王之涣',
        questionType: PracticeMode.evaluation,
        prompt: '白日依山尽',
        correctAnswer: '白日依山尽',
        userAnswer: '白日山尽',
        mistakeType: PracticeMistakeType.missingCharacters,
        severity: 'medium',
        createdAt: DateTime(2026, 5, 9, 12),
        stageId: 'jielong_entry',
      ),
      WrongQuestionEntry(
        id: 82,
        poemId: 4,
        poemTitle: '江雪',
        poemAuthor: '柳宗元',
        questionType: PracticeMode.dictation,
        prompt: '千山鸟飞绝',
        correctAnswer: '千山鸟飞绝',
        userAnswer: '千山鸟绝',
        mistakeType: PracticeMistakeType.missingCharacters,
        severity: 'medium',
        createdAt: DateTime(2026, 5, 9, 13),
        stageId: 'jielong_entry',
      ),
    ].where((entry) {
      final matchesStage =
          query.stageId == null || entry.stageId == query.stageId;
      final matchesReviewed = !query.onlyUnreviewed || !entry.isReviewed;
      return matchesStage && matchesReviewed;
    });
    return entries.take(query.limit).toList(growable: false);
  }

  @override
  Future<List<Poem>> fetchPracticePoems({int limit = 60}) {
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
  Future<PracticeReport> completeSession({
    required PracticeSession session,
    required Map<int, String> answers,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeReport> saveAssessmentReport({
    required Poem poem,
    required PracticeMode mode,
    required List<PracticeLineResult> results,
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PracticeReportSummary>> fetchPracticeReportSummaries({
    int limit = 100,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PracticeReportDetail?> fetchPracticeReportDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<WrongQuestionEntry?> fetchWrongQuestionDetail(int id) {
    throw UnimplementedError();
  }

  @override
  Future<void> markWrongQuestionReviewed(int id) {
    throw UnimplementedError();
  }
}
