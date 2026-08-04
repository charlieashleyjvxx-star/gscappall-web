import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/app_logger.dart';
import '../../core/user_facing_error.dart';
import '../../domain/poem.dart';
import '../../domain/practice_models.dart';
import '../../services/speech/speech_assessment_service.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/recognition_debug_card.dart';

enum _ReciteRevealLevel { full, fewMissing, halfHidden, fullyHidden }

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
  _ReciteRevealLevel _revealLevel = _ReciteRevealLevel.full;
  final Set<int> _completedLineIndexes = <int>{};
  bool _childSessionSaved = false;
  bool _isStarting = false;
  bool _isListening = false;
  bool _isStopping = false;
  bool _isScoring = false;
  bool _isSavingSession = false;
  DateTime? _sessionStartedAt;
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
    final speechDebugSnapshot = speechService.lastDebugSnapshot;
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('背一背'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _currentLineIndex = 0;
                _revealLevel = _ReciteRevealLevel.full;
                _completedLineIndexes.clear();
                _childSessionSaved = false;
                _lineScores.clear();
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
          final completedCount = _completedLineIndexes.length;
          final currentScore = _lineScores[safeLineIndex];
          final hasRecognizedText =
              _recognizedController.text.trim().isNotEmpty;
          final isLastLine = safeLineIndex >= lines.length - 1;
          final averageScore =
              _lineScores.isEmpty
                  ? null
                  : (_lineScores.values
                              .map((score) => score.totalScore)
                              .reduce((value, element) => value + element) /
                          _lineScores.length)
                      .round();
          final isLineComplete = _completedLineIndexes.contains(safeLineIndex);

          late final String primaryLabel;
          late final IconData primaryIcon;
          late final VoidCallback? primaryAction;
          if (_isStarting) {
            primaryLabel = '正在准备麦克风...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_isListening) {
            primaryLabel = '背完啦';
            primaryIcon = Icons.stop_circle_rounded;
            primaryAction = _requestStopRecognition;
          } else if (_isStopping) {
            primaryLabel = '正在整理背诵内容...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_isScoring) {
            primaryLabel = '正在生成反馈...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_isSavingSession) {
            primaryLabel = '正在保存练习...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_childSessionSaved) {
            primaryLabel = '再背一遍';
            primaryIcon = Icons.replay_rounded;
            primaryAction = _restartSession;
          } else if (isLineComplete) {
            primaryLabel = isLastLine ? '完成这首诗' : '练下一句';
            primaryIcon =
                isLastLine ? Icons.check_circle_rounded : Icons.arrow_forward;
            primaryAction =
                isLastLine
                    ? () => _finishChildRecitation(poem)
                    : () => _jumpToLine(safeLineIndex + 1);
          } else {
            primaryLabel = switch (_revealLevel) {
              _ReciteRevealLevel.full => '少几个字',
              _ReciteRevealLevel.fewMissing => '再遮一些',
              _ReciteRevealLevel.halfHidden => '全部遮住',
              _ReciteRevealLevel.fullyHidden => '我背完啦',
            };
            primaryIcon = switch (_revealLevel) {
              _ReciteRevealLevel.full ||
              _ReciteRevealLevel.fewMissing => Icons.visibility_outlined,
              _ReciteRevealLevel.halfHidden => Icons.visibility_off_outlined,
              _ReciteRevealLevel.fullyHidden =>
                Icons.check_circle_outline_rounded,
            };
            primaryAction = () => _advanceChildRecitation(safeLineIndex);
          }

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
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _revealLevelLabel(_revealLevel),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_revealLevel == _ReciteRevealLevel.full)
                        PoemPinyinText(
                          poem: poem,
                          lineIndices: [safeLineIndex],
                          showPinyin: showPinyin,
                          variant: PoemPinyinTextVariant.study,
                        )
                      else
                        Text(
                          _maskedLineForLevel(currentLine, _revealLevel),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            height: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PrimaryReciteCard(
                title: _recitePanelTitle(isLineComplete),
                message: _sessionMessage ?? _recitePanelMessage(isLineComplete),
                buttonLabel: primaryLabel,
                buttonIcon: primaryIcon,
                onPressed: primaryAction,
                secondaryLabel:
                    !isLineComplete &&
                            _revealLevel == _ReciteRevealLevel.fullyHidden &&
                            !_isListening &&
                            _supportsLiveRecognition &&
                            speechCapability.isAvailable
                        ? '我想挑战开口背'
                        : null,
                onSecondary:
                    !isLineComplete &&
                            _revealLevel == _ReciteRevealLevel.fullyHidden &&
                            !_isListening &&
                            _supportsLiveRecognition &&
                            speechCapability.isAvailable
                        ? () => _startRecognition(poem)
                        : null,
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: const Text('家长辅助'),
                subtitle: const Text('识别详情、练习反馈和诗句设置'),
                children: [
                  if (kDebugMode && speechDebugSnapshot != null) ...[
                    RecognitionDebugCard(
                      snapshot: speechDebugSnapshot,
                      nativeState: speechService.lastNativeState,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (currentScore != null) ...[
                    _LatestFeedbackCard(
                      lineIndex: safeLineIndex,
                      score: currentScore,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_lineScores.isNotEmpty) ...[
                    _SessionSummaryCard(
                      completedCount: _lineScores.length,
                      totalLines: lines.length,
                      averageScore: averageScore ?? 0,
                      weakLineIndexes: _weakLineIndexes(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isSavingSession
                                ? null
                                : () => _persistSession(poem, lines),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存评估记录'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _recognizedController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '手动修改背诵内容',
                      hintText: '自动听背不准确时，可以在这里修改',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '清空背诵内容',
                        onPressed:
                            hasRecognizedText
                                ? () => setState(() {
                                  _recognizedController.clear();
                                  _lineScores.remove(safeLineIndex);
                                })
                                : null,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed:
                          hasRecognizedText && !_isScoring
                              ? () => _scoreCurrentLine(
                                poem: poem,
                                currentLine: currentLine,
                                moveNext: false,
                              )
                              : null,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('生成家长反馈'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LineProgressWrap(
                    lines: lines,
                    selectedIndex: safeLineIndex,
                    lineScores: _lineScores,
                    onSelected: _handleLineSelected,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              safeLineIndex == 0
                                  ? null
                                  : () => _jumpToLine(safeLineIndex - 1),
                          icon: const Icon(Icons.chevron_left_rounded),
                          label: const Text('上一句'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              isLastLine
                                  ? null
                                  : () => _jumpToLine(safeLineIndex + 1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          label: const Text('下一句'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
      _revealLevel = _ReciteRevealLevel.full;
      _resetPracticeState(message: '已切换到新的背诵诗句。');
    });
  }

  void _jumpToLine(int index) {
    setState(() {
      _currentLineIndex = index;
      _revealLevel = _ReciteRevealLevel.full;
      _resetPracticeState(message: '已切换到新的背诵诗句。');
    });
  }

  void _advanceChildRecitation(int lineIndex) {
    setState(() {
      switch (_revealLevel) {
        case _ReciteRevealLevel.full:
          _revealLevel = _ReciteRevealLevel.fewMissing;
          _sessionMessage = '少了几个字，再试着读一遍。';
          break;
        case _ReciteRevealLevel.fewMissing:
          _revealLevel = _ReciteRevealLevel.halfHidden;
          _sessionMessage = '已经记住不少了，再挑战一次。';
          break;
        case _ReciteRevealLevel.halfHidden:
          _revealLevel = _ReciteRevealLevel.fullyHidden;
          _sessionMessage = '现在不看文字，试着完整背出来。';
          break;
        case _ReciteRevealLevel.fullyHidden:
          _completedLineIndexes.add(lineIndex);
          _sessionMessage = '这一句背完啦。';
          break;
      }
    });
  }

  String _revealLevelLabel(_ReciteRevealLevel level) {
    return switch (level) {
      _ReciteRevealLevel.full => '看着读',
      _ReciteRevealLevel.fewMissing => '少几个字',
      _ReciteRevealLevel.halfHidden => '再遮一些',
      _ReciteRevealLevel.fullyHidden => '全部遮住',
    };
  }

  String _recitePanelTitle(bool isLineComplete) {
    if (_childSessionSaved) {
      return '这首诗背完啦';
    }
    if (_isListening) {
      return '正在听你背';
    }
    if (isLineComplete) {
      return '做得好';
    }
    return _revealLevel == _ReciteRevealLevel.fullyHidden ? '轮到你背' : '记住这一句';
  }

  String _recitePanelMessage(bool isLineComplete) {
    if (_childSessionSaved) {
      return '今天的背诵完成了。';
    }
    if (isLineComplete) {
      return '可以继续下一句。';
    }
    return switch (_revealLevel) {
      _ReciteRevealLevel.full => '先看着读一遍，再慢慢遮住文字。',
      _ReciteRevealLevel.fewMissing => '想一想方框里藏着哪个字。',
      _ReciteRevealLevel.halfHidden => '不用着急，按自己的节奏说出来。',
      _ReciteRevealLevel.fullyHidden => '不看文字背一遍，背完点“我背完啦”。',
    };
  }

  Future<void> _finishChildRecitation(Poem poem) async {
    setState(() {
      _childSessionSaved = true;
      _sessionMessage = '今天的背诵完成了。';
    });
    try {
      await ref
          .read(learningRepositoryProvider)
          .logLearningRecord(
            poemId: poem.id,
            mode: PracticeMode.recitation.rawValue,
            durationMinutes: 1,
            note: '完成渐进背诵练习',
          );
      ref.invalidate(learningSummaryProvider);
      ref.invalidate(recentLearningRecordsProvider);
      ref.invalidate(learningHistoryProvider);
    } catch (_) {
      // Child completion does not depend on persistence or speech services.
    }
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
      _completedLineIndexes.add(_currentLineIndex);
      _sessionMessage = result.hasText ? '开口背完啦，做得好。' : '这次没有听清，也算完成开口挑战。';
    });
  }

  void _handleRecognitionError(Object error) {
    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    unawaited(subscription?.cancel() ?? Future<void>.value());

    if (!mounted) {
      return;
    }

    AppLogger.event(
      'recognition_failed',
      feature: 'recite',
      level: AppLogLevel.error,
    );
    setState(() {
      _isStarting = false;
      _isListening = false;
      _isStopping = false;
      _completedLineIndexes.add(_currentLineIndex);
      _sessionMessage = '这次没有听清，也算完成开口挑战。';
    });
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
        _completedLineIndexes.add(_currentLineIndex);
        _sessionMessage = hadText ? '开口背完啦，做得好。' : '这次没有听清，也算完成开口挑战。';
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

  void _restartSession() {
    setState(() {
      _currentLineIndex = 0;
      _revealLevel = _ReciteRevealLevel.full;
      _completedLineIndexes.clear();
      _childSessionSaved = false;
      _lineScores.clear();
      _resetPracticeState(message: '从第一句重新开始。');
    });
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

  String _maskedLineForLevel(String line, _ReciteRevealLevel level) {
    var visibleCharacterIndex = 0;
    return line.split('').map((character) {
      final isContent = RegExp(r'[A-Za-z0-9\u4E00-\u9FFF]').hasMatch(character);
      if (!isContent) {
        return character;
      }
      final index = visibleCharacterIndex++;
      final hide = switch (level) {
        _ReciteRevealLevel.full => false,
        _ReciteRevealLevel.fewMissing => index % 4 == 1,
        _ReciteRevealLevel.halfHidden => index.isOdd,
        _ReciteRevealLevel.fullyHidden => true,
      };
      return hide ? '□' : character;
    }).join();
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('第 ${currentLineIndex + 1} 句')),
                Text(
                  '$completedCount / $totalLines 已完成',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
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

class _PrimaryReciteCard extends StatelessWidget {
  const _PrimaryReciteCard({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback? onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(buttonIcon),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
  });

  final int completedCount;
  final int totalLines;
  final int averageScore;
  final List<int> weakLineIndexes;

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
          ],
        ),
      ),
    );
  }
}
