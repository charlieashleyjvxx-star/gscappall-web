import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../core/app_logger.dart';
import '../../core/service_status.dart';
import 'sherpa_onnx_model_bundle.dart';

class SpeechRecognitionDebugSnapshot {
  const SpeechRecognitionDebugSnapshot({
    required this.permissionGranted,
    required this.isRecognitionAvailable,
    required this.isOnDeviceRecognitionAvailable,
    required this.eventSinkReady,
    required this.recognizerCreated,
    required this.listenerBound,
    required this.currentState,
    required this.currentLocale,
    required this.selectedBackend,
    required this.currentDeviceBrand,
    required this.currentDeviceManufacturer,
    required this.sdkInt,
    this.selectedServiceInfo,
    this.modelFilesReady = false,
    this.availableBackends = const <String>[],
    this.diagnostics = const <String>[],
    this.firstPartialLatencyMs,
    this.finalLatencyMs,
    this.partialResultCount = 0,
    this.decodeCycles = 0,
    this.endpointDetected = false,
  });

  factory SpeechRecognitionDebugSnapshot.fromMap(Map<Object?, Object?> map) {
    return SpeechRecognitionDebugSnapshot(
      permissionGranted: map['permissionGranted'] == true,
      isRecognitionAvailable: map['isRecognitionAvailable'] == true,
      isOnDeviceRecognitionAvailable:
          map['isOnDeviceRecognitionAvailable'] == true,
      eventSinkReady: map['eventSinkReady'] == true,
      recognizerCreated: map['recognizerCreated'] == true,
      listenerBound: map['listenerBound'] == true,
      currentState: map['currentState'] as String? ?? 'unknown',
      currentLocale: map['currentLocale'] as String? ?? 'unknown',
      selectedBackend: map['selectedBackend'] as String? ?? 'unselected',
      currentDeviceBrand: map['currentDeviceBrand'] as String? ?? '',
      currentDeviceManufacturer:
          map['currentDeviceManufacturer'] as String? ?? '',
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      selectedServiceInfo: map['selectedServiceInfo'] as String?,
      modelFilesReady: map['modelFilesReady'] == true,
      availableBackends:
          (map['availableBackends'] as List<Object?>?)
              ?.map((Object? value) => value?.toString() ?? '')
              .where((String value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      diagnostics:
          (map['diagnostics'] as List<Object?>?)
              ?.map((Object? value) => value?.toString() ?? '')
              .where((String value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      firstPartialLatencyMs: (map['firstPartialLatencyMs'] as num?)?.toInt(),
      finalLatencyMs: (map['finalLatencyMs'] as num?)?.toInt(),
      partialResultCount: (map['partialResultCount'] as num?)?.toInt() ?? 0,
      decodeCycles: (map['decodeCycles'] as num?)?.toInt() ?? 0,
      endpointDetected: map['endpointDetected'] == true,
    );
  }

  final bool permissionGranted;
  final bool isRecognitionAvailable;
  final bool isOnDeviceRecognitionAvailable;
  final bool eventSinkReady;
  final bool recognizerCreated;
  final bool listenerBound;
  final String currentState;
  final String currentLocale;
  final String selectedBackend;
  final String currentDeviceBrand;
  final String currentDeviceManufacturer;
  final int sdkInt;
  final String? selectedServiceInfo;
  final bool modelFilesReady;
  final List<String> availableBackends;
  final List<String> diagnostics;
  final int? firstPartialLatencyMs;
  final int? finalLatencyMs;
  final int partialResultCount;
  final int decodeCycles;
  final bool endpointDetected;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'permissionGranted': permissionGranted,
      'isRecognitionAvailable': isRecognitionAvailable,
      'isOnDeviceRecognitionAvailable': isOnDeviceRecognitionAvailable,
      'eventSinkReady': eventSinkReady,
      'recognizerCreated': recognizerCreated,
      'listenerBound': listenerBound,
      'currentState': currentState,
      'currentLocale': currentLocale,
      'selectedBackend': selectedBackend,
      'currentDeviceBrand': currentDeviceBrand,
      'currentDeviceManufacturer': currentDeviceManufacturer,
      'sdkInt': sdkInt,
      'selectedServiceInfo': selectedServiceInfo,
      'modelFilesReady': modelFilesReady,
      'availableBackends': availableBackends,
      'diagnostics': diagnostics,
      'firstPartialLatencyMs': firstPartialLatencyMs,
      'finalLatencyMs': finalLatencyMs,
      'partialResultCount': partialResultCount,
      'decodeCycles': decodeCycles,
      'endpointDetected': endpointDetected,
    };
  }
}

class SpeechRecognitionResult {
  const SpeechRecognitionResult({
    required this.text,
    required this.isFinal,
    required this.type,
    this.errorCode,
    this.errorName,
    this.backend,
    this.state,
    this.timestamp,
    this.debugSnapshot,
  });

  final String text;
  final bool isFinal;
  final String type;
  final int? errorCode;
  final String? errorName;
  final String? backend;
  final String? state;
  final DateTime? timestamp;
  final SpeechRecognitionDebugSnapshot? debugSnapshot;

  bool get hasText => text.trim().isNotEmpty;
  bool get isErrorEvent => type == 'onError';
}

class SpeechRecognitionFailure implements Exception {
  const SpeechRecognitionFailure({
    required this.message,
    this.code,
    this.details,
    this.debugSnapshot,
  });

  final String message;
  final String? code;
  final Object? details;
  final SpeechRecognitionDebugSnapshot? debugSnapshot;

  @override
  String toString() => message;
}

abstract class SpeechRecognitionService {
  ServiceCapability get capability;
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot;
  String? get lastNativeState;

  Future<void> initialize();
  Stream<SpeechRecognitionResult> recognize();
  Future<void> stop();
}

class PlatformSpeechRecognitionService implements SpeechRecognitionService {
  const PlatformSpeechRecognitionService();

  static final _SpeechRecognitionBackendDelegate _delegate =
      _SpeechRecognitionBackendDelegate.create();

  @override
  ServiceCapability get capability => _delegate.capability;

  @override
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot =>
      _delegate.lastDebugSnapshot;

  @override
  String? get lastNativeState => _delegate.lastNativeState;

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Stream<SpeechRecognitionResult> recognize() => _delegate.recognize();

  @override
  Future<void> stop() => _delegate.stop();
}

abstract class _SpeechRecognitionBackendDelegate {
  const _SpeechRecognitionBackendDelegate();

  factory _SpeechRecognitionBackendDelegate.create() {
    if (kIsWeb) {
      return const _UnsupportedSpeechRecognitionDelegate();
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _SherpaOnnxSpeechRecognitionDelegate(),
      TargetPlatform.iOS => _NativeChannelSpeechRecognitionDelegate(),
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => const _UnsupportedSpeechRecognitionDelegate(),
    };
  }

  ServiceCapability get capability;
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot;
  String? get lastNativeState;

  Future<void> initialize();
  Stream<SpeechRecognitionResult> recognize();
  Future<void> stop();
}

class _UnsupportedSpeechRecognitionDelegate
    implements _SpeechRecognitionBackendDelegate {
  const _UnsupportedSpeechRecognitionDelegate();

  @override
  ServiceCapability get capability => const ServiceCapability(
    state: ServiceState.placeholder,
    message: '当前平台暂未接入实时语音识别，请在 Android 设备上使用。',
  );

  @override
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot => null;

  @override
  String? get lastNativeState => 'unsupported';

  @override
  Future<void> initialize() async {}

  @override
  Stream<SpeechRecognitionResult> recognize() {
    return Stream<SpeechRecognitionResult>.error(
      const SpeechRecognitionFailure(
        code: 'speech_unsupported_platform',
        message: '当前平台暂未接入实时语音识别，请在 Android 设备上使用。',
      ),
    );
  }

  @override
  Future<void> stop() async {}
}

class _NativeChannelSpeechRecognitionDelegate
    implements _SpeechRecognitionBackendDelegate {
  _NativeChannelSpeechRecognitionDelegate();

  static const MethodChannel _methodChannel = MethodChannel(
    'gscappall/speech/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'gscappall/speech/events',
  );

  ServiceState _lastKnownState = ServiceState.available;
  String? _lastStatusMessage;
  bool _isListening = false;
  String _lastRecognizedText = '';
  String? _lastNativeStateValue;
  SpeechRecognitionDebugSnapshot? _lastDebugSnapshotValue;

  @override
  ServiceCapability get capability {
    return ServiceCapability(
      state: _lastKnownState,
      message:
          _lastStatusMessage ?? (_isListening ? '正在使用原生语音识别。' : '已接入原生语音识别。'),
    );
  }

  @override
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot =>
      _lastDebugSnapshotValue;

  @override
  String? get lastNativeState => _lastNativeStateValue;

  @override
  Future<void> initialize() async {
    try {
      _log('initialize start');
      final Map<String, dynamic>? result = await _methodChannel
          .invokeMapMethod<String, dynamic>('initialize');
      _applyMethodStatus(result);

      final supported = result?['supported'] == true;
      final authorized = result?['authorized'] != false;
      final errorCode = result?['errorCode'] as String?;
      final message =
          result?['message'] as String? ??
          (supported ? '原生语音识别已准备。' : '当前设备不支持原生语音识别。');

      _lastKnownState =
          supported && authorized
              ? ServiceState.available
              : ServiceState.unavailable;
      _lastStatusMessage = message;

      if (!supported || !authorized) {
        throw SpeechRecognitionFailure(
          code:
              errorCode ??
              (supported ? 'speech_permission_denied' : 'speech_unavailable'),
          message: message,
          details: result,
          debugSnapshot: _lastDebugSnapshotValue,
        );
      }
    } on PlatformException catch (error) {
      final failure = _mapPlatformException(error);
      _lastKnownState = _stateForFailure(failure);
      _lastStatusMessage = failure.message;
      throw failure;
    } catch (error) {
      final failure = _mapError(error, fallbackMessage: '语音识别初始化失败，请稍后重试。');
      _lastKnownState = _stateForFailure(failure);
      _lastStatusMessage = failure.message;
      throw failure;
    }
  }

  @override
  Stream<SpeechRecognitionResult> recognize() {
    late final StreamController<SpeechRecognitionResult> controller;
    StreamSubscription<dynamic>? platformSubscription;
    var sessionClosed = false;

    Future<void> closeSession({bool stopNative = false}) async {
      if (sessionClosed) {
        return;
      }
      sessionClosed = true;

      if (stopNative) {
        try {
          await stop();
        } catch (_) {}
      }

      await platformSubscription?.cancel();
      platformSubscription = null;
      _isListening = false;
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    Future<void> startSession() async {
      try {
        if (_isListening) {
          try {
            await stop();
          } catch (_) {}
        }

        platformSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            final result = _parseResult(event);
            _applyEventStatus(result);

            if (result.isErrorEvent) {
              final failure = SpeechRecognitionFailure(
                code: 'speech_error',
                message: _messageForErrorResult(result),
                details: event,
                debugSnapshot: result.debugSnapshot,
              );
              _lastKnownState = _stateForFailure(failure);
              _lastStatusMessage = failure.message;

              if (!controller.isClosed) {
                controller.addError(failure, StackTrace.current);
              }

              unawaited(closeSession());
              return;
            }

            if (!controller.isClosed) {
              controller.add(result);
            }

            if (result.isFinal) {
              unawaited(closeSession());
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            final failure = _mapError(error);
            _lastKnownState = _stateForFailure(failure);
            _lastStatusMessage = failure.message;

            if (!controller.isClosed) {
              controller.addError(failure, stackTrace);
            }

            unawaited(closeSession());
          },
          onDone: () {
            unawaited(closeSession());
          },
          cancelOnError: false,
        );

        await Future<void>.delayed(Duration.zero);
        await initialize();
        final Map<String, dynamic>? status = await _methodChannel
            .invokeMapMethod<String, dynamic>('startListening');
        _applyMethodStatus(status);
        _isListening = true;
        _lastKnownState = ServiceState.available;
        _lastStatusMessage = status?['message'] as String? ?? '语音识别已开始，请开始朗读。';
      } catch (error, stackTrace) {
        final failure = _mapError(error, fallbackMessage: '启动语音识别失败，请稍后重试。');
        _lastKnownState = _stateForFailure(failure);
        _lastStatusMessage = failure.message;

        if (!controller.isClosed) {
          controller.addError(failure, stackTrace);
        }

        await closeSession();
      }
    }

    controller = StreamController<SpeechRecognitionResult>(
      onListen: () {
        unawaited(startSession());
      },
      onCancel: () async {
        await closeSession(stopNative: true);
      },
    );

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    try {
      final Map<String, dynamic>? status = await _methodChannel
          .invokeMapMethod<String, dynamic>('stopListening');
      _applyMethodStatus(status);
      _isListening = false;
      _lastKnownState = ServiceState.available;
      _lastStatusMessage = status?['message'] as String? ?? '语音识别已停止。';
    } on PlatformException catch (error) {
      final failure = _mapPlatformException(error);
      _isListening = false;
      _lastKnownState = _stateForFailure(failure);
      _lastStatusMessage = failure.message;
      throw failure;
    } catch (error) {
      final failure = _mapError(error, fallbackMessage: '停止语音识别失败，请稍后重试。');
      _isListening = false;
      _lastKnownState = _stateForFailure(failure);
      _lastStatusMessage = failure.message;
      throw failure;
    }
  }

  SpeechRecognitionResult _parseResult(dynamic event) {
    final payload = Map<Object?, Object?>.from(event as Map);
    final type = payload['type'] as String? ?? 'unknown';
    final rawText = (payload['text'] as String? ?? '').trim();
    if (rawText.isNotEmpty) {
      _lastRecognizedText = rawText;
    }

    final debugSnapshot =
        payload['debugSnapshot'] is Map<Object?, Object?>
            ? SpeechRecognitionDebugSnapshot.fromMap(
              payload['debugSnapshot'] as Map<Object?, Object?>,
            )
            : null;
    final timestampMillis = (payload['timestamp'] as num?)?.toInt();

    return SpeechRecognitionResult(
      text: rawText.isNotEmpty ? rawText : _lastRecognizedText,
      isFinal: payload['isFinal'] == true || type == 'onResults',
      type: type,
      errorCode: (payload['errorCode'] as num?)?.toInt(),
      errorName: payload['errorName'] as String?,
      backend: payload['backend'] as String?,
      state: payload['state'] as String?,
      timestamp:
          timestampMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      debugSnapshot: debugSnapshot,
    );
  }

  void _applyMethodStatus(Map<String, dynamic>? status) {
    if (status == null) {
      return;
    }

    final debugSnapshot = _snapshotFromDynamic(status['debugSnapshot']);
    if (debugSnapshot != null) {
      _lastDebugSnapshotValue = debugSnapshot;
      _lastNativeStateValue = debugSnapshot.currentState;
    }

    final state = status['state'] as String?;
    if (state != null && state.isNotEmpty) {
      _lastNativeStateValue = state;
    }
  }

  void _applyEventStatus(SpeechRecognitionResult result) {
    if (result.debugSnapshot != null) {
      _lastDebugSnapshotValue = result.debugSnapshot;
    }
    if (result.state != null && result.state!.isNotEmpty) {
      _lastNativeStateValue = result.state;
    }

    _isListening =
        result.state == 'listening' ||
        result.state == 'initializing' ||
        result.state == 'stopping';
    _lastKnownState = _serviceStateForEvent(result);
    _lastStatusMessage = _messageForEvent(result);
  }

  SpeechRecognitionDebugSnapshot? _snapshotFromDynamic(Object? value) {
    if (value is Map<Object?, Object?>) {
      return SpeechRecognitionDebugSnapshot.fromMap(value);
    }
    if (value is Map) {
      return SpeechRecognitionDebugSnapshot.fromMap(
        Map<Object?, Object?>.from(value),
      );
    }
    return null;
  }

  SpeechRecognitionFailure _mapError(Object error, {String? fallbackMessage}) {
    if (error is SpeechRecognitionFailure) {
      return error;
    }

    if (error is PlatformException) {
      return _mapPlatformException(error);
    }

    final message = error.toString().trim();
    return SpeechRecognitionFailure(
      message: message.isEmpty ? (fallbackMessage ?? '语音识别发生未知错误。') : message,
      details: error,
      debugSnapshot: _lastDebugSnapshotValue,
    );
  }

  SpeechRecognitionFailure _mapPlatformException(PlatformException error) {
    final detailsMap =
        error.details is Map
            ? Map<Object?, Object?>.from(error.details as Map)
            : null;
    final debugSnapshot =
        detailsMap == null
            ? null
            : _snapshotFromDynamic(detailsMap['debugSnapshot']);

    final message =
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : '原生语音识别调用失败。';

    return SpeechRecognitionFailure(
      code: error.code,
      message: message,
      details: error.details,
      debugSnapshot: debugSnapshot ?? _lastDebugSnapshotValue,
    );
  }

  ServiceState _stateForFailure(SpeechRecognitionFailure failure) {
    switch (failure.code) {
      case 'speech_unsupported_platform':
        return ServiceState.placeholder;
      default:
        return ServiceState.unavailable;
    }
  }

  ServiceState _serviceStateForEvent(SpeechRecognitionResult result) {
    if (result.isErrorEvent) {
      return ServiceState.unavailable;
    }
    return ServiceState.available;
  }

  String _messageForEvent(SpeechRecognitionResult result) {
    switch (result.type) {
      case 'initialize':
        return '原生语音识别已准备。';
      case 'recognize':
      case 'onReadyForSpeech':
      case 'onBeginningOfSpeech':
      case 'onRmsChanged':
      case 'onPartialResults':
      case 'listening':
        return result.hasText ? '正在识别中。' : '正在听取语音。';
      case 'onEndOfSpeech':
        return '已停止收音，正在整理识别结果。';
      case 'onResults':
        return result.hasText ? '识别完成。' : '没有识别到清晰语音。';
      case 'onError':
        return _messageForErrorResult(result);
      default:
        return '语音识别状态已更新。';
    }
  }

  String _messageForErrorResult(SpeechRecognitionResult result) {
    return result.errorName?.trim().isNotEmpty == true
        ? result.errorName!.trim()
        : '语音识别失败，请稍后重试。';
  }

  void _log(String message) {
    AppLogger.event(message, feature: 'speech_native');
  }
}

class _SherpaOnnxSpeechRecognitionDelegate
    implements _SpeechRecognitionBackendDelegate {
  _SherpaOnnxSpeechRecognitionDelegate();

  static const _speechLanguageTag = 'zh-CN';
  static const _sampleRate = 16000;
  static const _backendId = 'sherpa_onnx_streaming';
  static const _decodeWindowBytes = 3200;
  static const _partialEmitInterval = Duration(milliseconds: 220);
  static const SherpaOnnxModelBundle _modelBundle = SherpaOnnxModelBundle(
    assetRoot:
        'assets/speech/sherpa_onnx_streaming_zipformer_zh_14m_2023_02_23',
    directoryName: 'zh_14m_2023_02_23',
    encoderAssetName: 'encoder-epoch-99-avg-1.int8.onnx',
    decoderAssetName: 'decoder-epoch-99-avg-1.onnx',
    joinerAssetName: 'joiner-epoch-99-avg-1.int8.onnx',
    tokensAssetName: 'tokens.txt',
  );

  final AudioRecorder _audioRecorder = AudioRecorder();

  StreamController<SpeechRecognitionResult>? _controller;
  StreamSubscription<Uint8List>? _audioSubscription;

  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _stream;
  SherpaOnnxResolvedModel? _resolvedModel;

  bool _bindingsInitialized = false;
  bool _warmupCompleted = false;
  bool _permissionGranted = false;
  bool _isStarting = false;
  bool _isListening = false;
  bool _isStopping = false;
  bool _speechStarted = false;
  bool _endpointDetected = false;
  DateTime _lastRmsAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPartialEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _sessionStartedAt;
  DateTime? _firstAudioAt;
  DateTime? _firstPartialAt;
  DateTime? _finalResultAt;
  ServiceState _lastKnownState = ServiceState.available;
  String _currentState = 'idle';
  String _statusMessage = '已接入 sherpa-onnx 离线语音识别。';
  String _committedText = '';
  String _segmentText = '';
  String _displayText = '';
  Uint8List _pendingPcmBytes = Uint8List(0);
  int _partialResultCount = 0;
  int _decodeCycles = 0;
  double _maxObservedRms = 0;
  SpeechRecognitionDebugSnapshot? _lastDebugSnapshotValue;
  List<String> _diagnostics = const <String>[];

  @override
  ServiceCapability get capability =>
      ServiceCapability(state: _lastKnownState, message: _statusMessage);

  @override
  SpeechRecognitionDebugSnapshot? get lastDebugSnapshot =>
      _lastDebugSnapshotValue;

  @override
  String? get lastNativeState => _currentState;

  @override
  Future<void> initialize() async {
    _setState('initializing');
    _lastKnownState = ServiceState.available;
    _permissionGranted = await _audioRecorder.hasPermission(request: true);
    if (!_permissionGranted) {
      _statusMessage = '麦克风权限未授予，无法开始语音识别。';
      _lastKnownState = ServiceState.unavailable;
      _setState('error');
      throw SpeechRecognitionFailure(
        code: 'speech_permission_denied',
        message: _statusMessage,
        debugSnapshot: _buildSnapshot(),
      );
    }

    try {
      if (_resolvedModel != null && _recognizer != null) {
        _lastKnownState = ServiceState.available;
        _setState('ready');
        _updateSnapshot();
        return;
      }

      if (!_bindingsInitialized) {
        sherpa_onnx.initBindings();
        _bindingsInitialized = true;
      }

      _resolvedModel ??= await _modelBundle.resolve();
      if (_recognizer == null) {
        final model = _resolvedModel!;
        final config = sherpa_onnx.OnlineRecognizerConfig(
          model: sherpa_onnx.OnlineModelConfig(
            transducer: sherpa_onnx.OnlineTransducerModelConfig(
              encoder: model.encoder,
              decoder: model.decoder,
              joiner: model.joiner,
            ),
            tokens: model.tokens,
            modelType: model.modelType,
            numThreads: _recommendedThreads(),
            provider: 'cpu',
            debug: false,
          ),
          decodingMethod: 'greedy_search',
          maxActivePaths: 4,
          enableEndpoint: true,
          rule1MinTrailingSilence: 1.8,
          rule2MinTrailingSilence: 0.9,
          rule3MinUtteranceLength: 8.0,
          ruleFsts: '',
          ruleFars: '',
        );
        _recognizer = sherpa_onnx.OnlineRecognizer(config);
      }

      await _warmUpRecognizerIfNeeded();

      _diagnostics = <String>[
        'backend=$_backendId',
        'assetRoot=${_modelBundle.assetRoot}',
        'modelDir=${_resolvedModel?.modelDirectory ?? '<pending>'}',
        'sampleRate=$_sampleRate',
      ];
      _statusMessage = 'sherpa-onnx 离线模型已准备，可开始识别。';
      _lastKnownState = ServiceState.available;
      _setState('ready');
      _updateSnapshot();
    } catch (error) {
      _statusMessage = 'sherpa-onnx 初始化失败：$error';
      _lastKnownState = ServiceState.unavailable;
      _setState('error');
      throw SpeechRecognitionFailure(
        code: 'speech_backend_init_failed',
        message: _statusMessage,
        details: error,
        debugSnapshot: _buildSnapshot(),
      );
    }
  }

  @override
  Stream<SpeechRecognitionResult> recognize() {
    if (!Platform.isAndroid) {
      return Stream<SpeechRecognitionResult>.error(
        const SpeechRecognitionFailure(
          code: 'speech_unsupported_platform',
          message: 'sherpa-onnx 当前仅在 Android 端作为实时识别主实现接入。',
        ),
      );
    }

    late final StreamController<SpeechRecognitionResult> controller;
    var sessionClosed = false;

    Future<void> closeSession({bool stopNative = false}) async {
      if (sessionClosed) {
        return;
      }
      sessionClosed = true;

      if (stopNative) {
        await _cancelSession(emitFinal: false);
      }

      if (!controller.isClosed) {
        await controller.close();
      }
      if (identical(_controller, controller)) {
        _controller = null;
      }
    }

    Future<void> startSession() async {
      try {
        if (_isListening || _isStarting || _isStopping) {
          await _cancelSession(emitFinal: false);
        }

        _isStarting = true;
        await initialize();
        _controller = controller;
        _resetRealtimeSession();
        _setState('initializing');
        _emit(type: 'initialize');

        _stream?.free();
        _stream = _recognizer!.createStream();
        final audioStream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: _sampleRate,
            numChannels: 1,
          ),
        );

        _isStarting = false;
        _isListening = true;
        _isStopping = false;
        _setState('listening');
        _lastKnownState = ServiceState.available;
        _statusMessage = '正在使用 sherpa-onnx 识别语音。';
        _emit(type: 'recognize');
        _emit(type: 'onReadyForSpeech');

        _audioSubscription = audioStream.listen(
          _handleAudioChunk,
          onError: (Object error, StackTrace stackTrace) async {
            await _failSession(
              code: 'speech_stream_error',
              message: '录音流发生异常：$error',
              details: error,
            );
          },
          onDone: () async {
            if (_isListening || _isStopping) {
              await _finishSession(emitFinal: true);
            }
          },
          cancelOnError: false,
        );
      } catch (error, stackTrace) {
        _isStarting = false;
        final failure =
            error is SpeechRecognitionFailure
                ? error
                : SpeechRecognitionFailure(
                  code: 'speech_start_failed',
                  message: '启动 sherpa-onnx 识别失败：$error',
                  details: error,
                  debugSnapshot: _buildSnapshot(),
                );

        if (!controller.isClosed) {
          controller.addError(failure, stackTrace);
        }
        await closeSession();
      }
    }

    controller = StreamController<SpeechRecognitionResult>(
      onListen: () {
        unawaited(startSession());
      },
      onCancel: () async {
        await closeSession(stopNative: true);
      },
    );

    return controller.stream;
  }

  @override
  Future<void> stop() async {
    if (!_isListening && !_isStopping) {
      return;
    }

    await _finishSession(emitFinal: true);
  }

  void _handleAudioChunk(Uint8List bytes) {
    final stream = _stream;
    final recognizer = _recognizer;
    if (stream == null || recognizer == null || bytes.isEmpty) {
      return;
    }

    try {
      _firstAudioAt ??= DateTime.now();

      _pendingPcmBytes = _appendPcmBytes(_pendingPcmBytes, bytes);
      while (_pendingPcmBytes.length >= _decodeWindowBytes) {
        final chunk = _pendingPcmBytes.sublist(0, _decodeWindowBytes);
        _pendingPcmBytes = _pendingPcmBytes.sublist(_decodeWindowBytes);
        if (_processPcmChunk(chunk, allowEndpointDetection: true)) {
          return;
        }
      }
    } catch (error) {
      unawaited(
        _failSession(
          code: 'speech_decode_failed',
          message: 'sherpa-onnx 解码失败：$error',
          details: error,
        ),
      );
    }
  }

  Future<void> _finishSession({required bool emitFinal}) async {
    if (!_isListening && !_isStopping) {
      return;
    }

    _isListening = false;
    _isStopping = true;
    _setState('stopping');
    _emit(type: 'onEndOfSpeech', text: _displayText);

    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      try {
        await _audioRecorder.stop();
      } catch (_) {}

      final stream = _stream;
      final recognizer = _recognizer;
      if (stream != null && recognizer != null) {
        if (_pendingPcmBytes.isNotEmpty) {
          _processPcmChunk(_pendingPcmBytes, allowEndpointDetection: false);
          _pendingPcmBytes = Uint8List(0);
        }
        stream.inputFinished();
        while (recognizer.isReady(stream)) {
          recognizer.decode(stream);
          _decodeCycles += 1;
        }
        final finalSegment = _normalizeRecognizerText(
          recognizer.getResult(stream).text,
        );
        _segmentText = finalSegment;
        _displayText = _combineResultTexts(_committedText, _segmentText);
        _finalResultAt = DateTime.now();
      }

      if (emitFinal) {
        _setState('completed');
        _lastKnownState = ServiceState.available;
        _statusMessage = _displayText.isEmpty ? '没有识别到清晰语音。' : '识别完成，可以直接评分。';
        _emit(type: 'onResults', text: _displayText, isFinal: true);
      } else {
        _setState('idle');
      }
    } finally {
      _disposeStream();
      _isStopping = false;
      if (emitFinal) {
        await _controller?.close();
        _controller = null;
      }
    }
  }

  Future<void> _cancelSession({required bool emitFinal}) async {
    if (!_isListening && !_isStopping && _audioSubscription == null) {
      return;
    }

    await _finishSession(emitFinal: emitFinal);
  }

  Future<void> _failSession({
    required String code,
    required String message,
    Object? details,
  }) async {
    _statusMessage = message;
    _lastKnownState = ServiceState.unavailable;
    _setState('error');
    _emit(
      type: 'onError',
      text: _displayText,
      errorName: message,
      extras: <String, Object?>{'code': code},
    );
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.addError(
        SpeechRecognitionFailure(
          code: code,
          message: message,
          details: details,
          debugSnapshot: _buildSnapshot(),
        ),
      );
      await controller.close();
    }
    _controller = null;
    _disposeStream();
    _isStarting = false;
    _isListening = false;
    _isStopping = false;
    _pendingPcmBytes = Uint8List(0);
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
  }

  void _disposeStream() {
    _stream?.free();
    _stream = null;
  }

  void _setState(String state) {
    _currentState = state;
    _updateSnapshot();
  }

  void _updateSnapshot() {
    _lastDebugSnapshotValue = _buildSnapshot();
  }

  SpeechRecognitionDebugSnapshot _buildSnapshot() {
    final model = _resolvedModel;
    final availableBackends = <String>[_backendId, 'native_system_fallback'];
    final now = DateTime.now();
    final diagnostics = <String>[
      ..._diagnostics,
      if (_sessionStartedAt != null)
        'sessionMs=${now.difference(_sessionStartedAt!).inMilliseconds}',
      if (_firstAudioAt != null)
        'audioStartMs=${_firstAudioAt!.difference(_sessionStartedAt ?? _firstAudioAt!).inMilliseconds}',
      'maxRms=${_maxObservedRms.toStringAsFixed(4)}',
      'bufferedBytes=${_pendingPcmBytes.length}',
      'warmup=${_warmupCompleted ? 'done' : 'pending'}',
    ];
    return SpeechRecognitionDebugSnapshot(
      permissionGranted: _permissionGranted,
      isRecognitionAvailable: model != null,
      isOnDeviceRecognitionAvailable: true,
      eventSinkReady: _controller?.hasListener == true,
      recognizerCreated: _recognizer != null,
      listenerBound: _audioSubscription != null,
      currentState: _currentState,
      currentLocale: _speechLanguageTag,
      selectedBackend: _backendId,
      currentDeviceBrand: Platform.operatingSystem,
      currentDeviceManufacturer: Platform.operatingSystem,
      sdkInt: 0,
      selectedServiceInfo: model?.modelDirectory,
      modelFilesReady: model != null,
      availableBackends: availableBackends,
      diagnostics: diagnostics,
      firstPartialLatencyMs:
          _firstPartialAt == null || _sessionStartedAt == null
              ? null
              : _firstPartialAt!.difference(_sessionStartedAt!).inMilliseconds,
      finalLatencyMs:
          _finalResultAt == null || _sessionStartedAt == null
              ? null
              : _finalResultAt!.difference(_sessionStartedAt!).inMilliseconds,
      partialResultCount: _partialResultCount,
      decodeCycles: _decodeCycles,
      endpointDetected: _endpointDetected,
    );
  }

  void _emit({
    required String type,
    String text = '',
    bool isFinal = false,
    int? errorCode,
    String? errorName,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final controller = _controller;
    if (controller == null || controller.isClosed) {
      return;
    }

    if (extras.isNotEmpty) {
      _diagnostics = <String>[
        ..._diagnostics.where((String item) => !item.startsWith('$type:')),
        '$type:${extras.entries.map((entry) => '${entry.key}=${entry.value}').join(',')}',
      ];
      _updateSnapshot();
    }

    final payloadText = text.isNotEmpty ? text : _displayText;
    final result = SpeechRecognitionResult(
      text: payloadText,
      isFinal: isFinal,
      type: type,
      errorCode: errorCode,
      errorName: errorName,
      backend: _backendId,
      state: _currentState,
      timestamp: DateTime.now(),
      debugSnapshot: _buildSnapshot(),
    );

    if (!controller.isClosed) {
      controller.add(result);
    }
  }

  String _normalizeRecognizerText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '');
  }

  String _combineResultTexts(String committed, String current) {
    final merged = <String>[
      if (committed.trim().isNotEmpty) committed.trim(),
      if (current.trim().isNotEmpty) current.trim(),
    ];
    return merged.join();
  }

  double _calculateRms(Float32List samples) {
    if (samples.isEmpty) {
      return 0;
    }

    var sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }

  int _recommendedThreads() {
    final processors = Platform.numberOfProcessors;
    return processors <= 2 ? 1 : math.min(4, processors - 1);
  }

  void _resetRealtimeSession() {
    _committedText = '';
    _segmentText = '';
    _displayText = '';
    _pendingPcmBytes = Uint8List(0);
    _speechStarted = false;
    _endpointDetected = false;
    _partialResultCount = 0;
    _decodeCycles = 0;
    _maxObservedRms = 0;
    _sessionStartedAt = DateTime.now();
    _firstAudioAt = null;
    _firstPartialAt = null;
    _finalResultAt = null;
    _lastRmsAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastPartialEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Uint8List _appendPcmBytes(Uint8List current, Uint8List next) {
    if (current.isEmpty) {
      return Uint8List.fromList(next);
    }

    final merged = Uint8List(current.length + next.length);
    merged.setRange(0, current.length, current);
    merged.setRange(current.length, merged.length, next);
    return merged;
  }

  bool _processPcmChunk(
    Uint8List bytes, {
    required bool allowEndpointDetection,
  }) {
    final stream = _stream;
    final recognizer = _recognizer;
    if (stream == null || recognizer == null || bytes.isEmpty) {
      return false;
    }

    final samples = sherpaPcm16ToFloat32(bytes);
    final rms = _calculateRms(samples);
    final now = DateTime.now();
    _maxObservedRms = math.max(_maxObservedRms, rms);

    if (!_speechStarted && rms > 0.015) {
      _speechStarted = true;
      _emit(type: 'onBeginningOfSpeech');
    }

    if (now.difference(_lastRmsAt) >= const Duration(milliseconds: 180)) {
      _lastRmsAt = now;
      _emit(type: 'onRmsChanged', extras: <String, Object?>{'rmsDb': rms});
    }

    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
      _decodeCycles += 1;
    }

    final partial = _normalizeRecognizerText(recognizer.getResult(stream).text);
    final previousDisplay = _displayText;
    final combined = _combineResultTexts(_committedText, partial);
    if (combined != previousDisplay) {
      _segmentText = partial;
      _displayText = combined;
      if (_displayText.isNotEmpty && _firstPartialAt == null) {
        _firstPartialAt = now;
      }
      if (now.difference(_lastPartialEmittedAt) >= _partialEmitInterval ||
          partial.length <= 4 ||
          partial.length > previousDisplay.length) {
        _partialResultCount += 1;
        _lastPartialEmittedAt = now;
        _emit(type: 'onPartialResults', text: _displayText);
      }
    }

    if (allowEndpointDetection &&
        !_isStopping &&
        _speechStarted &&
        _displayText.isNotEmpty &&
        recognizer.isEndpoint(stream)) {
      _endpointDetected = true;
      unawaited(_finishSession(emitFinal: true));
      return true;
    }

    return false;
  }

  Future<void> _warmUpRecognizerIfNeeded() async {
    if (_warmupCompleted || _recognizer == null) {
      return;
    }

    final warmupStream = _recognizer!.createStream();
    try {
      warmupStream.acceptWaveform(
        samples: Float32List(_sampleRate ~/ 5),
        sampleRate: _sampleRate,
      );
      while (_recognizer!.isReady(warmupStream)) {
        _recognizer!.decode(warmupStream);
      }
      warmupStream.inputFinished();
      while (_recognizer!.isReady(warmupStream)) {
        _recognizer!.decode(warmupStream);
      }
      _warmupCompleted = true;
    } finally {
      warmupStream.free();
    }
  }
}
