# 架构决策

## ADR-001：新主线采用 Flutter + Drift + Local-First

## 背景

旧项目 `GSCapp` 已经证明了产品方向成立，但它的技术栈是 `React + Tauri + Web Speech API`，很难自然覆盖 iPhone、Android 和 Windows 三端共用一套稳定主线。新项目要求固定为：

- Flutter + Dart
- 手机优先，自适应到 Windows
- 本地优先，云端可接
- 旧数据和规则尽量迁移
- 页面不直接写平台分支

## 决策

新项目采用以下主结构：

- UI：Flutter
- 状态管理：Riverpod
- 本地数据：Drift runtime + SQLite
- 服务边界：Audio / Record / Speech / Notification / Sync / Purchase 全部抽象成接口
- 数据访问：Repository 分层
- 云端预留：`data/remote` + `SyncService`，不在 P0 就把后端做重

## 为什么是 Flutter

- 一套 Dart 代码可同时覆盖 Windows、iOS、Android，最符合“一套主代码基线”目标。
- UI 与平台能力都能自然抽象，不需要像旧项目那样再套 Web 容器或 Tauri 壳。
- 对儿童友好、中文优先的自定义界面更容易做一致性控制。

## 为什么是 Drift + SQLite

- 本地 SQLite 是 local-first 的最稳底座，离线可用、查询稳定、迁移成熟。
- Drift 能把初始化、迁移、事务和后续 schema 演进纳入统一数据层，而不是散落在页面。
- 后续如果接加密字段、同步游标、云端主键映射，可以在现有表上增量扩展，不需要推翻重做。

## 为什么坚持 local-first

- 学习产品的第一优先是“随时打开就能学”，不能被登录、网络、云端状态卡死。
- 收藏、学习记录、每日一诗、卡片复习这些核心链路本质上都适合先落本地。
- 云端同步属于增强项，不该反过来绑架主链路。

## 架构分层

### 应用层

- `lib/app`
  负责启动、主题、壳导航、Provider 注册、初始化。

### 领域层

- `lib/domain`
  存放实体和 repository 接口，避免页面直接依赖数据库细节。

### 数据层

- `lib/data/local`
  管 Drift runtime、SQLite schema、seed loader。
- `lib/data/repositories`
  管本地查询、收藏、每日一诗、学习记录、设置保存。
- `lib/data/remote`
  只放云端预留 API，不在 P0 过度实现。

### 功能层

- `lib/features/*`
  每个页面独立组织，先做 P0 主链路。

### 服务层

- `lib/services/*`
  插件与平台能力统一走接口，页面只依赖抽象。

## 当前实现上的刻意取舍

### Drift 先用 runtime + custom SQL

原因不是放弃 Drift，而是当前执行环境没有可用 Flutter / Dart 工具链，无法在本轮调用 `build_runner` 生成 DSL 代码。为了先把 P0 主链路落下来，本轮采用：

- Drift runtime 负责数据库生命周期
- custom SQL 负责 schema、迁移和查询

这能保证结构是 Drift 方向，并且后续在工具链可用时可以平滑升级到 table DSL。

### 原生工程壳暂为占位目录

当前机器没有 `flutter` 命令，因此 `android/ios/windows` 目录只是先占位，真正的原生工程壳需要在安装 Flutter SDK 后执行：

```powershell
flutter create . --platforms=android,ios,windows
```

## 不做的事

- 不继续扩展旧项目主线
- 不直接复制 React 组件
- 不把 Web Speech API 伪装成跨平台方案
- 不在 P0 就实现登录、VIP、排行榜、教师端、家长端

