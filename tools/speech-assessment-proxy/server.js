const http = require('http');

const port = Number(process.env.PORT || 8787);
const providerName = process.env.ASSESSMENT_PROVIDER || 'mock';

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

function normalizeText(text) {
  return String(text || '').replace(/[^\p{Script=Han}A-Za-z0-9]/gu, '');
}

function assessWithMock(payload) {
  const expected = normalizeText(payload.expectedText);
  const attempt = normalizeText(payload.attemptText);
  const expectedChars = Array.from(expected);
  const attemptChars = Array.from(attempt);
  const matched = expectedChars.filter((char, index) => attemptChars[index] === char).length;
  const accuracy = expectedChars.length === 0
    ? 0
    : Math.round((matched / expectedChars.length) * 100);
  const integrity = expectedChars.length === 0
    ? 0
    : Math.round((Math.min(attemptChars.length, expectedChars.length) / expectedChars.length) * 100);
  const fluency = payload.audioBase64 ? 88 : 72;
  const overall = Math.round(accuracy * 0.5 + integrity * 0.3 + fluency * 0.2);

  return {
    engine: 'mock-proxy',
    mode: payload.mode || 'reading',
    overallScore: overall,
    accuracyScore: accuracy,
    fluencyScore: fluency,
    integrityScore: integrity,
    confidence: Math.max(0, Math.min(1, overall / 100)),
    wordResults: [],
    sentenceResults: [],
    rawProviderPayload: {
      provider: 'mock',
      hasAudio: Boolean(payload.audioBase64),
      audioFormat: payload.audioFormat || null,
      sampleRate: payload.sampleRate || null,
      metadata: payload.metadata || {},
    },
  };
}

async function assessWithTencent(payload) {
  if (!process.env.TENCENT_SECRET_ID || !process.env.TENCENT_SECRET_KEY) {
    throw new Error('Tencent provider is selected, but TENCENT_SECRET_ID or TENCENT_SECRET_KEY is missing.');
  }

  // TODO: Implement Tencent Cloud Oral Evaluation request signing and payload
  // conversion here after the service is enabled for the project account.
  // Keep the response mapped to the normalized model returned by assessWithMock.
  throw new Error('Tencent provider is not implemented yet. Use ASSESSMENT_PROVIDER=mock for local development.');
}

async function assess(payload) {
  if (!payload.expectedText) {
    throw new Error('expectedText is required.');
  }

  switch (providerName) {
    case 'mock':
      return assessWithMock(payload);
    case 'tencent':
      return assessWithTencent(payload);
    default:
      throw new Error(`Unknown ASSESSMENT_PROVIDER: ${providerName}`);
  }
}

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === 'GET' && request.url === '/health') {
      sendJson(response, 200, {
        ok: true,
        provider: providerName,
      });
      return;
    }

    if (request.method === 'POST' && request.url === '/assess') {
      const payload = await readJson(request);
      const result = await assess(payload);
      sendJson(response, 200, result);
      return;
    }

    sendJson(response, 404, {
      error: 'Not found.',
    });
  } catch (error) {
    sendJson(response, 400, {
      error: error.message,
    });
  }
});

server.listen(port, () => {
  console.log(`speech-assessment-proxy listening on http://localhost:${port}`);
  console.log(`provider=${providerName}`);
});
