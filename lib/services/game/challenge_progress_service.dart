class ChallengeStageRule {
  const ChallengeStageRule({
    required this.id,
    required this.title,
    required this.mode,
    required this.description,
    required this.rewardLabel,
    required this.requiredScore,
    required this.requiredLines,
    this.chapter = '基础路线',
  });

  final String id;
  final String title;
  final String mode;
  final String description;
  final String rewardLabel;
  final int requiredScore;
  final int requiredLines;
  final String chapter;
}

class ChallengeStageProgress {
  const ChallengeStageProgress({
    required this.rule,
    required this.bestScore,
    required this.completedLines,
    required this.totalSessions,
  });

  final ChallengeStageRule rule;
  final int bestScore;
  final int completedLines;
  final int totalSessions;

  int get stars {
    var value = 0;
    if (completedLines >= rule.requiredLines || totalSessions > 0) {
      value += 1;
    }
    if (bestScore >= rule.requiredScore) {
      value += 1;
    }
    if (bestScore >= 90 && completedLines >= rule.requiredLines + 1) {
      value += 1;
    }
    return value.clamp(0, 3);
  }

  bool get unlocked => stars > 0;
  double get lineProgress =>
      (completedLines / rule.requiredLines).clamp(0, 1).toDouble();

  String get statusLabel {
    if (stars >= 3) {
      return '三星通关';
    }
    if (stars > 0) {
      return '已点亮 $stars 星';
    }
    return '尚未挑战';
  }

  String get nextGoal {
    if (completedLines < rule.requiredLines) {
      return '先完成 ${rule.requiredLines} 句练习，点亮第一颗星。';
    }
    if (bestScore < rule.requiredScore) {
      return '把最好成绩提升到 ${rule.requiredScore} 分，点亮第二颗星。';
    }
    if (stars < 3) {
      return '冲到 90 分并超过基础完成量，点亮三星。';
    }
    return '已经三星通关，可以继续刷新最好成绩。';
  }
}

class ChallengeProgressService {
  const ChallengeProgressService();

  List<ChallengeStageRule> defaultRules() {
    return const [
      ChallengeStageRule(
        id: 'jielong_entry',
        title: '接龙入门',
        mode: 'poetry_jielong',
        description: '用诗句首尾相接完成接龙，训练对原文和句序的熟悉度。',
        rewardLabel: '每日首次完成可领取接龙积分，并计入成长报告。',
        requiredScore: 75,
        requiredLines: 3,
        chapter: '基础路线',
      ),
      ChallengeStageRule(
        id: 'jielong_same_sound',
        title: '同音接龙',
        mode: 'poetry_jielong',
        description: '加入同音兜底规则，练习在卡住时继续接句。',
        rewardLabel: '完成后会刷新接龙进度，并强化同音字判断能力。',
        requiredScore: 85,
        requiredLines: 4,
        chapter: '进阶路线',
      ),
      ChallengeStageRule(
        id: 'jielong_master',
        title: '长链接龙',
        mode: 'poetry_jielong',
        description: '连续完成更长的诗句接龙，训练稳定回忆和首尾判断。',
        rewardLabel: '长链接龙通关后，会把最好成绩回流到闯关地图和成长报告。',
        requiredScore: 90,
        requiredLines: 6,
        chapter: '进阶路线',
      ),
      ChallengeStageRule(
        id: 'feihualing_entry',
        title: '飞花初试',
        mode: 'feihualing',
        description: '围绕主题字说出诗句，训练主题联想和诗句检索能力。',
        rewardLabel: '每日首次完成可领取飞花令积分，并计入成长报告。',
        requiredScore: 75,
        requiredLines: 3,
        chapter: '基础路线',
      ),
      ChallengeStageRule(
        id: 'feihualing_theme',
        title: '主题飞花',
        mode: 'feihualing',
        description: '围绕主题字连续答句，训练更快的诗句检索。',
        rewardLabel: '完成主题飞花后，会计入飞花令成长记录。',
        requiredScore: 85,
        requiredLines: 4,
        chapter: '进阶路线',
      ),
      ChallengeStageRule(
        id: 'feihualing_speed',
        title: '限时飞花',
        mode: 'feihualing',
        description: '在更短时间内围绕主题字答句，提升诗句检索速度。',
        rewardLabel: '限时飞花成绩会同步刷新地图星级，鼓励反复挑战最好成绩。',
        requiredScore: 90,
        requiredLines: 5,
        chapter: '进阶路线',
      ),
      ChallengeStageRule(
        id: 'dictation_checkpoint',
        title: '听写关卡',
        mode: 'dictation',
        description: '通过听写检查字形、顺序和易错字，适合作为综合复盘。',
        rewardLabel: '完成听写会生成报告和错题，帮助后续复盘。',
        requiredScore: 80,
        requiredLines: 3,
        chapter: '基础路线',
      ),
      ChallengeStageRule(
        id: 'dictation_review',
        title: '错字复盘',
        mode: 'dictation',
        description: '围绕错题和易错字再做一轮听写，把薄弱点转成通关进度。',
        rewardLabel: '错字复盘完成后，会同时进入错题改善趋势和家长摘要。',
        requiredScore: 88,
        requiredLines: 5,
        chapter: '复盘路线',
      ),
    ];
  }

  bool isStageLocked(List<ChallengeStageProgress> stages, int index) {
    if (index <= 0) {
      return false;
    }
    return stages[index - 1].stars == 0;
  }

  ChallengeStageProgress evaluate({
    required ChallengeStageRule rule,
    required int bestScore,
    required int completedLines,
    int totalSessions = 0,
  }) {
    return ChallengeStageProgress(
      rule: rule,
      bestScore: bestScore,
      completedLines: completedLines,
      totalSessions: totalSessions,
    );
  }

  String? stageIdForResult({
    required String mode,
    required int score,
    required int completedLines,
  }) {
    final rules = defaultRules()
      .where((rule) => rule.mode == mode)
      .toList(growable: false)..sort(
      (left, right) => right.requiredLines.compareTo(left.requiredLines),
    );
    for (final rule in rules) {
      if (completedLines >= rule.requiredLines || score >= rule.requiredScore) {
        return rule.id;
      }
    }
    return rules.isEmpty ? null : rules.last.id;
  }
}
