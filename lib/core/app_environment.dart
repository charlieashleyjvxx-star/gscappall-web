import 'package:flutter/foundation.dart';

abstract final class AppEnvironment {
  static const diagnosticsEnabled = bool.fromEnvironment(
    'GSC_DIAGNOSTICS',
    defaultValue: !kReleaseMode,
  );

  static const isProduction = kReleaseMode && !diagnosticsEnabled;
}
