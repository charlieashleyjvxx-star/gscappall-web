import 'package:flutter/material.dart';

import '../../core/service_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.capability});

  final ServiceCapability capability;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (capability.state) {
      ServiceState.available => (
        '可用',
        const Color(0xFFDDEFD7),
        const Color(0xFF22693E),
      ),
      ServiceState.placeholder => (
        '受限',
        const Color(0xFFF7E3BE),
        const Color(0xFF7A5008),
      ),
      ServiceState.unavailable => (
        '不可用',
        const Color(0xFFE9E5E0),
        const Color(0xFF65584E),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
