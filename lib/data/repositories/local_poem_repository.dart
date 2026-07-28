import '../../core/app_formatters.dart';
import '../../domain/learning_models.dart';
import '../../domain/poem.dart';
import '../../domain/repositories/poem_repository.dart';
import '../local/app_database.dart';
import '../local/local_seed_loader.dart';
import '../remote/cloud_sync_api.dart';

class LocalPoemRepository implements PoemRepository {
  LocalPoemRepository({
    required AppDatabase database,
    required LocalSeedLoader seedLoader,
    required CloudSyncApi remoteApi,
  }) : _database = database,
       _seedLoader = seedLoader,
       _remoteApi = remoteApi;

  final AppDatabase _database;
  final LocalSeedLoader _seedLoader;
  final CloudSyncApi _remoteApi;

  @override
  Future<void> importSeedIfNeeded({required String seedVersion}) async {
    await _database.ensureDefaults();
    final currentCount = await _database.poemCount();
    final currentVersion = await _database.currentSeedVersion();
    if (currentCount > 0 && currentVersion == seedVersion) {
      return;
    }

    final poems = await _seedLoader.loadPoems();
    await _database.replaceSeed(poems: poems, seedVersion: seedVersion);

    await _remoteApi.uploadPendingChanges();
  }

  @override
  Future<List<Poem>> fetchPoems({PoemQuery query = const PoemQuery()}) async {
    final conditions = <String>['deleted_at IS NULL'];
    final trimmedSearch = query.search.trim();
    if (trimmedSearch.isNotEmpty) {
      final safeSearch = trimmedSearch
          .replaceAll("'", "''")
          .replaceAll('%', '');
      conditions.add(
        "(title LIKE '%$safeSearch%' OR author LIKE '%$safeSearch%' OR content LIKE '%$safeSearch%')",
      );
    }
    if (query.grade != null) {
      conditions.add('grade = ${query.grade}');
    }
    if (query.category != null && query.category!.isNotEmpty) {
      conditions.add('category = ${sqlString(query.category!)}');
    }
    if (query.dynasty != null && query.dynasty!.isNotEmpty) {
      conditions.add('dynasty = ${sqlString(query.dynasty!)}');
    }

    final rows = await _database.selectList('''
      SELECT *
      FROM poems
      WHERE ${conditions.join(' AND ')}
      ORDER BY grade ASC, id ASC;
    ''');
    return rows.map(Poem.fromRow).toList(growable: false);
  }

  @override
  Future<Poem?> fetchPoemById(int id) async {
    final row = await _database.selectSingle(
      'SELECT * FROM poems WHERE id = $id AND deleted_at IS NULL LIMIT 1;',
    );
    if (row == null) {
      return null;
    }
    return Poem.fromRow(row);
  }

  @override
  Future<List<Poem>> fetchFavorites() async {
    final profileId = await _database.activeProfileId();
    final rows = await _database.selectList('''
      SELECT p.*
      FROM poems p
      INNER JOIN favorites f ON f.poem_id = p.id
      WHERE p.deleted_at IS NULL
        AND f.profile_id = $profileId
        AND f.deleted_at IS NULL
      ORDER BY f.updated_at DESC;
    ''');
    return rows.map(Poem.fromRow).toList(growable: false);
  }

  @override
  Future<void> setFavorite(int poemId, bool isFavorite) async {
    final profileId = await _database.activeProfileId();
    final now = DateTime.now().toUtc().toIso8601String();
    final mutationId = nextClientMutationId('favorite');
    final deviceId = currentActorDeviceId();

    if (isFavorite) {
      await _database.customStatement('''
        INSERT INTO favorites (
          profile_id,
          poem_id,
          client_mutation_id,
          last_actor_device_id,
          sync_status,
          created_at,
          updated_at
        )
        VALUES (
          $profileId,
          $poemId,
          ${sqlString(mutationId)},
          ${sqlString(deviceId)},
          'pending_push',
          ${sqlString(now)},
          ${sqlString(now)}
        )
        ON CONFLICT(profile_id, poem_id) DO UPDATE SET
          deleted_at = NULL,
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(now)};
      ''');
      return;
    }

    await _database.customStatement('''
      UPDATE favorites
      SET deleted_at = ${sqlString(now)},
          client_mutation_id = ${sqlString(mutationId)},
          last_actor_device_id = ${sqlString(deviceId)},
          sync_status = 'pending_push',
          updated_at = ${sqlString(now)}
      WHERE profile_id = $profileId AND poem_id = $poemId AND deleted_at IS NULL;
    ''');
  }

  @override
  Future<bool> isFavorite(int poemId) async {
    final profileId = await _database.activeProfileId();
    final row = await _database.selectSingle(
      'SELECT COUNT(*) AS count FROM favorites WHERE profile_id = $profileId AND poem_id = $poemId AND deleted_at IS NULL;',
    );
    return ((row?['count'] as int?) ?? 0) > 0;
  }

  @override
  Future<PoemStats> fetchStats() async {
    final totalRow = await _database.selectSingle('''
      SELECT COUNT(*) AS count
      FROM poems
      WHERE deleted_at IS NULL;
    ''');
    final gradeRows = await _database.selectList('''
      SELECT grade_label, MIN(grade) AS sort_order, COUNT(*) AS count
      FROM poems
      WHERE deleted_at IS NULL
      GROUP BY grade_label
      ORDER BY sort_order ASC;
    ''');
    final categoryRows = await _database.selectList('''
      SELECT category, COUNT(*) AS count
      FROM poems
      WHERE deleted_at IS NULL
      GROUP BY category
      ORDER BY count DESC;
    ''');
    final dynastyRows = await _database.selectList('''
      SELECT dynasty, COUNT(*) AS count
      FROM poems
      WHERE deleted_at IS NULL
      GROUP BY dynasty
      ORDER BY count DESC;
    ''');

    return PoemStats(
      total: (totalRow?['count'] as int?) ?? 0,
      gradeCounts: {
        for (final row in gradeRows)
          (row['grade_label'] as String? ?? '未分级'): (row['count'] as int?) ?? 0,
      },
      categoryCounts: {
        for (final row in categoryRows)
          (row['category'] as String? ?? '未分类'): (row['count'] as int?) ?? 0,
      },
      dynastyCounts: {
        for (final row in dynastyRows)
          (row['dynasty'] as String? ?? '未知'): (row['count'] as int?) ?? 0,
      },
    );
  }

  @override
  Future<DailyPoemBundle> getDailyPoem(DateTime date) async {
    await _database.ensureDailyPoem(date);
    final profileId = await _database.activeProfileId();
    final dateKey = AppFormatters.dateKey(date);
    final row = await _database.selectSingle('''
      SELECT d.date_key, d.is_completed, p.*
      FROM daily_poem_records d
      INNER JOIN poems p ON p.id = d.poem_id
      WHERE d.profile_id = $profileId
        AND d.date_key = ${sqlString(dateKey)}
      LIMIT 1;
    ''');

    if (row == null) {
      final poems = await fetchPoems();
      final fallback =
          poems.isEmpty
              ? const Poem(
                id: 0,
                title: '暂无种子数据',
                author: '',
                dynasty: '',
                grade: 0,
                gradeLabel: '',
                category: '',
                content: '请先完成种子导入。',
                pinyin: '',
                annotation: '',
                translation: '',
                appreciation: '',
                authorIntro: '',
                extension: '',
                audioUrl: null,
                imageUrl: null,
                difficulty: 1,
              )
              : poems.first;
      return DailyPoemBundle(
        dateKey: dateKey,
        poem: fallback,
        isCompleted: false,
      );
    }

    return DailyPoemBundle(
      dateKey: row['date_key'] as String? ?? AppFormatters.dateKey(date),
      poem: Poem.fromRow(row),
      isCompleted: ((row['is_completed'] as int?) ?? 0) == 1,
    );
  }
}
