# 同步生产化收口计划

本文件用于约束 sync-proxy 从本地联调服务走向生产服务时的边界。目标是保留 Flutter 端和同步协议的稳定形态，只替换身份源、部署形态和大数据量传输策略。

## 固定回归入口

发布前同步线至少执行：

```powershell
flutter analyze
flutter test
powershell -ExecutionPolicy Bypass -File tools\sync_proxy_postgres_smoke.ps1
powershell -ExecutionPolicy Bypass -File tools\sync_proxy_management_smoke.ps1
```

`tools\sync_proxy_postgres_smoke.ps1` 是全资源 Postgres smoke。它会创建一次性数据库 `gscappall_sync_smoke`，验证账号注册/登录/刷新、profile grant、多设备、全资源 push/pull、超大批量拒绝、冲突策略和账号隔离。

`tools\sync_proxy_management_smoke.ps1` 验证请求日志分页/筛选/清理、注销和基础限流。修改 `/debug/request-logs`、`/auth/logout` 或限流逻辑后必须跑。

## 生产身份源接入

当前 sync-proxy 内置本地账号表，适合开发和 staging。接真实账号服务时只替换账号边界，不改同步协议：

- `POST /auth/register`：生产可关闭或转发到真实注册服务。
- `POST /auth/login`：校验真实账号服务，拿到稳定用户 id 后映射为 `accountId`。
- `POST /auth/refresh`：校验真实 refresh token 或本地 token 映射，轮换 refresh token，并签发 proxy-local access token。
- `POST /auth/logout`：撤销当前 access token；`revokeAll=true` 时撤销当前账号所有 access token。
- `profileIds` 必须来自服务端授权表或真实账号服务的 profile grant，不允许只相信客户端请求头。

生产身份源需要提供的最小接口：

| 能力 | 输入 | 输出 |
| --- | --- | --- |
| 登录校验 | account/login id、password 或第三方凭证 | stable user id、账号状态 |
| refresh 校验 | refresh token | stable user id、是否有效、是否需要轮换 |
| profile 授权 | stable user id | 可访问 profile id 列表和角色 |
| 注销/吊销 | stable user id、token id | 吊销结果 |

sync-proxy 继续负责：

- 生成和校验短期 `accessToken`。
- 记录 `sync_access_tokens`、`sync_devices`、`sync_request_logs`。
- 用 `accountId + profile grant` 做数据隔离。
- 返回 Flutter 端现有 session envelope：`accountId`、`accessToken`、`refreshToken`、`expiresAt`、`profileIds`。

## Postgres 迁移与备份恢复

当前 Postgres adapter 通过启动时 `CREATE TABLE IF NOT EXISTS` 建表，适合 smoke 和早期部署。进入生产前建议改为显式迁移：

1. 建立迁移目录，例如 `tools/sync-proxy/migrations/postgres/001_initial.sql`。
2. 增加 `sync_schema_migrations(version, applied_at, checksum)` 表。
3. 服务启动时只检查迁移状态，不在业务启动中静默改表。
4. 每次新增字段或索引都走版本化 SQL，并在 Postgres smoke 中从空库重放。
5. 发布前备份：`pg_dump -Fc <database> > sync-backup-<date>.dump`。
6. 恢复演练：`createdb <restore-db>` 后执行 `pg_restore -d <restore-db> <dump>`，再跑 `tools\sync_proxy_postgres_smoke.ps1` 的等价只读/隔离验证。

生产建议索引：

- `sync_records(account_id, resource, revision)`：pull 分页和增量回放。
- `sync_records(account_id, resource, record_key)`：单条冲突检测。
- `sync_profile_grants(account_id, profile_id)`：profile 授权。
- `sync_request_logs(created_at DESC)` 和 `sync_request_logs(request_id)`：日志查询。
- `sync_access_tokens(account_id, expires_at)`：过期清理和注销。

## 大批量 pull 分页/分片策略

当前协议已通过 `maxBatchSize` 限制 push/preview。pull 进入生产后也应限制单次 envelope：

- capabilities 返回 `maxPullRecords`，默认建议 500。
- 服务端按资源顺序拉取，每个响应最多返回 `maxPullRecords` 条记录。
- 如果还有未返回数据，响应增加 `hasMore: true`。
- 服务端仍返回每个资源的 collection cursor；未完全拉完的资源 cursor 只能推进到本页最后一条 revision。
- Flutter 端每收到一页就先执行 `applyRemoteEnvelope()`，成功后保存 checkpoint，再继续下一页。
- 每页都必须按 account/profile 授权过滤，不能为了分页把其他 profile 的记录混入 envelope。

推荐响应扩展：

```json
{
  "checkpoint": {},
  "batch": {},
  "receivedCounts": {},
  "hasMore": true,
  "page": {
    "maxRecords": 500,
    "returnedRecords": 500,
    "nextResource": "learning_records"
  }
}
```

后续实现顺序：

1. 服务端增加 `SYNC_PROXY_MAX_PULL_RECORDS` 和分页响应。
2. Flutter `SyncCoordinator` 支持连续 pull page，限制最大页数并写同步日志。
3. 增加 Postgres smoke 的多页 pull 场景。
4. 增加本地 DB `applyRemoteEnvelope()` 多页幂等测试，确认奖励不重复、pending 不被误覆盖。
