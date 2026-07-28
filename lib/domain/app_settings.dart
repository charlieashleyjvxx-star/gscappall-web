class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.fontScale = 1.0,
    this.speechRate = 1.0,
    this.dailyReminderEnabled = true,
    this.notificationsEnabled = true,
    this.showPinyin = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.activeProfileId = 1,
    this.seedVersion = '',
    this.autoSyncEnabled = false,
    this.autoSyncCooldownMinutes = 5,
    this.autoSyncAllowMobileNetwork = true,
    this.autoSyncRequireCharging = false,
    this.syncAccountId = '',
    this.syncAuthToken = '',
    this.syncRefreshToken = '',
  });

  factory AppSettings.fromRow(Map<String, Object?>? row) {
    if (row == null) {
      return const AppSettings();
    }

    return AppSettings(
      themeMode: row['theme_mode'] as String? ?? 'system',
      fontScale: (row['font_scale'] as num?)?.toDouble() ?? 1.0,
      speechRate: (row['speech_rate'] as num?)?.toDouble() ?? 1.0,
      dailyReminderEnabled: ((row['daily_reminder_enabled'] as int?) ?? 1) == 1,
      notificationsEnabled: ((row['notifications_enabled'] as int?) ?? 1) == 1,
      showPinyin: ((row['show_pinyin'] as int?) ?? 1) == 1,
      reminderHour: (row['reminder_hour'] as int?) ?? 20,
      reminderMinute: (row['reminder_minute'] as int?) ?? 0,
      activeProfileId: (row['active_profile_id'] as int?) ?? 1,
      seedVersion: row['seed_version'] as String? ?? '',
      autoSyncEnabled: ((row['auto_sync_enabled'] as int?) ?? 0) == 1,
      autoSyncCooldownMinutes: (row['auto_sync_cooldown_minutes'] as int?) ?? 5,
      autoSyncAllowMobileNetwork:
          ((row['auto_sync_allow_mobile_network'] as int?) ?? 1) == 1,
      autoSyncRequireCharging:
          ((row['auto_sync_require_charging'] as int?) ?? 0) == 1,
      syncAccountId: row['sync_account_id'] as String? ?? '',
      syncAuthToken: row['sync_auth_token'] as String? ?? '',
      syncRefreshToken: row['sync_refresh_token'] as String? ?? '',
    );
  }

  final String themeMode;
  final double fontScale;
  final double speechRate;
  final bool dailyReminderEnabled;
  final bool notificationsEnabled;
  final bool showPinyin;
  final int reminderHour;
  final int reminderMinute;
  final int activeProfileId;
  final String seedVersion;
  final bool autoSyncEnabled;
  final int autoSyncCooldownMinutes;
  final bool autoSyncAllowMobileNetwork;
  final bool autoSyncRequireCharging;
  final String syncAccountId;
  final String syncAuthToken;
  final String syncRefreshToken;

  String get reminderLabel =>
      '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}';

  AppSettings copyWith({
    String? themeMode,
    double? fontScale,
    double? speechRate,
    bool? dailyReminderEnabled,
    bool? notificationsEnabled,
    bool? showPinyin,
    int? reminderHour,
    int? reminderMinute,
    int? activeProfileId,
    String? seedVersion,
    bool? autoSyncEnabled,
    int? autoSyncCooldownMinutes,
    bool? autoSyncAllowMobileNetwork,
    bool? autoSyncRequireCharging,
    String? syncAccountId,
    String? syncAuthToken,
    String? syncRefreshToken,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      speechRate: speechRate ?? this.speechRate,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      showPinyin: showPinyin ?? this.showPinyin,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      seedVersion: seedVersion ?? this.seedVersion,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      autoSyncCooldownMinutes:
          autoSyncCooldownMinutes ?? this.autoSyncCooldownMinutes,
      autoSyncAllowMobileNetwork:
          autoSyncAllowMobileNetwork ?? this.autoSyncAllowMobileNetwork,
      autoSyncRequireCharging:
          autoSyncRequireCharging ?? this.autoSyncRequireCharging,
      syncAccountId: syncAccountId ?? this.syncAccountId,
      syncAuthToken: syncAuthToken ?? this.syncAuthToken,
      syncRefreshToken: syncRefreshToken ?? this.syncRefreshToken,
    );
  }
}
