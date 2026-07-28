import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_formatters.dart';
import '../../domain/poem.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'gscappall',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  AppDatabase.forTesting(super.executor);

  Future<void>? _ensureDefaultsFuture;
  bool _defaultsReady = false;

  @override
  int get schemaVersion => 10;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await _ensureSyncSchema();
    },
    onCreate: (m) async => _createSchema(),
    onUpgrade: (m, from, to) async => _migrateSchema(from, to),
  );

  Future<void> _createSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS poems (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        dynasty TEXT NOT NULL,
        grade INTEGER DEFAULT 0,
        grade_label TEXT,
        category TEXT,
        content TEXT NOT NULL,
        pinyin TEXT,
        annotation TEXT,
        translation TEXT,
        appreciation TEXT,
        author_intro TEXT,
        extension_text TEXT,
        audio_url TEXT,
        image_url TEXT,
        difficulty INTEGER DEFAULT 1,
        seed_version TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        poem_id INTEGER NOT NULL,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
        UNIQUE (profile_id, poem_id)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS learning_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        poem_id INTEGER NOT NULL,
        mode TEXT NOT NULL,
        duration_minutes INTEGER DEFAULT 0,
        score INTEGER,
        note TEXT,
        stage_id TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS recite_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        poem_id INTEGER NOT NULL,
        score INTEGER,
        recognized_text TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS wrong_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        poem_id INTEGER NOT NULL,
        question_type TEXT,
        prompt TEXT,
        correct_answer TEXT,
        user_answer TEXT,
        rule_tag TEXT,
        severity TEXT DEFAULT 'medium',
        stage_id TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        reviewed_at TEXT,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS daily_poem_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        date_key TEXT NOT NULL,
        poem_id INTEGER NOT NULL,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        points_earned INTEGER DEFAULT 0,
        review_count INTEGER DEFAULT 0,
        last_reviewed_at TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
        UNIQUE (profile_id, date_key)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS study_card_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        poem_id INTEGER NOT NULL,
        memory_status TEXT NOT NULL DEFAULT 'new',
        review_count INTEGER NOT NULL DEFAULT 0,
        next_review_at TEXT,
        note TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
        UNIQUE (profile_id, poem_id)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS check_in_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        date_key TEXT NOT NULL,
        check_in_type TEXT NOT NULL DEFAULT 'daily_poem',
        points_earned INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (profile_id, date_key, check_in_type)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS challenge_stage_rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        stage_id TEXT NOT NULL,
        stars INTEGER NOT NULL DEFAULT 0,
        claimed_at TEXT NOT NULL,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (profile_id, stage_id, stars)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_points (
        id INTEGER PRIMARY KEY,
        total_points INTEGER NOT NULL DEFAULT 0,
        current_points INTEGER NOT NULL DEFAULT 0,
        total_check_ins INTEGER NOT NULL DEFAULT 0,
        consecutive_days INTEGER NOT NULL DEFAULT 0,
        last_check_in_date TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        nickname TEXT NOT NULL,
        tagline TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS profile_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL,
        tagline TEXT,
        avatar_seed TEXT,
        last_active_at TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        theme_mode TEXT NOT NULL DEFAULT 'system',
        font_scale REAL NOT NULL DEFAULT 1.0,
        speech_rate REAL NOT NULL DEFAULT 1.0,
        daily_reminder_enabled INTEGER NOT NULL DEFAULT 1,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        show_pinyin INTEGER NOT NULL DEFAULT 1,
        auto_sync_enabled INTEGER NOT NULL DEFAULT 0,
        auto_sync_cooldown_minutes INTEGER NOT NULL DEFAULT 5,
        auto_sync_allow_mobile_network INTEGER NOT NULL DEFAULT 1,
        auto_sync_require_charging INTEGER NOT NULL DEFAULT 0,
        reminder_hour INTEGER NOT NULL DEFAULT 20,
        reminder_minute INTEGER NOT NULL DEFAULT 0,
        active_profile_id INTEGER NOT NULL DEFAULT 1,
        seed_version TEXT DEFAULT '',
        sync_device_id TEXT,
        sync_account_id TEXT,
        sync_auth_token TEXT,
        sync_refresh_token TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_run_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        state TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        pushed_count INTEGER NOT NULL DEFAULT 0,
        pulled_count INTEGER NOT NULL DEFAULT 0,
        conflict_count INTEGER NOT NULL DEFAULT 0,
        trigger_source TEXT NOT NULL DEFAULT 'unknown',
        error_message TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await _ensurePracticeReportSchema();

    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_checkpoints (
        scope_key TEXT PRIMARY KEY,
        global_cursor TEXT,
        resource_cursors_json TEXT,
        last_successful_sync_at TEXT,
        schema_version INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      );
    ''');

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_poems_grade ON poems(grade);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_poems_category ON poems(category);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_poems_dynasty ON poems(dynasty);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_learning_poem ON learning_records(poem_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_favorites_sync_status ON favorites(sync_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_learning_sync_status ON learning_records(sync_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recite_sync_status ON recite_records(sync_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wrong_questions_sync_status ON wrong_questions(sync_status);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wrong_questions_profile_identity ON wrong_questions(profile_id, poem_id, question_type, prompt, correct_answer);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_check_in_records_date_key ON check_in_records(date_key);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_daily_poem_records_completed_at ON daily_poem_records(completed_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_card_progress_poem_id ON study_card_progress(poem_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_card_progress_next_review_at ON study_card_progress(next_review_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_card_progress_memory_status ON study_card_progress(memory_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_accounts_last_active_at ON profile_accounts(last_active_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_challenge_stage_rewards_profile ON challenge_stage_rewards(profile_id, stage_id, stars);',
    );
  }

  Future<void> _migrateSchema(int from, int to) async {
    await _createSchema();
    await _ensureSyncSchema();
  }

  Future<void> _ensureSyncSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_checkpoints (
        scope_key TEXT PRIMARY KEY,
        global_cursor TEXT,
        resource_cursors_json TEXT,
        last_successful_sync_at TEXT,
        schema_version INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      );
    ''');

    await _ensureColumn('poems', 'revision_token', 'TEXT');
    await _ensureColumn('poems', 'client_mutation_id', 'TEXT');
    await _ensureColumn('poems', 'last_actor_device_id', 'TEXT');

    await _ensureColumn('favorites', 'revision_token', 'TEXT');
    await _ensureColumn('favorites', 'client_mutation_id', 'TEXT');
    await _ensureColumn('favorites', 'last_actor_device_id', 'TEXT');

    await _ensureColumn('learning_records', 'revision_token', 'TEXT');
    await _ensureColumn('learning_records', 'client_mutation_id', 'TEXT');
    await _ensureColumn('learning_records', 'last_actor_device_id', 'TEXT');

    await _ensureColumn('recite_records', 'revision_token', 'TEXT');
    await _ensureColumn('recite_records', 'client_mutation_id', 'TEXT');
    await _ensureColumn('recite_records', 'last_actor_device_id', 'TEXT');

    await _ensureColumn('wrong_questions', 'revision_token', 'TEXT');
    await _ensureColumn('wrong_questions', 'client_mutation_id', 'TEXT');
    await _ensureColumn('wrong_questions', 'last_actor_device_id', 'TEXT');
    await _ensureColumn('wrong_questions', 'stage_id', 'TEXT');
    await _ensureColumn('wrong_questions', 'updated_at', 'TEXT');

    await _ensureColumn('daily_poem_records', 'revision_token', 'TEXT');
    await _ensureColumn('daily_poem_records', 'client_mutation_id', 'TEXT');
    await _ensureColumn('daily_poem_records', 'last_actor_device_id', 'TEXT');
    await _ensureColumn(
      'daily_poem_records',
      'points_earned',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn(
      'daily_poem_records',
      'review_count',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn('daily_poem_records', 'last_reviewed_at', 'TEXT');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS study_card_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        poem_id INTEGER NOT NULL,
        memory_status TEXT NOT NULL DEFAULT 'new',
        review_count INTEGER NOT NULL DEFAULT 0,
        next_review_at TEXT,
        note TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
        UNIQUE (profile_id, poem_id)
      );
    ''');

    await _ensureColumn('user_profiles', 'revision_token', 'TEXT');
    await _ensureColumn('user_profiles', 'client_mutation_id', 'TEXT');
    await _ensureColumn('user_profiles', 'last_actor_device_id', 'TEXT');

    await _ensureColumn('settings', 'revision_token', 'TEXT');
    await _ensureColumn('settings', 'client_mutation_id', 'TEXT');
    await _ensureColumn('settings', 'last_actor_device_id', 'TEXT');
    await _ensureColumn('settings', 'active_profile_id', 'INTEGER DEFAULT 1');
    await _ensureColumn('settings', 'show_pinyin', 'INTEGER DEFAULT 1');
    await _ensureColumn('settings', 'auto_sync_enabled', 'INTEGER DEFAULT 0');
    await _ensureColumn(
      'settings',
      'auto_sync_cooldown_minutes',
      'INTEGER DEFAULT 5',
    );
    await _ensureColumn(
      'settings',
      'auto_sync_allow_mobile_network',
      'INTEGER DEFAULT 1',
    );
    await _ensureColumn(
      'settings',
      'auto_sync_require_charging',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn('settings', 'sync_device_id', 'TEXT');
    await _ensureColumn('settings', 'sync_account_id', 'TEXT');
    await _ensureColumn('settings', 'sync_auth_token', 'TEXT');
    await _ensureColumn('settings', 'sync_refresh_token', 'TEXT');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_run_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        state TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        pushed_count INTEGER NOT NULL DEFAULT 0,
        pulled_count INTEGER NOT NULL DEFAULT 0,
        conflict_count INTEGER NOT NULL DEFAULT 0,
        trigger_source TEXT NOT NULL DEFAULT 'unknown',
        error_message TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await _ensureColumn(
      'sync_run_logs',
      'trigger_source',
      "TEXT NOT NULL DEFAULT 'unknown'",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_run_logs_created ON sync_run_logs(created_at DESC);',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS profile_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT NOT NULL,
        tagline TEXT,
        avatar_seed TEXT,
        last_active_at TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS check_in_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        date_key TEXT NOT NULL,
        check_in_type TEXT NOT NULL DEFAULT 'daily_poem',
        points_earned INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (profile_id, date_key, check_in_type)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS challenge_stage_rewards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        stage_id TEXT NOT NULL,
        stars INTEGER NOT NULL DEFAULT 0,
        claimed_at TEXT NOT NULL,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (profile_id, stage_id, stars)
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_points (
        id INTEGER PRIMARY KEY,
        total_points INTEGER NOT NULL DEFAULT 0,
        current_points INTEGER NOT NULL DEFAULT 0,
        total_check_ins INTEGER NOT NULL DEFAULT 0,
        consecutive_days INTEGER NOT NULL DEFAULT 0,
        last_check_in_date TEXT,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await _ensurePracticeReportSchema();
    await _ensureProfileScopedSchema();
    await _ensureColumn('learning_records', 'stage_id', 'TEXT');

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_card_progress_poem_id ON study_card_progress(poem_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_card_progress_next_review_at ON study_card_progress(next_review_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_card_progress_memory_status ON study_card_progress(memory_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_profile_accounts_last_active_at ON profile_accounts(last_active_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_challenge_stage_rewards_profile ON challenge_stage_rewards(profile_id, stage_id, stars);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_learning_records_stage ON learning_records(profile_id, mode, stage_id, created_at DESC);',
    );
    await _ensureColumn('challenge_stage_rewards', 'cloud_id', 'TEXT');
    await _ensureColumn('challenge_stage_rewards', 'revision_token', 'TEXT');
    await _ensureColumn(
      'challenge_stage_rewards',
      'client_mutation_id',
      'TEXT',
    );
    await _ensureColumn(
      'challenge_stage_rewards',
      'last_actor_device_id',
      'TEXT',
    );
    await _ensureColumn(
      'challenge_stage_rewards',
      'sync_status',
      "TEXT DEFAULT 'local'",
    );
  }

  Future<void> _ensureColumn(
    String table,
    String columnName,
    String columnDefinition,
  ) async {
    final rows = await customSelect('PRAGMA table_info($table);').get();
    final hasColumn = rows.any((row) => row.data['name'] == columnName);
    if (hasColumn) {
      return;
    }

    await customStatement(
      'ALTER TABLE $table ADD COLUMN $columnName $columnDefinition;',
    );
  }

  Future<String> _tableSql(String table) async {
    final row = await selectSingle('''
      SELECT sql
      FROM sqlite_master
      WHERE type = 'table' AND name = ${sqlString(table)}
      LIMIT 1;
    ''');
    return row?['sql'] as String? ?? '';
  }

  Future<void> _ensurePracticeReportSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS practice_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL DEFAULT 1,
        session_id TEXT NOT NULL,
        mode TEXT NOT NULL,
        poem_id INTEGER NOT NULL,
        total_score INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        total_questions INTEGER NOT NULL DEFAULT 0,
        generated_wrong_count INTEGER NOT NULL DEFAULT 0,
        stage_id TEXT,
        suggestions_json TEXT NOT NULL DEFAULT '[]',
        completed_at TEXT NOT NULL,
        cloud_id TEXT,
        revision_token TEXT,
        client_mutation_id TEXT,
        last_actor_device_id TEXT,
        sync_status TEXT DEFAULT 'local',
        is_encrypted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS practice_report_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        line_index INTEGER NOT NULL,
        prompt TEXT NOT NULL,
        hint TEXT,
        expected_answer TEXT NOT NULL,
        user_answer TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        score INTEGER NOT NULL DEFAULT 0,
        feedback TEXT NOT NULL,
        mistake_type TEXT,
        assessment_engine TEXT,
        assessment_confidence REAL,
        assessment_accuracy INTEGER,
        assessment_fluency INTEGER,
        assessment_integrity INTEGER,
        assessment_basis TEXT,
        assessment_audio_path TEXT,
        assessment_payload_json TEXT,
        FOREIGN KEY (report_id) REFERENCES practice_reports(id) ON DELETE CASCADE
      );
    ''');

    await _ensureColumn('practice_reports', 'stage_id', 'TEXT');
    await _ensureColumn('practice_reports', 'cloud_id', 'TEXT');
    await _ensureColumn('practice_reports', 'revision_token', 'TEXT');
    await _ensureColumn('practice_reports', 'client_mutation_id', 'TEXT');
    await _ensureColumn('practice_reports', 'last_actor_device_id', 'TEXT');
    await _ensureColumn(
      'practice_reports',
      'sync_status',
      "TEXT DEFAULT 'local'",
    );
    await _ensureColumn(
      'practice_reports',
      'is_encrypted',
      'INTEGER DEFAULT 0',
    );
    await _ensureColumn('practice_report_items', 'assessment_engine', 'TEXT');
    await _ensureColumn(
      'practice_report_items',
      'assessment_confidence',
      'REAL',
    );
    await _ensureColumn(
      'practice_report_items',
      'assessment_accuracy',
      'INTEGER',
    );
    await _ensureColumn(
      'practice_report_items',
      'assessment_fluency',
      'INTEGER',
    );
    await _ensureColumn(
      'practice_report_items',
      'assessment_integrity',
      'INTEGER',
    );
    await _ensureColumn('practice_report_items', 'assessment_basis', 'TEXT');
    await _ensureColumn(
      'practice_report_items',
      'assessment_audio_path',
      'TEXT',
    );
    await _ensureColumn(
      'practice_report_items',
      'assessment_payload_json',
      'TEXT',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_practice_reports_profile_completed ON practice_reports(profile_id, completed_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_practice_reports_profile_stage ON practice_reports(profile_id, mode, stage_id, completed_at DESC);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_practice_reports_profile_session ON practice_reports(profile_id, session_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_practice_reports_sync_status ON practice_reports(sync_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_practice_report_items_report ON practice_report_items(report_id, line_index);',
    );
  }

  Future<void> _ensureProfileScopedSchema() async {
    await _ensureColumn(
      'learning_records',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      'recite_records',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      'wrong_questions',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );

    await _rebuildFavoritesForProfilesIfNeeded();
    await _rebuildDailyPoemRecordsForProfilesIfNeeded();
    await _rebuildStudyCardProgressForProfilesIfNeeded();
    await _rebuildCheckInRecordsForProfilesIfNeeded();
    await _rebuildUserPointsForProfilesIfNeeded();

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_favorites_profile_poem ON favorites(profile_id, poem_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_learning_profile_created ON learning_records(profile_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_recite_profile_created ON recite_records(profile_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_wrong_questions_profile_created ON wrong_questions(profile_id, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_wrong_questions_profile_identity ON wrong_questions(profile_id, poem_id, question_type, prompt, correct_answer);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_daily_poem_records_profile_date ON daily_poem_records(profile_id, date_key);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_check_in_records_profile_date ON check_in_records(profile_id, date_key);',
    );
  }

  Future<void> _rebuildFavoritesForProfilesIfNeeded() async {
    await _ensureColumn(
      'favorites',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );
    final schema = await _tableSql('favorites');
    if (schema.contains('UNIQUE (profile_id, poem_id)')) {
      return;
    }

    await transaction(() async {
      await customStatement('ALTER TABLE favorites RENAME TO favorites_old;');
      await customStatement('''
        CREATE TABLE favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER NOT NULL DEFAULT 1,
          poem_id INTEGER NOT NULL,
          cloud_id TEXT,
          revision_token TEXT,
          client_mutation_id TEXT,
          last_actor_device_id TEXT,
          sync_status TEXT DEFAULT 'local',
          is_encrypted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT,
          FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
          UNIQUE (profile_id, poem_id)
        );
      ''');
      await customStatement('''
        INSERT OR IGNORE INTO favorites (
          id, profile_id, poem_id, cloud_id, revision_token, client_mutation_id,
          last_actor_device_id, sync_status, is_encrypted, created_at, updated_at, deleted_at
        )
        SELECT
          id, COALESCE(profile_id, 1), poem_id, cloud_id, revision_token,
          client_mutation_id, last_actor_device_id, sync_status, is_encrypted,
          created_at, updated_at, deleted_at
        FROM favorites_old;
      ''');
      await customStatement('DROP TABLE favorites_old;');
    });
  }

  Future<void> _rebuildDailyPoemRecordsForProfilesIfNeeded() async {
    await _ensureColumn(
      'daily_poem_records',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );
    final schema = await _tableSql('daily_poem_records');
    if (schema.contains('UNIQUE (profile_id, date_key)')) {
      return;
    }

    await transaction(() async {
      await customStatement(
        'ALTER TABLE daily_poem_records RENAME TO daily_poem_records_old;',
      );
      await customStatement('''
        CREATE TABLE daily_poem_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER NOT NULL DEFAULT 1,
          date_key TEXT NOT NULL,
          poem_id INTEGER NOT NULL,
          is_completed INTEGER DEFAULT 0,
          completed_at TEXT,
          points_earned INTEGER DEFAULT 0,
          review_count INTEGER DEFAULT 0,
          last_reviewed_at TEXT,
          cloud_id TEXT,
          revision_token TEXT,
          client_mutation_id TEXT,
          last_actor_device_id TEXT,
          sync_status TEXT DEFAULT 'local',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
          UNIQUE (profile_id, date_key)
        );
      ''');
      await customStatement('''
        INSERT OR IGNORE INTO daily_poem_records (
          profile_id, date_key, poem_id, is_completed, completed_at,
          points_earned, review_count, last_reviewed_at, cloud_id,
          revision_token, client_mutation_id, last_actor_device_id,
          sync_status, created_at, updated_at
        )
        SELECT
          COALESCE(profile_id, 1), date_key, poem_id, is_completed, completed_at,
          points_earned, review_count, last_reviewed_at, cloud_id,
          revision_token, client_mutation_id, last_actor_device_id,
          sync_status, created_at, updated_at
        FROM daily_poem_records_old;
      ''');
      await customStatement('DROP TABLE daily_poem_records_old;');
    });
  }

  Future<void> _rebuildStudyCardProgressForProfilesIfNeeded() async {
    await _ensureColumn(
      'study_card_progress',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );
    final schema = await _tableSql('study_card_progress');
    if (schema.contains('UNIQUE (profile_id, poem_id)')) {
      return;
    }

    await transaction(() async {
      await customStatement(
        'ALTER TABLE study_card_progress RENAME TO study_card_progress_old;',
      );
      await customStatement('''
        CREATE TABLE study_card_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER NOT NULL DEFAULT 1,
          poem_id INTEGER NOT NULL,
          memory_status TEXT NOT NULL DEFAULT 'new',
          review_count INTEGER NOT NULL DEFAULT 0,
          next_review_at TEXT,
          note TEXT,
          cloud_id TEXT,
          revision_token TEXT,
          client_mutation_id TEXT,
          last_actor_device_id TEXT,
          sync_status TEXT DEFAULT 'local',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (poem_id) REFERENCES poems(id) ON DELETE CASCADE,
          UNIQUE (profile_id, poem_id)
        );
      ''');
      await customStatement('''
        INSERT OR IGNORE INTO study_card_progress (
          id, profile_id, poem_id, memory_status, review_count, next_review_at,
          note, cloud_id, revision_token, client_mutation_id,
          last_actor_device_id, sync_status, created_at, updated_at
        )
        SELECT
          id, COALESCE(profile_id, 1), poem_id, memory_status, review_count,
          next_review_at, note, cloud_id, revision_token, client_mutation_id,
          last_actor_device_id, sync_status, created_at, updated_at
        FROM study_card_progress_old;
      ''');
      await customStatement('DROP TABLE study_card_progress_old;');
    });
  }

  Future<void> _rebuildCheckInRecordsForProfilesIfNeeded() async {
    await _ensureColumn(
      'check_in_records',
      'profile_id',
      'INTEGER NOT NULL DEFAULT 1',
    );
    final schema = await _tableSql('check_in_records');
    if (schema.contains('UNIQUE (profile_id, date_key, check_in_type)')) {
      return;
    }

    await transaction(() async {
      await customStatement(
        'ALTER TABLE check_in_records RENAME TO check_in_records_old;',
      );
      await customStatement('''
        CREATE TABLE check_in_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          profile_id INTEGER NOT NULL DEFAULT 1,
          date_key TEXT NOT NULL,
          check_in_type TEXT NOT NULL DEFAULT 'daily_poem',
          points_earned INTEGER NOT NULL DEFAULT 0,
          cloud_id TEXT,
          revision_token TEXT,
          client_mutation_id TEXT,
          last_actor_device_id TEXT,
          sync_status TEXT DEFAULT 'local',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE (profile_id, date_key, check_in_type)
        );
      ''');
      await customStatement('''
        INSERT OR IGNORE INTO check_in_records (
          id, profile_id, date_key, check_in_type, points_earned, cloud_id,
          revision_token, client_mutation_id, last_actor_device_id,
          sync_status, created_at, updated_at
        )
        SELECT
          id, COALESCE(profile_id, 1), date_key, check_in_type, points_earned,
          cloud_id, revision_token, client_mutation_id, last_actor_device_id,
          sync_status, created_at, updated_at
        FROM check_in_records_old;
      ''');
      await customStatement('DROP TABLE check_in_records_old;');
    });
  }

  Future<void> _rebuildUserPointsForProfilesIfNeeded() async {
    final schema = await _tableSql('user_points');
    if (!schema.contains('CHECK (id = 1)')) {
      return;
    }

    await transaction(() async {
      await customStatement(
        'ALTER TABLE user_points RENAME TO user_points_old;',
      );
      await customStatement('''
        CREATE TABLE user_points (
          id INTEGER PRIMARY KEY,
          total_points INTEGER NOT NULL DEFAULT 0,
          current_points INTEGER NOT NULL DEFAULT 0,
          total_check_ins INTEGER NOT NULL DEFAULT 0,
          consecutive_days INTEGER NOT NULL DEFAULT 0,
          last_check_in_date TEXT,
          cloud_id TEXT,
          revision_token TEXT,
          client_mutation_id TEXT,
          last_actor_device_id TEXT,
          sync_status TEXT DEFAULT 'local',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await customStatement('''
        INSERT OR IGNORE INTO user_points (
          id, total_points, current_points, total_check_ins, consecutive_days,
          last_check_in_date, cloud_id, revision_token, client_mutation_id,
          last_actor_device_id, sync_status, created_at, updated_at
        )
        SELECT
          id, total_points, current_points, total_check_ins, consecutive_days,
          last_check_in_date, cloud_id, revision_token, client_mutation_id,
          last_actor_device_id, sync_status, created_at, updated_at
        FROM user_points_old;
      ''');
      await customStatement('DROP TABLE user_points_old;');
    });
  }

  Future<List<Map<String, Object?>>> selectList(String sql) async {
    final rows = await customSelect(sql).get();
    return rows.map((row) => row.data).toList(growable: false);
  }

  Future<Map<String, Object?>?> selectSingle(String sql) async {
    final rows = await selectList(sql);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<int> poemCount() async {
    final row = await selectSingle('SELECT COUNT(*) AS count FROM poems;');
    return (row?['count'] as int?) ?? 0;
  }

  Future<String?> currentSeedVersion() async {
    final row = await selectSingle(
      'SELECT seed_version FROM settings WHERE id = 1;',
    );
    return row?['seed_version'] as String?;
  }

  Future<void> ensureDefaults() async {
    if (_defaultsReady) {
      return;
    }
    final inFlight = _ensureDefaultsFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _ensureDefaultsUncached();
    _ensureDefaultsFuture = future;
    try {
      await future;
      _defaultsReady = true;
    } finally {
      _ensureDefaultsFuture = null;
    }
  }

  Future<void> _ensureDefaultsUncached() async {
    final now = sqlString(DateTime.now().toUtc().toIso8601String());
    await customStatement('''
      INSERT INTO user_profiles (
        id, nickname, tagline, sync_status, created_at, updated_at
      )
      VALUES (
        1,
        ${sqlString('小诗童')},
        ${sqlString('今天也和古诗做朋友')},
        'synced',
        $now,
        $now
      )
      ON CONFLICT(id) DO NOTHING;
    ''');

    await customStatement('''
      INSERT INTO settings (
        id, theme_mode, font_scale, speech_rate, daily_reminder_enabled,
        notifications_enabled, show_pinyin, auto_sync_enabled, reminder_hour, reminder_minute, active_profile_id, seed_version,
        sync_status, created_at, updated_at
      )
      VALUES (
        1, 'system', 1.0, 1.0, 1, 1, 1, 0, 20, 0, 1, '', 'synced', $now, $now
      )
      ON CONFLICT(id) DO NOTHING;
    ''');

    final profileCountRow = await selectSingle(
      'SELECT COUNT(*) AS count FROM profile_accounts;',
    );
    final profileCount = (profileCountRow?['count'] as int?) ?? 0;
    if (profileCount == 0) {
      final legacyProfile = await selectSingle(
        'SELECT nickname, tagline FROM user_profiles WHERE id = 1 LIMIT 1;',
      );
      await customStatement('''
        INSERT INTO profile_accounts (
          id, nickname, tagline, avatar_seed, last_active_at, sync_status, created_at, updated_at
        )
        VALUES (
          1,
          ${sqlString(legacyProfile?['nickname'] as String? ?? '小诗童')},
          ${sqlString(legacyProfile?['tagline'] as String? ?? '今天也和古诗做朋友')},
          ${sqlString('amber')},
          $now,
          'synced',
          $now,
          $now
        );
      ''');
    }

    final activeProfileRow = await selectSingle(
      'SELECT active_profile_id FROM settings WHERE id = 1 LIMIT 1;',
    );
    final activeProfileId =
        (activeProfileRow?['active_profile_id'] as int?) ?? 1;
    final activeProfileExists = await selectSingle(
      'SELECT id FROM profile_accounts WHERE id = $activeProfileId LIMIT 1;',
    );
    if (activeProfileExists == null) {
      await customStatement('''
        UPDATE settings
        SET active_profile_id = 1,
            updated_at = $now
        WHERE id = 1;
      ''');
    }

    final resolvedProfileId = activeProfileExists == null ? 1 : activeProfileId;
    await ensureProfileDefaults(resolvedProfileId);
  }

  Future<int> activeProfileId() async {
    await ensureDefaults();
    final row = await selectSingle(
      'SELECT active_profile_id FROM settings WHERE id = 1 LIMIT 1;',
    );
    return (row?['active_profile_id'] as int?) ?? 1;
  }

  Future<void> ensureProfileDefaults(int profileId) async {
    final now = sqlString(DateTime.now().toUtc().toIso8601String());
    await customStatement('''
      INSERT INTO user_points (
        id, total_points, current_points, total_check_ins, consecutive_days,
        sync_status, created_at, updated_at
      )
      VALUES (
        $profileId, 0, 0, 0, 0, 'synced', $now, $now
      )
      ON CONFLICT(id) DO NOTHING;
    ''');
  }

  Future<void> replaceSeed({
    required List<Poem> poems,
    required String seedVersion,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await customStatement('DELETE FROM poems;');
      for (final poem in poems) {
        await customStatement('''
          INSERT INTO poems (
            id, title, author, dynasty, grade, grade_label, category, content,
            pinyin, annotation, translation, appreciation, author_intro,
            extension_text, audio_url, image_url, difficulty, seed_version,
            sync_status, created_at, updated_at
          )
          VALUES (
            ${poem.id},
            ${sqlString(poem.title)},
            ${sqlString(poem.author)},
            ${sqlString(poem.dynasty)},
            ${poem.grade},
            ${sqlNullable(poem.gradeLabel)},
            ${sqlNullable(poem.category)},
            ${sqlString(poem.content)},
            ${sqlNullable(poem.pinyin)},
            ${sqlNullable(poem.annotation)},
            ${sqlNullable(poem.translation)},
            ${sqlNullable(poem.appreciation)},
            ${sqlNullable(poem.authorIntro)},
            ${sqlNullable(poem.extension)},
            ${sqlNullable(poem.audioUrl)},
            ${sqlNullable(poem.imageUrl)},
            ${poem.difficulty},
            ${sqlString(seedVersion)},
            'synced',
            ${sqlString(now)},
            ${sqlString(now)}
          );
        ''');
      }

      await customStatement('''
        UPDATE settings
        SET seed_version = ${sqlString(seedVersion)},
            updated_at = ${sqlString(now)}
        WHERE id = 1;
      ''');
    });
  }

  Future<void> ensureDailyPoem(DateTime date) async {
    final profileId = await activeProfileId();
    final dateKey = AppFormatters.dateKey(date);
    final existing = await selectSingle(
      'SELECT date_key FROM daily_poem_records WHERE profile_id = $profileId AND date_key = ${sqlString(dateKey)};',
    );
    if (existing != null) {
      return;
    }

    final total = await poemCount();
    if (total == 0) {
      return;
    }

    final offset = (date.difference(DateTime(date.year, 1, 1)).inDays) % total;
    final poemRow = await selectSingle(
      'SELECT id FROM poems ORDER BY id ASC LIMIT 1 OFFSET $offset;',
    );
    final poemId = (poemRow?['id'] as int?) ?? 1;
    final now = DateTime.now().toUtc().toIso8601String();
    await customStatement('''
      INSERT OR REPLACE INTO daily_poem_records (
        profile_id, date_key, poem_id, is_completed, sync_status, created_at, updated_at
      )
      VALUES (
        $profileId,
        ${sqlString(dateKey)},
        $poemId,
        0,
        'synced',
        ${sqlString(now)},
        ${sqlString(now)}
      );
    ''');
  }

  Future<Map<String, Object?>?> loadSyncCheckpoint(String scopeKey) async {
    return selectSingle('''
      SELECT *
      FROM sync_checkpoints
      WHERE scope_key = ${sqlString(scopeKey)}
      LIMIT 1;
    ''');
  }

  Future<void> saveSyncCheckpoint({
    required String scopeKey,
    required String? globalCursor,
    required Map<String, String> resourceCursors,
    required DateTime? lastSuccessfulSyncAt,
    required int schemaVersion,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final resourceCursorsJson = jsonEncode(resourceCursors);
    await customStatement('''
      INSERT INTO sync_checkpoints (
        scope_key,
        global_cursor,
        resource_cursors_json,
        last_successful_sync_at,
        schema_version,
        updated_at
      )
      VALUES (
        ${sqlString(scopeKey)},
        ${sqlNullable(globalCursor)},
        ${sqlString(resourceCursorsJson)},
        ${sqlNullable(lastSuccessfulSyncAt?.toIso8601String())},
        $schemaVersion,
        ${sqlString(now)}
      )
      ON CONFLICT(scope_key) DO UPDATE SET
        global_cursor = excluded.global_cursor,
        resource_cursors_json = excluded.resource_cursors_json,
        last_successful_sync_at = excluded.last_successful_sync_at,
        schema_version = excluded.schema_version,
        updated_at = excluded.updated_at;
    ''');
  }
}

String sqlString(String value) {
  final escaped = value.replaceAll("'", "''");
  return "'$escaped'";
}

String sqlNullable(String? value) {
  if (value == null || value.isEmpty) {
    return 'NULL';
  }
  return sqlString(value);
}

String nextClientMutationId([String prefix = 'mutation']) {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
  return '$prefix-$timestamp';
}

String currentActorDeviceId() {
  if (kIsWeb) {
    return 'gscappall-web-device';
  }

  try {
    final normalizedHost = Platform.localHostname
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final hostToken = normalizedHost.isEmpty ? 'local' : normalizedHost;
    return 'gscappall-${Platform.operatingSystem}-$hostToken';
  } catch (_) {
    return 'gscappall-local-device';
  }
}
