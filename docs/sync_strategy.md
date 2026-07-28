# 同步策略

## 目标

同步层保持 local-first：本地功能不依赖网络结果，云端只负责多设备恢复、冲突回放和跨设备状态一致。

核心要求：

- 所有资料相关数据必须携带 `profileId`。
- push payload、pull envelope、applyRemoteEnvelope 必须保持 profile 隔离。
- 本地 pending 与远端更新并存时，按资源级策略处理，避免覆盖用户本地未上传修改。
- 奖励领取记录必须同步，避免多设备重复弹奖励。

## 资源范围

当前同步重点资源：

- `user_profiles`
- `settings`
- `favorites`
- `learning_records`
- `practice_reports`
- `wrong_questions`
- `daily_poem_records`
- `study_card_progress`
- `user_points`
- `challenge_stage_rewards`
- `poems`
- `recite_records`

## 冲突策略

- `last_write_wins`：适用于设置项、部分用户配置等最后修改优先的资源。
- `soft_delete`：适用于收藏等可软删除资源，删除状态需要参与同步。
- `server_merge_suggested`：适用于错题、学习记录、报告等需要服务端返回合并建议的资源。
- `append_only`：适用于学习记录、报告历史等主要追加型资源。

## 本地状态

本地记录通过 `sync_status` 标识同步状态：

- `local`：已与服务端一致或无需上传。
- `pending`：本地有待上传修改。
- `conflicted`：服务端返回冲突，需要提示或后续处理。
- `failed`：同步失败，保留错误信息和日志。

push ACK 后应把对应本地记录从 `pending` 标记为 `local`，局部成功不能影响失败资源的状态。

## 回放要求

`applyRemoteEnvelope` 已覆盖并应继续保持：

- 学习记录、报告、错题、收藏、设置、资料。
- 每日诗、学习卡、积分、关卡奖励。
- poems 和 recite_records 的 placeholder 收口。

回放时必须：

- 校验 profile 权限。
- 不重复写入已存在的远端记录。
- 不覆盖本地 pending，除非冲突策略明确允许。
- 写入同步日志，记录 requestId、push/pull 数量、冲突数量、notes/error。

## sync-proxy

当前 proxy 方向：

- HTTP transport 使用正式鉴权 header 和稳定 device id header。
- proxy 支持账号/用户维度隔离、设备注册、cursor、push ACK、pull envelope。
- SQLite/Postgres adapter 已对齐同一 store 接口，并通过正式 smoke 覆盖账号、profile 授权、冲突和全资源回放。
- `SYNC_PROXY_MAX_BATCH_SIZE` 用于限制 push/preview 批量大小，避免异常大包进入冲突计算和持久化层。
- 管理/调试接口用于查看 request log、状态码、错误码和 requestId。
- 生产身份源接入、Postgres 迁移/备份和 pull 分页策略见 `docs/sync_productionization_plan.md`。

## 验证建议

本地测试：

```powershell
flutter test test\sync_local_repository_profile_scope_test.dart
flutter test test\sync_profile_scope_test.dart
flutter test test\sync_remote_apply_envelope_test.dart
```

真机链路：

```powershell
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -SyncLogOnly -ArchiveArtifacts
```

多设备/全资源压力测试应持续覆盖：

- 多 profile。
- 多资源同时 pending。
- 远端 envelope 回放。
- 奖励记录去重。
- 本地 pending 与远端更新并存。

服务端固定 smoke：

```powershell
powershell -ExecutionPolicy Bypass -File tools\sync_proxy_postgres_smoke.ps1
powershell -ExecutionPolicy Bypass -File tools\sync_proxy_management_smoke.ps1
```
