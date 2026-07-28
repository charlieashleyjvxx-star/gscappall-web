const postgresSchemaSql = `
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
  last_seen_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (account_id, device_id)
);

CREATE TABLE IF NOT EXISTS sync_accounts (
  account_id TEXT NOT NULL PRIMARY KEY,
  refresh_token_hash TEXT NOT NULL,
  password_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_access_tokens (
  token_hash TEXT NOT NULL PRIMARY KEY,
  account_id TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS sync_request_logs (
  id BIGSERIAL PRIMARY KEY,
  request_id TEXT NOT NULL,
  method TEXT NOT NULL,
  path TEXT NOT NULL,
  account_id TEXT,
  device_id TEXT,
  status_code INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  error_code TEXT,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_profile_grants (
  account_id TEXT NOT NULL,
  profile_id INTEGER NOT NULL,
  role TEXT NOT NULL DEFAULT 'owner',
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (account_id, profile_id)
);

CREATE TABLE IF NOT EXISTS sync_records (
  account_id TEXT NOT NULL,
  resource TEXT NOT NULL,
  record_key TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  revision BIGINT NOT NULL,
  updated_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  owner_device_id TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  server_updated_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (account_id, resource, record_key)
);

CREATE INDEX IF NOT EXISTS idx_sync_records_account_revision
  ON sync_records(account_id, resource, revision);

CREATE INDEX IF NOT EXISTS idx_sync_request_logs_created
  ON sync_request_logs(created_at DESC);
`;

class PostgresSyncStore {
  constructor({ connectionString, pool } = {}) {
    if (!pool && !connectionString) {
      throw new Error('POSTGRES_URL_REQUIRED');
    }
    const { Pool } = require('pg');
    this.pool =
      pool ||
      new Pool({
        connectionString,
      });
  }

  async init() {
    await this.pool.query(postgresSchemaSql);
    await this.pool.query(
      'ALTER TABLE sync_accounts ADD COLUMN IF NOT EXISTS password_hash TEXT;',
    );
  }

  async ensureAccount(accountId) {
    await this.pool.query(
      `
      INSERT INTO sync_meta (account_id, key, value)
      VALUES ($1, 'global_revision', '0')
      ON CONFLICT (account_id, key) DO NOTHING;
      `,
      [accountId],
    );
  }

  async readAccount(accountId) {
    const result = await this.pool.query(
      `
      SELECT account_id, refresh_token_hash, password_hash
      FROM sync_accounts
      WHERE account_id = $1
      LIMIT 1;
      `,
      [accountId],
    );
    if (result.rows.length === 0) {
      return null;
    }
    const row = result.rows[0];
    return {
      accountId: row.account_id,
      refreshTokenHash: row.refresh_token_hash,
      passwordHash: row.password_hash || null,
    };
  }

  async upsertAccount(accountId, refreshTokenHash, passwordHash = null) {
    await this.ensureAccount(accountId);
    await this.pool.query(
      `
      INSERT INTO sync_accounts (
        account_id, refresh_token_hash, password_hash, created_at, updated_at
      )
      VALUES ($1, $2, $3, NOW(), NOW())
      ON CONFLICT (account_id) DO UPDATE SET
        refresh_token_hash = EXCLUDED.refresh_token_hash,
        password_hash = COALESCE(EXCLUDED.password_hash, sync_accounts.password_hash),
        updated_at = EXCLUDED.updated_at;
      `,
      [accountId, refreshTokenHash, passwordHash],
    );
  }

  async storeAccessToken(accountId, tokenHash, expiresAt) {
    await this.ensureAccount(accountId);
    await this.pool.query(
      `
      INSERT INTO sync_access_tokens (
        token_hash, account_id, expires_at, created_at, revoked_at
      )
      VALUES ($1, $2, $3, NOW(), NULL);
      `,
      [tokenHash, accountId, expiresAt],
    );
  }

  async revokeAccessToken(tokenHash) {
    await this.pool.query(
      `
      UPDATE sync_access_tokens
      SET revoked_at = COALESCE(revoked_at, NOW())
      WHERE token_hash = $1;
      `,
      [tokenHash],
    );
  }

  async revokeAccountAccessTokens(accountId) {
    await this.pool.query(
      `
      UPDATE sync_access_tokens
      SET revoked_at = COALESCE(revoked_at, NOW())
      WHERE account_id = $1 AND revoked_at IS NULL;
      `,
      [accountId],
    );
  }

  async deleteExpiredAccessTokens(nowIso = new Date().toISOString()) {
    await this.pool.query(
      `
      DELETE FROM sync_access_tokens
      WHERE expires_at <= $1;
      `,
      [nowIso],
    );
  }

  async readAccessToken(tokenHash) {
    const result = await this.pool.query(
      `
      SELECT token_hash, account_id, expires_at, revoked_at
      FROM sync_access_tokens
      WHERE token_hash = $1
      LIMIT 1;
      `,
      [tokenHash],
    );
    if (result.rows.length === 0) {
      return null;
    }
    const row = result.rows[0];
    return {
      tokenHash: row.token_hash,
      accountId: row.account_id,
      expiresAt: row.expires_at?.toISOString?.() || row.expires_at,
      revokedAt: row.revoked_at?.toISOString?.() || row.revoked_at || null,
    };
  }

  async recordRequestLog(entry) {
    await this.pool.query(
      `
      INSERT INTO sync_request_logs (
        request_id, method, path, account_id, device_id, status_code,
        duration_ms, error_code, created_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);
      `,
      [
        entry.requestId,
        entry.method,
        entry.path,
        entry.accountId || null,
        entry.deviceId || null,
        Number(entry.statusCode) || 0,
        Number(entry.durationMs) || 0,
        entry.errorCode || null,
        entry.createdAt || new Date().toISOString(),
      ],
    );
  }

  async fetchRequestLogs({
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
    const params = [];
    if (accountId) {
      params.push(accountId);
      conditions.push(`account_id = $${params.length}`);
    }
    if (requestId) {
      params.push(requestId);
      conditions.push(`request_id = $${params.length}`);
    }
    if (statusCode) {
      params.push(Number(statusCode));
      conditions.push(`status_code = $${params.length}`);
    }
    if (errorCode) {
      params.push(errorCode);
      conditions.push(`error_code = $${params.length}`);
    }
    params.push(safeLimit);
    params.push(safeOffset);
    const whereClause =
      conditions.length === 0 ? '' : `WHERE ${conditions.join(' AND ')}`;
    const result = await this.pool.query(
      `
      SELECT *
      FROM sync_request_logs
      ${whereClause}
      ORDER BY created_at DESC, id DESC
      LIMIT $${params.length - 1} OFFSET $${params.length};
      `,
      params,
    );
    return result.rows.map(row => ({
      id: Number(row.id),
      requestId: row.request_id,
      method: row.method,
      path: row.path,
      accountId: row.account_id || null,
      deviceId: row.device_id || null,
      statusCode: Number(row.status_code),
      durationMs: Number(row.duration_ms),
      errorCode: row.error_code || null,
      createdAt: row.created_at?.toISOString?.() || row.created_at,
    }));
  }

  async pruneRequestLogs({ retain = 500, olderThan = null } = {}) {
    const safeRetain = Math.max(0, Number(retain) || 0);
    if (olderThan) {
      await this.pool.query(
        `
        DELETE FROM sync_request_logs
        WHERE created_at < $1;
        `,
        [olderThan],
      );
    }
    if (safeRetain === 0) {
      await this.pool.query('DELETE FROM sync_request_logs;');
      return;
    }
    await this.pool.query(
      `
      DELETE FROM sync_request_logs
      WHERE id NOT IN (
        SELECT id
        FROM sync_request_logs
        ORDER BY created_at DESC, id DESC
        LIMIT $1
      );
      `,
      [safeRetain],
    );
  }

  async registerDevice(accountId, device) {
    await this.ensureAccount(accountId);
    await this.pool.query(
      `
      INSERT INTO sync_devices (
        account_id, device_id, platform, app_version, schema_version, last_seen_at
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (account_id, device_id) DO UPDATE SET
        platform = EXCLUDED.platform,
        app_version = EXCLUDED.app_version,
        schema_version = EXCLUDED.schema_version,
        last_seen_at = EXCLUDED.last_seen_at;
      `,
      [
        accountId,
        device.deviceId,
        device.platform,
        device.appVersion,
        device.schemaVersion,
        device.lastSeenAt,
      ],
    );
    return device;
  }

  async grantProfile(accountId, profileId, role = 'owner') {
    await this.ensureAccount(accountId);
    await this.pool.query(
      `
      INSERT INTO sync_profile_grants (account_id, profile_id, role, created_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (account_id, profile_id) DO UPDATE SET role = EXCLUDED.role;
      `,
      [accountId, profileId, role],
    );
  }

  async listProfileGrants(accountId) {
    await this.ensureAccount(accountId);
    const result = await this.pool.query(
      `
      SELECT profile_id
      FROM sync_profile_grants
      WHERE account_id = $1
      ORDER BY profile_id ASC;
      `,
      [accountId],
    );
    return result.rows.map(row => Number(row.profile_id));
  }

  async nextRevision(accountId) {
    await this.ensureAccount(accountId);
    const result = await this.pool.query(
      `
      UPDATE sync_meta
      SET value = (value::BIGINT + 1)::TEXT
      WHERE account_id = $1 AND key = 'global_revision'
      RETURNING value;
      `,
      [accountId],
    );
    return Number(result.rows[0]?.value || 0);
  }

  async currentRevision(accountId) {
    await this.ensureAccount(accountId);
    const result = await this.pool.query(
      `
      SELECT value
      FROM sync_meta
      WHERE account_id = $1 AND key = 'global_revision';
      `,
      [accountId],
    );
    return Number(result.rows[0]?.value || 0);
  }

  async readRecord(accountId, resource, key) {
    const result = await this.pool.query(
      `
      SELECT *
      FROM sync_records
      WHERE account_id = $1 AND resource = $2 AND record_key = $3
      LIMIT 1;
      `,
      [accountId, resource, key],
    );
    if (result.rows.length === 0) {
      return null;
    }
    const row = result.rows[0];
    return {
      accountId: row.account_id,
      resource: row.resource,
      recordKey: row.record_key,
      payload: row.payload_json,
      revision: Number(row.revision),
      updatedAt: row.updated_at?.toISOString?.() || row.updated_at || null,
      deletedAt: row.deleted_at?.toISOString?.() || row.deleted_at || null,
      isDeleted: Boolean(row.is_deleted),
      ownerDeviceId: row.owner_device_id || null,
    };
  }

  async upsertRecord(accountId, resource, key, item, metadata, device) {
    const revision = await this.nextRevision(accountId);
    await this.pool.query(
      `
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
      VALUES ($1, $2, $3, $4::jsonb, $5, $6, $7, $8, $9, NOW(), NOW())
      ON CONFLICT (account_id, resource, record_key) DO UPDATE SET
        payload_json = EXCLUDED.payload_json,
        revision = EXCLUDED.revision,
        updated_at = EXCLUDED.updated_at,
        deleted_at = EXCLUDED.deleted_at,
        is_deleted = EXCLUDED.is_deleted,
        owner_device_id = EXCLUDED.owner_device_id,
        server_updated_at = EXCLUDED.server_updated_at;
      `,
      [
        accountId,
        resource,
        key,
        JSON.stringify(item),
        revision,
        metadata.updatedAt,
        metadata.deletedAt,
        metadata.isDeleted,
        device.deviceId,
      ],
    );
  }

  async pullRecords(accountId, resource, fromRevision) {
    const result = await this.pool.query(
      `
      SELECT payload_json
      FROM sync_records
      WHERE account_id = $1 AND resource = $2 AND revision > $3
      ORDER BY revision ASC;
      `,
      [accountId, resource, fromRevision],
    );
    return result.rows.map(row => row.payload_json);
  }
}

module.exports = {
  PostgresSyncStore,
  postgresSchemaSql,
};
