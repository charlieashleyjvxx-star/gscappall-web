import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SherpaOnnxResolvedModel {
  const SherpaOnnxResolvedModel({
    required this.modelDirectory,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    required this.assetRoot,
    required this.sampleRate,
    required this.modelType,
  });

  final String modelDirectory;
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
  final String assetRoot;
  final int sampleRate;
  final String modelType;
}

class SherpaOnnxModelBundle {
  const SherpaOnnxModelBundle({
    required this.assetRoot,
    required this.directoryName,
    required this.encoderAssetName,
    required this.decoderAssetName,
    required this.joinerAssetName,
    required this.tokensAssetName,
    this.sampleRate = 16000,
    this.modelType = 'zipformer',
  });

  final String assetRoot;
  final String directoryName;
  final String encoderAssetName;
  final String decoderAssetName;
  final String joinerAssetName;
  final String tokensAssetName;
  final int sampleRate;
  final String modelType;

  Future<SherpaOnnxResolvedModel> resolve() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final targetDirectory = Directory(
      p.join(supportDirectory.path, 'speech_models', 'sherpa_onnx', directoryName),
    );
    if (!targetDirectory.existsSync()) {
      targetDirectory.createSync(recursive: true);
    }

    final encoder = await _ensureAssetCopied(
      assetPath: '$assetRoot/$encoderAssetName',
      destinationPath: p.join(targetDirectory.path, encoderAssetName),
    );
    final decoder = await _ensureAssetCopied(
      assetPath: '$assetRoot/$decoderAssetName',
      destinationPath: p.join(targetDirectory.path, decoderAssetName),
    );
    final joiner = await _ensureAssetCopied(
      assetPath: '$assetRoot/$joinerAssetName',
      destinationPath: p.join(targetDirectory.path, joinerAssetName),
    );
    final tokens = await _ensureAssetCopied(
      assetPath: '$assetRoot/$tokensAssetName',
      destinationPath: p.join(targetDirectory.path, tokensAssetName),
    );

    return SherpaOnnxResolvedModel(
      modelDirectory: targetDirectory.path,
      encoder: encoder,
      decoder: decoder,
      joiner: joiner,
      tokens: tokens,
      assetRoot: assetRoot,
      sampleRate: sampleRate,
      modelType: modelType,
    );
  }

  Future<String> _ensureAssetCopied({
    required String assetPath,
    required String destinationPath,
  }) async {
    final destinationFile = File(destinationPath);
    final assetData = await rootBundle.load(assetPath);
    final assetLength = assetData.lengthInBytes;

    final exists = destinationFile.existsSync();
    if (exists && destinationFile.lengthSync() == assetLength) {
      return destinationFile.path;
    }

    final bytes = Uint8List.sublistView(assetData.buffer.asUint8List());
    await destinationFile.writeAsBytes(bytes, flush: true);
    return destinationFile.path;
  }
}

Float32List sherpaPcm16ToFloat32(Uint8List bytes, [Endian endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < bytes.length; index += 2) {
    final sample = data.getInt16(index, endian);
    values[index ~/ 2] = sample / 32768.0;
  }
  return values;
}
