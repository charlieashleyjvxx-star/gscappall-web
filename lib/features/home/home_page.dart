import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/app_design.dart';
import '../../core/user_facing_error.dart';
import '../../domain/learning_models.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/section_card.dart';
import '../poem_detail/poem_detail_page.dart';
import '../study_cards/study_cards_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const pagePadding = AppSpacing.large;
    final todayAsync = ref.watch(todayPoemProvider);
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.readingMaxWidth,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                pagePadding,
                pagePadding,
                pagePadding + AppSpacing.small,
              ),
              children: [
                todayAsync.when(
                  data: (bundle) {
                    return SectionCard(
                      title: '今日任务',
                      onTap:
                          () => _openPage(
                            context,
                            PoemDetailPage(poemId: bundle.poem.id),
                          ),
                      child: _TodayPoemCard(
                        bundle: bundle,
                        showPinyin: showPinyin,
                      ),
                    );
                  },
                  loading:
                      () => const SectionCard(
                        title: '今日任务',
                        child: _TodayTaskLoading(),
                      ),
                  error:
                      (error, _) => SectionCard(
                        title: '今日任务',
                        child: Text(
                          UserFacingErrorMapper.message(
                            error,
                            fallbackMessage: '今日任务加载失败，请稍后重试。',
                          ),
                        ),
                      ),
                ),
                const SizedBox(height: AppSpacing.medium),
                SectionCard(
                  title: '学习卡片',
                  onTap: () => _openPage(context, const StudyCardsPage()),
                  child: const _StudyCardPreview(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _TodayTaskLoading extends StatelessWidget {
  const _TodayTaskLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(),
        SizedBox(height: 12),
        Text('正在准备今天要学的诗。'),
      ],
    );
  }
}

class _TodayPoemCard extends StatelessWidget {
  const _TodayPoemCard({required this.bundle, required this.showPinyin});

  final DailyPoemBundle bundle;
  final bool showPinyin;

  @override
  Widget build(BuildContext context) {
    final poem = bundle.poem;
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poem.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          poem.author.isEmpty
              ? poem.dynasty
              : '${poem.dynasty} · ${poem.author}',
          maxLines: compactLayout ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        PoemPinyinText(
          poem: poem,
          showPinyin: showPinyin,
          maxVisibleLines: compactLayout ? 1 : 2,
          variant: PoemPinyinTextVariant.preview,
          alignment: Alignment.centerLeft,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              bundle.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: bundle.isCompleted ? Colors.green : Colors.amber[800],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bundle.isCompleted ? '今天已完成' : '今天待学习',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StudyCardPreview extends StatelessWidget {
  const _StudyCardPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '翻一张卡片',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text('先想一想，再看答案。', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
