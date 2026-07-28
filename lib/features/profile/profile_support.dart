import 'package:flutter/material.dart';

import '../../core/app_formatters.dart';
import '../../domain/learning_models.dart';
import '../../domain/user_profile.dart';

class ProfileLevel {
  const ProfileLevel({
    required this.level,
    required this.title,
    required this.progress,
    required this.nextTarget,
  });

  final int level;
  final String title;
  final double progress;
  final int nextTarget;
}

enum ProfileBadgeTier {
  foundation('入门'),
  habit('习惯'),
  mastery('进阶'),
  review('复盘');

  const ProfileBadgeTier(this.label);

  final String label;
}

class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.total,
    required this.tier,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int progress;
  final int total;
  final ProfileBadgeTier tier;

  bool get unlocked => progress >= total;
  int get remaining => (total - progress).clamp(0, total);
  double get progressRatio =>
      total == 0 ? 1 : (progress / total).clamp(0, 1).toDouble();

  String get statusLabel {
    if (unlocked) {
      return '已解锁';
    }
    return '还差 $remaining';
  }
}

const List<Color> _avatarPalette = <Color>[
  Color(0xFFE07A5F),
  Color(0xFFD7A84D),
  Color(0xFF7F9F6B),
  Color(0xFF5E9AA8),
  Color(0xFF7D7BC0),
  Color(0xFFCB769A),
];

Color profileAvatarColor(UserProfile profile) {
  return _avatarPalette[profile.id % _avatarPalette.length];
}

String learningModeLabel(String mode) {
  switch (mode) {
    case 'daily_poem':
      return '每日一诗';
    case 'daily_poem_review':
      return '每日一诗复习';
    case 'study_card':
      return '学习卡片';
    case 'dictation':
      return '听写';
    case 'read':
    case 'reading':
      return '朗读';
    case 'recite':
    case 'recite_practice':
      return '背诵';
    case 'evaluation':
      return '测评';
    case 'poetry_jielong':
      return '诗词接龙';
    case 'feihualing':
      return '飞花令';
    case 'wrong_question_retry':
      return '错题再练';
    default:
      return mode.replaceAll('_', ' ');
  }
}

String challengeStageLabel(String? stageId) {
  switch (stageId) {
    case 'jielong_entry':
      return '接龙入门';
    case 'jielong_same_sound':
      return '同音接龙';
    case 'jielong_master':
      return '长链接龙';
    case 'feihualing_entry':
      return '飞花初试';
    case 'feihualing_theme':
      return '主题飞花';
    case 'feihualing_speed':
      return '限时飞花';
    case 'dictation_checkpoint':
      return '听写关卡';
    case 'dictation_review':
      return '错字复盘';
    default:
      if (stageId == null || stageId.isEmpty) {
        return '';
      }
      if (stageId.startsWith('chapter:')) {
        return stageId.substring('chapter:'.length);
      }
      return stageId.replaceAll('_', ' ');
  }
}

String challengeStagePrefix(String? stageId) {
  final label = challengeStageLabel(stageId);
  return label.isEmpty ? '' : '关卡：$label';
}

ProfileLevel buildProfileLevel(
  LearningSummary summary,
  DailyPoemProgress points,
) {
  const milestones = <int>[0, 5, 15, 30, 50, 80, 120, 165];
  const titles = <String>[
    '诗词新手',
    '诗词学徒',
    '诗词爱好者',
    '诗词进阶者',
    '诗词高手',
    '诗词专家',
    '诗词大师',
    '诗词宗师',
  ];

  final progressScore = summary.totalLearnedPoems + (points.totalPoints ~/ 20);
  var levelIndex = 0;
  for (var i = 0; i < milestones.length; i++) {
    if (progressScore >= milestones[i]) {
      levelIndex = i;
    }
  }

  final currentTarget = milestones[levelIndex];
  final nextTarget =
      levelIndex >= milestones.length - 1
          ? milestones.last
          : milestones[levelIndex + 1];
  final denominator = (nextTarget - currentTarget).clamp(1, 999999);
  final progress =
      levelIndex >= milestones.length - 1
          ? 1.0
          : ((progressScore - currentTarget) / denominator)
              .clamp(0, 1)
              .toDouble();

  return ProfileLevel(
    level: levelIndex + 1,
    title: titles[levelIndex],
    progress: progress,
    nextTarget: nextTarget,
  );
}

List<ProfileBadge> buildProfileBadges({
  required LearningSummary summary,
  required DailyPoemProgress points,
}) {
  return <ProfileBadge>[
    ProfileBadge(
      id: 'first_poem',
      title: '初识诗词',
      description: '完成第一首诗词学习',
      icon: Icons.menu_book_rounded,
      progress: summary.totalLearnedPoems,
      total: 1,
      tier: ProfileBadgeTier.foundation,
    ),
    ProfileBadge(
      id: 'ten_poems',
      title: '诗词入门',
      description: '累计学会 10 首诗词',
      icon: Icons.auto_stories_rounded,
      progress: summary.totalLearnedPoems,
      total: 10,
      tier: ProfileBadgeTier.foundation,
    ),
    ProfileBadge(
      id: 'thirty_poems',
      title: '腹有诗书',
      description: '累计学会 30 首诗词',
      icon: Icons.school_rounded,
      progress: summary.totalLearnedPoems,
      total: 30,
      tier: ProfileBadgeTier.mastery,
    ),
    ProfileBadge(
      id: 'streak_three',
      title: '坚持三天',
      description: '连续学习 3 天',
      icon: Icons.local_fire_department_rounded,
      progress: summary.streakDays,
      total: 3,
      tier: ProfileBadgeTier.habit,
    ),
    ProfileBadge(
      id: 'streak_seven',
      title: '一周不断',
      description: '连续学习 7 天',
      icon: Icons.bolt_rounded,
      progress: summary.streakDays,
      total: 7,
      tier: ProfileBadgeTier.habit,
    ),
    ProfileBadge(
      id: 'streak_twenty_one',
      title: '习惯养成',
      description: '连续学习 21 天',
      icon: Icons.calendar_month_rounded,
      progress: summary.streakDays,
      total: 21,
      tier: ProfileBadgeTier.habit,
    ),
    ProfileBadge(
      id: 'favorite_keeper',
      title: '收藏家',
      description: '收藏 10 首喜欢的诗词',
      icon: Icons.favorite_rounded,
      progress: summary.totalFavorites,
      total: 10,
      tier: ProfileBadgeTier.foundation,
    ),
    ProfileBadge(
      id: 'points_harvest',
      title: '打卡能手',
      description: '累计获得 100 积分',
      icon: Icons.workspace_premium_rounded,
      progress: points.totalPoints,
      total: 100,
      tier: ProfileBadgeTier.habit,
    ),
    ProfileBadge(
      id: 'steady_reader',
      title: '稳定练习',
      description: '累计学习 120 分钟',
      icon: Icons.timer_rounded,
      progress: summary.totalMinutes,
      total: 120,
      tier: ProfileBadgeTier.mastery,
    ),
    ProfileBadge(
      id: 'deep_practice',
      title: '深度练习',
      description: '累计学习 300 分钟',
      icon: Icons.self_improvement_rounded,
      progress: summary.totalMinutes,
      total: 300,
      tier: ProfileBadgeTier.mastery,
    ),
    ProfileBadge(
      id: 'review_builder',
      title: '复盘小队长',
      description: '累计打卡 14 次',
      icon: Icons.fact_check_rounded,
      progress: points.totalCheckIns,
      total: 14,
      tier: ProfileBadgeTier.review,
    ),
    ProfileBadge(
      id: 'review_guardian',
      title: '复习守护者',
      description: '累计打卡 30 次',
      icon: Icons.verified_rounded,
      progress: points.totalCheckIns,
      total: 30,
      tier: ProfileBadgeTier.review,
    ),
  ];
}

String profileProgressHint(ProfileLevel level, LearningSummary summary) {
  if (level.progress >= 1) {
    return '已经达到当前阶段的最高等级，继续保持节奏就能稳定进入下一轮成长。';
  }
  return '再积累一些学习值，就能冲向 ${level.nextTarget} 学习值阶段。当前已学 ${summary.totalLearnedPoems} 首。';
}

String recentRecordSubtitle(LearningRecord record) {
  final date = record.studiedAt.toLocal();
  return '${AppFormatters.shortDate(date)} · ${AppFormatters.minutesLabel(record.durationMinutes)}';
}
