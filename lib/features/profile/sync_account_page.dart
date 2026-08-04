import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../core/user_facing_error.dart';
import '../../data/remote/cloud_sync_api.dart';
import '../../domain/app_settings.dart';
import '../../domain/sync/sync_models.dart';
import '../../shared/widgets/section_card.dart';

enum _AuthMode { login, register }

class SyncAccountPage extends ConsumerStatefulWidget {
  const SyncAccountPage({super.key});

  @override
  ConsumerState<SyncAccountPage> createState() => _SyncAccountPageState();
}

class _SyncAccountPageState extends ConsumerState<SyncAccountPage> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _initialized = false;
  bool _submitting = false;
  _AuthMode _mode = _AuthMode.login;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('备份账号')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Text(
                UserFacingErrorMapper.parentMessage(
                  error,
                  fallbackMessage: '账号状态加载失败，请稍后重试。',
                ),
              ),
            ),
        data: (settings) {
          if (!_initialized) {
            _initialized = true;
            _accountController.text = settings.syncAccountId;
          }
          final hasSession = settings.syncAuthToken.trim().isNotEmpty;
          final hasRefreshToken = settings.syncRefreshToken.trim().isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionCard(
                title: hasSession ? '备份账号已登录' : '登录备份账号',
                subtitle:
                    hasSession
                        ? '当前设备会使用已保存的登录凭据访问备份服务，过期后会自动续期。'
                        : '使用账号和密码登录；没有账号时可在这里注册一个备份账号。',
                child: Column(
                  children: [
                    SegmentedButton<_AuthMode>(
                      segments: const [
                        ButtonSegment(
                          value: _AuthMode.login,
                          label: Text('登录'),
                          icon: Icon(Icons.login_rounded),
                        ),
                        ButtonSegment(
                          value: _AuthMode.register,
                          label: Text('注册'),
                          icon: Icon(Icons.person_add_alt_1_rounded),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged:
                          _submitting
                              ? null
                              : (value) => setState(() => _mode = value.first),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _accountController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        hintText: '例如 manual-account',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _mode == _AuthMode.login ? '密码' : '新密码',
                        hintText: '至少 6 位',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                _submitting
                                    ? null
                                    : () => _submit(context, settings),
                            icon:
                                _submitting
                                    ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(
                                      _mode == _AuthMode.login
                                          ? Icons.login_rounded
                                          : Icons.person_add_alt_1_rounded,
                                    ),
                            label: Text(
                              _mode == _AuthMode.login ? '登录' : '注册并登录',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed:
                              hasSession && !_submitting
                                  ? () => _logout(context, settings)
                                  : null,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('退出'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: '当前状态',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLine(
                      label: '账号',
                      value:
                          settings.syncAccountId.trim().isEmpty
                              ? '未登录'
                              : settings.syncAccountId.trim(),
                    ),
                    const SizedBox(height: 8),
                    _StatusLine(
                      label: '登录凭据',
                      value: hasSession ? '已保存' : '未保存',
                    ),
                    const SizedBox(height: 8),
                    _StatusLine(
                      label: '自动刷新',
                      value: hasRefreshToken ? '已启用' : '未启用',
                    ),
                    const SizedBox(height: 8),
                    const Text('登录凭据会保存在本机，用于账号过期后的自动续期；退出登录会清空本机凭据并关闭自动备份。'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, AppSettings settings) async {
    final accountId = _accountController.text.trim();
    final password = _passwordController.text.trim();
    if (accountId.isEmpty || password.isEmpty) {
      _showMessage(context, '请填写账号和密码');
      return;
    }

    setState(() => _submitting = true);
    try {
      final profiles =
          await ref.read(settingsRepositoryProvider).loadProfiles();
      final api = ref.read(cloudSyncApiProvider);
      final result =
          _mode == _AuthMode.login
              ? await api.loginAccount(accountId: accountId, password: password)
              : await api.registerAccount(
                accountId: accountId,
                password: password,
                profileIds: profiles.map((profile) => profile.id).toList(),
              );
      if (!context.mounted) return;
      await _saveSession(context, settings, accountId, result);
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, _friendlyAuthError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _saveSession(
    BuildContext context,
    AppSettings settings,
    String fallbackAccountId,
    Map<String, dynamic> result,
  ) async {
    final token = result['accessToken'] as String?;
    final refreshToken = result['refreshToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('账号服务没有返回登录凭据');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('账号服务没有返回自动续期凭据');
    }
    final next = settings.copyWith(
      syncAccountId: result['accountId'] as String? ?? fallbackAccountId,
      syncAuthToken: token,
      syncRefreshToken: refreshToken,
      autoSyncEnabled: true,
    );
    await ref.read(settingsRepositoryProvider).saveSettings(next);
    ref.invalidate(settingsProvider);
    ref.invalidate(syncStatusProvider);
    if (context.mounted) {
      _passwordController.clear();
      _showMessage(context, '备份账号已登录，正在执行首次备份。');
    }
    final report = await ref
        .read(syncStatusProvider.notifier)
        .synchronize(trigger: SyncRunTrigger.loginInitial);
    ref.invalidate(syncRunLogPageProvider);
    if (context.mounted) {
      _showMessage(
        context,
        report == null ? '备份账号已登录，首次备份未完成。' : '备份账号已登录，首次备份已完成。',
      );
    }
  }

  Future<void> _logout(BuildContext context, AppSettings settings) async {
    final next = settings.copyWith(
      syncAccountId: '',
      syncAuthToken: '',
      syncRefreshToken: '',
      autoSyncEnabled: false,
    );
    await ref.read(settingsRepositoryProvider).saveSettings(next);
    ref.invalidate(settingsProvider);
    ref.invalidate(syncStatusProvider);
    if (context.mounted) {
      _accountController.clear();
      _passwordController.clear();
      _showMessage(context, '已退出备份账号');
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is CloudSyncHttpException) {
      switch (error.code) {
        case 'ACCOUNT_EXISTS':
          return '账号已存在，请切换到“登录”。';
        case 'ACCOUNT_NOT_FOUND':
          return '账号不存在，请先注册。';
        case 'INVALID_CREDENTIALS':
          return '账号或密码不正确。';
        case 'WEAK_PASSWORD':
          return '密码至少需要 6 位。';
        case 'INVALID_REFRESH_TOKEN':
        case 'UNAUTHORIZED':
          return '登录已失效，请重新登录。';
        default:
          return '账号服务暂时不可用，请稍后重试。';
      }
    }
    return UserFacingErrorMapper.message(error, fallbackMessage: '登录失败，请稍后再试。');
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
