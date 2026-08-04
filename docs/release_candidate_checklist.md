# Sprint 4 Release Candidate 验收记录

验收日期：2026-07-29
候选版本：`1.0.0+2001`
当前结论：**工程验收 GO，外部发布操作待负责人执行**。Release 产物、签名、静态门禁与 Android 真机专项均已通过；正式推送、密钥备份和 Play Console 内测仍需发布负责人完成。

## 1. Git 与发布基线

- [x] 初始发布基线提交：`5868517 chore: establish release candidate baseline`
- [x] `node_modules`、`.env`、IDE 文件、签名文件与 `key.properties` 已排除
- [x] Sherpa ONNX 模型已配置 Git LFS：`assets/speech/**/*.onnx`
- [x] 未发现硬编码的真实凭据
- [ ] 正式推送前将临时提交作者 `Codex <codex@local>` 修订为实际作者
- [ ] 确认远端 Git LFS 可用，并完成首次推送
- [ ] 离线备份 production keystore、密码和证书指纹

## 2. 代码质量与 Release 安全边界

- [x] `flutter analyze --no-pub`：通过
- [x] `flutter test --no-pub`：161/161 通过
- [x] `debugPrint` 仅存在于 `lib/core/app_logger.dart`
- [x] `AppLogger` 在 `kReleaseMode` 下不输出日志
- [x] Profile 技术状态、同步 HTTP 与原始错误详情受 `AppEnvironment.diagnosticsEnabled` 控制
- [x] production Release 分支成功编译
- [x] Production 页面不再展示记录 ID、HTTP/URL、异常堆栈、数据库路径、构建环境或测试术语
- [x] Release 模式强制关闭诊断入口和持续日志，不能通过 `GSC_DIAGNOSTICS` 重新开启
- [x] 技术状态集中到诊断页面；诊断导出自动隐藏凭据、账号、内部标识、网络地址和本地路径
- [x] 全局崩溃收集已接入；Production 不保存原始异常消息，保留脱敏堆栈供符号化
- [x] 未配置网络备份时明确显示不可用，不执行占位同步，也不会伪报成功或清空待上传记录
- [x] 发布前最终门禁已重跑：`flutter analyze --no-pub` 无问题，`flutter test --no-pub` 161/161 通过

## 3. 候选产物

构建命令：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_android_release.ps1 -Flavor production -SkipTests
```

构建结果：通过。Release ID：`production-20260729T022335Z`。全部产物启用 Dart 混淆，符号文件与还原清单保存在 `build/symbols/production/production-20260729T022335Z`。

| 产物 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `app-armeabi-v7a-production-release.apk` | 68,610,723 | `F599C373D9A0C205FE7BF57BC52640C285DE7642D80996920527E4F76D074E25` |
| `app-arm64-v8a-production-release.apk` | 79,736,261 | `2ABACCBD78010629A0AD7C251F55571E42F0A3693EB6898ABC73E103F626C62E` |
| `app-x86_64-production-release.apk` | 87,148,488 | `4ABEE510BC201FFA714740BA997E8CA9B16A7F09093FA133C94C2B90D995E1D3` |
| `app-production-release.aab` | 122,298,174 | `25CB5015A74874652B45254B0B58DB49AEFA995F2210000D17C509B15597604B` |

签名与清单：

- [x] APK v2 签名验证通过，签名者数量 1
- [x] 证书 SHA-256：`58baa23762d73c0e13941bcf3d627c92d1469d95c843ae5baf6482a828cc6d9d`
- [x] 包名：`com.gsc.appall`
- [x] `versionName=1.0.0`，`versionCode=2001`
- [x] `minSdk=24`，`targetSdk=36`
- [x] AAB `jarsigner -verify` 通过
- [ ] 上传 Play Console 内部测试轨道，确认 App Signing、设备拆分和安装结果

## 4. 包体结论

- 通用 APK 约 174.1 MB，主要因为同时包含多 ABI。
- ARM64 混淆分包约 75.9 MB，ARMv7 约 65.2 MB，符合单设备交付预期。
- ARM64 包内主要占用为 native libraries 约 51.3 MB、离线语音模型约 26.7 MB。
- Play 分发应使用 AAB；不要为缩包移除离线模型或 x86_64，除非产品明确取消离线识别或模拟器/ChromeOS 支持。

## 5. Android 真机验收

设备：Huawei `ALN-AL80`，序列号 `2MM0224131051743`。

- [x] Debug APK 构建与安装通过
- [x] 启动、麦克风授权和基础前台恢复通过
- [x] 同步日志成功/失败详情、报告、错题、学习记录与闯关地图回跳通过
  - 归档：`build/android-regression/20260728-103405-2MM0224131051743`
- [x] 已修正真机脚本与当前 UI 不一致的断言和定位：回跳文案、成长趋势折叠区、“读一读”入口、边缘手势滚动
- [x] 朗读评分及三张本地表写入通过
  - 数据变化：`learning_records 12->13`、`practice_reports 12->13`、`practice_report_items 12->13`
  - 归档：`build/android-regression/20260728-125553-2MM0224131051743`
- [x] 朗读识别、录音、结束录音与回放控件通过
  - 归档：`build/android-regression/20260728-131145-2MM0224131051743`
- [x] 麦克风权限撤销、不可用状态与恢复通过
  - 归档：`build/android-regression/20260728-132028-2MM0224131051743`
- [x] 闯关地图、章节详情、学习记录、练习报告、错题本和成长报告返回通过
  - 归档：`build/android-regression/20260728-142811-2MM0224131051743`
- [x] 成长趋势日期点、报告、错题、学习记录详情和回跳通过
  - 归档：`build/android-regression/20260728-151604-2MM0224131051743`
- [x] 资料设置恢复、资料创建/切换、学习卡片完成、笔记取消/保存、数据库持久化及权限异常通过
  - 归档：`build/android-regression/20260728-155630-2MM0224131051743`
- [x] 七个最终通过归档均已扫描，未发现 `FlutterError`、`FATAL EXCEPTION`、widgets assertion、`Failed assertion` 或 `RenderFlex overflow`

## 6. RC 放行结论

工程验收条件已满足：

1. Android 真机专项全部通过并保留归档。
2. 最终通过归档未发现 Flutter 红屏、原生崩溃、布局溢出或未处理断言。
3. 最终 analyze/test 门禁通过。
4. production Release AAB、ABI APK、签名校验和混淆符号文件均已生成。

正式对外发布前仍需发布负责人完成：

1. 将临时 Git 提交作者修订为实际作者，并确认远端仓库与 Git LFS 首次推送正常。
2. 离线备份 production keystore、密码、证书指纹和 `build/symbols/production/production-20260729T022335Z`。
3. 上传 AAB 至 Play Console 内部测试轨道，确认 App Signing、设备拆分、安装与升级结果。
4. 保存本检查记录及最终产物校验值，完成发布审批。
