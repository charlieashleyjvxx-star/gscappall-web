import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/app_logger.dart';
import '../../core/service_status.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../domain/practice_models.dart';
import '../../services/speech/speech_assessment_service.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/recognition_debug_card.dart';

class RecitePlaceholderPage extends ConsumerStatefulWidget {
  const RecitePlaceholderPage({super.key, this.poemId});

  final int? poemId;

  @override
  ConsumerState<RecitePlaceholderPage> createState() =>
      _RecitePlaceholderPageState();
}

class _RecitePlaceholderPageState extends ConsumerState<RecitePlaceholderPage> {
  final TextEditingController _recognizedController = TextEditingController();
  StreamSubscription<SpeechRecognitionResult>? _recognitionSubscription;
  late Future<Poem?> _poemFuture;
  final Map<int, SpeechAssessmentResult> _lineScores =
      <int, SpeechAssessmentResult>{};
  int _currentLineIndex = 0;
  int? _latestScoredLineIndex;
  bool _showHint = true;
  bool _isStarting = false;
  bool _isListening = false;
  bool _isStopping = false;
  bool _isScoring = false;
  bool _isSavingSession = false;
  DateTime? _sessionStartedAt;
  SpeechAssessmentResult? _latestScore;
  String? _sessionMessage;

  bool get _supportsLiveRecognition {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _poemFuture = _loadPoem();
  }

  @override
  void dispose() {
    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    unawaited(subscription?.cancel() ?? Future<void>.value());
    _recognizedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speechService = ref.watch(speechRecognitionServiceProvider);
    final speechCapability = speechService.capability;
    final recorderCapability = ref.watch(recorderServiceProvider).capability;
    final scoringCapability = ref.watch(speechAssessmentProvider).capability;
    final speechDebugSnapshot = speechService.lastDebugSnapshot;
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('背诵模式'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _currentLineIndex = 0;
                _latestScoredLineIndex = null;
                _showHint = true;
                _lineScores.clear();
                _latestScore = null;
                _resetPracticeState(message: '已刷新背诵练习。');
                _poemFuture = _loadPoem();
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Poem?>(
        future: _poemFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final poem = snapshot.data;
          if (poem == null) {
            return const EmptyState(
              title: '暂时没有可背诵的诗词',
              description: '请先确认本地诗词数据已经导入，或稍后从诗词详情页进入背诵练习。',
              icon: Icons.mic_none_rounded,
            );
          }

          final lines = poem.lines;
          if (lines.isEmpty) {
            return const EmptyState(
              title: '这首诗缺少可练习的诗句',
              description: '当前无法进行逐句背诵，请换一首诗继续。',
              icon: Icons.short_text_rounded,
            );
          }

          final safeLineIndex = _currentLineIndex.clamp(0, lines.length - 1);
          final currentLine = lines[safeLineIndex];
          final completedCount = _lineScores.length;
          final averageScore =
              completedCount == 0
                  ? null
                  : (_lineScores.values
                              .map((score) => score.totalScore)
                              .reduce((value, element) => value + element) /
                          completedCount)
                      .round();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ReciteHeaderCard(
                poem: poem,
                currentLineIndex: safeLineIndex,
                totalLines: lines.length,
                completedCount: completedCount,
              ),
              const SizedBox(height: 16),
              _CapabilityBanner(
                speechCapability: speechCapability,
                recorderCapability: recorderCapability,
                scoringCapability: scoringCapability,
                isListening: _isListening,
                message:
                    _sessionMessage ??
                    _defaultPracticeMessage(speechCapability),
              ),
              if (kDebugMode && speechDebugSnapshot != null) ...[
                const SizedBox(height: 16),
                RecognitionDebugCard(
                  snapshot: speechDebugSnapshot,
                  nativeState: speechService.lastNativeState,
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '逐句练习',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Switch.adaptive(
                            value: _showHint,
                            onChanged: (value) {
                              setState(() {
                                _showHint = value;
                              });
                            },
                          ),
                          Text(_showHint ? '提示开' : '提示关'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LineProgressWrap(
                        lines: lines,
                        selectedIndex: safeLineIndex,
                        lineScores: _lineScores,
                        onSelected: _handleLineSelected,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7EEDC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE4CFA6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '第 ${safeLineIndex + 1} 句',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_showHint)
                              PoemPinyinText(
                                poem: poem,
                                lineIndices: [safeLineIndex],
                                showPinyin: showPinyin,
                                variant: PoemPinyinTextVariant.study,
                              )
                            else
                              Text(
                                _maskedLine(currentLine),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  height: 1.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              _showHint
                                  ? '先看提示背一遍，再试着自己背。'
                                  : '提示已关闭，先完整背一遍，再看哪里要复习。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '背完看一看',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                !_supportsLiveRecognition ||
                                        !speechCapability.isAvailable ||
                                        _isStarting ||
                                        _isListening ||
                                        _isStopping
                                    ? null
                                    : () => _startRecognition(poem),
                            icon: Icon(
                              _isListening
                                  ? Icons.hearing_rounded
                                  : Icons.mic_rounded,
                            ),
                            label: Text(
                              _isStarting
                                  ? '准备中...'
                                  : (_isListening ? '正在听' : '开始跟背'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                (!_isListening && !_isStarting) || _isStopping
                                    ? null
                                    : _requestStopRecognition,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('停止'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _resetPracticeState(message: '已清空当前背诵文本。');
                              });
                            },
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('清空文本'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _recognizedController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: '背诵结果',
                          hintText:
                              _supportsLiveRecognition
                                  ? '背诵内容会写在这里，也可以自己修改'
                                  : '把背出来的内容写在这里',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                _isScoring
                                    ? null
                                    : () => _scoreCurrentLine(
                                      poem: poem,
                                      currentLine: currentLine,
                                      moveNext: false,
                                    ),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(_isScoring ? '正在看...' : '看看本句'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed:
                                _isScoring
                                    ? null
                                    : () => _scoreCurrentLine(
                                      poem: poem,
                                      currentLine: currentLine,
                                      moveNext: true,
                                    ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('看完下一句'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                safeLineIndex == 0
                                    ? null
                                    : () => _jumpToLine(safeLineIndex - 1),
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('上一句'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                safeLineIndex >= lines.length - 1
                                    ? null
                                    : () => _jumpToLine(safeLineIndex + 1),
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('下一句'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_latestScore != null && _latestScoredLineIndex != null) ...[
                const SizedBox(height: 16),
                _LatestFeedbackCard(
                  lineIndex: _latestScoredLineIndex!,
                  score: _latestScore!,
                ),
              ],
              if (_lineScores.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SessionSummaryCard(
                  completedCount: completedCount,
                  totalLines: lines.length,
                  averageScore: averageScore ?? 0,
                  weakLineIndexes: _weakLineIndexes(),
                  onSave:
                      _isSavingSession
                          ? null
                          : () => _persistSession(poem, lines),
                  isSaving: _isSavingSession,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<Poem?> _loadPoem() async {
    if (widget.poemId != null) {
      return ref.read(poemRepositoryProvider).fetchPoemById(widget.poemId!);
    }

    try {
      final dailyPoem = await ref
          .read(poemRepositoryProvider)
          .getDailyPoem(DateTime.now());
      return dailyPoem.poem;
    } catch (_) {
      final poems = await ref.read(poemRepositoryProvider).fetchPoems();
      if (poems.isEmpty) {
        return null;
      }
      return poems.first;
    }
  }

  void _handleLineSelected(int index) {
    setState(() {
      _currentLineIndex = index;
      _resetPracticeState(message: '已切换到新的背诵诗句。');
    });
  }

  void _jumpToLine(int index) {
    setState(() {
      _currentLineIndex = index;
      _resetPracticeState(message: '已切换到新的背诵诗句。');
    });
  }

  Future<void> _startRecognition(Poem poem) async {
    if (_isListening || _isStarting) {
      return;
    }

    AppLogger.event('recognition_started', feature: 'recite');

    final speechService = ref.read(speechRecognitionServiceProvider);
    final recorderService = ref.read(recorderServiceProvider);

    setState(() {
      _isStarting = true;
      _isListening = false;
      _isStopping = false;
      _latestScore = null;
      _sessionStartedAt ??= DateTime.now();
      _sessionMessage =
          _supportsLiveRecognition ? '正在准备跟背，请开始背诵。' : '可以先把背出的内容写下来。';
      _recognizedController.clear();
    });

    if (!_supportsLiveRecognition) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isStarting = false;
        _isStopping = false;
      });
      _showSnackBar('可以先把背出的内容写下来，再看看这一句。');
      return;
    }

    try {
      if (recorderService.capability.isAvailable) {
        await recorderService.requestPermission();
      }

      await speechService.initialize();
      await _cancelRecognitionSession();
      final subscription = speechService.recognize().listen(
        _handleRecognitionResult,
        onError: (Object error, StackTrace stackTrace) {
          _handleRecognitionError(error);
        },
      );
      _recognitionSubscription = subscription;

      if (!mounted) {
        await subscription.cancel();
        return;
      }

      setState(() {
        _isStarting = false;
        _isListening = true;
        _sessionMessage = '已经开始听了，请背诵当前诗句。';
      });
    } catch (error) {
      _handleRecognitionError(error);
    }
  }

  void _handleRecognitionResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }

    AppLogger.event(
      'recognition_result',
      feature: 'recite',
      fields: {'textLength': result.text.length, 'isFinal': result.isFinal},
    );

    _updateRecognizedText(result.text);

    if (!result.isFinal) {
      setState(() {
        _isStarting = false;
        _isListening = true;
        _sessionMessage = '正在听，请继续背诵当前诗句。';
      });
      return;
    }

    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    unawaited(subscription?.cancel() ?? Future<void>.value());

    setState(() {
      _isStarting = false;
      _isListening = false;
      _isStopping = false;
      _sessionMessage =
          result.hasText ? '已经听完，可以看看这一句。' : '这次没听清，可以再试一次或自己写下来。';
    });

    if (!result.hasText) {
      _showSnackBar('这次没听清，可以再试一次。');
    }
  }

  void _handleRecognitionError(Object error) {
    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    unawaited(subscription?.cancel() ?? Future<void>.value());

    if (!mounted) {
      return;
    }

    final message = _describeError(error);
    AppLogger.event(
      'recognition_failed',
      feature: 'recite',
      level: AppLogLevel.error,
    );
    setState(() {
      _isStarting = false;
      _isListening = false;
      _isStopping = false;
      _sessionMessage = message;
    });
    _showSnackBar(message);
  }

  // ignore: unused_element
  Future<void> _stopRecognition() async {
    final hadText = _recognizedController.text.trim().isNotEmpty;
    await _cancelRecognitionSession();

    if (!mounted) {
      return;
    }

    setState(() {
      _isStarting = false;
      _isListening = false;
      _sessionMessage = hadText ? '已经停下，可以看看这一句。' : '已经停下，可以再试一次或自己写下来。';
    });
  }

  Future<void> _requestStopRecognition() async {
    if (_isStopping) {
      return;
    }

    AppLogger.event('recognition_stop_requested', feature: 'recite');

    final speechService = ref.read(speechRecognitionServiceProvider);
    final hadText = _recognizedController.text.trim().isNotEmpty;

    setState(() {
      _isStarting = false;
      _isStopping = true;
      _sessionMessage = hadText ? '已经停下，正在整理背诵内容...' : '已经停下，正在整理这一次练习...';
    });

    try {
      await speechService.stop();
    } catch (error) {
      _handleRecognitionError(error);
      return;
    }

    if (!mounted) {
      return;
    }

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted || !_isStopping) {
        return;
      }

      setState(() {
        _isStopping = false;
        _isListening = false;
        _sessionMessage = hadText ? '已经停下，可以看看这一句。' : '这次没有听清，可以再试一次或自己写下来。';
      });
    });
  }

  Future<void> _scoreCurrentLine({
    required Poem poem,
    required String currentLine,
    required bool moveNext,
  }) async {
    final recognizedText = _recognizedController.text.trim();
    if (recognizedText.isEmpty) {
      _showSnackBar('请先背一遍，或把背出的内容写下来。');
      return;
    }

    final scoredLineIndex = _currentLineIndex;

    setState(() {
      _isScoring = true;
    });

    try {
      final score = await ref
          .read(speechAssessmentProvider)
          .assess(
            SpeechAssessmentRequest(
              mode: SpeechAssessmentMode.recitation,
              expectedText: currentLine,
              attemptText: recognizedText,
              duration: _sessionDuration,
              metadata: <String, Object?>{
                'poemId': poem.id,
                'lineIndex': scoredLineIndex,
              },
            ),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isScoring = false;
        _latestScore = score;
        _latestScoredLineIndex = scoredLineIndex;
        _lineScores[scoredLineIndex] = score;
        _sessionMessage = '第 ${scoredLineIndex + 1} 句已经看完，请继续练习。';

        if (moveNext && scoredLineIndex < poem.lines.length - 1) {
          _currentLineIndex = scoredLineIndex + 1;
          _recognizedController.clear();
          _isListening = false;
          _isStarting = false;
        }
      });

      _showSnackBar('第 ${scoredLineIndex + 1} 句看完了。');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _describeError(error);
      setState(() {
        _isScoring = false;
        _sessionMessage = '暂时看不了这一句：$message';
      });
      _showSnackBar('暂时看不了这一句：$message');
    }
  }

  Future<void> _persistSession(Poem poem, List<String> lines) async {
    if (_lineScores.isEmpty) {
      _showSnackBar('请至少看完一句后再保存背诵记录。');
      return;
    }

    setState(() {
      _isSavingSession = true;
    });

    try {
      final scoredEntries = _lineScores.entries.toList(growable: false)
        ..sort((left, right) => left.key.compareTo(right.key));
      await ref
          .read(practiceRepositoryProvider)
          .saveAssessmentReport(
            poem: poem,
            mode: PracticeMode.recitation,
            results: [
              for (final entry in scoredEntries)
                PracticeLineResult(
                  question: PracticeQuestion(
                    poemId: poem.id,
                    poemTitle: poem.title,
                    poemAuthor: poem.author,
                    lineIndex: entry.key,
                    prompt: 'Recitation line ${entry.key + 1}',
                    hint: poem.title,
                    expectedAnswer: lines[entry.key],
                  ),
                  answer: entry.value.rawAttemptText,
                  isCorrect: entry.value.totalScore >= 80,
                  score: entry.value.totalScore,
                  feedback: entry.value.feedback,
                  assessment: PracticeAssessmentMetrics(
                    engine: entry.value.engine,
                    confidence: entry.value.confidence,
                    accuracy: entry.value.accuracy,
                    fluency: entry.value.fluency,
                    integrity: entry.value.completeness,
                    assessmentBasis: entry.value.assessmentBasis,
                    audioFilePath: entry.value.audioFilePath,
                    rawPayloadJson: jsonEncode(entry.value.rawProviderPayload),
                  ),
                ),
            ],
          );

      ref.invalidate(learningSummaryProvider);
      ref.invalidate(recentLearningRecordsProvider);
      ref.invalidate(learningHistoryProvider);
      ref.invalidate(practiceReportOverviewProvider);
      ref.invalidate(practiceReportSummariesProvider);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingSession = false;
        _sessionMessage = '本次背诵练习已写入本地学习记录。';
      });
      _showSnackBar('已保存《${poem.title}》的背诵记录。');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _describeError(error);
      setState(() {
        _isSavingSession = false;
        _sessionMessage = '写入背诵记录失败：$message';
      });
      _showSnackBar('保存失败：$message');
    }
  }

  List<int> _weakLineIndexes() {
    final indexes = _lineScores.entries
        .where((entry) => entry.value.totalScore < 80)
        .map((entry) => entry.key)
        .toList(growable: false);
    indexes.sort();
    return indexes;
  }

  void _resetPracticeState({String? message}) {
    unawaited(_cancelRecognitionSession());
    _recognizedController.clear();
    _sessionStartedAt = null;
    _sessionMessage = message;
    _isListening = false;
    _isStarting = false;
    _isStopping = false;
    _isScoring = false;
    _isSavingSession = false;
  }

  Future<void> _cancelRecognitionSession() async {
    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    await subscription?.cancel();
  }

  void _updateRecognizedText(String value) {
    _recognizedController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _describeError(Object error) {
    return UserFacingErrorMapper.message(
      error,
      fallbackMessage: '语音识别暂时不可用，请稍后重试。',
    );
  }

  String _defaultPracticeMessage(ServiceCapability speechCapability) {
    if (_supportsLiveRecognition) {
      if (speechCapability.isAvailable) {
        return '可以先看提示背一遍，熟了以后关掉提示自测。';
      }
      return '暂时不能自动听背诵，也可以先手动写下背诵内容。';
    }

    return '可以先手动写下背诵内容，再看看这一句背得怎么样。';
  }

  String _maskedLine(String line) {
    return line.replaceAllMapped(
      RegExp(r'[A-Za-z0-9\u4E00-\u9FFF]'),
      (_) => '□',
    );
  }

  Duration get _sessionDuration {
    if (_sessionStartedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_sessionStartedAt!);
  }
}

class _ReciteHeaderCard extends StatelessWidget {
  const _ReciteHeaderCard({
    required this.poem,
    required this.currentLineIndex,
    required this.totalLines,
    required this.completedCount,
  });

  final Poem poem;
  final int currentLineIndex;
  final int totalLines;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalLines == 0 ? 0.0 : completedCount / totalLines;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poem.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${poem.dynasty} · ${poem.author}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(poem.category)),
                Chip(label: Text('第 ${currentLineIndex + 1} / $totalLines 句')),
                Chip(label: Text('已完成 $completedCount 句')),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityBanner extends StatelessWidget {
  const _CapabilityBanner({
    required this.speechCapability,
    required this.recorderCapability,
    required this.scoringCapability,
    required this.isListening,
    required this.message,
  });

  final ServiceCapability speechCapability;
  final ServiceCapability recorderCapability;
  final ServiceCapability scoringCapability;
  final bool isListening;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6D3AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isListening
                    ? Icons.hearing_rounded
                    : Icons.lightbulb_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CapabilityChip(label: '跟背检查', capability: speechCapability),
              _CapabilityChip(label: '录音回放', capability: recorderCapability),
              _CapabilityChip(label: '背诵反馈', capability: scoringCapability),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.label, required this.capability});

  final String label;
  final ServiceCapability capability;

  @override
  Widget build(BuildContext context) {
    final (chipColor, text) = switch (capability.state) {
      ServiceState.available => (const Color(0xFFDDF3E1), '可以'),
      ServiceState.placeholder => (const Color(0xFFFFE9C8), '稍后'),
      ServiceState.unavailable => (const Color(0xFFF6D7D4), '稍后'),
    };

    return Chip(backgroundColor: chipColor, label: Text('$label：$text'));
  }
}

class _LineProgressWrap extends StatelessWidget {
  const _LineProgressWrap({
    required this.lines,
    required this.selectedIndex,
    required this.lineScores,
    required this.onSelected,
  });

  final List<String> lines;
  final int selectedIndex;
  final Map<int, SpeechAssessmentResult> lineScores;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(lines.length, (index) {
        final score = lineScores[index];
        final label =
            score == null
                ? '第 ${index + 1} 句'
                : '第 ${index + 1} 句 ${score.totalScore}';
        return ChoiceChip(
          label: Text(label),
          selected: index == selectedIndex,
          avatar:
              score == null
                  ? null
                  : Icon(
                    score.totalScore >= 80
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                  ),
          onSelected: (_) => onSelected(index),
        );
      }),
    );
  }
}

class _LatestFeedbackCard extends StatelessWidget {
  const _LatestFeedbackCard({required this.lineIndex, required this.score});

  final int lineIndex;
  final SpeechAssessmentResult score;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('总分', '${score.totalScore}'),
      ('准确度', '${score.accuracy}'),
      ('完整度', '${score.completeness}'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 ${lineIndex + 1} 句反馈',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map((item) {
                    return Container(
                      width: 112,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBDD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              score.feedback,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.completedCount,
    required this.totalLines,
    required this.averageScore,
    required this.weakLineIndexes,
    required this.onSave,
    required this.isSaving,
  });

  final int completedCount;
  final int totalLines;
  final int averageScore;
  final List<int> weakLineIndexes;
  final VoidCallback? onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final weakLineText =
        weakLineIndexes.isEmpty
            ? '当前没有低于 80 分的句子。'
            : weakLineIndexes.map((index) => '第 ${index + 1} 句').join('、');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本次背诵小结',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('已看完句数')),
                Text(
                  '$completedCount / $totalLines',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Text('平均分')),
                Text(
                  '$averageScore',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '薄弱句：$weakLineText',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: Text(isSaving ? '保存中...' : '保存本次背诵记录'),
            ),
          ],
        ),
      ),
    );
  }
}
