# Speech Assessment Proxy

This is the development proxy for cloud pronunciation assessment.

The Flutter app should call this proxy instead of calling vendor APIs directly,
so cloud credentials stay on the server side. The first implementation ships
with a mock provider and a Tencent placeholder provider. After the vendor
account is ready, fill the Tencent request signing and response conversion in
`server.js`.

## Run

```powershell
cd tools\speech-assessment-proxy
node server.js
```

## Environment

- `PORT`: HTTP port, defaults to `8787`.
- `ASSESSMENT_PROVIDER`: `mock` or `tencent`, defaults to `mock`.
- `TENCENT_SECRET_ID`: Tencent Cloud secret id, used by the Tencent provider.
- `TENCENT_SECRET_KEY`: Tencent Cloud secret key, used by the Tencent provider.

## API

`GET /health`

Returns provider and server status.

`POST /assess`

Request body:

```json
{
  "mode": "reading",
  "expectedText": "床前明月光",
  "attemptText": "床前明月光",
  "audioBase64": "",
  "audioFormat": "wav",
  "sampleRate": 16000,
  "metadata": {
    "poemId": 1,
    "lineIndex": 0
  }
}
```

Response body uses the app-side normalized assessment model:

```json
{
  "engine": "mock-proxy",
  "overallScore": 96,
  "accuracyScore": 96,
  "fluencyScore": 92,
  "integrityScore": 100,
  "confidence": 0.96,
  "wordResults": [],
  "sentenceResults": [],
  "rawProviderPayload": {}
}
```
