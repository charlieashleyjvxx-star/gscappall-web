import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tools/exec_sqlite.dart <db-path> <sql>');
    exitCode = 64;
    return;
  }

  final sqlArg = args[1];
  final sql =
      sqlArg.startsWith('@')
          ? File(sqlArg.substring(1)).readAsStringSync()
          : sqlArg;

  final database = sqlite3.open(args[0]);
  try {
    database.execute(sql);
  } finally {
    database.close();
  }
}
