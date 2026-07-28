import 'dart:convert';
import 'dart:io';

import 'package:gscappall/data/remote/cloud_sync_api.dart';
import 'package:gscappall/data/remote/sync_payload_dtos.dart';

const _supportedPolicies = <String, String>{
  'poems': 'server_authoritative',
  'favorites': 'last_write_wins',
  'learning_records': 'append_only',
  'study_card_progress': 'last_write_wins',
  'recite_records': 'append_only',
  'wrong_questions': 'last_write_wins',
  'practice_reports': 'append_only',
  'daily_poem_records': 'last_write_wins',
  'user_points': 'server_merge_suggested',
  'challenge_stage_rewards': 'last_write_wins',
  'settings': 'last_write_wins',
  'user_profiles': 'last_write_wins',
};

const _batchKeyToResource = <String, String>{
  'poems': 'poems',
  'favorites': 'favorites',
  'learningRecords': 'learning_records',
  'studyCardProgress': 'study_card_progress',
  'reciteRecords': 'recite_records',
  'wrongQuestions': 'wrong_questions',
  'practiceReports': 'practice_reports',
  'dailyPoemRecords': 'daily_poem_records',
  'userPoints': 'user_points',
  'challengeStageRewards': 'challenge_stage_rewards',
  'settings': 'settings',
  'userProfiles': 'user_profiles',
};

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen(_handleRequest);
  final baseUri = Uri.parse('http://127.0.0.1:${server.port}');
  final api = CloudSyncApi(
    config: CloudSyncApiConfig(baseUri: baseUri, enableNetwork: true),
  );

  try {
    final capabilities = await api.fetchCapabilities();
    if (capabilities.maxBatchSize != 500) {
      throw StateError('Unexpected maxBatchSize: ${capabilities.maxBatchSize}');
    }

    final checkpoint = const SyncCheckpointDto(schemaVersion: 10);
    final device = const SyncDeviceContextDto(
      deviceId: 'sync-proxy-smoke',
      platform: 'tool',
      appVersion: 'dev',
      schemaVersion: 10,
    );
    final push = await api.pushChanges(
      SyncUpstreamPayloadDto(
        requestId: 'sync-proxy-smoke-push',
        device: device,
        checkpoint: checkpoint,
        batch: const SyncBatchPayloadDto(),
        generatedAt: DateTime.now().toUtc(),
      ),
    );
    if (push.requestId != 'sync-proxy-smoke-push') {
      throw StateError('Unexpected push requestId: ${push.requestId}');
    }

    final pull = await api.pullChanges(
      SyncPullRequestDto(
        requestId: 'sync-proxy-smoke-pull',
        device: device,
        checkpoint: push.checkpoint,
        requestedAt: DateTime.now().toUtc(),
      ),
    );
    if (pull.conflicts.isNotEmpty) {
      throw StateError('Unexpected pull conflicts: ${pull.conflicts.length}');
    }

    stdout.writeln(
      'sync proxy HTTP smoke passed: '
      'capabilities=${capabilities.maxBatchSize}, '
      'pushRequest=${push.requestId}, '
      'pullNotes=${pull.notes.length}',
    );
  } finally {
    await subscription.cancel();
    await server.close(force: true);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  try {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/sync/capabilities') {
      await _sendJson(request.response, {
        'supportsPoemCatalog': true,
        'supportsSoftDelete': true,
        'supportsFieldMerge': true,
        'maxBatchSize': 500,
        'supportedPolicies': _supportedPolicies,
        'notes': ['sync proxy smoke capabilities'],
      });
      return;
    }

    if (request.method == 'POST' && path == '/sync/push') {
      final payload = await _readJson(request);
      await _sendJson(request.response, {
        'requestId': payload['requestId'] ?? 'sync-proxy-smoke-push',
        'checkpoint': _checkpointFrom(payload),
        'acceptedCounts': _countBatch(
          Map<String, dynamic>.from(payload['batch'] as Map? ?? const {}),
        ),
        'conflicts': [],
        'serverTime': DateTime.now().toUtc().toIso8601String(),
        'notes': ['sync proxy smoke accepted push'],
      });
      return;
    }

    if (request.method == 'POST' && path == '/sync/pull') {
      final payload = await _readJson(request);
      await _sendJson(request.response, {
        'checkpoint': _checkpointFrom(payload),
        'batch': {},
        'receivedCounts': {},
        'conflicts': [],
        'serverTime': DateTime.now().toUtc().toIso8601String(),
        'notes': ['sync proxy smoke returned empty pull'],
      });
      return;
    }

    if (request.method == 'POST' && path == '/sync/conflicts/preview') {
      await _sendJson(request.response, {'conflicts': []});
      return;
    }

    await _sendJson(request.response, {'error': 'Not found.'}, statusCode: 404);
  } catch (error) {
    await _sendJson(request.response, {
      'error': error.toString(),
    }, statusCode: 400);
  }
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  final body = await utf8.decoder.bind(request).join();
  if (body.trim().isEmpty) {
    return {};
  }
  return Map<String, dynamic>.from(jsonDecode(body) as Map);
}

Future<void> _sendJson(
  HttpResponse response,
  Map<String, dynamic> payload, {
  int statusCode = 200,
}) async {
  final text = jsonEncode(payload);
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(text);
  await response.close();
}

Map<String, dynamic> _checkpointFrom(Map<String, dynamic> payload) {
  final checkpoint = Map<String, dynamic>.from(
    payload['checkpoint'] as Map? ?? const {},
  );
  return {
    ...checkpoint,
    'globalCursor': 'mock-${DateTime.now().millisecondsSinceEpoch}',
    'lastSuccessfulSyncAt': DateTime.now().toUtc().toIso8601String(),
    'schemaVersion': checkpoint['schemaVersion'] ?? 10,
  };
}

Map<String, int> _countBatch(Map<String, dynamic> batch) {
  return {
    for (final entry in _batchKeyToResource.entries)
      if (batch[entry.key] is List && (batch[entry.key] as List).isNotEmpty)
        entry.value: (batch[entry.key] as List).length,
  };
}
