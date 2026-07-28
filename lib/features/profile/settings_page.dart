import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/app_settings.dart';
import '../../shared/widgets/section_card.dart';
import 'sync_account_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  AppSettings? _draft;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('本地设置')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.parentMessage(
                  error,
                  fallbackMessage: '设置加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (settings) {
          _draft ??= settings;
          final draft = _draft!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionCard(
                title: '外观',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'system', label: Text('跟随系统')),
                        ButtonSegment(value: 'light', label: Text('浅色')),
                        ButtonSegment(value: 'dark', label: Text('深色')),
                      ],
                      selected: {draft.themeMode},
                      onSelectionChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(themeMode: value.first);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('字体缩放 ${draft.fontScale.toStringAsFixed(2)}'),
                    Slider(
                      min: 0.9,
                      max: 1.25,
                      value: draft.fontScale,
                      onChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(fontScale: value);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: '学习显示',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示拼音'),
                  subtitle: const Text('关闭后仍保留古诗原文居中排版'),
                  value: draft.showPinyin,
                  onChanged: (value) {
                    setState(() {
                      _draft = draft.copyWith(showPinyin: value);
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: '备份与多设备',
                subtitle: '家长需要换设备或保护学习记录时再设置。',
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('展开备份设置'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('自动备份'),
                      subtitle: Text(
                        '打开后会在合适的时候备份学习数据，间隔 ${draft.autoSyncCooldownMinutes} 分钟',
                      ),
                      value: draft.autoSyncEnabled,
                      onChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(autoSyncEnabled: value);
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('备份间隔'),
                      subtitle: Slider(
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '${draft.autoSyncCooldownMinutes} 分钟',
                        value:
                            draft.autoSyncCooldownMinutes
                                .clamp(1, 30)
                                .toDouble(),
                        onChanged: (value) {
                          setState(() {
                            _draft = draft.copyWith(
                              autoSyncCooldownMinutes: value.round(),
                            );
                          });
                        },
                      ),
                      trailing: Text('${draft.autoSyncCooldownMinutes} 分钟'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('允许移动网络备份'),
                      subtitle: const Text('关闭后只在 Wi-Fi 环境下自动备份'),
                      value: draft.autoSyncAllowMobileNetwork,
                      onChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(
                            autoSyncAllowMobileNetwork: value,
                          );
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('仅充电时自动备份'),
                      subtitle: const Text('数据较多时可以减少电量消耗'),
                      value: draft.autoSyncRequireCharging,
                      onChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(
                            autoSyncRequireCharging: value,
                          );
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('备份账号'),
                      subtitle: Text(
                        draft.syncAccountId.trim().isEmpty
                            ? '未登录，当前只保留本地数据'
                            : '已登录：${draft.syncAccountId.trim()}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SyncAccountPage(),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: '提醒与语速',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('每日提醒'),
                      subtitle: Text('当前时间 ${draft.reminderLabel}'),
                      value: draft.dailyReminderEnabled,
                      onChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(dailyReminderEnabled: value);
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('提醒时间'),
                      subtitle: Text(draft.reminderLabel),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: draft.reminderHour,
                            minute: draft.reminderMinute,
                          ),
                        );
                        if (picked == null) return;
                        setState(() {
                          _draft = draft.copyWith(
                            reminderHour: picked.hour,
                            reminderMinute: picked.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('朗读语速 ${draft.speechRate.toStringAsFixed(2)}'),
                    Slider(
                      min: 0.75,
                      max: 1.4,
                      value: draft.speechRate,
                      onChanged: (value) {
                        setState(() {
                          _draft = draft.copyWith(speechRate: value);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  final settingsToSave = _draft!;
                  await ref
                      .read(settingsRepositoryProvider)
                      .saveSettings(settingsToSave);
                  await ref
                      .read(notificationServiceProvider)
                      .syncWithSettings(settingsToSave);
                  ref.invalidate(settingsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('设置已保存')));
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存设置'),
              ),
            ],
          );
        },
      ),
    );
  }
}
