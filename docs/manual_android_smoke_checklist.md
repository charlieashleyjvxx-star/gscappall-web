# Android 手动 Smoke 验证清单

目标：在 Android 真机或模拟器上快速确认首页、诗词库、游戏、我的、同步日志、学习记录、报告、错题、朗读和权限异常路径没有红屏、崩溃或 FlutterError。

## 准备

- 建议先执行 `flutter build apk --flavor development --debug`，再安装 `build/app/outputs/flutter-apk/app-development-debug.apk`。
- 真机验证前保持常亮：`adb -s <device-serial> shell svc power stayon true`。
- 如果需要干净开发渠道数据，可执行 `adb shell pm clear com.gsc.appall.dev`。
- 运行脚本前确认设备在线：`adb devices`。
- 失败排查重点看 `FlutterError`、`FATAL EXCEPTION`、`Exception caught by widgets library`、`_dependents`、`Failed assertion`。

## 自动化短入口

- 日常稳定短套件：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ShortSuite -ArchiveArtifacts`
- 同步日志详情链路：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -SyncLogOnly -ArchiveArtifacts`
- 成长报告趋势点链路：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -GrowthTrendOnly -ArchiveArtifacts`
- 成长报告到闯关地图章节详情链路：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ChallengeMapReturnOnly -ArchiveArtifacts`
- 朗读评分写库：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ReadingScoreOnly -ArchiveArtifacts`
- 朗读控制与录音回放：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ReadingControlsOnly -ArchiveArtifacts`
- 麦克风权限撤销：
  `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -PermissionOnly -ArchiveArtifacts`

## ShortSuite 超时建议

- `-ShortSuite -ArchiveArtifacts` 当前会连续覆盖“同步日志详情链路”和“成长报告趋势点链路”，在设备缺少 `sqlite3` 时还会走本机 SQLite 注入 fallback。
- 日常回归或 CI 命令超时建议设置为 `25 分钟` 以上；`15 分钟` 可能在业务已通过但脚本仍在归档或执行后续链路时误判超时。
- 如果只验证单条链路，优先单跑 `-SyncLogOnly`、`-GrowthTrendOnly` 或 `-ChallengeMapReturnOnly`。

## 手动重点

- 首页可进入，底部导航切换首页、诗词库、游戏、我的无红屏。
- 我的页同步状态卡可刷新，立即同步后可进入同步日志列表和详情。
- 同步日志详情中带 `stageId`、`reportId`、`wrongQuestionId`、`learningRecordId` 时，可跳转到对应页面。
- 成长报告趋势点可展开当天报告、错题和学习记录，并能返回后定位刚才点击的明细。
- 闯关地图可显示章节、路线、锁定/解锁状态、星级、奖励和章节详情。
- 章节详情中的“查看学习记录详情 / 查看报告 / 查看错题”返回后，应高亮刚才的推进记录。
- 朗读评分后应写入 `learning_records`、`practice_reports`、`practice_report_items`。
- 撤销麦克风权限后，能力芯片和识别入口应显示明确不可用提示，不应红屏。

## 归档

- 使用 `-ArchiveArtifacts` 后，脚本会把 transcript、每步 UI XML/截图和最终 logcat 保存到 `build/android-regression/<时间>-<设备>/`。
- 归档路径应写入发布验证记录，便于后续回看现场。
- 最近通过记录：
  - `-ShortSuite -ArchiveArtifacts`：`build/android-regression/20260526-133712-2MM0224131051743`
  - `-ChallengeMapReturnOnly -ArchiveArtifacts`：`build/android-regression/20260526-132723-2MM0224131051743`
  - `-ShortSuite -ArchiveArtifacts`：`build/android-regression/20260526-101122-2MM0224131051743`
  - `-GrowthTrendOnly -ArchiveArtifacts`：`build/android-regression/20260526-095910-2MM0224131051743`
  - `-ChallengeMapReturnOnly -ArchiveArtifacts`：`build/android-regression/20260526-065653-2MM0224131051743`
  - `-GrowthTrendOnly -ArchiveArtifacts`：`build/android-regression/20260525-103616-2MM0224131051743`
  - `-ChallengeMapReturnOnly -ArchiveArtifacts`：`build/android-regression/20260525-105303-2MM0224131051743`

## 脚本断言策略

- 来源提示完整浮层会在约 4 秒后自动收起为来源 chip。
- 涉及成长报告、同步日志、章节详情回跳的脚本断言，应接受完整浮层或来源 chip 任一状态。
- 不建议再强依赖“成长报告已定位到……”这类完整文案一直存在；应优先断言目标页、目标关卡、来源 chip、关键入口和无红屏。
## 2026-05-25 最新真机记录

- `-ChallengeMapReturnOnly -ArchiveArtifacts -SkipBuild -SkipInstall` 通过。
- 归档：`build/android-regression/20260525-124943-2MM0224131051743`
- 备注：真机脚本已覆盖动态关注关卡数据注入、UIAutomator 抓到非目标包时回前台重试，以及返回高亮提示自动收起后的稳定断言。
