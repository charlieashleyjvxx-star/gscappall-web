import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/service_status.dart';

class TextToSpeechSynthesisResult {
  const TextToSpeechSynthesisResult({
    required this.filePath,
    required this.locale,
    required this.engine,
    required this.voice,
    required this.wasCached,
  });

  final String filePath;
  final String locale;
  final String? engine;
  final String? voice;
  final bool wasCached;
}

abstract class TextToSpeechService {
  ServiceCapability get capability;

  Future<void> initialize();

  Future<TextToSpeechSynthesisResult> synthesizeToFile({
    required String text,
    String locale = 'zh-CN',
    String? cacheKey,
    bool forceRegenerate = false,
    double speechRate = 1.0,
    double pitch = 1.0,
  });
}

class PlatformTextToSpeechService implements TextToSpeechService {
  const PlatformTextToSpeechService();

  static const MethodChannel _methodChannel = MethodChannel(
    'gscappall/tts/methods',
  );

  static ServiceState _lastKnownState =
      defaultTargetPlatform == TargetPlatform.android
          ? ServiceState.placeholder
          : ServiceState.unavailable;
  static String? _lastMessage;
  static String? _lastEngine;
  static String? _lastVoice;

  @override
  ServiceCapability get capability {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return ServiceCapability(
        state: _lastKnownState,
        message: _lastMessage ?? 'Android 原生 TTS 已接入，可将诗句预生成到本地音频文件。',
      );
    }

    return const ServiceCapability(
      state: ServiceState.placeholder,
      message: '当前仅在 Android 侧接入原生 TTS，其他平台暂时保留占位。',
    );
  }

  @override
  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _lastKnownState = ServiceState.placeholder;
      _lastMessage = '当前仅在 Android 侧接入原生 TTS。';
      return;
    }

    try {
      final status = await _methodChannel.invokeMapMethod<String, dynamic>(
        'initialize',
      );
      _applyStatus(status);
      final available = status?['available'] == true;
      if (!available) {
        throw PlatformException(
          code: 'tts_unavailable',
          message: status?['message'] as String? ?? 'Android 原生 TTS 当前不可用。',
          details: status,
        );
      }
    } on PlatformException catch (error) {
      _applyErrorState(error);
      rethrow;
    } catch (error) {
      _lastKnownState = ServiceState.unavailable;
      _lastMessage = '初始化 Android 原生 TTS 失败：$error';
      rethrow;
    }
  }

  @override
  Future<TextToSpeechSynthesisResult> synthesizeToFile({
    required String text,
    String locale = 'zh-CN',
    String? cacheKey,
    bool forceRegenerate = false,
    double speechRate = 1.0,
    double pitch = 1.0,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw PlatformException(
        code: 'tts_unsupported_platform',
        message: '当前仅在 Android 侧接入原生 TTS。',
      );
    }

    if (text.trim().isEmpty) {
      throw PlatformException(
        code: 'tts_empty_text',
        message: '用于生成示范音频的文本不能为空。',
      );
    }

    await initialize();

    try {
      final status = await _methodChannel.invokeMapMethod<String, dynamic>(
        'synthesizeToFile',
        <String, Object?>{
          'text': text,
          'locale': locale,
          'cacheKey': cacheKey,
          'forceRegenerate': forceRegenerate,
          'speechRate': speechRate,
          'pitch': pitch,
        },
      );
      _applyStatus(status);

      final outputPath = (status?['outputPath'] as String?)?.trim();
      if (outputPath == null || outputPath.isEmpty) {
        throw PlatformException(
          code: 'tts_missing_output',
          message: 'Android 原生 TTS 没有返回可播放的音频文件。',
          details: status,
        );
      }

      return TextToSpeechSynthesisResult(
        filePath: outputPath,
        locale: (status?['locale'] as String? ?? locale).trim(),
        engine: status?['engine'] as String?,
        voice: status?['voice'] as String?,
        wasCached: status?['cached'] == true,
      );
    } on PlatformException catch (error) {
      _applyErrorState(error);
      rethrow;
    } catch (error) {
      _lastKnownState = ServiceState.unavailable;
      _lastMessage = '生成示范音频失败：$error';
      rethrow;
    }
  }

  void _applyStatus(Map<String, dynamic>? status) {
    if (status == null) {
      return;
    }

    final available = status['available'] == true;
    _lastKnownState =
        available ? ServiceState.available : ServiceState.unavailable;
    _lastMessage = status['message'] as String?;
    _lastEngine = status['engine'] as String?;
    _lastVoice = status['voice'] as String?;

    if (available) {
      final engine = _lastEngine?.trim();
      final voice = _lastVoice?.trim();
      _lastMessage = [
        status['message'] as String? ?? 'Android 原生 TTS 已接入，可将诗句预生成到本地音频文件。',
        if (engine != null && engine.isNotEmpty) '引擎：$engine',
        if (voice != null && voice.isNotEmpty) '音色：$voice',
      ].join(' ');
    }
  }

  void _applyErrorState(PlatformException error) {
    final details = error.details;
    if (details is Map) {
      _applyStatus(Map<String, dynamic>.from(details));
      return;
    }

    _lastKnownState = ServiceState.unavailable;
    _lastMessage =
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Android 原生 TTS 当前不可用。';
  }
}
