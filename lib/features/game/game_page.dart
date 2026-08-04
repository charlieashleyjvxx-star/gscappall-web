import 'package:flutter/material.dart';

import '../../app/app_design.dart';
import '../dictation/dictation_page.dart';
import 'feihualing_page.dart';
import 'poetry_jielong_page.dart';

class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('练习')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.readingMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.large,
                AppSpacing.medium,
                AppSpacing.large,
                AppSpacing.xLarge,
              ),
              children: [
                _GameEntryGrid(
                  entries: [
                    _GameEntryData(
                      title: '听写模块',
                      subtitle: '逐句默写，错了就进错题本。',
                      icon: Icons.edit_note_rounded,
                      color: const Color(0xFFB6E3FF),
                      onTap: () => _openPage(context, const DictationPage()),
                    ),
                    _GameEntryData(
                      title: '同音接龙',
                      subtitle: '根据诗句首字或同音继续接龙。',
                      icon: Icons.link_rounded,
                      color: const Color(0xFFFFD89C),
                      onTap:
                          () => _openPage(context, const PoetryJielongPage()),
                    ),
                    _GameEntryData(
                      title: '飞花初试',
                      subtitle: '围绕主题字说出对应诗句。',
                      icon: Icons.local_florist_rounded,
                      color: const Color(0xFFFFB7A5),
                      onTap: () => _openPage(context, const FeihualingPage()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _GameEntryGrid extends StatelessWidget {
  const _GameEntryGrid({required this.entries});

  final List<_GameEntryData> entries;

  @override
  Widget build(BuildContext context) {
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: compactLayout ? 10 : 12,
        crossAxisSpacing: compactLayout ? 10 : 12,
        childAspectRatio: compactLayout ? 1.34 : 1.08,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _GameEntryCard(entry: entries[index]),
    );
  }
}

class _GameEntryCard extends StatelessWidget {
  const _GameEntryCard({required this.entry});

  final _GameEntryData entry;

  @override
  Widget build(BuildContext context) {
    final compactLayout =
        MediaQuery.sizeOf(context).width < AppLayout.compactWidth;
    return Semantics(
      button: true,
      label: '${entry.title}，${entry.subtitle}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.feature),
        onTap: entry.onTap,
        child: Container(
          padding: EdgeInsets.all(compactLayout ? 13 : 16),
          decoration: BoxDecoration(
            color: entry.color,
            borderRadius: BorderRadius.circular(AppRadii.feature),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.icon,
                size: compactLayout ? 26 : 30,
                color: const Color(0xFF5F4211),
              ),
              const Spacer(),
              Text(
                entry.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: compactLayout ? 4 : 6),
              Text(
                entry.subtitle,
                maxLines: compactLayout ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameEntryData {
  const _GameEntryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
}
