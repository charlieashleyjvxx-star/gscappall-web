const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

class SqliteSyncStore {
  constructor(databasePath) {
    this.databasePath = databasePath;
  }

  init() {
    fs.mkdirSync(path.dirname(this.databasePath), { recursive: true });
    this.exec(`
      PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS sync_meta (
        account_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (account_id, key)
      );
      CREATE TABLE IF NOT EXISTS sync_devices (
        account_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        app_version TEXT NOT NULL,
        schema_version INTEGER NOT NULL,
        last_seen_at TEXT NOT NULL,
        PRIMARY KEY (account_id, device_id)
      );
      CREATE TABLE IF NOT EXISTS sync_accounts (
        account_id TEXT NOT NULL PRIMARY KEY,
        refresh_token_hash TEXT NOT NULL,
        password_hash TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS sync_access_tokens (
        token_hash TEXT NOT NULL PRIMARY KEY,
        account_id TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        revoked_at TEXT
      );
      CREATE TABLE IF NOT EXISTS sync_request_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT NOT NULL,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        account_id TEXT,
        device_id TEXT,
        status_code INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        error_code TEXT,
        created_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS sync_profile_grants (
        account_id TEXT NOT NULL,
        profile_id INTEGER NOT NULL,
        role TEXT NOT NULL DEFAULT 'owner',
        created_at TEXT NOT NULL,
        PRIMARY KEY (account_id, profile_id)
      );
      CREATE TABLE IF NOT EXISTS sync_records (
        account_id TEXT NOT NULL,
        resource TEXT NOT NULL,
        record_key TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        revision INTEGER NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        owner_device_id TEXT,
        created_at TEXT NOT NULL,
        server_updated_at TEXT NOT NULL,
        PRIMARY KEY (account_id, resource, record_key)
      );
      CREATE INDEX IF NOT EXISTS idx_sync_records_account_revision
        ON sync_records(account_id, resource, revision);
      CREATE INDEX IF NOT EXISTS idx_sync_request_logs_created
        ON sync_request_logs(created_at DESC);
    `);
    const accountColumns = this.exec('PRAGMA table_info(sync_accounts);', {
      json: true,
    }).map(row => row.name);
    if (!accountColumns.includes('password_hash')) {
      this.exec('ALTER TABLE sync_accounts ADD COLUMN password_hash TEXT;');
    }
  }

  exec(sql, { json = false } = {}) {
    const args = json ? ['-json', this.databasePath, sql] : [this.databasePath, sql];
    const result = spawnSync('sqlite3', args, { encoding: 'utf8' });
    if (result.status !== 0) {
      throw new Error(`SQLITE_ERROR: ${result.stderr || result.stdout}`);
    }
    if (!json) {
      return [];
    }
    const output = result.stdout.trim();
    return output ? JSON.parse(output) : [];
  }

  ensureAccount(accountId) {
    this.exec(`
      INSERT OR IGNORE INTO sync_meta (account_id, key, value)
      VALUES (${sqlString(accountId)}, 'global_revision', '0');
    `);
  }

  readAccount(accountId) {
    const rows = this.exec(
      `
        SELECT account_id, refresh_token_hash, password_hash
        FROM sync_accounts
        WHERE account_id = ${sqlString(accountId)}
        LIMIT 1;
      `,
      { json: true },
    );
    if (rows.length === 0) {
      return null;
    }
      return {
      accountId: rows[0].account_id,
      refreshTokenHash: rows[0].refresh_token_hash,
      passwordHash: rows[0].password_hash || null,
    };
  }

  upsertAccount(accountId, refreshTokenHash, passwordHash = null) {
    this.ensureAccount(accountId);
    const now = new Date().toISOString();
    this.exec(`
      INSERT INTO sync_accounts (
        account_id, refresh_token_hash, password_hash, created_at, updated_at
      )
      VALUES (
        ${sqlString(accountId)},
        ${sqlString(refreshTokenHash)},
        ${sqlString(passwordHash)},
        ${sqlString(now)},
        ${sqlString(now)}
      )
      ON CONFLICT(account_id) DO UPDATE SET
        refresh_token_hash = excluded.refresh_token_hash,
        password_hash = COALESCE(excluded.password_hash, sync_accounts.password_hash),
        updated_at = excluded.updated_at;
    `);
  }

  storeAccessToken(accountId, tokenHash, expiresAt) {
    this.ensureAccount(accountId);
    this.exec(`
      INSERT INTO sync_access_tokens (
        token_hash, account_id, expires_at, created_at, revoked_at
      )
      VALUES (
        ${sqlString(tokenHash)},
        ${sqlString(accountId)},
        ${sqlString(expiresAt)},
        ${sqlString(new Date().toISOString())},
        NULL
      );
    `);
  }

  revokeAccessToken(tokenHash) {
    this.exec(`
      UPDATE sync_access_tokens
      SET revoked_at = COALESCE(revoked_at, ${sqlString(new Date().toISOString())})
      WHERE token_hash = ${sqlString(tokenHash)};
    `);
  }

  revokeAccountAccessTokens(accountId) {
    this.exec(`
      UPDATE sync_access_tokens
      SET revoked_at = COALESCE(revoked_at, ${sqlString(new Date().toISOString())})
      WHERE account_id = ${sqlString(accountId)}
        AND revoked_at IS NULL;
    `);
  }

  deleteExpiredAccessTokens(nowIso = new Date().toISOString()) {
    this.exec(`
      DELETE FROM sync_access_tokens
      WHERE expires_at <= ${sqlString(nowIso)};
    `);
  }

  readAccessToken(tokenHash) {
    const rows = this.exec(
      `
        SELECT token_hash, account_id, expires_at, revoked_at
        FROM sync_access_tokens
        WHERE token_hash = ${sqlString(tokenHash)}
        LIMIT 1;
      `,
      { json: true },
    );
    if (rows.length === 0) {
      return null;
    }
    return {
      tokenHash: rows[0].token_hash,
      accountId: rows[0].account_id,
      expiresAt: rows[0].expires_at,
      revokedAt: rows[0].revoked_at || null,
    };
  }

  recordRequestLog(entry) {
    this.exec(`
      INSERT INTO sync_request_logs (
        request_id, method, path, account_id, device_id, status_code,
        duration_ms, error_code, created_at
      )
      VALUES (
        ${sqlString(entry.requestId)},
        ${sqlString(entry.method)},
        ${sqlString(entry.path)},
        ${sqlString(entry.accountId)},
        ${sqlString(entry.deviceId)},
        ${Number(entry.statusCode) || 0},
        ${Number(entry.durationMs) || 0},
        ${sqlString(entry.errorCode)},
        ${sqlString(entry.createdAt || new Date().toISOString())}
      );
    `);
  }

  fetchRequestLogs({
    limit = 50,
    offset = 0,
    accountId = null,
    requestId = null,
    statusCode = null,
    errorCode = null,
  } = {}) {
    const safeLimit = Math.max(1, Math.min(Number(limit) || 50, 200));
    const safeOffset = Math.max(0, Number(offset) || 0);
    const conditions = [];
    if (accountId) {
      conditions.push(`account_id = ${sqlString(accountId)}`);
    }
    if (requestId) {
      conditions.push(`request_id = ${sqlString(requestId)}`);
    }
    if (statusCode) {
      conditions.push(`status_code = ${Number(statusCode)}`);
    }
    if (errorCode) {
      conditions.push(`error_code = ${sqlString(errorCode)}`);
    }
    const whereClause =
      conditions.length === 0 ? '' : `WHERE ${conditions.join(' AND ')}`;
    return this.exec(
      `
        SELECT *
        FROM sync_request_logs
        ${whereClause}
        ORDER BY created_at DESC, id DESC
        LIMIT ${safeLimit} OFFSET ${safeOffset};
      `,
      { json: true },
    ).map(row => ({
      id: Number(row.id),
      requestId: row.request_id,
      method: row.method,
      path: row.path,
      accountId: row.account_id || null,
      deviceId: row.device_id || null,
      statusCode: Number(row.status_code),
      durationMs: Number(row.duration_ms),
      errorCode: row.error_code || null,
      createdAt: row.created_at,
    }));
  }

  pruneRequestLogs({ retain = 500, olderThan = null } = {}) {
    const safeRetain = Math.max(0, Number(retain) || 0);
    if (olderThan) {
      this.exec(`
        DELETE FROM sync_request_logs
        WHERE created_at < ${sqlString(olderThan)};
      `);
    }
    if (safeRetain === 0) {
      this.exec('DELETE FROM sync_request_logs;');
      return;
    }
    this.exec(`
      DELETE FROM sync_request_logs
      WHERE id NOT IN (
        SELECT id
        FROM sync_request_logs
        ORDER BY created_at DESC, id DESC
        LIMIT ${safeRetain}
      );
    `);
  }

  registerDevice(accountId, device) {
    this.ensureAccount(accountId);
    this.exec(`
      INSERT INTO sync_devices (
        account_id, device_id, platform, app_version, schema_version, last_seen_at
      )
      VALUES (
        ${sqlString(accountId)},
        ${sqlString(device.deviceId)},
        ${sqlString(device.platform)},
        ${sqlString(device.appVersion)},
        ${device.schemaVersion},
        ${sqlString(device.lastSeenAt)}
      )
      ON CONFLICT(account_id, device_id) DO UPDATE SET
        platform = excluded.platform,
        app_version = excluded.app_version,
        schema_version = excluded.schema_version,
        last_seen_at = excluded.last_seen_at;
    `);
    return device;
  }

  grantProfile(accountId, profileId, role = 'owner') {
    this.ensureAccount(accountId);
    this.exec(`
      INSERT INTO sync_profile_grants (account_id, profile_id, role, created_at)
      VALUES (
        ${sqlString(accountId)},
        ${profileId},
        ${sqlString(role)},
        ${sqlString(new Date().toISOString())}
      )
      ON CONFLICT(account_id, profile_id) DO UPDATE SET
        role = excluded.role;
    `);
  }

  listProfileGrants(accountId) {
    this.ensureAccount(accountId);
    return this.exec(
      `
        SELECT profile_id
        FROM sync_profile_grants
        WHERE account_id = ${sqlString(accountId)}
        ORDER BY profile_id ASC;
      `,
      { json: true },
    ).map(row => Number(row.profile_id));
  }

  nextRevision(accountId) {
    this.ensureAccount(accountId);
    this.exec(`
      UPDATE sync_meta
      SET value = CAST(CAST(value AS INTEGER) + 1 AS TEXT)
      WHERE account_id = ${sqlString(accountId)}
        AND key = 'global_revision';
    `);
    return this.currentRevision(accountId);
  }

  currentRevision(accountId) {
    this.ensureAccount(accountId);
    const rows = this.exec(
      `
        SELECT value
        FROM sync_meta
        WHERE account_id = ${sqlString(accountId)}
          AND key = 'global_revision';
      `,
      { json: true },
    );
    return Number(rows[0]?.value || 0);
  }

  readRecord(accountId, resource, key) {
    const rows = this.exec(
      `
        SELECT *
        FROM sync_records
        WHERE account_id = ${sqlString(accountId)}
          AND resource = ${sqlString(resource)}
          AND record_key = ${sqlString(key)}
        LIMIT 1;
      `,
      { json: true },
    );
    if (rows.length === 0) {
      return null;
    }
    const row = rows[0];
    return {
      accountId: row.account_id,
      resource: row.resource,
      recordKey: row.record_key,
      payload: JSON.parse(row.payload_json),
      revision: Number(row.revision),
      updatedAt: row.updated_at || null,
      deletedAt: row.deleted_at || null,
      isDeleted: Number(row.is_deleted) === 1,
      ownerDeviceId: row.owner_device_id || null,
    };
  }

  upsertRecord(accountId, resource, key, item, metadata, device) {
    const revision = this.nextRevision(accountId);
    const now = new Date().toISOString();
    this.exec(`
      INSERT INTO sync_records (
        account_id,
        resource,
        record_key,
        payload_json,
        revision,
        updated_at,
        deleted_at,
        is_deleted,
        owner_device_id,
        created_at,
        server_updated_at
      )
      VALUES (
        ${sqlString(accountId)},
        ${sqlString(resource)},
        ${sqlString(key)},
        ${sqlString(JSON.stringify(item))},
        ${revision},
        ${sqlString(metadata.updatedAt)},
        ${sqlString(metadata.deletedAt)},
        ${metadata.isDeleted ? 1 : 0},
        ${sqlString(device.deviceId)},
        ${sqlString(now)},
        ${sqlString(now)}
      )
      ON CONFLICT(account_id, resource, record_key) DO UPDATE SET
        payload_json = excluded.payload_json,
        revision = excluded.revision,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at,
        is_deleted = excluded.is_deleted,
        owner_device_id = excluded.owner_device_id,
        server_updated_at = excluded.server_updated_at;
    `);
  }

  pullRecords(accountId, resource, fromRevision) {
    return this.exec(
      `
        SELECT payload_json
        FROM sync_records
        WHERE account_id = ${sqlString(accountId)}
          AND resource = ${sqlString(resource)}
          AND revision > ${fromRevision}
        ORDER BY revision ASC;
      `,
      { json: true },
    ).map(row => JSON.parse(row.payload_json));
  }
}

function sqlString(value) {
  if (value === null || value === undefined) {
    return 'NULL';
  }
  return `'${String(value).replace(/'/g, "''")}'`;
}

module.exports = {
  SqliteSyncStore,
};
