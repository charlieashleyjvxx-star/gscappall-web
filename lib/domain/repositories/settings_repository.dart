import '../app_settings.dart';
import '../user_profile.dart';

abstract class SettingsRepository {
  Future<void> ensureDefaults();
  Future<String> loadSyncDeviceId();
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<UserProfile> loadProfile();
  Future<List<UserProfile>> loadProfiles();
  Future<UserProfile> createProfile({
    required String nickname,
    String? tagline,
  });
  Future<void> renameProfile({
    required int profileId,
    required String nickname,
    String? tagline,
  });
  Future<void> switchProfile(int profileId);
  Future<void> deleteProfile(int profileId);
}
