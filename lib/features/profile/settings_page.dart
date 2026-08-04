import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/app_settings.dart';
import '../../domain/user_profile.dart';
import '../../shared/widgets/section_card.dart';
import 'profile_switch_page.dart';
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
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
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
                title: '孩子',
                child: profileAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error:
                      (error, _) => Text(
                        UserFacingErrorMapper.parentMessage(
                          error,
                          fallbackMessage: '资料加载失败，请稍后重试。',
                        ),
                      ),
                  data:
                      (profile) => Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('切换孩子'),
                            subtitle: Text(profile.nickname),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ProfileSwitchPage(),
                                  ),
                                ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('修改名字'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _renameProfile(profile),
                          ),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 18),
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
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('展开备份设置'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('自动备份'),
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
                title: '学习提醒',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('每日提醒'),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(draft.reminderLabel),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
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
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: '朗读语速',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${draft.speechRate.toStringAsFixed(2)} 倍'),
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

  Future<void> _renameProfile(UserProfile profile) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameDialog(initialNickname: profile.nickname),
    );
    if (nickname == null || nickname.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(settingsRepositoryProvider)
          .renameProfile(
            profileId: profile.id,
            nickname: nickname.trim(),
            tagline: profile.tagline,
          );
      ref.invalidate(profileProvider);
      ref.invalidate(profilesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('名字已修改')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('修改失败：${UserFacingErrorMapper.parentMessage(error)}'),
          ),
        );
      }
    }
  }
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.initialNickname});

  final String initialNickname;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNickname,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改名字'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '名字'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
