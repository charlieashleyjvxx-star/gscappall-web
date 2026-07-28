import 'package:flutter/material.dart';

import '../../domain/poem.dart';
import '../../app/app_design.dart';
import 'poem_pinyin_text.dart';

class PoemListTile extends StatelessWidget {
  const PoemListTile({
    super.key,
    required this.poem,
    required this.onTap,
    this.isFavorite,
    this.onFavoriteToggle,
    this.showPinyin = true,
  });

  final Poem poem;
  final VoidCallback onTap;
  final bool? isFavorite;
  final VoidCallback? onFavoriteToggle;
  final bool showPinyin;

  @override
  Widget build(BuildContext context) {
    final lines = poem.lines;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.small,
        ),
        title: Text(
          poem.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${poem.dynasty} · ${poem.author}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (showPinyin)
                PoemPinyinText(
                  poem: poem,
                  maxVisibleLines: 1,
                  variant: PoemPinyinTextVariant.list,
                  alignment: Alignment.centerLeft,
                )
              else
                Text(
                  '${poem.category} · ${lines.isEmpty ? poem.content : lines.first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        trailing:
            onFavoriteToggle == null
                ? const Icon(Icons.chevron_right_rounded)
                : IconButton(
                  onPressed: onFavoriteToggle,
                  tooltip: isFavorite == true ? '取消收藏' : '收藏',
                  icon: Icon(
                    isFavorite == true
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite == true ? Colors.redAccent : null,
                  ),
                ),
      ),
    );
  }
}
