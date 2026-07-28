import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/services/game/challenge_progress_service.dart';

void main() {
  const service = ChallengeProgressService();

  test('provides default challenge stage rules', () {
    final rules = service.defaultRules();

    expect(rules.map((rule) => rule.id), [
      'jielong_entry',
      'jielong_same_sound',
      'jielong_master',
      'feihualing_entry',
      'feihualing_theme',
      'feihualing_speed',
      'dictation_checkpoint',
      'dictation_review',
    ]);
    expect(rules.map((rule) => rule.mode), [
      'poetry_jielong',
      'poetry_jielong',
      'poetry_jielong',
      'feihualing',
      'feihualing',
      'feihualing',
      'dictation',
      'dictation',
    ]);
    expect(rules.first.description, contains('接龙'));
    expect(rules.first.rewardLabel, contains('积分'));
  });

  test('evaluates star progress from score and completed lines', () {
    final rule = service.defaultRules().first;

    expect(
      service.evaluate(rule: rule, bestScore: 60, completedLines: 2).stars,
      0,
    );
    expect(
      service.evaluate(rule: rule, bestScore: 60, completedLines: 3).stars,
      1,
    );
    expect(
      service.evaluate(rule: rule, bestScore: 80, completedLines: 3).stars,
      2,
    );
    expect(
      service.evaluate(rule: rule, bestScore: 95, completedLines: 4).stars,
      3,
    );
  });

  test('counts started stages as one star even before line target', () {
    final rule = service.defaultRules().first;

    final progress = service.evaluate(
      rule: rule,
      bestScore: 40,
      completedLines: 1,
      totalSessions: 1,
    );

    expect(progress.stars, 1);
    expect(progress.unlocked, isTrue);
    expect(progress.statusLabel, '已点亮 1 星');
    expect(progress.nextGoal, contains('完成 3 句'));
  });

  test('describes completed three-star stages', () {
    final rule = service.defaultRules().first;
    final progress = service.evaluate(
      rule: rule,
      bestScore: 96,
      completedLines: 4,
      totalSessions: 2,
    );

    expect(progress.stars, 3);
    expect(progress.statusLabel, '三星通关');
    expect(progress.nextGoal, contains('刷新最好成绩'));
  });

  test('locks stages until the previous stage has at least one star', () {
    final rules = service.defaultRules();
    final stages = [
      service.evaluate(rule: rules[0], bestScore: 0, completedLines: 0),
      service.evaluate(rule: rules[1], bestScore: 90, completedLines: 4),
    ];

    expect(service.isStageLocked(stages, 0), isFalse);
    expect(service.isStageLocked(stages, 1), isTrue);
  });
}
