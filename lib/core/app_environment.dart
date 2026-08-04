import 'package:flutter/foundation.dart';

abstract final class AppEnvironment {
  static const diagnosticsEnabled =
      !kReleaseMode &&
      bool.fromEnvironment('GSC_DIAGNOSTICS', defaultValue: true);

  static const isProduction = kReleaseMode && !diagnosticsEnabled;
}
