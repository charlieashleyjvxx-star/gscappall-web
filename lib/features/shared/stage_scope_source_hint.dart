import 'dart:async';

import 'package:flutter/material.dart';

String? stageScopeSourceLabel(String? source) {
  return switch (source) {
    'growth-report' => '已帮你找到这一关',
    'practice-report' => '已回到这一关',
    'wrong-question' => '先练这一关',
    'learning-record' => '继续这一关',
    'chapter-detail' => '继续看这一关',
    'sync-log' => '已找到相关进度',
    'notification' => '继续练习',
    _ => null,
  };
}

String stageScopeSourceMessage({
  required String stageLabel,
  String? source,
  String targetLabel = '地图',
}) {
  return switch (source) {
    'sync-log' => '已找到 $stageLabel，相关进度会在$targetLabel中短暂高亮。',
    'notification' => '通知已定位到 $stageLabel，可以从这里继续练习。',
    'growth-report' => '已帮你找到 $stageLabel，可以从这里继续练。',
    'practice-report' => '已回到 $stageLabel，可以继续看本关进度。',
    'wrong-question' => '已找到 $stageLabel，先把这一关再练一练。',
    'learning-record' => '已找到 $stageLabel，可以继续这一关。',
    'chapter-detail' => '已找到 $stageLabel，可以继续看本关进度。',
    _ => '已找到 $stageLabel，目标关卡会短暂高亮。',
  };
}

class _StageScopeSourceVisualSpec {
  const _StageScopeSourceVisualSpec({
    required this.icon,
    required this.background,
    required this.expandedBackground,
    required this.foreground,
    required this.border,
  });

  factory _StageScopeSourceVisualSpec.fromSource(String? source) {
    return switch (source) {
      'growth-report' => const _StageScopeSourceVisualSpec(
        icon: Icons.insights_rounded,
        background: Color(0xFFFFF0C7),
        expandedBackground: Color(0xFFFFF5DD),
        foreground: Color(0xFF7A4B00),
        border: Color(0xFFE0A11F),
      ),
      'sync-log' => const _StageScopeSourceVisualSpec(
        icon: Icons.sync_alt_rounded,
        background: Color(0xFFE7F0FF),
        expandedBackground: Color(0xFFF0F6FF),
        foreground: Color(0xFF1E4F8F),
        border: Color(0xFF4C7FC4),
      ),
      'notification' => const _StageScopeSourceVisualSpec(
        icon: Icons.notifications_active_rounded,
        background: Color(0xFFE3F6EA),
        expandedBackground: Color(0xFFF0FAF3),
        foreground: Color(0xFF17633A),
        border: Color(0xFF5EAA75),
      ),
      'practice-report' => const _StageScopeSourceVisualSpec(
        icon: Icons.assignment_rounded,
        background: Color(0xFFEDE7DD),
        expandedBackground: Color(0xFFF8F1E6),
        foreground: Color(0xFF5A4A37),
        border: Color(0xFFB78D54),
      ),
      'wrong-question' => const _StageScopeSourceVisualSpec(
        icon: Icons.rule_folder_rounded,
        background: Color(0xFFFFE4DC),
        expandedBackground: Color(0xFFFFF1EC),
        foreground: Color(0xFF8A2B13),
        border: Color(0xFFD06C4A),
      ),
      'learning-record' => const _StageScopeSourceVisualSpec(
        icon: Icons.history_edu_rounded,
        background: Color(0xFFE9F3E0),
        expandedBackground: Color(0xFFF4FAEF),
        foreground: Color(0xFF315E1E),
        border: Color(0xFF7EAA58),
      ),
      'chapter-detail' => const _StageScopeSourceVisualSpec(
        icon: Icons.route_rounded,
        background: Color(0xFFFFECD7),
        expandedBackground: Color(0xFFFFF7EC),
        foreground: Color(0xFF8A4C12),
        border: Color(0xFFD19A4E),
      ),
      _ => const _StageScopeSourceVisualSpec(
        icon: Icons.assistant_navigation,
        background: Color(0xFFEAF1FF),
        expandedBackground: Color(0xFFFFF4D9),
        foreground: Color(0xFF2F4A6B),
        border: Color(0xFF8CA6C8),
      ),
    };
  }

  final IconData icon;
  final Color background;
  final Color expandedBackground;
  final Color foreground;
  final Color border;
}

@visibleForTesting
IconData debugStageScopeSourceIcon(String? source) {
  return _StageScopeSourceVisualSpec.fromSource(source).icon;
}

@visibleForTesting
Color debugStageScopeSourceBackground(String? source) {
  return _StageScopeSourceVisualSpec.fromSource(source).background;
}

@visibleForTesting
Color debugStageScopeSourceForeground(String? source) {
  return _StageScopeSourceVisualSpec.fromSource(source).foreground;
}

class StageScopeSourceHint extends StatelessWidget {
  const StageScopeSourceHint({super.key, required this.source}) : label = null;

  const StageScopeSourceHint.label(String this.label, {super.key})
    : source = null;

  final String? source;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label ?? stageScopeSourceLabel(source);
    if (resolvedLabel == null) {
      return const SizedBox.shrink();
    }
    final spec = _StageScopeSourceVisualSpec.fromSource(source);
    return Chip(
      avatar: Icon(spec.icon, size: 16, color: spec.foreground),
      label: Text(resolvedLabel),
      labelStyle: TextStyle(
        color: spec.foreground,
        fontWeight: FontWeight.w800,
      ),
      backgroundColor: spec.background,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class StageScopeFloatingBanner extends StatefulWidget {
  const StageScopeFloatingBanner({
    super.key,
    required this.stageLabel,
    this.source,
    this.sourceLabel,
    this.message,
    this.autoCollapseAfter = const Duration(seconds: 4),
  });

  final String stageLabel;
  final String? source;
  final String? sourceLabel;
  final String? message;
  final Duration? autoCollapseAfter;

  @override
  State<StageScopeFloatingBanner> createState() =>
      _StageScopeFloatingBannerState();
}

class _StageScopeFloatingBannerState extends State<StageScopeFloatingBanner> {
  Timer? _collapseTimer;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scheduleCollapse();
  }

  @override
  void didUpdateWidget(covariant StageScopeFloatingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stageLabel != widget.stageLabel ||
        oldWidget.source != widget.source ||
        oldWidget.sourceLabel != widget.sourceLabel ||
        oldWidget.message != widget.message) {
      _collapsed = false;
      _scheduleCollapse();
    }
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    final delay = widget.autoCollapseAfter;
    if (delay == null) {
      return;
    }
    _collapseTimer = Timer(delay, () {
      if (mounted) {
        setState(() => _collapsed = true);
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSource =
        widget.sourceLabel ?? stageScopeSourceLabel(widget.source);
    final spec = _StageScopeSourceVisualSpec.fromSource(widget.source);
    final fullMessage =
        widget.message ??
        '${resolvedSource ?? '地图回跳'} · ${stageScopeSourceMessage(stageLabel: widget.stageLabel, source: widget.source)}';
    final collapsedMessage =
        '${resolvedSource ?? '已找到'} · ${widget.stageLabel}';
    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder:
            (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
        child: Container(
          key: ValueKey(_collapsed ? 'collapsed' : 'expanded'),
          padding: EdgeInsets.symmetric(
            horizontal: _collapsed ? 12 : 14,
            vertical: _collapsed ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: _collapsed ? spec.background : spec.expandedBackground,
            borderRadius: BorderRadius.circular(_collapsed ? 999 : 18),
            border: Border.all(color: spec.border.withValues(alpha: 0.55)),
            boxShadow:
                _collapsed
                    ? null
                    : [
                      BoxShadow(
                        color: spec.border.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
          ),
          child: Row(
            mainAxisSize: _collapsed ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                _collapsed ? spec.icon : Icons.my_location_rounded,
                size: _collapsed ? 16 : 22,
                color: spec.foreground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _collapsed ? collapsedMessage : fullMessage,
                  maxLines: _collapsed ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: spec.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
