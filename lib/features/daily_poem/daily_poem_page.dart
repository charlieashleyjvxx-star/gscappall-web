import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../core/app_formatters.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/section_card.dart';
import '../poem_detail/poem_detail_page.dart';

class DailyPoemPage extends ConsumerWidget {
  const DailyPoemPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayPoemProvider);
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('每日一诗')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '每日一诗',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${AppFormatters.dateKey(DateTime.now())} · 读懂今天这一首，明天再回来复习。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF6B5B45),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            todayAsync.when(
              loading:
                  () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: LinearProgressIndicator(),
                    ),
                  ),
              error:
                  (error, _) => Text(
                    UserFacingErrorMapper.message(
                      error,
                      fallbackMessage: '今日诗词加载失败，请稍后重试。',
                    ),
                  ),
              data:
                  (bundle) => SectionCard(
                    title: bundle.poem.title,
                    subtitle: '${bundle.poem.dynasty} · ${bundle.poem.author}',
                    trailing: Chip(
                      avatar: Icon(
                        bundle.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        size: 18,
                      ),
                      label: Text(bundle.isCompleted ? '已完成' : '今天读这首'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoemPinyinText(
                          poem: bundle.poem,
                          showPinyin: showPinyin,
                          variant: PoemPinyinTextVariant.detail,
                        ),
                        if (bundle.poem.translation.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            bundle.poem.translation,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed:
                                  bundle.isCompleted
                                      ? () => _reviewDate(
                                        context,
                                        ref,
                                        DateTime.now(),
                                      )
                                      : () => _completeToday(context, ref),
                              icon: const Icon(Icons.done_all_rounded),
                              label: Text(bundle.isCompleted ? '再读一遍' : '我学会了'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => PoemDetailPage(
                                            poemId: bundle.poem.id,
                                          ),
                                    ),
                                  ),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('查看详情'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeToday(BuildContext context, WidgetRef ref) async {
    await ref
        .read(learningRepositoryProvider)
        .completeDailyPoem(DateTime.now());
    ref.invalidate(todayPoemProvider);
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(learningHistoryProvider);
    ref.invalidate(dailyPoemProgressProvider);
    ref.invalidate(dailyPoemHistoryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今日一诗已完成，并记入打卡积分。')));
    }
  }

  Future<void> _reviewDate(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    await ref.read(learningRepositoryProvider).reviewDailyPoem(date);
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(learningHistoryProvider);
    ref.invalidate(dailyPoemProgressProvider);
    ref.invalidate(dailyPoemHistoryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录 ${AppFormatters.shortDate(date)} 的每日一诗复习。'),
        ),
      );
    }
  }
}
