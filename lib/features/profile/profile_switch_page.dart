import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../domain/user_profile.dart';
import '../../shared/widgets/empty_state.dart';
import 'profile_support.dart';

class ProfileSwitchPage extends ConsumerStatefulWidget {
  const ProfileSwitchPage({super.key});

  @override
  ConsumerState<ProfileSwitchPage> createState() => _ProfileSwitchPageState();
}

class _ProfileSwitchPageState extends ConsumerState<ProfileSwitchPage> {
  @override
  Widget build(BuildContext context) {
    final activeProfileAsync = ref.watch(profileProvider);
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('切换本地资料')),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.parentMessage(
                  error,
                  fallbackMessage: '本地资料加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (profiles) {
          if (profiles.isEmpty) {
            return EmptyState(
              title: '还没有本地资料',
              icon: Icons.group_outlined,
              action: FilledButton(
                onPressed: _createProfile,
                child: const Text('新建资料'),
              ),
            );
          }

          final activeProfile = activeProfileAsync.asData?.value;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ...profiles.map(
                (profile) => _ProfileTile(
                  profile: profile,
                  isActive: activeProfile?.id == profile.id,
                  canDelete: profiles.length > 1,
                  onSwitch: () => _switchProfile(profile.id),
                  onRename: () => _renameProfile(profile),
                  onDelete: () => _deleteProfile(profile.id),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _createProfile,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('新建本地资料'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createProfile() async {
    final nickname = await _showProfileEditor(
      title: '新建本地资料',
      initialNickname: '',
    );
    if (nickname == null || nickname.trim().isEmpty) {
      return;
    }

    try {
      final profile = await ref
          .read(settingsRepositoryProvider)
          .createProfile(nickname: nickname.trim());
      await _switchProfile(profile.id);
    } catch (error) {
      _showError('新建资料失败：${_describeError(error)}');
    }
  }

  Future<void> _renameProfile(UserProfile profile) async {
    final nickname = await _showProfileEditor(
      title: '修改资料名称',
      initialNickname: profile.nickname,
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
      _scheduleProfileScopedRefresh();
    } catch (error) {
      _showError('修改资料失败：${_describeError(error)}');
    }
  }

  Future<void> _deleteProfile(int profileId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除本地资料'),
          content: const Text('会删除这张本地资料卡，但当前学习数据仍保留在本机。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(settingsRepositoryProvider).deleteProfile(profileId);
      _scheduleProfileScopedRefresh();
    } catch (error) {
      _showError('删除资料失败：${_describeError(error)}');
    }
  }

  Future<void> _switchProfile(int profileId) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await ref.read(settingsRepositoryProvider).switchProfile(profileId);
      if (!mounted) {
        invalidateProfileScopedProviderContainer(container);
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        invalidateProfileScopedProviderContainer(container);
      });
    } catch (error) {
      _showError('切换资料失败：${_describeError(error)}');
    }
  }

  Future<String?> _showProfileEditor({
    required String title,
    required String initialNickname,
  }) {
    return showDialog<String>(
      context: context,
      builder:
          (_) => _ProfileEditorDialog(
            title: title,
            initialNickname: initialNickname,
          ),
    );
  }

  void _scheduleProfileScopedRefresh() {
    final container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      invalidateProfileScopedProviderContainer(container);
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _describeError(Object error) {
    return UserFacingErrorMapper.parentMessage(error);
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({
    required this.title,
    required this.initialNickname,
  });

  final String title;
  final String initialNickname;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '昵称',
          hintText: '例如：晨晨、小书童',
        ),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.canDelete,
    required this.onSwitch,
    required this.onRename,
    required this.onDelete,
  });

  final UserProfile profile;
  final bool isActive;
  final bool canDelete;
  final VoidCallback onSwitch;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: profileAvatarColor(profile),
              child: Text(
                profile.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6E4BE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '当前',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<_ProfileAction>(
              onSelected: (action) {
                switch (action) {
                  case _ProfileAction.switchProfile:
                    onSwitch();
                    break;
                  case _ProfileAction.rename:
                    onRename();
                    break;
                  case _ProfileAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) {
                return [
                  if (!isActive)
                    const PopupMenuItem(
                      value: _ProfileAction.switchProfile,
                      child: Text('切换到这里'),
                    ),
                  const PopupMenuItem(
                    value: _ProfileAction.rename,
                    child: Text('修改昵称'),
                  ),
                  if (canDelete)
                    const PopupMenuItem(
                      value: _ProfileAction.delete,
                      child: Text('删除资料'),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _ProfileAction { switchProfile, rename, delete }
