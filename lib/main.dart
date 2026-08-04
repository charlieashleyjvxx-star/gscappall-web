import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/app_crash_reporter.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppCrashReporter.initialize();
      FlutterError.onError = (details) {
        if (!kReleaseMode) {
          FlutterError.presentError(details);
        }
        unawaited(
          AppCrashReporter.record(
            details.exception,
            details.stack ?? StackTrace.current,
            context: details.context?.toDescription() ?? 'flutter-framework',
          ),
        );
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(
          AppCrashReporter.record(
            error,
            stackTrace,
            context: 'platform-dispatcher',
          ),
        );
        return true;
      };
      runApp(const ProviderScope(child: GscApp()));
    },
    (error, stackTrace) {
      unawaited(
        AppCrashReporter.record(error, stackTrace, context: 'root-zone'),
      );
    },
  );
}
