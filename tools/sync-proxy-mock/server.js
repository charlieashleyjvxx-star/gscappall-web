const http = require('http');

const port = Number(process.env.PORT || 8788);

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

const supportedPolicies = {
  poems: 'server_authoritative',
  favorites: 'last_write_wins',
  learning_records: 'append_only',
  study_card_progress: 'last_write_wins',
  recite_records: 'append_only',
  wrong_questions: 'last_write_wins',
  practice_reports: 'append_only',
  daily_poem_records: 'last_write_wins',
  user_points: 'server_merge_suggested',
  challenge_stage_rewards: 'last_write_wins',
  settings: 'last_write_wins',
  user_profiles: 'last_write_wins',
};

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.on('data', chunk => {
      body += chunk;
      if (body.length > 10 * 1024 * 1024) {
        reject(new Error('Request body is too large.'));
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
        reject(new Error(`Invalid JSON: ${error.message}`));
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

function checkpointFrom(payload) {
  const now = new Date().toISOString();
  return {
    ...(payload.checkpoint || {}),
    globalCursor: `mock-${Date.now()}`,
    lastSuccessfulSyncAt: now,
    schemaVersion: payload.checkpoint?.schemaVersion || 10,
  };
}

function countBatch(batch) {
  const counts = {};
  for (const [batchKey, resource] of Object.entries(batchKeyToResource)) {
    const value = batch?.[batchKey];
    if (Array.isArray(value) && value.length > 0) {
      counts[resource] = value.length;
    }
  }
  return counts;
}

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url, `http://${request.headers.host}`);

    if (request.method === 'GET' && url.pathname === '/health') {
      sendJson(response, 200, { ok: true, service: 'sync-proxy-mock' });
      return;
    }

    if (request.method === 'GET' && url.pathname === '/sync/capabilities') {
      sendJson(response, 200, {
        supportsPoemCatalog: true,
        supportsSoftDelete: true,
        supportsFieldMerge: true,
        maxBatchSize: 500,
        supportedPolicies,
        notes: ['sync-proxy-mock capabilities'],
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/sync/push') {
      const payload = await readJson(request);
      sendJson(response, 200, {
        requestId: payload.requestId || 'sync-proxy-mock-push',
        checkpoint: checkpointFrom(payload),
        acceptedCounts: countBatch(payload.batch || {}),
        conflicts: [],
        serverTime: new Date().toISOString(),
        notes: ['sync-proxy-mock accepted all pushed records'],
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/sync/pull') {
      const payload = await readJson(request);
      sendJson(response, 200, {
        checkpoint: checkpointFrom(payload),
        batch: {},
        receivedCounts: {},
        conflicts: [],
        serverTime: new Date().toISOString(),
        notes: ['sync-proxy-mock returned empty pull batch'],
      });
      return;
    }

    if (request.method === 'POST' && url.pathname === '/sync/conflicts/preview') {
      sendJson(response, 200, { conflicts: [] });
      return;
    }

    sendJson(response, 404, { error: 'Not found.' });
  } catch (error) {
    sendJson(response, 400, { error: error.message });
  }
});

server.listen(port, () => {
  console.log(`sync-proxy-mock listening on http://localhost:${port}`);
});
