import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/app_constants.dart';
import '../../domain/poem.dart';

class LocalSeedLoader {
  const LocalSeedLoader();

  Future<List<Poem>> loadPoems() async {
    final raw = await rootBundle.loadString(AppConstants.seedAssetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(Poem.fromJson)
        .toList(growable: false);
  }
}

