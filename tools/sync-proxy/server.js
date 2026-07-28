const http = require('http');
const crypto = require('crypto');
const path = require('path');

const { SqliteSyncStore } = require('./adapters/sqlite_adapter');
const { PostgresSyncStore } = require('./adapters/postgres_adapter');

const port = Number(process.env.PORT || 8790);
const requireAuth = process.env.SYNC_PROXY_REQUIRE_AUTH !== 'false';
const accessTokenTtlHours = Number(process.env.SYNC_PROXY_ACCESS_TOKEN_TTL_HOURS || 24);
const rateLimitWindowMs = Number(process.env.SYNC_PROXY_RATE_LIMIT_WINDOW_MS || 60_000);
const rateLimitMaxRequests = Number(process.env.SYNC_PROXY_RATE_LIMIT_MAX || 120);
const databasePath =
  process.env.SYNC_PROXY_DB || path.join(__dirname, 'sync-proxy.sqlite');
const storeKind = process.env.SYNC_PROXY_STORE || 'sqlite';
const maxBatchSize = Number(process.env.SYNC_PROXY_MAX_BATCH_SIZE || 500);
const store =
  storeKind === 'postgres'
    ? new PostgresSyncStore({
        connectionString: process.env.SYNC_PROXY_POSTGRES_URL,
      })
    : new SqliteSyncStore(databasePath);

const batchKeyToResource = {
  poems: 'poems',
  favorites: 'favorites',
  learningRecords: 'learning_records',
  studyCardProgress: 'study_card_progress',
  reciteRecords: 'recite_records',
  wrongQuestions: 'wrong_questions',
  practiceReports: 'practice_reports',
  dailyPoemRecords: 'daily_poem_records',
  userPoints: 'user_points',
  challengeStageRewards: 'challenge_stage_rewards',
  settings: 'settings',
  userProfiles: 'user_profiles',
};

const resourceToBatchKey = Object.fromEntries(
  Object.entries(batchKeyToResource).map(([batchKey, resource]) => [
    resource,
    batchKey,
  ]),
);

const supportedPolicies = {
  poems: 'server_authoritative',
  favorites: 'soft_delete',
  learning_records: 'append_only',
  study_card_progress: 'server_merge_suggested',
  recite_records: 'append_only',
  wrong_questions: 'server_merge_suggested',
  practice_reports: 'append_only',
  daily_poem_records: 'last_write_wins',
  user_points: 'server_merge_suggested',
  challenge_stage_rewards: 'server_merge_suggested',
  settings: 'server_merge_suggested',
  user_profiles: 'server_merge_suggested',
};

const storeTarget =
  storeKind === 'postgres'
    ? process.env.SYNC_PROXY_POSTGRES_URL || 'postgres'
    : databasePath;

const rateBuckets = new Map();

function requestIdFrom(request) {
  return (
    request.headers['x-request-id'] ||
    request.headers['x-gsc-request-id'] ||
    crypto.randomBytes(8).toString('hex')
  );
}

function requestIp(request) {
  return String(
    request.headers['x-forwarded-for'] ||
      request.socket?.remoteAddress ||
      'unknown',
  ).split(',')[0].trim();
}

function checkRateLimit(request) {
  const key = `${requestIp(request)}:${tokenHash(tokenFrom(request) || 'anonymous')}`;
  const now = Date.now();
  const existing = rateBuckets.get(key);
  if (!existing || now >= existing.resetAt) {
    rateBuckets.set(key, { count: 1, resetAt: now + rateLimitWindowMs });
    return;
  }
  existing.count += 1;
  if (existing.count > rateLimitMaxRequests) {
    const error = new Error('Too many requests.');
    error.code = 'RATE_LIMITED';
    error.statusCode = 429;
    error.retryAfterSeconds = Math.ceil((existing.resetAt - now) / 1000);
    throw error;
  }
}

function pruneRateBuckets() {
  const now = Date.now();
  for (const [key, bucket] of rateBuckets.entries()) {
    if (now >= bucket.resetAt) {
      rateBuckets.delete(key);
    }
  }
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.on('data', chunk => {
      body += chunk;
      if (body.length > 10 * 1024 * 1024) {
        reject(new Error('PAYLOAD_TOO_LARGE'));
        request.destroy();
      }
    });
    request.on('end', () => {
      if (!body.trim()) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch (error) {
        reject(new Error(`INVALID_JSON: ${error.message}`));
      }
    });
    request.on('error', reject);
  });
}

function sendJson(response, statusCode, payload) {
  const text = JSON.stringify(payload);
  response.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(text),
  });
  response.end(text);
}

function sendError(
  response,
  statusCode,
  code,
  message,
  retryable = false,
  details = {},
) {
  sendJson(response, statusCode, {
    error: { code, message, retryable, details },
  });
}

function tokenFrom(request) {
  const header = request.headers.authorization || '';
  if (header.startsWith('Bearer ')) {
    return header.substring(7);
  }
  return '';
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

function passwordHash(password, salt = crypto.randomBytes(16).toString('hex')) {
  const digest = crypto
    .pbkdf2Sync(String(password), salt, 120000, 32, 'sha256')
    .toString('hex');
  return `pbkdf2_sha256$120000$${salt}$${digest}`;
}

function verifyPassword(password, storedHash) {
  const parts = String(storedHash || '').split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2_sha256') {
    return false;
  }
  const rounds = Number(parts[1]);
  const salt = parts[2];
  const expected = parts[3];
  const actual = crypto
    .pbkdf2Sync(String(password), salt, rounds, 32, 'sha256')
    .toString('hex');
  return crypto.timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
}

function authError(code, message, statusCode = 401) {
  const error = new Error(message);
  error.code = code;
  error.statusCode = statusCode;
  return error;
}

async function authenticate(request) {
  if (!requireAuth) {
    return { accountId: await accountIdFrom(request) };
  }
  const token = tokenFrom(request);
  if (!token) {
    throw authError('UNAUTHORIZED', 'Missing bearer token.');
  }
  const session = await store.readAccessToken(tokenHash(token));
  if (!session || session.revokedAt) {
    throw authError('UNAUTHORIZED', 'Invalid bearer token.');
  }
  if (Date.parse(session.expiresAt) <= Date.now()) {
    if (store.revokeAccessToken) {
      await store.revokeAccessToken(tokenHash(token));
    }
    throw authError('UNAUTHORIZED', 'Expired bearer token.');
  }
  const headerAccount = request.headers['x-gsc-account-id'];
  if (headerAccount && String(headerAccount) !== session.accountId) {
    throw authError(
      'ACCOUNT_FORBIDDEN',
      'Bearer token does not belong to the requested account.',
      403,
    );
  }
  return { accountId: session.accountId };
}

async function issueAccountSession(accountId, { rotateRefreshToken = true } = {}) {
  if (store.deleteExpiredAccessTokens) {
    await store.deleteExpiredAccessTokens();
  }
  const refreshToken = rotateRefreshToken
    ? crypto.randomBytes(32).toString('hex')
    : null;
  if (refreshToken) {
    await store.upsertAccount(accountId, tokenHash(refreshToken));
  }
  const accessToken = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(
    Date.now() + accessTokenTtlHours * 60 * 60 * 1000,
  ).toISOString();
  await store.storeAccessToken(accountId, tokenHash(accessToken), expiresAt);
  return {
    accountId,
    accessToken,
    ...(refreshToken ? { refreshToken } : {}),
    expiresAt,
    profileIds: await store.listProfileGrants(accountId),
  };
}

async function accountIdFrom(request) {
  const headerAccount = request.headers['x-gsc-account-id'];
  if (headerAccount) {
    return String(headerAccount);
  }
  const token = tokenFrom(request) || 'anonymous';
  return `account-${crypto.createHash('sha1').update(token).digest('hex').slice(0, 16)}`;
}

async function refreshAccountSession(payload = {}) {
  const accountId = String(payload.accountId || '').trim();
  const refreshToken = String(payload.refreshToken || '').trim();
  if (!accountId) {
    throw authError('ACCOUNT_REQUIRED', 'accountId is required.', 400);
  }
  if (!refreshToken) {
    throw authError('REFRESH_TOKEN_REQUIRED', 'refreshToken is required.', 400);
  }

  const hashedRefreshToken = tokenHash(refreshToken);
  const account = await store.readAccount(accountId);
  if (!account) {
    throw authError('ACCOUNT_NOT_FOUND', 'Account does not exist.', 404);
  } else if (account.refreshTokenHash !== hashedRefreshToken) {
    throw authError('INVALID_REFRESH_TOKEN', 'Refresh token is invalid.');
  }

  return issueAccountSession(accountId, { rotateRefreshToken: true });
}

function profileIdsOf(payload) {
  const ids = Array.isArray(payload.profileIds)
    ? payload.profileIds.map(item => Number(item)).filter(Number.isInteger)
    : [1];
  return [...new Set(ids.length > 0 ? ids : [1])];
}

async function registerAccount(payload = {}) {
  const accountId = String(payload.accountId || '').trim();
  const password = String(payload.password || '').trim();
  if (!accountId) {
    throw authError('ACCOUNT_REQUIRED', 'accountId is required.', 400);
  }
  if (password.length < 6) {
    throw authError(
      'WEAK_PASSWORD',
      'Password must contain at least 6 characters.',
      400,
    );
  }
  const existing = await store.readAccount(accountId);
  if (existing) {
    throw authError('ACCOUNT_EXISTS', 'Account already exists.', 409);
  }
  await store.upsertAccount(
    accountId,
    tokenHash(crypto.randomBytes(32).toString('hex')),
    passwordHash(password),
  );
  for (const profileId of profileIdsOf(payload)) {
    await store.grantProfile(accountId, profileId, 'owner');
  }
  return issueAccountSession(accountId, { rotateRefreshToken: true });
}

async function loginAccount(payload = {}) {
  const accountId = String(payload.accountId || '').trim();
  const password = String(payload.password || '').trim();
  if (!accountId || !password) {
    throw authError(
      'LOGIN_REQUIRED',
      'accountId and password are required.',
      400,
    );
  }
  const account = await store.readAccount(accountId);
  if (!account || !verifyPassword(password, account.passwordHash)) {
    throw authError('INVALID_CREDENTIALS', 'Account or password is invalid.');
  }
  return issueAccountSession(accountId, { rotateRefreshToken: true });
}

async function logoutAccount(request, accountId) {
  const token = tokenFrom(request);
  if (token && store.revokeAccessToken) {
    await store.revokeAccessToken(tokenHash(token));
  }
  const payload = await readJson(request);
  if (payload.revokeAll === true && store.revokeAccountAccessTokens) {
    await store.revokeAccountAccessTokens(accountId);
  }
  return {
    accountId,
    revoked: true,
    serverTime: new Date().toISOString(),
  };
}

function requestedProfileIdsFrom(request) {
  const raw = request.headers['x-gsc-profile-ids'];
  if (!raw) return [];
  const ids = String(raw)
    .split(',')
    .map(item => Number(item.trim()))
    .filter(item => Number.isInteger(item));
  return ids;
}

async function authorizedProfileIdsFrom(accountId, request) {
  const granted = await store.listProfileGrants(accountId);
  const requested = requestedProfileIdsFrom(request);
  if (granted.length === 0 && requested.length === 0) {
    return null;
  }
  const grantedSet = new Set(granted);
  if (requested.length === 0) {
    return grantedSet;
  }
  const unauthorized = requested.filter(profileId => !grantedSet.has(profileId));
  if (unauthorized.length > 0) {
    const error = new Error(`PROFILE_FORBIDDEN: ${unauthorized.join(',')}`);
    error.statusCode = 403;
    error.code = 'PROFILE_FORBIDDEN';
    throw error;
  }
  return new Set(requested);
}

function deviceFrom(request, payload = {}) {
  const bodyDevice = payload.device || {};
  const deviceId =
    request.headers['x-gsc-device-id'] ||
    bodyDevice.deviceId ||
    'unknown-device';
  return {
    deviceId: String(deviceId),
    platform: String(
      request.headers['x-gsc-platform'] || bodyDevice.platform || 'unknown',
    ),
    appVersion: String(
      request.headers['x-gsc-app-version'] || bodyDevice.appVersion || 'dev',
    ),
    schemaVersion: Number(
      request.headers['x-gsc-schema-version'] || bodyDevice.schemaVersion || 1,
    ),
    lastSeenAt: new Date().toISOString(),
  };
}

function profileIdOf(item) {
  if (item.profileId === undefined || item.profileId === null) {
    return null;
  }
  const profileId = Number(item.profileId);
  return Number.isInteger(profileId) ? profileId : null;
}

function assertProfileAuthorized(resource, item, authorizedProfileIds) {
  if (authorizedProfileIds === null) {
    return;
  }
  const profileId = profileIdOf(item);
  if (profileId === null) {
    return;
  }
  if (!authorizedProfileIds.has(profileId)) {
    const error = new Error(`PROFILE_FORBIDDEN: ${resource}/${profileId}`);
    error.statusCode = 403;
    error.code = 'PROFILE_FORBIDDEN';
    throw error;
  }
}

function recordKey(resource, item) {
  if (item.recordKey) {
    return String(item.recordKey);
  }
  if (item.id !== undefined && item.id !== null) {
    return `${resource}:${item.id}`;
  }
  const hash = crypto.createHash('sha1').update(JSON.stringify(item)).digest('hex');
  return `${resource}:${hash}`;
}

function metadataOf(item) {
  const metadata = item.metadata || {};
  return {
    updatedAt:
      metadata.updatedAt || item.updatedAt || metadata.createdAt || item.createdAt || null,
    deletedAt: metadata.deletedAt || item.deletedAt || null,
    isDeleted: Boolean(metadata.isDeleted || item.isDeleted),
  };
}

function compareTime(left, right) {
  const leftMs = left ? Date.parse(left) : 0;
  const rightMs = right ? Date.parse(right) : 0;
  if (leftMs > rightMs) return 1;
  if (leftMs < rightMs) return -1;
  return 0;
}

function buildConflict({
  resource,
  key,
  policy,
  localPayload,
  remote,
  winner,
  reason,
  mergedPayload = null,
  fields = [],
}) {
  return {
    resource,
    recordKey: key,
    mergePolicy: policy,
    recommendedWinner: winner,
    localPayload,
    remotePayload: remote ? remote.payload : null,
    mergedPayload,
    fieldsInConflict: fields,
    reason,
  };
}

async function evaluateConflict(accountId, resource, item, device) {
  const key = recordKey(resource, item);
  const policy = supportedPolicies[resource] || 'last_write_wins';
  const remote = await store.readRecord(accountId, resource, key);
  if (!remote) {
    return { key, policy, remote, accept: true, conflict: null };
  }
  if (remote.ownerDeviceId === device.deviceId) {
    return { key, policy, remote, accept: true, conflict: null };
  }

  const incoming = metadataOf(item);
  if (policy === 'last_write_wins') {
    const remoteTime = remote.updatedAt || remote.deletedAt;
    const incomingTime = incoming.updatedAt || incoming.deletedAt;
    if (compareTime(remoteTime, incomingTime) > 0) {
      return {
        key,
        policy,
        remote,
        accept: false,
        conflict: buildConflict({
          resource,
          key,
          policy,
          localPayload: item,
          remote,
          winner: 'remote',
          reason: 'Remote record is newer by updatedAt.',
          fields: ['updatedAt'],
        }),
      };
    }
    return { key, policy, remote, accept: true, conflict: null };
  }

  if (policy === 'soft_delete') {
    const remoteDeleteWins =
      remote.isDeleted &&
      compareTime(
        remote.deletedAt || remote.updatedAt,
        incoming.deletedAt || incoming.updatedAt,
      ) >= 0;
    if (remoteDeleteWins) {
      return {
        key,
        policy,
        remote,
        accept: false,
        conflict: buildConflict({
          resource,
          key,
          policy,
          localPayload: item,
          remote,
          winner: 'remote',
          reason: 'Remote tombstone is newer or equal.',
          fields: ['isDeleted', 'deletedAt'],
        }),
      };
    }
    return { key, policy, remote, accept: true, conflict: null };
  }

  if (policy === 'server_merge_suggested') {
    const mergedPayload = {
      ...remote.payload,
      ...item,
      metadata: {
        ...(remote.payload.metadata || {}),
        ...(item.metadata || {}),
        lastActorDeviceId: device.deviceId,
      },
    };
    return {
      key,
      policy,
      remote,
      accept: false,
      conflict: buildConflict({
        resource,
        key,
        policy,
        localPayload: item,
        remote,
        winner: 'merged',
        mergedPayload,
        reason: 'Server merge is suggested for this resource.',
        fields: ['payload'],
      }),
    };
  }

  return { key, policy, remote, accept: true, conflict: null };
}

async function acceptBatch(
  accountId,
  batch = {},
  device,
  { dryRun = false, authorizedProfileIds = null } = {},
) {
  const acceptedCounts = {};
  const conflicts = [];
  for (const [batchKey, resource] of Object.entries(batchKeyToResource)) {
    const items = Array.isArray(batch[batchKey]) ? batch[batchKey] : [];
    let accepted = 0;
    for (const item of items) {
      assertProfileAuthorized(resource, item, authorizedProfileIds);
      const result = await evaluateConflict(accountId, resource, item, device);
      if (result.conflict) {
        conflicts.push(result.conflict);
        continue;
      }
      if (!dryRun && result.accept) {
        await store.upsertRecord(
          accountId,
          resource,
          result.key,
          item,
          metadataOf(item),
          device,
        );
      }
      if (result.accept) {
        accepted += 1;
      }
    }
    if (accepted > 0) {
      acceptedCounts[resource] = accepted;
    }
  }
  return { acceptedCounts, conflicts };
}

function countBatchItems(batch = {}) {
  return Object.keys(batchKeyToResource).reduce((total, batchKey) => {
    const items = Array.isArray(batch[batchKey]) ? batch[batchKey] : [];
    return total + items.length;
  }, 0);
}

function assertBatchSize(batch = {}) {
  const total = countBatchItems(batch);
  if (total > maxBatchSize) {
    const error = new Error(
      `Batch contains ${total} records, max is ${maxBatchSize}.`,
    );
    error.code = 'BATCH_TOO_LARGE';
    error.statusCode = 413;
    throw error;
  }
}

async function checkpoint(accountId) {
  const revision = await store.currentRevision(accountId);
  const cursors = {};
  for (const resource of Object.values(batchKeyToResource)) {
    cursors[resource] = String(revision);
  }
  return {
    globalCursor: String(revision),
    collectionCursors: cursors,
    lastSuccessfulSyncAt: new Date().toISOString(),
    schemaVersion: 10,
  };
}

async function pullBatch(accountId, requestCheckpoint = {}, authorizedProfileIds = null) {
  const batch = {};
  const receivedCounts = {};
  const cursors = requestCheckpoint.collectionCursors || {};
  for (const resource of Object.values(batchKeyToResource)) {
    const fromRevision = Number(cursors[resource] || 0);
    const records = (await store
      .pullRecords(accountId, resource, fromRevision))
      .filter(item => {
        if (authorizedProfileIds === null) {
          return true;
        }
        const profileId = profileIdOf(item);
        return profileId === null || authorizedProfileIds.has(profileId);
      });
    if (records.length > 0) {
      const batchKey = resourceToBatchKey[resource];
      batch[batchKey] = records;
      receivedCounts[resource] = records.length;
    }
  }
  return { batch, receivedCounts };
}

function capabilities() {
  return {
    supportsPoemCatalog: true,
    supportsSoftDelete: true,
    supportsFieldMerge: true,
    maxBatchSize,
    supportedPolicies,
    notes: [`sync-proxy ${storeKind} store: ${storeTarget}`],
  };
}

const server = http.createServer(async (request, response) => {
  const startedAt = Date.now();
  const requestId = requestIdFrom(request);
  let logAccountId = null;
  let logDeviceId = request.headers['x-gsc-device-id'] || null;
  let statusCode = 200;
  let errorCode = null;
  try {
    checkRateLimit(request);
    const url = new URL(request.url, `http://${request.headers.host}`);

    if (request.method === 'GET' && url.pathname === '/health') {
      const accountId = await accountIdFrom(request);
      sendJson(response, 200, {
        ok: true,
        service: 'sync-proxy',
        authRequired: requireAuth,
        storeTarget,
        storeKind,
        maxBatchSize,
        accountId,
        globalRevision: await store.currentRevision(accountId),
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/auth/register') {
      const payload = await readJson(request);
      sendJson(response, 201, await registerAccount(payload));
      return;
    }

    if (request.method === 'POST' && url.pathname === '/auth/login') {
      const payload = await readJson(request);
      sendJson(response, 200, await loginAccount(payload));
      return;
    }

    if (request.method === 'POST' && url.pathname === '/auth/refresh') {
      const payload = await readJson(request);
      sendJson(response, 200, await refreshAccountSession(payload));
      return;
    }

    const authContext = await authenticate(request);
    const accountId = authContext.accountId;
    logAccountId = accountId;

    if (request.method === 'POST' && url.pathname === '/devices/register') {
      const payload = await readJson(request);
      const device = await store.registerDevice(accountId, deviceFrom(request, payload));
      logDeviceId = device.deviceId;
      sendJson(response, 200, {
        accountId,
        device,
        serverTime: new Date().toISOString(),
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/auth/logout') {
      sendJson(response, 200, await logoutAccount(request, accountId));
      return;
    }

    if (request.method === 'GET' && url.pathname === '/debug/request-logs') {
      const limit = Number(url.searchParams.get('limit') || 50);
      const offset = Number(url.searchParams.get('offset') || 0);
      const requestId = url.searchParams.get('requestId');
      const statusCode = url.searchParams.get('statusCode');
      const errorCode = url.searchParams.get('errorCode');
      const logs = await store.fetchRequestLogs?.({
        limit,
        offset,
        accountId,
        requestId,
        statusCode,
        errorCode,
      });
      sendJson(response, 200, {
        items: logs || [],
        limit,
        offset,
        serverTime: new Date().toISOString(),
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/debug/request-logs/prune') {
      const payload = await readJson(request);
      await store.pruneRequestLogs?.({
        retain: payload.retain ?? 500,
        olderThan: payload.olderThan || null,
      });
      sendJson(response, 200, {
        ok: true,
        retain: payload.retain ?? 500,
        olderThan: payload.olderThan || null,
        serverTime: new Date().toISOString(),
      });
      return;
    }

    if (request.method === 'GET' && url.pathname === '/sync/capabilities') {
      const device = await store.registerDevice(accountId, deviceFrom(request));
      logDeviceId = device.deviceId;
      sendJson(response, 200, capabilities());
      return;
    }

    if (request.method === 'POST' && url.pathname === '/sync/push') {
      const payload = await readJson(request);
      assertBatchSize(payload.batch || {});
      const device = await store.registerDevice(accountId, deviceFrom(request, payload));
      logDeviceId = device.deviceId;
      const authorizedProfileIds = await authorizedProfileIdsFrom(
        accountId,
        request,
      );
      const result = await acceptBatch(accountId, payload.batch || {}, device, {
        authorizedProfileIds,
      });
      sendJson(response, 200, {
        requestId: requestId,
        checkpoint: await checkpoint(accountId),
        acceptedCounts: result.acceptedCounts,
        conflicts: result.conflicts,
        serverTime: new Date().toISOString(),
        notes: [`accepted push for ${accountId} from ${device.deviceId}`],
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/sync/pull') {
      const payload = await readJson(request);
      const device = await store.registerDevice(accountId, deviceFrom(request, payload));
      logDeviceId = device.deviceId;
      const authorizedProfileIds = await authorizedProfileIdsFrom(
        accountId,
        request,
      );
      const pulled = await pullBatch(
        accountId,
        payload.checkpoint || {},
        authorizedProfileIds,
      );
      sendJson(response, 200, {
        requestId: requestId,
        checkpoint: await checkpoint(accountId),
        batch: pulled.batch,
        receivedCounts: pulled.receivedCounts,
        conflicts: [],
        serverTime: new Date().toISOString(),
        notes: [`returned pull envelope for ${accountId}/${device.deviceId}`],
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/sync/conflicts/preview') {
      const payload = await readJson(request);
      assertBatchSize(payload.batch || {});
      const device = await store.registerDevice(accountId, deviceFrom(request, payload));
      logDeviceId = device.deviceId;
      const authorizedProfileIds = await authorizedProfileIdsFrom(
        accountId,
        request,
      );
      const result = await acceptBatch(accountId, payload.batch || {}, device, {
        dryRun: true,
        authorizedProfileIds,
      });
      sendJson(response, 200, { conflicts: result.conflicts });
      return;
    }

    sendError(response, 404, 'NOT_FOUND', 'Endpoint not found.');
  } catch (error) {
    const message = error && error.message ? error.message : String(error);
    const code = error.code || (message.startsWith('PAYLOAD_TOO_LARGE')
      ? 'PAYLOAD_TOO_LARGE'
      : message.startsWith('INVALID_JSON')
        ? 'INVALID_JSON'
        : message.startsWith('SQLITE_ERROR')
          ? 'STORAGE_ERROR'
          : 'INTERNAL_ERROR');
    statusCode = error.statusCode || (code === 'INTERNAL_ERROR' ? 500 : 400);
    errorCode = code;
    if (code === 'RATE_LIMITED' && error.retryAfterSeconds) {
      response.setHeader('retry-after', String(error.retryAfterSeconds));
    }
    sendError(
      response,
      statusCode,
      code,
      message,
      code !== 'UNAUTHORIZED' && code !== 'PROFILE_FORBIDDEN',
    );
  } finally {
    const durationMs = Date.now() - startedAt;
    const url = new URL(request.url, `http://${request.headers.host}`);
    const entry = {
      requestId,
      method: request.method,
      path: url.pathname,
      accountId: logAccountId,
      deviceId: logDeviceId,
      statusCode: response.statusCode || statusCode,
      durationMs,
      errorCode,
      createdAt: new Date().toISOString(),
    };
    Promise.resolve(store.recordRequestLog?.(entry)).catch(error => {
      console.error('failed to record request log', error);
    });
    console.log(
      JSON.stringify({
        event: 'request',
        ...entry,
      }),
    );
  }
});

Promise.resolve(store.init()).then(() => {
  Promise.resolve(store.deleteExpiredAccessTokens?.()).catch(error => {
    console.error('failed to clean expired tokens', error);
  });
  setInterval(() => {
    pruneRateBuckets();
    Promise.resolve(store.deleteExpiredAccessTokens?.()).catch(error => {
      console.error('failed to clean expired tokens', error);
    });
  }, 60_000).unref?.();
  server.listen(port, () => {
    console.log(`sync-proxy listening on http://localhost:${port}`);
    console.log(`authRequired=${requireAuth}; accessTokenTtlHours=${accessTokenTtlHours}`);
    console.log(`rateLimit=${rateLimitMaxRequests}/${rateLimitWindowMs}ms`);
    console.log(`storeTarget=${storeTarget}`);
    console.log(`store=${storeKind}`);
  });
}).catch(error => {
  console.error(error);
  process.exit(1);
});
