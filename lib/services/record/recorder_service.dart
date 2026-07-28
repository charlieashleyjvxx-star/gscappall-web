// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/app_logger.dart';
import '../../core/service_status.dart';

abstract class RecorderService {
  ServiceCapability get capability;

  Future<bool> refreshPermission({bool request = false});
  Future<void> requestPermission();
  Future<void> start();
  Future<String?> stop();
}

class StubRecorderService implements RecorderService {
  const StubRecorderService();

  static AudioRecorder? _recorder;
  static bool _permissionGranted = false;
  static bool _isRecording = false;
  static String? _currentRecordingPath;
  static String? _lastRecordingPath;
  static String? _lastErrorMessage;

  static bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      TargetPlatform.fuchsia => false,
    };
  }

  @override
  ServiceCapability get capability {
    if (!_isSupportedPlatform) {
      return const ServiceCapability(
        state: ServiceState.unavailable,
        message: '当前平台不支持录音能力。',
      );
    }

    if (!_permissionGranted) {
      return ServiceCapability(
        state: ServiceState.unavailable,
        message: _lastErrorMessage ?? '麦克风权限未授予，无法录音或语音识别。',
      );
    }

    return ServiceCapability(
      state: ServiceState.available,
      message:
          _lastErrorMessage ??
          'record 已接入，可录制到本地文件。'
              '${_lastRecordingPath == null ? '' : ' 最近一次录音已保存。'}',
    );
  }

  @override
  Future<bool> refreshPermission({bool request = false}) async {
    if (!_isSupportedPlatform) {
      _permissionGranted = false;
      _lastErrorMessage = '当前平台不支持录音能力。';
      return false;
    }

    final recorder = _ensureRecorder();
    final granted = await recorder.hasPermission(request: request);
    _permissionGranted = granted;

    if (!granted) {
      _lastErrorMessage = '麦克风权限未授予，无法录音或语音识别。请在系统权限弹窗中允许，或到应用设置中开启麦克风权限。';
      return false;
    }

    _lastErrorMessage = null;
    return true;
  }

  @override
  Future<void> requestPermission() async {
    final granted = await refreshPermission(request: true);
    if (!granted) {
      throw StateError(_lastErrorMessage!);
    }
  }

  @override
  Future<void> start() async {
    if (!_isSupportedPlatform) {
      return;
    }

    final recorder = _ensureRecorder();
    if (_isRecording) {
      return;
    }

    if (!_permissionGranted) {
      await requestPermission();
    }

    final supportsAac = await recorder.isEncoderSupported(AudioEncoder.aacLc);
    final encoder = supportsAac ? AudioEncoder.aacLc : AudioEncoder.wav;
    final extension = supportsAac ? 'm4a' : 'wav';
    final outputPath = await _buildOutputPath(extension);

    try {
      await recorder.start(
        RecordConfig(
          encoder: encoder,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: outputPath,
      );
      _currentRecordingPath = outputPath;
      _isRecording = true;
      _lastErrorMessage = null;
    } catch (error) {
      _lastErrorMessage = '录音启动失败，请稍后重试。';
      AppLogger.event(
        'recording_start_failed',
        feature: 'recording',
        level: AppLogLevel.error,
      );
      rethrow;
    }
  }

  @override
  Future<String?> stop() async {
    if (!_isSupportedPlatform) {
      return null;
    }

    final recorder = _recorder;
    if (recorder == null) {
      return _lastRecordingPath;
    }
    if (!_isRecording) {
      return _lastRecordingPath;
    }

    try {
      final savedPath = await recorder.stop();
      _isRecording = false;
      _lastRecordingPath = savedPath ?? _currentRecordingPath;
      _currentRecordingPath = null;
      _lastErrorMessage = null;
      return _lastRecordingPath;
    } catch (error) {
      _lastErrorMessage = '录音停止失败，请稍后重试。';
      AppLogger.event(
        'recording_stop_failed',
        feature: 'recording',
        level: AppLogLevel.error,
      );
      rethrow;
    }
  }

  static AudioRecorder _ensureRecorder() => _recorder ??= AudioRecorder();

  static Future<String> _buildOutputPath(String extension) async {
    final baseDirectory = await _resolveRecordingDirectory();
    final recordingsDirectory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}recordings',
    );
    if (!recordingsDirectory.existsSync()) {
      recordingsDirectory.createSync(recursive: true);
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_'
        '${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';

    return '${recordingsDirectory.path}${Platform.pathSeparator}recite_$stamp.$extension';
  }

  static Future<Directory> _resolveRecordingDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
