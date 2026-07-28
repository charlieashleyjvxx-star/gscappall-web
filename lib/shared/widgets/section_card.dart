import 'package:flutter/material.dart';

import '../../app/app_design.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.large),
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactScreen = MediaQuery.sizeOf(context).width < 390;
    final resolvedPadding =
        padding == const EdgeInsets.all(AppSpacing.large) && compactScreen
            ? const EdgeInsets.all(AppSpacing.medium)
            : padding;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: resolvedPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 380;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compactHeader ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: compactHeader ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trailing == null)
                    header
                  else if (compactHeader)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing!,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: header),
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ),
                  SizedBox(
                    height:
                        compactHeader ? AppSpacing.medium : AppSpacing.large,
                  ),
                  child,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
