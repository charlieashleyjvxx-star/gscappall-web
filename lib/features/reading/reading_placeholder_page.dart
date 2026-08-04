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
import '../../services/audio/audio_player_service.dart';
import '../../services/record/recorder_service.dart';
import '../../services/speech/poem_recognition_post_processor.dart';
import '../../services/speech/speech_assessment_service.dart';
import '../../services/speech/speech_recognition_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/poem_pinyin_text.dart';

enum _ReadingChildStep { listen, readTogether, complete, voiceChallenge }

enum _ReadingScope { whole, line }

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
  late final AudioPlayerService _audioPlayerService;
  late final RecorderService _recorderService;
  late Future<Poem?> _poemFuture;
  Poem? _activePoem;
  int? _activeLineIndex;

  int _selectedLineIndex = 0;
  bool _isStarting = false;
  bool _isListening = false;
  bool _isStopping = false;
  bool _isSaving = false;
  bool _isPracticeRecording = false;
  bool _isChildFollowing = false;
  bool _isPreparingDemoAudio = false;
  bool _isDemoPlaybackActive = false;
  bool _hasPlayedDemoForLine = false;
  DateTime? _sessionStartedAt;
  String? _lastRawRecognitionText;
  String? _practiceRecordingPath;
  String? _playingSource;
  double _playbackSpeed = 1.0;
  _ReadingScope _readingScope = _ReadingScope.line;
  _ReadingChildStep _childStep = _ReadingChildStep.listen;
  final Set<int> _completedLineIndexes = <int>{};
  bool _childSessionSaved = false;

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
    _audioPlayerService = ref.read(audioPlayerServiceProvider);
    _recorderService = ref.read(recorderServiceProvider);
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
    unawaited(_audioPlayerService.stop());
    if (_isPracticeRecording) {
      unawaited(_recorderService.stop());
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
    final showPinyin = ref.watch(pinyinVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('跟着读'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedLineIndex = 0;
                _hasPlayedDemoForLine = false;
                _childStep = _ReadingChildStep.listen;
                _completedLineIndexes.clear();
                _childSessionSaved = false;
                _resetPracticeState();
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
              icon: Icons.graphic_eq_rounded,
            );
          }

          final lines = poem.lines;
          if (lines.isEmpty) {
            return const EmptyState(
              title: '这首诗暂时缺少可练习的原文',
              icon: Icons.short_text_rounded,
            );
          }

          final safeLineIndex = _selectedLineIndex.clamp(0, lines.length - 1);
          final isWholePoem = _readingScope == _ReadingScope.whole;
          final demoAudioSource = _resolveDemoAudioSource(poem);
          final canUseGeneratedDemo =
              _supportsNativeTextToSpeech &&
              textToSpeechCapability.state != ServiceState.unavailable;
          final canPlayDemo = demoAudioSource != null || canUseGeneratedDemo;
          final isLastLine = safeLineIndex >= lines.length - 1;
          final effectiveChildStep =
              !canPlayDemo && _childStep == _ReadingChildStep.listen
                  ? _ReadingChildStep.readTogether
                  : _childStep;
          final isListeningStep =
              effectiveChildStep == _ReadingChildStep.listen;

          late final String primaryLabel;
          late final IconData primaryIcon;
          late final VoidCallback? primaryAction;
          if (_isPreparingDemoAudio) {
            primaryLabel = '正在准备示范...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_isDemoPlaybackActive) {
            primaryLabel = '正在听';
            primaryIcon = Icons.graphic_eq_rounded;
            primaryAction = null;
          } else if (_isChildFollowing) {
            primaryLabel = '读完啦';
            primaryIcon = Icons.stop_circle_rounded;
            primaryAction =
                () => _finishChildFollowReading(
                  poem: poem,
                  lineIndex: safeLineIndex,
                );
          } else if (_isStarting) {
            primaryLabel = '正在准备麦克风...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_isListening) {
            primaryLabel = '读完啦';
            primaryIcon = Icons.stop_circle_rounded;
            primaryAction = _requestStopRecognition;
          } else if (_isStopping) {
            primaryLabel = '正在整理朗读内容...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_isSaving) {
            primaryLabel = '正在生成反馈...';
            primaryIcon = Icons.hourglass_top_rounded;
            primaryAction = null;
          } else if (_childSessionSaved) {
            primaryLabel = '再读一遍';
            primaryIcon = Icons.replay_rounded;
            primaryAction =
                () =>
                    _restartChildReading(poem: poem, canPlayDemo: canPlayDemo);
          } else if (effectiveChildStep == _ReadingChildStep.listen) {
            primaryLabel = '听一听';
            primaryIcon = Icons.volume_up_rounded;
            primaryAction = () => _listenForChild(poem);
          } else if (effectiveChildStep == _ReadingChildStep.readTogether) {
            primaryLabel = '一起读';
            primaryIcon = Icons.record_voice_over_rounded;
            primaryAction = () => _readTogether(poem: poem);
          } else if (effectiveChildStep == _ReadingChildStep.voiceChallenge) {
            primaryLabel = '开口读';
            primaryIcon = Icons.mic_rounded;
            primaryAction =
                !_supportsLiveRecognition || !speechCapability.isAvailable
                    ? null
                    : () => _startRecognition(poem);
          } else {
            primaryLabel = isWholePoem || isLastLine ? '完成这首诗' : '读下一句';
            primaryIcon =
                isWholePoem || isLastLine
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_rounded;
            primaryAction =
                isWholePoem || isLastLine
                    ? () => _finishChildReading(poem)
                    : () => _handleLineSelected(safeLineIndex + 1);
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PoemHeaderCard(
                poem: poem,
                lineIndex: safeLineIndex,
                totalLines: lines.length,
                completedLineIndexes: _completedLineIndexes,
                showLineProgress: !isWholePoem,
              ),
              const SizedBox(height: 16),
              SegmentedButton<_ReadingScope>(
                segments: const [
                  ButtonSegment(
                    value: _ReadingScope.whole,
                    icon: Icon(Icons.subject_rounded),
                    label: Text('整首朗读'),
                  ),
                  ButtonSegment(
                    value: _ReadingScope.line,
                    icon: Icon(Icons.format_list_numbered_rounded),
                    label: Text('逐句朗读'),
                  ),
                ],
                selected: {_readingScope},
                showSelectedIcon: false,
                onSelectionChanged:
                    (selection) => _handleScopeChanged(selection.first),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      PoemPinyinText(
                        poem: poem,
                        lineIndices: isWholePoem ? null : [safeLineIndex],
                        showPinyin: showPinyin,
                        variant: PoemPinyinTextVariant.study,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PrimaryPracticeCard(
                buttonLabel: primaryLabel,
                buttonIcon: primaryIcon,
                onPressed: primaryAction,
                playbackSpeedControl:
                    isListeningStep
                        ? _PlaybackSpeedSelector(
                          value: _playbackSpeed,
                          onChanged:
                              audioCapability.isAvailable
                                  ? _handlePlaybackSpeedChanged
                                  : null,
                        )
                        : null,
                recordingLabel:
                    effectiveChildStep == _ReadingChildStep.complete &&
                            _practiceRecordingPath != null
                        ? _playingSource == _practiceRecordingPath
                            ? '停止回放'
                            : '听听我的声音'
                        : null,
                onRecording:
                    effectiveChildStep == _ReadingChildStep.complete &&
                            _practiceRecordingPath != null
                        ? _playingSource == _practiceRecordingPath
                            ? _stopPlayback
                            : () => _playAudioSource(
                              source: _practiceRecordingPath!,
                              isDemoPlayback: false,
                            )
                        : null,
                secondaryLabel:
                    effectiveChildStep == _ReadingChildStep.complete &&
                            !_childSessionSaved
                        ? '重新读一遍'
                        : null,
                onSecondary:
                    effectiveChildStep == _ReadingChildStep.complete &&
                            !_childSessionSaved
                        ? () => _repeatCurrentReading(
                          poem: poem,
                          canPlayDemo: canPlayDemo,
                        )
                        : null,
              ),
              const SizedBox(height: 8),
              _RecordingPlaybackCard(
                isRecording: _isPracticeRecording,
                isPlayingRecording:
                    !_isDemoPlaybackActive &&
                    _playingSource == _practiceRecordingPath,
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
                        ),
                onStopPlay:
                    !_isDemoPlaybackActive &&
                            _playingSource == _practiceRecordingPath
                        ? _stopPlayback
                        : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _listenForChild(Poem poem) async {
    await _playDemoAudio(poem: poem);
    if (!mounted) {
      return;
    }
    setState(() {
      _childStep = _ReadingChildStep.readTogether;
    });
  }

  Future<void> _handlePlaybackSpeedChanged(double speed) async {
    if (_playbackSpeed == speed) {
      return;
    }

    setState(() {
      _playbackSpeed = speed;
    });

    try {
      await _audioPlayerService.setSpeed(speed);
    } catch (error) {
      _showSnackBar('倍速设置失败：${_describeError(error)}');
    }
  }

  Future<void> _readTogether({required Poem poem}) async {
    if (_isAudioPlaying) {
      await _stopPlayback();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isChildFollowing = true;
      _practiceRecordingPath = null;
    });

    try {
      final recorder = ref.read(recorderServiceProvider);
      await recorder.requestPermission();
      await recorder.start();
      if (!mounted || !_isChildFollowing) {
        await recorder.stop();
        return;
      }
      setState(() {
        _isPracticeRecording = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPracticeRecording = false;
      });
    }
  }

  Future<void> _finishChildFollowReading({
    required Poem poem,
    required int lineIndex,
  }) async {
    String? recordingPath;
    if (_isPracticeRecording) {
      try {
        recordingPath = await ref.read(recorderServiceProvider).stop();
      } catch (_) {
        recordingPath = null;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isChildFollowing = false;
      _isPracticeRecording = false;
      _practiceRecordingPath = recordingPath;
      if (_readingScope == _ReadingScope.whole) {
        _completedLineIndexes.addAll(
          List<int>.generate(poem.lines.length, (index) => index),
        );
      } else {
        _completedLineIndexes.add(lineIndex);
      }
      _childStep = _ReadingChildStep.complete;
    });
  }

  Future<void> _finishChildReading(Poem poem) async {
    setState(() {
      _childSessionSaved = true;
    });
    try {
      await ref
          .read(learningRepositoryProvider)
          .logLearningRecord(
            poemId: poem.id,
            mode: PracticeMode.reading.rawValue,
            durationMinutes: 1,
            note: '完成跟读练习',
          );
      ref.invalidate(learningSummaryProvider);
      ref.invalidate(recentLearningRecordsProvider);
      ref.invalidate(learningHistoryProvider);
    } catch (_) {
      // Completion remains available even when the local record cannot be saved.
    }
  }

  Future<void> _restartChildReading({
    required Poem poem,
    required bool canPlayDemo,
  }) async {
    if (_isAudioPlaying) {
      await _stopPlayback();
    }
    setState(() {
      _selectedLineIndex = 0;
      _childStep =
          canPlayDemo
              ? _ReadingChildStep.listen
              : _ReadingChildStep.readTogether;
      _completedLineIndexes.clear();
      _childSessionSaved = false;
      _hasPlayedDemoForLine = false;
      _resetPracticeState();
    });
    if (canPlayDemo) {
      await _listenForChild(poem);
    }
  }

  Future<void> _repeatCurrentReading({
    required Poem poem,
    required bool canPlayDemo,
  }) async {
    if (_isAudioPlaying) {
      await _stopPlayback();
    }
    final lineIndex = _selectedLineIndex;
    setState(() {
      if (_readingScope == _ReadingScope.whole) {
        _completedLineIndexes.clear();
        _selectedLineIndex = 0;
      } else {
        _completedLineIndexes.remove(lineIndex);
      }
      _childStep =
          canPlayDemo
              ? _ReadingChildStep.listen
              : _ReadingChildStep.readTogether;
      _hasPlayedDemoForLine = false;
      _resetPracticeState();
    });
    if (canPlayDemo) {
      await _listenForChild(poem);
    }
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
      _hasPlayedDemoForLine = false;
      _childStep = _ReadingChildStep.listen;
      _resetPracticeState();
    });
  }

  void _handleScopeChanged(_ReadingScope scope) {
    if (scope == _readingScope) {
      return;
    }
    if (_isAudioPlaying) {
      unawaited(_stopPlayback());
    }
    setState(() {
      _readingScope = scope;
      _selectedLineIndex = 0;
      _hasPlayedDemoForLine = false;
      _childStep = _ReadingChildStep.listen;
      _completedLineIndexes.clear();
      _childSessionSaved = false;
      _resetPracticeState();
    });
  }

  String? _resolveDemoAudioSource(Poem poem) {
    if (_readingScope != _ReadingScope.whole) {
      return null;
    }
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

  Future<void> _playDemoAudio({required Poem poem}) async {
    if (_isPracticeRecording) {
      _showSnackBar('请先结束当前录音，再播放示范朗读。');
      return;
    }
    final demoAudioSource = _resolveDemoAudioSource(poem);
    if (_isAudioPlaying) {
      await _stopPlayback();
    }
    if (demoAudioSource != null) {
      await _playAudioSource(source: demoAudioSource, isDemoPlayback: true);
      return;
    }
    setState(() {
      _isPreparingDemoAudio = true;
    });
    try {
      final safeLineIndex = _selectedLineIndex.clamp(0, poem.lines.length - 1);
      final targetText =
          _readingScope == _ReadingScope.whole
              ? _poeticNarrationText(poem.lines)
              : _poeticNarrationText([poem.lines[safeLineIndex]]);
      final cacheKey =
          _readingScope == _ReadingScope.whole
              ? 'poem_${poem.id}_whole_child_v2'
              : 'poem_${poem.id}_line_${safeLineIndex + 1}_child_v2';
      final synthesized = await ref
          .read(textToSpeechServiceProvider)
          .synthesizeToFile(
            text: targetText,
            cacheKey: cacheKey,
            speechRate: 0.82,
            pitch: 1.03,
          );
      if (!mounted) {
        return;
      }
      await _playAudioSource(
        source: synthesized.filePath,
        isDemoPlayback: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _describeError(error);
      _showSnackBar('生成示范朗读失败：$message');
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
    required bool isDemoPlayback,
  }) async {
    if (_isPracticeRecording) {
      _showSnackBar('请先结束当前录音，再进行播放。');
      return;
    }
    try {
      await ref.read(audioPlayerServiceProvider).setSpeed(_playbackSpeed);
      if (!mounted) {
        return;
      }
      setState(() {
        _playingSource = source;
        _isDemoPlaybackActive = isDemoPlayback;
      });
      await ref.read(audioPlayerServiceProvider).play(source);
      if (!mounted) {
        return;
      }
      setState(() {
        if (_playingSource == source) {
          _playingSource = null;
          _isDemoPlaybackActive = false;
          _hasPlayedDemoForLine = _hasPlayedDemoForLine || isDemoPlayback;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _playingSource = null;
          _isDemoPlaybackActive = false;
        });
      }
      _showSnackBar('播放失败：${_describeError(error)}');
    }
  }

  String _poeticNarrationText(Iterable<String> lines) {
    return lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => line
              .replaceAll('，', '，  ')
              .replaceAll('。', '。   ')
              .replaceAll('？', '？   ')
              .replaceAll('！', '！   '),
        )
        .join('   ');
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
      _lastRawRecognitionText = null;
      _sessionStartedAt = DateTime.now();
      _activePoem = poem;
      _activeLineIndex = _selectedLineIndex;
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
      _completedLineIndexes.add(_selectedLineIndex);
      _childStep = _ReadingChildStep.complete;
    });

    final poem = _activePoem;
    final lineIndex = _activeLineIndex;
    if (result.hasText && poem != null && lineIndex != null) {
      unawaited(_scoreAndPersist(poem, poem.lines[lineIndex], silent: true));
    }
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
      feature: 'reading',
      level: AppLogLevel.error,
    );
    setState(() {
      _isStarting = false;
      _isListening = false;
      _isStopping = false;
      _completedLineIndexes.add(_selectedLineIndex);
      _childStep = _ReadingChildStep.complete;
    });
  }

  Future<void> _requestStopRecognition() async {
    if (_isStopping) {
      return;
    }

    AppLogger.event('recognition_stop_requested', feature: 'reading');

    final speechService = ref.read(speechRecognitionServiceProvider);
    setState(() {
      _isStarting = false;
      _isStopping = true;
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
        _completedLineIndexes.add(_selectedLineIndex);
        _childStep = _ReadingChildStep.complete;
      });
    });
  }

  Future<void> _scoreAndPersist(
    Poem poem,
    String targetLine, {
    bool silent = false,
  }) async {
    final recognizedText = _recognizedController.text.trim();
    final assessmentText =
        _lastRawRecognitionText?.trim().isNotEmpty == true
            ? _lastRawRecognitionText!.trim()
            : recognizedText;
    if (recognizedText.isEmpty) {
      _showSnackBar('请先读一遍，或把朗读内容填在这里。');
      return;
    }

    if (!silent) {
      setState(() {
        _isSaving = true;
      });
    }

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
      });
      if (!silent) {
        _showSnackBar('已记录《${poem.title}》的朗读练习。');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _describeError(error);
      setState(() {
        _isSaving = false;
      });
      if (!silent) {
        _showSnackBar('操作失败：$message');
      }
    }
  }

  void _resetPracticeState() {
    unawaited(_cancelRecognitionSession());
    if (_isPracticeRecording) {
      unawaited(_recorderService.stop());
    }
    _recognizedController.clear();
    _lastRawRecognitionText = null;
    _sessionStartedAt = null;
    _isListening = false;
    _isStarting = false;
    _isStopping = false;
    _isSaving = false;
    _isPracticeRecording = false;
    _isChildFollowing = false;
    _practiceRecordingPath = null;
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
    required this.completedLineIndexes,
    required this.showLineProgress,
  });

  final Poem poem;
  final int lineIndex;
  final int totalLines;
  final Set<int> completedLineIndexes;
  final bool showLineProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          poem.title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text('${poem.dynasty} · ${poem.author}'),
        if (showLineProgress) ...[
          const SizedBox(height: 12),
          Row(
            children: List.generate(totalLines, (index) {
              final isCurrent = index == lineIndex;
              final isCompleted = completedLineIndexes.contains(index);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isCurrent ? 24 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        isCurrent || isCompleted
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PrimaryPracticeCard extends StatelessWidget {
  const _PrimaryPracticeCard({
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
    this.playbackSpeedControl,
    this.recordingLabel,
    this.onRecording,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback? onPressed;
  final Widget? playbackSpeedControl;
  final String? recordingLabel;
  final VoidCallback? onRecording;
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
            if (playbackSpeedControl != null) ...[
              const SizedBox(height: 12),
              playbackSpeedControl!,
            ],
            if (recordingLabel != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.tonalIcon(
                  onPressed: onRecording,
                  icon: const Icon(Icons.hearing_rounded),
                  label: Text(
                    recordingLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
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

class _PlaybackSpeedSelector extends StatelessWidget {
  const _PlaybackSpeedSelector({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    const speeds = <double>[0.8, 1.0, 1.2];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final speed in speeds)
          ChoiceChip(
            label: Text('${speed.toStringAsFixed(1)}x'),
            selected: value == speed,
            onSelected: onChanged == null ? null : (_) => onChanged!(speed),
          ),
      ],
    );
  }
}

class _RecordingPlaybackCard extends StatelessWidget {
  const _RecordingPlaybackCard({
    required this.isRecording,
    required this.isPlayingRecording,
    required this.onStartRecord,
    required this.onStopRecord,
    required this.onPlay,
    required this.onStopPlay,
  });

  final bool isRecording;
  final bool isPlayingRecording;
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
          ],
        ),
      ),
    );
  }
}
