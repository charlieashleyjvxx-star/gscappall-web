import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_crash_reporter.dart';
import '../../core/app_environment.dart';
import '../../core/diagnostic_sanitizer.dart';
import '../../core/service_status.dart';
import '../../shared/widgets/status_chip.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key, required this.services});

  final List<ServiceDescriptor> services;

  @override
  Widget build(BuildContext context) {
    if (!AppEnvironment.diagnosticsEnabled) {
      return const Scaffold(body: Center(child: Text('诊断信息在当前版本中不可用。')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('诊断信息')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '仅用于排查问题，导出内容会自动隐藏账号、凭据、网络地址和本地路径。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...services.map(
            (service) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(service.name),
              subtitle: Text(
                service.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: StatusChip(capability: service.capability),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _copyReport(context),
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('复制脱敏诊断报告'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyReport(BuildContext context) async {
    final crashReport = await AppCrashReporter.exportSanitizedData();
    final serviceReport = services
        .map(
          (service) => <String, Object?>{
            'name': service.name,
            'state': service.capability.state.name,
            'description': service.description,
            'message': service.capability.message,
          },
        )
        .toList(growable: false);
    final report = DiagnosticSanitizer.prettyJson(<String, Object?>{
      'diagnosticsEnabled': AppEnvironment.diagnosticsEnabled,
      'services': serviceReport,
      'crashReport': crashReport,
    });
    await Clipboard.setData(ClipboardData(text: report));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制脱敏诊断报告')));
    }
  }
}
