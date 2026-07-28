import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../services/game/challenge_progress_service.dart';
import '../../services/game/poetry_jielong_service.dart';
import '../../shared/widgets/section_card.dart';

class PoetryJielongPage extends ConsumerStatefulWidget {
  const PoetryJielongPage({super.key});

  @override
  ConsumerState<PoetryJielongPage> createState() => _PoetryJielongPageState();
}

class _PoetryJielongPageState extends ConsumerState<PoetryJielongPage> {
  final TextEditingController _controller = TextEditingController();
  final Set<String> _usedKeys = <String>{};
  final List<PoetryJielongLine> _chain = <PoetryJielongLine>[];

  String? _targetChar;
  String? _targetPinyin;
  String? _message;
  int _sameSoundCount = 0;
  bool _saved = false;
  bool _pointsAwarded = false;
  PoetryJielongReport? _report;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poemsFuture = ref.watch(poemRepositoryProvider).fetchPoems();

    return Scaffold(
      appBar: AppBar(title: const Text('诗词接龙')),
      body: FutureBuilder<List<Poem>>(
        future: poemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                UserFacingErrorMapper.message(
                  snapshot.error!,
                  fallbackMessage: '诗词库加载失败，请稍后重试。',
                ),
              ),
            );
          }

          final service = ref.watch(poetryJielongServiceProvider);
          final bank = service.buildLineBank(snapshot.data ?? const []);
          if (bank.isEmpty) {
            return const Center(child: Text('本地诗词库暂无可接龙的诗句。'));
          }

          _ensureStarted(bank);
          final targetChar = _targetChar ?? bank.first.lastChar;
          final targetPinyin = _targetPinyin ?? bank.first.lastPinyin;
          final suggestions = service.suggestionsForTarget(
            bank,
            targetChar: targetChar,
            targetPinyin: targetPinyin,
            usedKeys: _usedKeys,
            limit: 5,
          );

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _JielongHero(
                  targetChar: targetChar,
                  targetPinyin: targetPinyin,
                  roundCount: _chain.length,
                  sameSoundCount: _sameSoundCount,
                  saved: _saved,
                ),
                const SizedBox(height: 16),
                if (_report != null) ...[
                  _CompletionReportCard(
                    report: _report!,
                    pointsAwarded: _pointsAwarded,
                  ),
                  const SizedBox(height: 16),
                ],
                SectionCard(
                  title: '当前接龙',
                  subtitle: '接上一句，继续挑战。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: '输入以“$targetChar”开头或同音的诗句',
                          hintText:
                              suggestions.isEmpty
                                  ? '例如输入完整诗句'
                                  : suggestions.first.text,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submit(bank, service),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _submit(bank, service),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('接一句'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed:
                                suggestions.isEmpty
                                    ? null
                                    : () {
                                      _controller.text = suggestions.first.text;
                                      _submit(bank, service);
                                    },
                            icon: const Icon(Icons.tips_and_updates_rounded),
                            label: const Text('用提示'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _restart(bank),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重开'),
                          ),
                        ],
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: TextStyle(
                            color:
                                _message!.contains('接上')
                                    ? const Color(0xFF3F7D45)
                                    : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '提示',
                  subtitle: suggestions.isEmpty ? '可以重开一局。' : '想不起来时看一眼。',
                  child:
                      suggestions.isEmpty
                          ? const Text('暂无候选。')
                          : Column(
                            children: suggestions
                                .map(
                                  (line) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(line.text),
                                    subtitle: Text(
                                      '《${line.poem.title}》${line.poem.author}',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () {
                                      _controller.text = line.text;
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: '接龙记录',
                  subtitle: '完成 3 句就能得到星星。',
                  child: Column(
                    children: _chain
                        .asMap()
                        .entries
                        .map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFFFF2D6),
                              child: Text('${entry.key + 1}'),
                            ),
                            title: Text(entry.value.text),
                            subtitle: Text('《${entry.value.poem.title}》'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _ensureStarted(List<PoetryJielongLine> bank) {
    if (_chain.isNotEmpty) {
      return;
    }
    final starter = bank[Random(DateTime.now().day).nextInt(bank.length)];
    _chain.add(starter);
    _usedKeys.add(starter.key);
    _targetChar = starter.lastChar;
    _targetPinyin = starter.lastPinyin;
  }

  void _restart(List<PoetryJielongLine> bank) {
    setState(() {
      _chain.clear();
      _usedKeys.clear();
      _controller.clear();
      _message = null;
      _sameSoundCount = 0;
      _saved = false;
      _pointsAwarded = false;
      _report = null;
      final starter = bank[Random().nextInt(bank.length)];
      _chain.add(starter);
      _usedKeys.add(starter.key);
      _targetChar = starter.lastChar;
      _targetPinyin = starter.lastPinyin;
    });
  }

  Future<void> _submit(
    List<PoetryJielongLine> bank,
    PoetryJielongService service,
  ) async {
    final targetChar = _targetChar;
    final targetPinyin = _targetPinyin;
    if (targetChar == null || targetPinyin == null) {
      return;
    }
    final result = service.validateTurn(
      bank: bank,
      input: _controller.text,
      targetChar: targetChar,
      targetPinyin: targetPinyin,
      usedKeys: _usedKeys,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _message = result.message;
      if (result.accepted && result.line != null) {
        _chain.add(result.line!);
        _usedKeys.add(result.line!.key);
        _targetChar = result.line!.lastChar;
        _targetPinyin = result.line!.lastPinyin;
        if (result.sameSoundFallback) {
          _sameSoundCount += 1;
        }
        _controller.clear();
      }
    });

    if (result.accepted && !_saved && _chain.length >= 3) {
      final report = service.buildReport(
        lineCount: _chain.length,
        sameSoundCount: _sameSoundCount,
      );
      final stageId = const ChallengeProgressService().stageIdForResult(
        mode: 'poetry_jielong',
        score: report.score,
        completedLines: _chain.length,
      );
      await ref
          .read(learningRepositoryProvider)
          .logLearningRecord(
            poemId: result.line!.poem.id,
            mode: 'poetry_jielong',
            durationMinutes: max(1, _chain.length * 2),
            score: report.score,
            note: report.summary,
            stageId: stageId,
          );
      final pointsAwarded = await ref
          .read(learningRepositoryProvider)
          .awardActivityPoints(
            activityType: 'poetry_jielong',
            points: report.points,
          );
      _refreshLearningProviders();
      if (mounted) {
        setState(() {
          _saved = true;
          _pointsAwarded = pointsAwarded;
          _report = report;
          _message = pointsAwarded ? '挑战完成，星星已记录。' : '挑战完成，今天已经记录过一次。';
        });
      }
    }
  }

  void _refreshLearningProviders() {
    ref.invalidate(learningSummaryProvider);
    ref.invalidate(learningGrowthReportProvider);
    ref.invalidate(dailyPoemProgressProvider);
    ref.invalidate(recentLearningRecordsProvider);
    ref.invalidate(learningHistoryProvider);
  }
}

class _JielongHero extends StatelessWidget {
  const _JielongHero({
    required this.targetChar,
    required this.targetPinyin,
    required this.roundCount,
    required this.sameSoundCount,
    required this.saved,
  });

  final String targetChar;
  final String targetPinyin;
  final int roundCount;
  final int sameSoundCount;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD99B), Color(0xFFFFF4DE)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  targetPinyin.isEmpty ? '-' : targetPinyin,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  targetChar,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF8A5A12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('下一句首字', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  '已接 $roundCount 句 · 同音 $sameSoundCount 次${saved ? ' · 已记录' : ''}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('接上一句，完成 3 句就能得到星星。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionReportCard extends StatelessWidget {
  const _CompletionReportCard({
    required this.report,
    required this.pointsAwarded,
  });

  final PoetryJielongReport report;
  final bool pointsAwarded;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '本局结果',
      subtitle: report.summary,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ReportChip(label: '句数', value: '${report.lineCount}'),
          _ReportChip(label: '提示', value: '${report.sameSoundCount}'),
          _ReportChip(label: '得分', value: '${report.score}'),
          _ReportChip(
            label: pointsAwarded ? '星星' : '今天已记',
            value: pointsAwarded ? '已得' : '已完成',
          ),
        ],
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value'),
      backgroundColor: const Color(0xFFFFF2D6),
    );
  }
}
