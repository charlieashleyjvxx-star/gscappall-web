import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/app_logger.dart';
import '../../core/service_status.dart';

abstract class AudioPlayerService {
  ServiceCapability get capability;

  Future<void> prepare();
  Future<void> play(String? source);
  Future<void> stop();
  Future<void> setSpeed(double speed);
}

class StubAudioPlayerService implements AudioPlayerService {
  const StubAudioPlayerService();

  static AudioPlayer? _player;
  static double _speed = 1.0;
  static String? _preparedSource;
  static String? _lastErrorMessage;

  static bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => false,
    };
  }

  @override
  ServiceCapability get capability {
    if (_isSupportedPlatform) {
      return ServiceCapability(
        state: ServiceState.available,
        message: _lastErrorMessage ?? 'just_audio 已接入，可播放资源音频与文件音频。',
      );
    }

    return const ServiceCapability(
      state: ServiceState.placeholder,
      message:
          '当前项目未安装 Windows 桌面端 just_audio 后端，Android / iOS 可用，Windows 保留接口占位。',
    );
  }

  @override
  Future<void> prepare() async {
    if (!_isSupportedPlatform) {
      return;
    }

    await _ensurePlayer();
  }

  @override
  Future<void> play(String? source) async {
    if (!_isSupportedPlatform || source == null || source.trim().isEmpty) {
      return;
    }

    final normalizedSource = source.trim();

    try {
      final player = await _ensurePlayer();
      if (_preparedSource != normalizedSource) {
        await _loadSource(player, normalizedSource);
        _preparedSource = normalizedSource;
      }
      await player.play();
      _lastErrorMessage = null;
    } catch (error) {
      _lastErrorMessage = '音频播放暂时不可用。';
      AppLogger.event(
        'playback_failed',
        feature: 'audio',
        level: AppLogLevel.error,
      );
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);

    if (!_isSupportedPlatform) {
      return;
    }

    try {
      final player = await _ensurePlayer();
      await player.setSpeed(_speed);
      _lastErrorMessage = null;
    } catch (error) {
      _lastErrorMessage = '音频倍速设置暂时不可用。';
      AppLogger.event(
        'speed_change_failed',
        feature: 'audio',
        level: AppLogLevel.error,
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_isSupportedPlatform || _player == null) {
      return;
    }

    try {
      await _player!.stop();
      _preparedSource = null;
      _lastErrorMessage = null;
    } catch (error) {
      _lastErrorMessage = '音频暂时无法停止。';
      AppLogger.event(
        'playback_stop_failed',
        feature: 'audio',
        level: AppLogLevel.error,
      );
    }
  }

  static Future<AudioPlayer> _ensurePlayer() async {
    final existingPlayer = _player;
    if (existingPlayer != null) {
      await existingPlayer.setSpeed(_speed);
      return existingPlayer;
    }

    final player = AudioPlayer(
      useProxyForRequestHeaders: false,
      handleInterruptions: true,
    );
    await player.setSpeed(_speed);
    _player = player;
    return player;
  }

  static Future<void> _loadSource(AudioPlayer player, String source) async {
    if (_isRemoteSource(source)) {
      await player.setUrl(source);
      return;
    }

    final assetSource = _assetPathFrom(source);
    if (assetSource != null) {
      await player.setAsset(assetSource);
      return;
    }

    if (File(source).existsSync()) {
      await player.setFilePath(source);
      return;
    }

    throw ArgumentError.value(source, 'source', 'Unsupported audio source');
  }

  static bool _isRemoteSource(String source) {
    final uri = Uri.tryParse(source);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static String? _assetPathFrom(String source) {
    if (source.startsWith('asset:///')) {
      return source.replaceFirst('asset:///', '');
    }
    if (source.startsWith('asset://')) {
      return source.replaceFirst('asset://', '');
    }
    if (source.startsWith('/assets/')) {
      return source.substring(1);
    }
    if (source.startsWith('assets/')) {
      return source;
    }
    return null;
  }
}
