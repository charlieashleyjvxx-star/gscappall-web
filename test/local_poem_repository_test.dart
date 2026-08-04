import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/data/local/local_seed_loader.dart';
import 'package:gscappall/data/remote/cloud_sync_api.dart';
import 'package:gscappall/data/repositories/local_poem_repository.dart';
import 'package:gscappall/domain/poem.dart';

void main() {
  test('local seed import succeeds when network backup is disabled', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = LocalPoemRepository(
      database: database,
      seedLoader: const _TestSeedLoader(),
      remoteApi: const CloudSyncApi(),
    );

    await repository.importSeedIfNeeded(seedVersion: 'test-seed');

    expect(await database.poemCount(), 1);
    expect(await database.currentSeedVersion(), 'test-seed');
  });
}

class _TestSeedLoader extends LocalSeedLoader {
  const _TestSeedLoader();

  @override
  Future<List<Poem>> loadPoems() async => const [
    Poem(
      id: 1,
      title: 'Test Poem',
      author: 'Test Author',
      dynasty: 'Test Dynasty',
      grade: 1,
      gradeLabel: 'Grade 1',
      category: 'Test',
      content: 'First line.\nSecond line.',
      pinyin: '',
      annotation: '',
      translation: '',
      appreciation: '',
      authorIntro: '',
      extension: '',
      audioUrl: null,
      imageUrl: null,
      difficulty: 1,
    ),
  ];
}
