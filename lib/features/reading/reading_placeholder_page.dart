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
import '../../services/speech/poem_recognition_post_processor.dart';
import '../../services/speech/speech_assessment_service.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_pinyin_text.dart';
import '../../shared/widgets/recognition_debug_card.dart';

class ReadingPlaceholderPage extends ConsumerStatefulWidget {
  const ReadingPlaceholderPage({super.key, this.poemId});

  final int? poemId;

  @override
  ConsumerState<ReadingPlaceholderPage> createState() =>
      _ReadingPlaceholderPageState();
}

class _ReadingPlaceholderPageState extends ConsumerState<ReadingPlaceholderPage>
    with WidgetsBindingObserver {
  final TextEditingController _recognizedController = TextEditingController();
  final PoemRecognitionPostProcessor _postProcessor =
      const PoemRecognitionPostProcessor();

  StreamSubscription<SpeechRecognitionResult>? _recognitionSubscription;
  late Future<Poem?> _poemFuture;
  Poem? _activePoem;
  int? _activeLineIndex;

  int _selectedLineIndex = 0;
  bool _isStarting = false;
  bool _isListening = false;
  bool _isStopping = false;
  bool _isSaving = false;
  bool _isPracticeRecording = false;
  bool _isPreparingDemoAudio = false;
  bool _isDemoPlaybackActive = false;
  DateTime? _sessionStartedAt;
  SpeechAssessmentResult? _lastScore;
  String? _sessionMessage;
  String? _lastRawRecognitionText;
  String? _practiceRecordingPath;
  String? _playingSource;
  double _playbackSpeed = 1.0;

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

  bool get _supportsNativeTextToSpeech {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _isAudioPlaying => _playingSource != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poemFuture = _loadPoem();
    unawaited(_refreshRecorderPermission());
    if (_supportsNativeTextToSpeech) {
      unawaited(_primeTextToSpeech());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    unawaited(subscription?.cancel() ?? Future<void>.value());
    unawaited(ref.read(audioPlayerServiceProvider).stop());
    if (_isPracticeRecording) {
      unawaited(ref.read(recorderServiceProvider).stop());
    }
    _recognizedController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshRecorderPermission());
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioCapability = ref.watch(audioPlayerServiceProvider).capability;
    final textToSpeechCapability =
        ref.watch(textToSpeechServiceProvider).capability;
    final speechService = ref.watch(speechRecognitionServiceProvider);
    final speechCapability = speechService.capability;
    final recorderCapability = ref.watch(recorderServiceProvider).capability;
    final speechDebugSnapshot = speechService.lastDebugSnapshot;
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('朗读模式'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedLineIndex = 0;
                _resetPracticeState(message: '已刷新本次朗读练习。');
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
              title: '暂时没有可练习的诗词',
              description: '可以先去诗词库选一首，再进入朗读练习。',
              icon: Icons.graphic_eq_rounded,
            );
          }

          final lines = poem.lines;
          if (lines.isEmpty) {
            return const EmptyState(
              title: '这首诗暂时缺少可练习的原文',
              description: '当前无法生成朗读目标句，请换一首诗继续练习。',
              icon: Icons.short_text_rounded,
            );
          }

          final safeLineIndex = _selectedLineIndex.clamp(0, lines.length - 1);
          final targetLine = lines[safeLineIndex];
          final demoAudioSource = _resolveDemoAudioSource(poem);
          final canUseGeneratedDemo =
              _supportsNativeTextToSpeech &&
              textToSpeechCapability.state != ServiceState.unavailable;
          final canPlayDemo = demoAudioSource != null || canUseGeneratedDemo;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PoemHeaderCard(
                poem: poem,
                lineIndex: safeLineIndex,
                totalLines: lines.length,
              ),
              const SizedBox(height: 16),
              _CapabilityBanner(
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
                      Text(
                        '目标诗句',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _LineSelector(
                        lines: lines,
                        selectedIndex: safeLineIndex,
                        onSelected: _handleLineSelected,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8EFE0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5CFA8)),
                        ),
                        child: PoemPinyinText(
                          poem: poem,
                          lineIndices: [safeLineIndex],
                          showPinyin: showPinyin,
                          variant: PoemPinyinTextVariant.study,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DemoPlayerCard(
                hasDemoAudio: canPlayDemo,
                isGeneratedDemo: demoAudioSource == null,
                isPlaying: _isDemoPlaybackActive,
                isPreparing: _isPreparingDemoAudio,
                playbackSpeed: _playbackSpeed,
                audioCapability: audioCapability,
                textToSpeechCapability: textToSpeechCapability,
                onPlay:
                    !canPlayDemo ||
                            _isPreparingDemoAudio ||
                            _isPracticeRecording ||
                            _isListening ||
                            _isStarting ||
                            _isStopping
                        ? null
                        : () => _playDemoAudio(poem: poem, sourceLabel: '示范音频'),
                onStop: _isDemoPlaybackActive ? _stopPlayback : null,
                onSpeedSelected:
                    audioCapability.isAvailable
                        ? _handlePlaybackSpeedChanged
                        : null,
              ),
              const SizedBox(height: 16),
              _RecordingPlaybackCard(
                recorderCapability: recorderCapability,
                audioCapability: audioCapability,
                isRecording: _isPracticeRecording,
                hasRecording: _practiceRecordingPath != null,
                isPlayingRecording:
                    !_isDemoPlaybackActive &&
                    _playingSource == _practiceRecordingPath,
                recordingHint: _recordingHint,
                onStartRecord:
                    _isPracticeRecording ||
                            _isListening ||
                            _isStarting ||
                            _isStopping
                        ? null
                        : _startPracticeRecording,
                onStopRecord:
                    _isPracticeRecording ? _stopPracticeRecording : null,
                onPlay:
                    _practiceRecordingPath == null ||
                            _isPracticeRecording ||
                            _isListening
                        ? null
                        : () => _playAudioSource(
                          source: _practiceRecordingPath!,
                          isDemoPlayback: false,
                          sourceLabel: '我的录音',
                        ),
                onStopPlay:
                    !_isDemoPlaybackActive &&
                            _playingSource == _practiceRecordingPath
                        ? _stopPlayback
                        : null,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '跟读练习',
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
                                        _isStopping ||
                                        _isPracticeRecording ||
                                        _isAudioPlaying
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
                                  : (_isListening ? '听你读' : '开始朗读'),
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
                                _resetPracticeState(message: '已清空本次朗读结果。');
                              });
                            },
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('清空结果'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _recognizedController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: '朗读内容',
                          hintText:
                              _supportsLiveRecognition
                                  ? '读完后会显示在这里，也可以自己改一改'
                                  : '可以先把自己读的内容写在这里',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed:
                            _isSaving
                                ? null
                                : () => _scoreAndPersist(poem, targetLine),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(_isSaving ? '保存中...' : '看看读得怎么样'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_lastScore != null) ...[
                const SizedBox(height: 16),
                _ScorePanel(score: _lastScore!),
              ],
              const SizedBox(height: 16),
              _ReadingTipsCard(
                supportsLiveRecognition: _supportsLiveRecognition,
                speechCapability: speechCapability,
                hasDemoAudio: canPlayDemo,
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
    if (_isDemoPlaybackActive) {
      unawaited(_stopPlayback());
    }
    setState(() {
      _selectedLineIndex = index;
      _resetPracticeState(message: '已切换目标诗句。');
    });
  }

  String? _resolveDemoAudioSource(Poem poem) {
    final audioUrl = poem.audioUrl?.trim();
    if (audioUrl == null || audioUrl.isEmpty) {
      return null;
    }
    return audioUrl;
  }

  Future<void> _primeTextToSpeech() async {
    try {
      await ref.read(textToSpeechServiceProvider).initialize();
    } catch (_) {
      // Keep the capability message from the service and simply refresh UI.
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<bool> _refreshRecorderPermission({bool request = false}) async {
    try {
      final granted = await ref
          .read(recorderServiceProvider)
          .refreshPermission(request: request);
      if (mounted) {
        setState(() {});
      }
      return granted;
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
      return false;
    }
  }

  Future<void> _handlePlaybackSpeedChanged(double speed) async {
    setState(() {
      _playbackSpeed = speed;
    });

    try {
      await ref.read(audioPlayerServiceProvider).setSpeed(speed);
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage = '播放语速已调整为 ${speed.toStringAsFixed(1)}x。';
      });
    } catch (error) {
      _showSnackBar('调整播放语速失败：${_describeError(error)}');
    }
  }

  Future<void> _playDemoAudio({required Poem poem, String? sourceLabel}) async {
    if (_isPracticeRecording) {
      _showSnackBar('请先结束当前录音，再播放示范朗读。');
      return;
    }
    final demoAudioSource = _resolveDemoAudioSource(poem);
    if (_isAudioPlaying) {
      await _stopPlayback();
    }
    if (demoAudioSource != null) {
      await _playAudioSource(
        source: demoAudioSource,
        sourceLabel: sourceLabel ?? '示范音频',
        isDemoPlayback: true,
      );
      return;
    }
    setState(() {
      _isPreparingDemoAudio = true;
      _sessionMessage = '正在准备这一句的示范朗读...';
    });
    try {
      final safeLineIndex = _selectedLineIndex.clamp(0, poem.lines.length - 1);
      final targetLine = poem.lines[safeLineIndex];
      final synthesized = await ref
          .read(textToSpeechServiceProvider)
          .synthesizeToFile(
            text: targetLine,
            cacheKey: 'poem_${poem.id}_line_${safeLineIndex + 1}',
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage =
            synthesized.wasCached ? '已命中本地示范缓存，正在播放。' : '示范朗读准备好了，正在播放。';
      });
      await _playAudioSource(
        source: synthesized.filePath,
        sourceLabel: sourceLabel ?? '示范朗读',
        isDemoPlayback: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _describeError(error);
      _showSnackBar('生成示范朗读失败：$message');
      setState(() {
        _sessionMessage = '生成示范朗读失败：$message';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingDemoAudio = false;
        });
      }
    }
  }

  Future<void> _playAudioSource({
    required String source,
    required String sourceLabel,
    required bool isDemoPlayback,
  }) async {
    if (_isPracticeRecording) {
      _showSnackBar('请先结束当前录音，再进行播放。');
      return;
    }
    try {
      await ref.read(audioPlayerServiceProvider).setSpeed(_playbackSpeed);
      await ref.read(audioPlayerServiceProvider).play(source);
      if (!mounted) {
        return;
      }
      setState(() {
        _playingSource = source;
        _isDemoPlaybackActive = isDemoPlayback;
        _sessionMessage = '正在播放$sourceLabel，可随时停止。';
      });
    } catch (error) {
      _showSnackBar('播放失败：${_describeError(error)}');
    }
  }

  Future<void> _stopPlayback() async {
    if (_playingSource == null) {
      return;
    }
    try {
      await ref.read(audioPlayerServiceProvider).stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _playingSource = null;
        _isDemoPlaybackActive = false;
        _sessionMessage = '播放已停止。';
      });
    } catch (error) {
      _showSnackBar('停止播放失败：${_describeError(error)}');
    }
  }

  Future<void> _startPracticeRecording() async {
    if (_isListening || _isStarting || _isStopping) {
      _showSnackBar('请先停下跟读，再开始录音回放。');
      return;
    }

    await _stopPlayback();
    final recorderService = ref.read(recorderServiceProvider);

    try {
      await recorderService.requestPermission();
      if (mounted) {
        setState(() {});
      }
      await recorderService.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPracticeRecording = true;
        _practiceRecordingPath = null;
        _sessionMessage = '正在录音，请读完这一句后点击“结束录音”。';
      });
    } catch (error) {
      _showSnackBar('开始录音失败：${_describeError(error)}');
    }
  }

  Future<void> _stopPracticeRecording() async {
    try {
      final path = await ref.read(recorderServiceProvider).stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPracticeRecording = false;
        _practiceRecordingPath = path;
        _sessionMessage = path == null ? '没有拿到录音文件，请再试一次。' : '录音已保存，可立即回放。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPracticeRecording = false;
      });
      _showSnackBar('结束录音失败：${_describeError(error)}');
    }
  }

  Future<void> _startRecognition(Poem poem) async {
    if (_isListening || _isStarting) {
      return;
    }

    if (_isPracticeRecording) {
      _showSnackBar('请先结束当前录音，再开始跟读检查。');
      return;
    }

    if (_isAudioPlaying) {
      await _stopPlayback();
    }

    AppLogger.event('recognition_started', feature: 'reading');

    final speechService = ref.read(speechRecognitionServiceProvider);
    final recorderService = ref.read(recorderServiceProvider);

    setState(() {
      _isStarting = true;
      _isListening = false;
      _isStopping = false;
      _lastScore = null;
      _lastRawRecognitionText = null;
      _sessionStartedAt = DateTime.now();
      _activePoem = poem;
      _activeLineIndex = _selectedLineIndex;
      _sessionMessage =
          _supportsLiveRecognition ? '准备好了，请开始朗读。' : '这台设备暂时不能自动听读，可以先手动填写。';
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
      _showSnackBar('这台设备暂时不能自动听读，可以先手动填写后查看反馈。');
      return;
    }

    try {
      final microphoneReady = await _refreshRecorderPermission();
      if (!microphoneReady) {
        await recorderService.requestPermission();
        if (mounted) {
          setState(() {});
        }
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
        _isStopping = false;
        _sessionMessage = '开始听你读，请朗读当前诗句。';
      });
    } catch (error) {
      unawaited(_refreshRecorderPermission());
      _handleRecognitionError(error);
    }
  }

  void _handleRecognitionResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }

    AppLogger.event(
      'recognition_result',
      feature: 'reading',
      fields: {'textLength': result.text.length, 'isFinal': result.isFinal},
    );

    final correction = _applyRecognitionCorrection(
      result: result,
      fallbackLineIndex: _selectedLineIndex,
    );
    if (!result.isFinal) {
      setState(() {
        _isStarting = false;
        _isListening = true;
        _sessionMessage = '正在听你读，请继续朗读当前诗句。';
      });
      return;
    }

    _lastRawRecognitionText = result.text;
    _updateRecognizedText(correction.displayText);

    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    unawaited(subscription?.cancel() ?? Future<void>.value());

    setState(() {
      _isStarting = false;
      _isListening = false;
      _isStopping = false;
      _sessionMessage =
          result.hasText ? '已经听完，可以看看读得怎么样。' : '没有听清楚，请再读一遍或自己填一下。';
    });

    if (!result.hasText) {
      _showSnackBar('没有听清楚，请再读一遍。');
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
      feature: 'reading',
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

  Future<void> _requestStopRecognition() async {
    if (_isStopping) {
      return;
    }

    AppLogger.event('recognition_stop_requested', feature: 'reading');

    final speechService = ref.read(speechRecognitionServiceProvider);
    final hadText = _recognizedController.text.trim().isNotEmpty;

    setState(() {
      _isStarting = false;
      _isStopping = true;
      _sessionMessage = hadText ? '已停下，正在整理你的朗读...' : '已停下，正在整理结果...';
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
        _sessionMessage = hadText ? '整理好了，可以看看读得怎么样。' : '还没有听清楚，请再试一次或自己填一下。';
      });
    });
  }

  Future<void> _scoreAndPersist(Poem poem, String targetLine) async {
    final recognizedText = _recognizedController.text.trim();
    final assessmentText =
        _lastRawRecognitionText?.trim().isNotEmpty == true
            ? _lastRawRecognitionText!.trim()
            : recognizedText;
    if (recognizedText.isEmpty) {
      _showSnackBar('请先读一遍，或把朗读内容填在这里。');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final score = await ref
          .read(speechAssessmentProvider)
          .assess(
            SpeechAssessmentRequest(
              mode: SpeechAssessmentMode.reading,
              expectedText: targetLine,
              attemptText: assessmentText,
              audioFilePath: _practiceRecordingPath,
              duration: _sessionDuration,
              metadata: <String, Object?>{
                'poemId': poem.id,
                'lineIndex': _selectedLineIndex,
              },
            ),
          );

      await ref
          .read(practiceRepositoryProvider)
          .saveAssessmentReport(
            poem: poem,
            mode: PracticeMode.reading,
            results: [
              PracticeLineResult(
                question: PracticeQuestion(
                  poemId: poem.id,
                  poemTitle: poem.title,
                  poemAuthor: poem.author,
                  lineIndex: _selectedLineIndex,
                  prompt: '朗读第 ${_selectedLineIndex + 1} 句',
                  hint: poem.title,
                  expectedAnswer: targetLine,
                ),
                answer: assessmentText,
                isCorrect: score.totalScore >= 80,
                score: score.totalScore,
                feedback: score.feedback,
                assessment: PracticeAssessmentMetrics(
                  engine: score.engine,
                  confidence: score.confidence,
                  accuracy: score.accuracy,
                  fluency: score.fluency,
                  integrity: score.completeness,
                  assessmentBasis: score.assessmentBasis,
                  audioFilePath: score.audioFilePath,
                  rawPayloadJson: jsonEncode(score.rawProviderPayload),
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
        _isSaving = false;
        _lastScore = score;
        _sessionMessage = '这次朗读已经记下来了，可以继续练下一句。';
      });
      _showSnackBar('已记录《${poem.title}》的朗读练习。');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _describeError(error);
      setState(() {
        _isSaving = false;
        _sessionMessage = '这次没有保存成功：$message';
      });
      _showSnackBar('操作失败：$message');
    }
  }

  void _resetPracticeState({String? message}) {
    unawaited(_cancelRecognitionSession());
    _recognizedController.clear();
    _lastScore = null;
    _lastRawRecognitionText = null;
    _sessionStartedAt = null;
    _sessionMessage = message;
    _isListening = false;
    _isStarting = false;
    _isStopping = false;
    _isSaving = false;
  }

  Future<void> _cancelRecognitionSession() async {
    final subscription = _recognitionSubscription;
    _recognitionSubscription = null;
    await subscription?.cancel();

    try {
      await ref.read(speechRecognitionServiceProvider).stop();
    } catch (_) {
      // Ignore "not listening" style shutdown errors when cleaning up.
    }
  }

  PoemRecognitionCorrection _applyRecognitionCorrection({
    required SpeechRecognitionResult result,
    required int fallbackLineIndex,
  }) {
    final poem = _activePoem;
    final lineIndex = _activeLineIndex ?? fallbackLineIndex;
    if (poem == null) {
      return PoemRecognitionCorrection(
        displayText: result.text,
        rawText: result.text,
        wasCorrected: false,
        reason: 'no_active_poem',
        charSimilarity: 0,
        phoneticSimilarity: 0,
      );
    }

    return _postProcessor.correctForTarget(
      poem: poem,
      lineIndex: lineIndex,
      recognizedText: result.text,
      isFinal: result.isFinal,
      preferTargetOnFinal: true,
    );
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
        return '可以先听示范，再录音回放，最后看看读得怎么样。';
      }
      return speechCapability.userMessage;
    }

    return '这台设备暂时不能自动听读，可以先手动填写后查看反馈。';
  }

  String get _recordingHint {
    if (_isPracticeRecording) {
      return '正在录音，请读完这一句后点击“结束录音”。';
    }
    if (_practiceRecordingPath != null) {
      return '上一段录音已保存，可直接回放，也可以重新录一遍覆盖。';
    }
    return '先录下自己的朗读，再用回放对照目标诗句做复盘。';
  }

  Duration get _sessionDuration {
    if (_sessionStartedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_sessionStartedAt!);
  }
}

class _PoemHeaderCard extends StatelessWidget {
  const _PoemHeaderCard({
    required this.poem,
    required this.lineIndex,
    required this.totalLines,
  });

  final Poem poem;
  final int lineIndex;
  final int totalLines;

  @override
  Widget build(BuildContext context) {
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
                Chip(label: Text('难度 ${poem.difficulty}')),
                Chip(label: Text('第 ${lineIndex + 1} / $totalLines 句')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityBanner extends StatelessWidget {
  const _CapabilityBanner({required this.isListening, required this.message});

  final bool isListening;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7D3AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isListening
                    ? Icons.hearing_rounded
                    : Icons.info_outline_rounded,
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
        ],
      ),
    );
  }
}

class _LineSelector extends StatelessWidget {
  const _LineSelector({
    required this.lines,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> lines;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(lines.length, (index) {
        return ChoiceChip(
          label: Text('第 ${index + 1} 句'),
          selected: index == selectedIndex,
          onSelected: (_) => onSelected(index),
        );
      }),
    );
  }
}

class _DemoPlayerCard extends StatelessWidget {
  const _DemoPlayerCard({
    required this.hasDemoAudio,
    required this.isGeneratedDemo,
    required this.isPlaying,
    required this.isPreparing,
    required this.playbackSpeed,
    required this.audioCapability,
    required this.textToSpeechCapability,
    required this.onPlay,
    required this.onStop,
    required this.onSpeedSelected,
  });
  final bool hasDemoAudio;
  final bool isGeneratedDemo;
  final bool isPlaying;
  final bool isPreparing;
  final double playbackSpeed;
  final ServiceCapability audioCapability;
  final ServiceCapability textToSpeechCapability;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;
  final ValueChanged<double>? onSpeedSelected;
  @override
  Widget build(BuildContext context) {
    final tips = switch ((hasDemoAudio, isGeneratedDemo, isPreparing)) {
      (_, _, true) => '正在为这一句生成本地示范朗读，请稍等。',
      (true, false, false) => '这一句已有真实示范音频，可以先听一遍再开始朗读。',
      (true, true, false) => '这一句会先生成一段本地示范朗读，可以听完再跟读。',
      (false, _, false) => '这一句暂时没有示范朗读，可以先自己试着读。',
    };
    final playLabel = switch ((hasDemoAudio, isGeneratedDemo, isPreparing)) {
      (_, _, true) => '生成中...',
      (false, _, false) => '暂不可用',
      (true, false, false) => '播放示范',
      (true, true, false) => '生成示范',
    };
    final speeds = <double>[0.8, 1.0, 1.2];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '示范播放',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              tips,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: speeds
                  .map(
                    (speed) => ChoiceChip(
                      label: Text('${speed.toStringAsFixed(1)}x'),
                      selected: playbackSpeed == speed,
                      onSelected:
                          onSpeedSelected == null
                              ? null
                              : (_) => onSpeedSelected!(speed),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: Icon(
                    isPreparing
                        ? Icons.hourglass_top_rounded
                        : isPlaying
                        ? Icons.volume_up_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(playLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('停止'),
                ),
              ],
            ),
            if (!audioCapability.isAvailable) ...[
              const SizedBox(height: 12),
              Text(
                audioCapability.userMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ] else if (isGeneratedDemo &&
                !textToSpeechCapability.isAvailable) ...[
              const SizedBox(height: 12),
              Text(
                textToSpeechCapability.message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordingPlaybackCard extends StatelessWidget {
  const _RecordingPlaybackCard({
    required this.recorderCapability,
    required this.audioCapability,
    required this.isRecording,
    required this.hasRecording,
    required this.isPlayingRecording,
    required this.recordingHint,
    required this.onStartRecord,
    required this.onStopRecord,
    required this.onPlay,
    required this.onStopPlay,
  });

  final ServiceCapability recorderCapability;
  final ServiceCapability audioCapability;
  final bool isRecording;
  final bool hasRecording;
  final bool isPlayingRecording;
  final String recordingHint;
  final VoidCallback? onStartRecord;
  final VoidCallback? onStopRecord;
  final VoidCallback? onPlay;
  final VoidCallback? onStopPlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的录音回放',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              recordingHint,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onStartRecord,
                  icon: const Icon(Icons.fiber_manual_record_rounded),
                  label: Text(isRecording ? '录音中...' : '开始录音'),
                ),
                OutlinedButton.icon(
                  onPressed: onStopRecord,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('结束录音'),
                ),
                OutlinedButton.icon(
                  onPressed: onPlay,
                  icon: Icon(
                    isPlayingRecording
                        ? Icons.volume_up_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: const Text('回放录音'),
                ),
                OutlinedButton.icon(
                  onPressed: onStopPlay,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('停止回放'),
                ),
              ],
            ),
            if (!recorderCapability.isAvailable) ...[
              const SizedBox(height: 12),
              Text(
                recorderCapability.userMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ] else if (!audioCapability.isAvailable) ...[
              const SizedBox(height: 12),
              Text(
                audioCapability.userMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ] else if (!hasRecording) ...[
              const SizedBox(height: 12),
              Text(
                '回放按钮会在生成本地录音后启用。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.score});

  final SpeechAssessmentResult score;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('总分', '${score.totalScore}'),
      ('准确度', '${score.accuracy}'),
      ('流畅度', '${score.fluency}'),
      ('完整度', '${score.completeness}'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '朗读反馈',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items
                  .map(
                    (item) => Container(
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
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: '目标字数', value: '${score.expectedLength}'),
                _InfoChip(label: '读到的字', value: '${score.recognizedLength}'),
                _InfoChip(label: '命中字数', value: '${score.matchedCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              score.feedback,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
            if (score.hasDetailFeedback) ...[
              const SizedBox(height: 14),
              if (score.mismatches.isNotEmpty)
                _DetailSection(
                  title: '容易混淆',
                  values:
                      score.mismatches
                          .map((item) => item.displayLabel)
                          .toList(),
                  tint: const Color(0xFFFFF0E0),
                ),
              if (score.missedChars.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailSection(
                  title: '容易漏读',
                  values: score.missedChars,
                  tint: const Color(0xFFFFF5D9),
                ),
              ],
              if (score.extraChars.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailSection(
                  title: '多读出来',
                  values: score.extraChars,
                  tint: const Color(0xFFF8E8E6),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label：$value'));
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.values,
    required this.tint,
  });

  final String title;
  final List<String> values;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final preview = values.take(8).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preview.map((value) => Chip(label: Text(value))).toList(),
          ),
          if (values.length > preview.length) ...[
            const SizedBox(height: 6),
            Text(
              '其余 ${values.length - preview.length} 项已省略，可继续跟读复盘。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingTipsCard extends StatelessWidget {
  const _ReadingTipsCard({
    required this.supportsLiveRecognition,
    required this.speechCapability,
    required this.hasDemoAudio,
  });

  final bool supportsLiveRecognition;
  final ServiceCapability speechCapability;
  final bool hasDemoAudio;

  @override
  Widget build(BuildContext context) {
    final tips = <String>[
      hasDemoAudio
          ? '先听一遍示范，再录下自己的声音，对照回放会更容易发现停顿和节奏问题。'
          : '当前还没有示范朗读，可以先录下自己的朗读，再通过回放做复盘。',
      '朗读内容可以手动修正，修正后再看反馈会更准。',
      '详细反馈会标出容易混淆、漏读和多读出来的字，适合第二遍有针对性地练。',
      '练完后会留下进步记录，之后可以继续复习。',
    ];

    if (!supportsLiveRecognition) {
      tips.add('这台设备暂时不能自动听读，可以先自己填写朗读内容。');
    } else if (!speechCapability.isAvailable) {
      tips.add(speechCapability.userMessage);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '练习说明',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.6),
                      ),
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
}
