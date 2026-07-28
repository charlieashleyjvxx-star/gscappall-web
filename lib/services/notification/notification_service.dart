// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_logger.dart';
import '../../core/service_status.dart';
import '../../domain/app_settings.dart';

abstract class NotificationService {
  ServiceCapability get capability;

  Future<void> initialize();
  Future<void> syncWithSettings(AppSettings settings);
}

class StubNotificationService implements NotificationService {
  const StubNotificationService();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 52001;
  static const int _windowsReminderBaseId = 52100;
  static const int _windowsReminderWindow = 14;

  static bool _initialized = false;
  static bool _timeZonesInitialized = false;
  static String? _lastStatusMessage;
  static void Function(String? payload)? _notificationResponseHandler;

  static void setNotificationResponseHandler(
    void Function(String? payload)? handler,
  ) {
    _notificationResponseHandler = handler;
  }

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

  static bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  ServiceCapability get capability {
    if (!_isSupportedPlatform) {
      return const ServiceCapability(
        state: ServiceState.unavailable,
        message: '当前平台不支持本地通知能力。',
      );
    }

    if (_isWindows) {
      return ServiceCapability(
        state: ServiceState.available,
        message:
            _lastStatusMessage ??
            '通知已接入。Windows 可初始化并排入未来 14 天提醒，但插件不支持系统级无限重复提醒。',
      );
    }

    return ServiceCapability(
      state: ServiceState.available,
      message: _lastStatusMessage ?? '本地通知已接入，可按设置同步每日提醒。',
    );
  }

  @override
  Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) {
      return;
    }

    _ensureTimeZones();

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );
      const windows = WindowsInitializationSettings(
        appName: 'GSCAPPALL',
        appUserModelId: 'GSCAPPALL.GSCAPPALL.App',
        guid: '4f7f9b14-26fa-4a0f-b829-0f9f4e5f7f01',
      );

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
          windows: windows,
        ),
        onDidReceiveNotificationResponse:
            (response) => _notificationResponseHandler?.call(response.payload),
      );

      if (_isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission();
      } else if (_isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }

      _initialized = true;
      _lastStatusMessage =
          _isWindows ? '通知初始化完成。Windows 采用未来 14 天提醒排程。' : '通知初始化完成，可同步每日提醒。';
    } catch (error) {
      _lastStatusMessage = '通知初始化失败，请稍后重试。';
      AppLogger.event(
        'initialization_failed',
        feature: 'notification',
        level: AppLogLevel.error,
      );
      rethrow;
    }
  }

  @override
  Future<void> syncWithSettings(AppSettings settings) async {
    if (!_isSupportedPlatform) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    await _cancelScheduledReminders();

    if (!settings.notificationsEnabled || !settings.dailyReminderEnabled) {
      _lastStatusMessage = '每日提醒已关闭，本地通知排程已清除。';
      return;
    }

    try {
      final now = DateTime.now();
      final nextReminder = _nextReminderDateTime(
        now: now,
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );

      if (_isWindows) {
        await _scheduleWindowsReminderSeries(
          startAt: nextReminder,
          settings: settings,
        );
        _lastStatusMessage =
            'Windows 已排入未来 $_windowsReminderWindow 天的每日提醒，超出范围后需应用再次同步。';
        return;
      }

      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: '每日一诗提醒',
        body: '今天也来学一首古诗词吧。',
        scheduledDate: tz.TZDateTime.from(nextReminder, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_poem',
      );

      _lastStatusMessage =
          '每日提醒已同步到 ${settings.reminderLabel}。Android / iOS 将按本地时间重复提醒。';
    } catch (error) {
      if (_isAndroid) {
        await _scheduleInexactReminder(settings);
        _lastStatusMessage = '已回退为 Android 非精确提醒，时间可能略有偏差，但每日提醒仍可用。';
        return;
      }

      _lastStatusMessage = '每日提醒同步失败，请稍后重试。';
      AppLogger.event(
        'schedule_sync_failed',
        feature: 'notification',
        level: AppLogLevel.error,
      );
      rethrow;
    }
  }

  static NotificationDetails get _notificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_poem_reminder',
          'Daily Poem Reminder',
          channelDescription: '古诗词学习每日提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        windows: WindowsNotificationDetails(),
      );

  static void _ensureTimeZones() {
    if (_timeZonesInitialized) {
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(_resolveTimeZoneLocation(DateTime.now()));
    _timeZonesInitialized = true;
  }

  static Future<void> _cancelScheduledReminders() async {
    await _plugin.cancel(id: _dailyReminderId);
    for (var index = 0; index < _windowsReminderWindow; index++) {
      await _plugin.cancel(id: _windowsReminderBaseId + index);
    }
  }

  static DateTime _nextReminderDateTime({
    required DateTime now,
    required int hour,
    required int minute,
  }) {
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> _scheduleWindowsReminderSeries({
    required DateTime startAt,
    required AppSettings settings,
  }) async {
    for (var index = 0; index < _windowsReminderWindow; index++) {
      final scheduled = startAt.add(Duration(days: index));
      await _plugin.zonedSchedule(
        id: _windowsReminderBaseId + index,
        title: '每日一诗提醒',
        body: '今天也来学一首古诗词吧。',
        scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'daily_poem_${settings.reminderLabel}_$index',
      );
    }
  }

  static Future<void> _scheduleInexactReminder(AppSettings settings) async {
    final nextReminder = _nextReminderDateTime(
      now: DateTime.now(),
      hour: settings.reminderHour,
      minute: settings.reminderMinute,
    );

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: '每日一诗提醒',
      body: '今天也来学一首古诗词吧。',
      scheduledDate: tz.TZDateTime.from(nextReminder, tz.local),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_poem',
    );
  }

  static tz.Location _resolveTimeZoneLocation(DateTime now) {
    final candidates = <String>[
      if (now.timeZoneName.contains('/')) now.timeZoneName,
      ..._offsetLocationCandidates(now.timeZoneOffset),
      'UTC',
    ];

    for (final candidate in candidates) {
      try {
        return tz.getLocation(candidate);
      } catch (_) {
        continue;
      }
    }

    return tz.UTC;
  }

  static List<String> _offsetLocationCandidates(Duration offset) {
    final candidates = <String>[];

    if (offset.inMinutes == 0) {
      candidates.add('Etc/UTC');
    } else if (offset.inMinutes % 60 == 0) {
      final hours = offset.inHours;
      final sign = hours > 0 ? '-' : '+';
      candidates.add('Etc/GMT$sign${hours.abs()}');
    }

    switch (offset.inMinutes) {
      case 480:
        candidates.add('Asia/Shanghai');
      case 330:
        candidates.add('Asia/Kolkata');
      case 540:
        candidates.add('Asia/Tokyo');
      case 570:
        candidates.add('Australia/Darwin');
      case 600:
        candidates.add('Australia/Brisbane');
      case -300:
        candidates.add('America/Bogota');
      case -240:
        candidates.add('America/La_Paz');
    }

    return candidates.toSet().toList(growable: false);
  }
}
