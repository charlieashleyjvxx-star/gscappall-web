import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_list_tile.dart';
import '../poem_detail/poem_detail_page.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: SafeArea(
        child: favoritesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Center(
                child: Text(
                  UserFacingErrorMapper.message(
                    error,
                    fallbackMessage: '收藏加载失败，请稍后重试。',
                  ),
                ),
              ),
          data: (favorites) {
            if (favorites.isEmpty) {
              return const EmptyState(
                title: '收藏夹还是空的',
                description: '从诗词详情页点亮红心，就能把喜欢的诗词放到这里。',
                icon: Icons.favorite_border_rounded,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '我的收藏',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('共 ${favorites.length} 首，可离线继续学习。'),
                const SizedBox(height: 18),
                ...favorites.map(
                  (poem) => PoemListTile(
                    poem: poem,
                    showPinyin: showPinyin,
                    isFavorite: true,
                    onFavoriteToggle: () async {
                      await ref
                          .read(poemRepositoryProvider)
                          .setFavorite(poem.id, false);
                      ref.invalidate(favoritesProvider);
                      ref.invalidate(learningSummaryProvider);
                    },
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PoemDetailPage(poemId: poem.id),
                          ),
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
