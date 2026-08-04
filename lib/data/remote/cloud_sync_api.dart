import 'dart:convert';
import 'dart:io';

import '../../domain/sync/sync_models.dart';
import 'sync_payload_dtos.dart';

class CloudSyncApiConfig {
  const CloudSyncApiConfig({
    this.baseUri,
    this.authToken,
    this.deviceId = 'gscappall-local-device',
    this.accountId,
    this.platform = 'unknown',
    this.appVersion = 'dev',
    this.schemaVersion = 10,
    this.capabilitiesPath = '/sync/capabilities',
    this.registerPath = '/auth/register',
    this.loginPath = '/auth/login',
    this.refreshTokenPath = '/auth/refresh',
    this.pushPath = '/sync/push',
    this.pullPath = '/sync/pull',
    this.conflictPreviewPath = '/sync/conflicts/preview',
    this.debugRequestLogsPath = '/debug/request-logs',
    this.enableNetwork = false,
  });

  final Uri? baseUri;
  final String? authToken;
  final String deviceId;
  final String? accountId;
  final String platform;
  final String appVersion;
  final int schemaVersion;
  final String capabilitiesPath;
  final String registerPath;
  final String loginPath;
  final String refreshTokenPath;
  final String pushPath;
  final String pullPath;
  final String conflictPreviewPath;
  final String debugRequestLogsPath;
  final bool enableNetwork;

  Uri endpoint(String path) {
    final base = baseUri ?? Uri.parse('https://sync.local.invalid');
    return base.resolve(path);
  }
}

abstract class CloudSyncTransport {
  Future<JsonMap> getJson(
    Uri endpoint, {
    Map<String, String> headers = const {},
  });

  Future<JsonMap> postJson(
    Uri endpoint,
    JsonMap body, {
    Map<String, String> headers = const {},
  });
}

class CloudSyncApi {
  const CloudSyncApi({
    this.config = const CloudSyncApiConfig(),
    this.transport,
    this.deviceIdResolver,
    this.authTokenResolver,
    this.accountIdResolver,
    this.profileIdsResolver,
  });

  final CloudSyncApiConfig config;
  final CloudSyncTransport? transport;
  final Future<String> Function()? deviceIdResolver;
  final Future<String?> Function()? authTokenResolver;
  final Future<String?> Function()? accountIdResolver;
  final Future<List<int>> Function()? profileIdsResolver;

  Future<void> uploadPendingChanges() async {
    _ensureNetworkEnabled();
  }

  Future<void> pullLatestSnapshot() async {
    _ensureNetworkEnabled();
  }

  Future<SyncDeviceInfo> resolveDeviceInfo() async {
    final resolvedDeviceId = await deviceIdResolver?.call();
    return SyncDeviceInfo(
      deviceId: resolvedDeviceId ?? config.deviceId,
      platform: config.platform,
      appVersion: config.appVersion,
      schemaVersion: config.schemaVersion,
    );
  }

  Future<JsonMap> registerAccount({
    required String accountId,
    required String password,
    required List<int> profileIds,
  }) async {
    if (!config.enableNetwork) {
      throw UnsupportedError('Cloud sync network transport is disabled.');
    }
    return _transport.postJson(
      config.endpoint(config.registerPath),
      {'accountId': accountId, 'password': password, 'profileIds': profileIds},
      headers: await _requestHeaders(includeAuthorization: false),
    );
  }

  Future<JsonMap> loginAccount({
    required String accountId,
    required String password,
  }) async {
    if (!config.enableNetwork) {
      throw UnsupportedError('Cloud sync network transport is disabled.');
    }
    return _transport.postJson(
      config.endpoint(config.loginPath),
      {'accountId': accountId, 'password': password},
      headers: await _requestHeaders(includeAuthorization: false),
    );
  }

  Future<JsonMap> refreshAuthToken({
    required String accountId,
    required String refreshToken,
    required List<int> profileIds,
  }) async {
    if (!config.enableNetwork) {
      throw UnsupportedError('Cloud sync network transport is disabled.');
    }
    return _transport.postJson(
      config.endpoint(config.refreshTokenPath),
      {
        'accountId': accountId,
        'refreshToken': refreshToken,
        'profileIds': profileIds,
      },
      headers: await _requestHeaders(includeAuthorization: false),
    );
  }

  Future<SyncServerCapabilitiesDto> fetchCapabilities() async {
    _ensureNetworkEnabled();
    final json = await _transport.getJson(
      config.endpoint(config.capabilitiesPath),
      headers: await _requestHeaders(),
    );
    return SyncServerCapabilitiesDto.fromJson(json);
  }

  Future<SyncPushResponseDto> pushChanges(
    SyncUpstreamPayloadDto payload,
  ) async {
    _ensureNetworkEnabled();
    final json = await _transport.postJson(
      config.endpoint(config.pushPath),
      payload.toJson(),
      headers: {
        ...await _requestHeaders(),
        'X-GSC-Request-Id': payload.requestId,
      },
    );
    return SyncPushResponseDto.fromJson(json);
  }

  Future<SyncPullResponseDto> pullChanges(SyncPullRequestDto request) async {
    _ensureNetworkEnabled();
    final json = await _transport.postJson(
      config.endpoint(config.pullPath),
      request.toJson(),
      headers: {
        ...await _requestHeaders(),
        'X-GSC-Request-Id': request.requestId,
      },
    );
    return SyncPullResponseDto.fromJson(json);
  }

  Future<List<SyncConflictSuggestionDto>> previewConflicts(
    SyncUpstreamPayloadDto payload,
  ) async {
    _ensureNetworkEnabled();
    final json = await _transport.postJson(
      config.endpoint(config.conflictPreviewPath),
      payload.toJson(),
      headers: await _requestHeaders(),
    );
    final raw = json['conflicts'] ?? json['items'] ?? const [];
    return (raw as List? ?? const [])
        .map(
          (item) => SyncConflictSuggestionDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<JsonMap> fetchRequestLogs({
    required String requestId,
    int limit = 20,
    int offset = 0,
    int? statusCode,
    String? errorCode,
  }) async {
    if (!config.enableNetwork) {
      return {
        'items': const [],
        'notes': const ['Cloud sync network transport is disabled.'],
      };
    }
    final endpoint = config
        .endpoint(config.debugRequestLogsPath)
        .replace(
          queryParameters: {
            'requestId': requestId,
            'limit': limit.clamp(1, 100).toString(),
            'offset': offset < 0 ? '0' : offset.toString(),
            if (statusCode != null) 'statusCode': statusCode.toString(),
            if (errorCode != null && errorCode.isNotEmpty)
              'errorCode': errorCode,
          },
        );
    return _transport.getJson(endpoint, headers: await _requestHeaders());
  }

  CloudSyncTransport get _transport =>
      transport ?? const HttpCloudSyncTransport();

  void _ensureNetworkEnabled() {
    if (!config.enableNetwork) {
      throw UnsupportedError('Cloud sync network transport is disabled.');
    }
  }

  Future<Map<String, String>> _requestHeaders({
    bool includeAuthorization = true,
  }) async {
    final resolvedDeviceId = await deviceIdResolver?.call();
    final resolvedAuthToken = await authTokenResolver?.call();
    final resolvedAccountId = await accountIdResolver?.call();
    final resolvedProfileIds = await profileIdsResolver?.call();
    final authToken = resolvedAuthToken ?? config.authToken;
    final accountId = resolvedAccountId ?? config.accountId;
    return {
      if (includeAuthorization && authToken != null && authToken.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $authToken',
      'X-GSC-Device-Id': resolvedDeviceId ?? config.deviceId,
      if (accountId != null && accountId.isNotEmpty)
        'X-GSC-Account-Id': accountId,
      if (resolvedProfileIds != null && resolvedProfileIds.isNotEmpty)
        'X-GSC-Profile-Ids': resolvedProfileIds.join(','),
      'X-GSC-Platform': config.platform,
      'X-GSC-App-Version': config.appVersion,
      'X-GSC-Schema-Version': config.schemaVersion.toString(),
    };
  }
}

class HttpCloudSyncTransport implements CloudSyncTransport {
  const HttpCloudSyncTransport({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  @override
  Future<JsonMap> getJson(
    Uri endpoint, {
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(endpoint).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _applyHeaders(request, headers);
      final response = await request.close().timeout(timeout);
      return await _decodeResponse(response);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<JsonMap> postJson(
    Uri endpoint,
    JsonMap body, {
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      _applyHeaders(request, headers);
      request.write(jsonEncode(body));
      final response = await request.close().timeout(timeout);
      return await _decodeResponse(response);
    } finally {
      client.close(force: true);
    }
  }

  Future<JsonMap> _decodeResponse(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudSyncHttpException.fromResponse(response.statusCode, body);
    }
    if (body.trim().isEmpty) {
      return const {};
    }
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String> headers) {
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }
}

class CloudSyncHttpException implements Exception {
  const CloudSyncHttpException({
    required this.statusCode,
    required this.message,
    this.code,
    this.retryable = false,
  });

  factory CloudSyncHttpException.fromResponse(int statusCode, String body) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final error = Map<String, dynamic>.from(json['error'] as Map? ?? {});
      return CloudSyncHttpException(
        statusCode: statusCode,
        code: error['code'] as String?,
        message: error['message'] as String? ?? body,
        retryable: error['retryable'] as bool? ?? false,
      );
    } catch (_) {
      return CloudSyncHttpException(statusCode: statusCode, message: body);
    }
  }

  final int statusCode;
  final String? code;
  final String message;
  final bool retryable;

  bool get isAuthExpired =>
      statusCode == 401 &&
      (code == 'UNAUTHORIZED' || message.toLowerCase().contains('expired'));

  @override
  String toString() {
    final codeLabel = code == null ? '' : ' $code';
    return 'Sync HTTP $statusCode$codeLabel: $message';
  }
}
