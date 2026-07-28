import 'dart:math';

import '../../domain/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/user_profile.dart';
import '../local/app_database.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  @override
  Future<void> ensureDefaults() => _database.ensureDefaults();

  @override
  Future<String> loadSyncDeviceId() async {
    await ensureDefaults();
    final row = await _database.selectSingle(
      'SELECT sync_device_id FROM settings WHERE id = 1 LIMIT 1;',
    );
    final existing = row?['sync_device_id'] as String?;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final generated = _newSyncDeviceId();
    await _database.customStatement('''
      UPDATE settings
      SET sync_device_id = ${sqlString(generated)}
      WHERE id = 1;
    ''');
    return generated;
  }

  @override
  Future<AppSettings> loadSettings() async {
    final row = await _database.selectSingle(
      'SELECT * FROM settings WHERE id = 1 LIMIT 1;',
    );
    return AppSettings.fromRow(row);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('settings');
    final deviceId = currentActorDeviceId();

    await _database.customStatement('''
      UPDATE settings
      SET theme_mode = ${sqlString(settings.themeMode)},
          font_scale = ${settings.fontScale},
          speech_rate = ${settings.speechRate},
          daily_reminder_enabled = ${settings.dailyReminderEnabled ? 1 : 0},
          notifications_enabled = ${settings.notificationsEnabled ? 1 : 0},
          show_pinyin = ${settings.showPinyin ? 1 : 0},
          reminder_hour = ${settings.reminderHour},
          reminder_minute = ${settings.reminderMinute},
          auto_sync_enabled = ${settings.autoSyncEnabled ? 1 : 0},
          auto_sync_cooldown_minutes = ${settings.autoSyncCooldownMinutes},
          auto_sync_allow_mobile_network = ${settings.autoSyncAllowMobileNetwork ? 1 : 0},
          auto_sync_require_charging = ${settings.autoSyncRequireCharging ? 1 : 0},
          sync_account_id = ${sqlNullable(settings.syncAccountId.trim())},
          sync_auth_token = ${sqlNullable(settings.syncAuthToken.trim())},
          sync_refresh_token = ${sqlNullable(settings.syncRefreshToken.trim())},
          active_profile_id = ${settings.activeProfileId},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE id = 1;
    ''');
  }

  @override
  Future<UserProfile> loadProfile() async {
    final settings = await loadSettings();
    final row = await _database.selectSingle('''
      SELECT *
      FROM profile_accounts
      WHERE id = ${settings.activeProfileId}
      LIMIT 1;
    ''');
    if (row != null) {
      return UserProfile.fromRow(row);
    }

    final fallbackRow = await _database.selectSingle('''
      SELECT *
      FROM profile_accounts
      ORDER BY COALESCE(last_active_at, created_at) DESC, id ASC
      LIMIT 1;
    ''');
    return UserProfile.fromRow(fallbackRow);
  }

  @override
  Future<List<UserProfile>> loadProfiles() async {
    final rows = await _database.selectList('''
      SELECT *
      FROM profile_accounts
      ORDER BY COALESCE(last_active_at, created_at) DESC, id ASC;
    ''');
    return rows.map(UserProfile.fromRow).toList(growable: false);
  }

  @override
  Future<UserProfile> createProfile({
    required String nickname,
    String? tagline,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('profile-create');
    final deviceId = currentActorDeviceId();
    final normalizedNickname = nickname.trim();
    final normalizedTagline =
        (tagline ?? '').trim().isEmpty ? '今天也和古诗做朋友' : tagline!.trim();

    await _database.customStatement('''
      INSERT INTO profile_accounts (
        nickname,
        tagline,
        avatar_seed,
        last_active_at,
        client_mutation_id,
        last_actor_device_id,
        sync_status,
        created_at,
        updated_at
      )
      VALUES (
        ${sqlString(normalizedNickname)},
        ${sqlString(normalizedTagline)},
        ${sqlString('amber')},
        ${sqlString(nowIso)},
        ${sqlString(mutationId)},
        ${sqlString(deviceId)},
        'pending_push',
        ${sqlString(nowIso)},
        ${sqlString(nowIso)}
      );
    ''');

    final row = await _database.selectSingle('''
      SELECT *
      FROM profile_accounts
      ORDER BY id DESC
      LIMIT 1;
    ''');
    final profile = UserProfile.fromRow(row);
    await _database.ensureProfileDefaults(profile.id);
    return profile;
  }

  @override
  Future<void> renameProfile({
    required int profileId,
    required String nickname,
    String? tagline,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('profile-rename');
    final deviceId = currentActorDeviceId();

    await _database.customStatement('''
      UPDATE profile_accounts
      SET nickname = ${sqlString(nickname.trim())},
          tagline = ${sqlNullable(tagline?.trim())},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE id = $profileId;
    ''');
  }

  @override
  Future<void> switchProfile(int profileId) async {
    await _database.ensureProfileDefaults(profileId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('profile-switch');
    final deviceId = currentActorDeviceId();

    await _database.customStatement('''
      UPDATE settings
      SET active_profile_id = $profileId,
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE id = 1;
    ''');

    await _database.customStatement('''
      UPDATE profile_accounts
      SET last_active_at = ${sqlString(nowIso)},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(nowIso)}
      WHERE id = $profileId;
    ''');
  }

  @override
  Future<void> deleteProfile(int profileId) async {
    final profiles = await loadProfiles();
    if (profiles.length <= 1) {
      throw StateError('至少保留一个本地资料');
    }

    final settings = await loadSettings();
    await _database.customStatement(
      'DELETE FROM profile_accounts WHERE id = $profileId;',
    );

    if (settings.activeProfileId == profileId) {
      final fallbackProfiles = await loadProfiles();
      if (fallbackProfiles.isNotEmpty) {
        await switchProfile(fallbackProfiles.first.id);
      }
    }
  }
}

String _newSyncDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
  return 'gscappall-${hex.join()}';
}
