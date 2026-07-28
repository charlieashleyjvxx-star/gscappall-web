import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tools/query_sqlite.dart <db-path> <sql>');
    exitCode = 64;
    return;
  }

  final database = sqlite3.open(args[0]);
  try {
    final rows = database.select(args[1]);
    if (rows.isEmpty) {
      stdout.writeln('0');
      return;
    }
    stdout.writeln(rows.first.values.first ?? '0');
  } finally {
    database.close();
  }
}
