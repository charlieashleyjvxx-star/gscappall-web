# GSCAPPALL

`GSCAPPALL` 是旧项目 `GSCapp` 的 Flutter 跨平台主线，面向儿童古诗词学习，统一承载 Android、iOS 和 Windows，采用 `local-first + cloud-ready` 架构。

## 产品主线

- 学习闭环：找诗 -> 学诗 -> 朗读/背诵/听写 -> 报告 -> 错题复习 -> 成长报告。
- 本地能力：165 首诗词 seed、Drift + SQLite、收藏、学习记录、多资料隔离。
- 练习与成长：朗读、背诵、听写、小测验、错题本、学习卡、积分、徽章、周/月报。
- 游戏化：诗词接龙、飞花令、闯关地图、章节详情和成绩回流。
- 平台服务：录音、TTS、本地通知、Android `sherpa_onnx` 离线辅助识别。

## 当前基线

更新日期：2026-07-27

- 版本：`1.0.0+1`。
- 正式 Android Application ID：`com.gsc.appall`。
- `dart analyze`：通过。
- `flutter test`：151/151 通过。
- 已使用独立 Release key 生成 `production` APK/AAB，不再使用 Debug 签名。
- Android 历史真机主链路已验证；正式包名切换后还需补一轮真机安装回归。

## 快速开始

```powershell
cd D:\GSCAPPALL
flutter pub get
flutter analyze
flutter test
flutter run --flavor development -d <android-device-id>
```

Windows 不使用 Android Flavor：

```powershell
flutter run -d windows
```

Android 正式构建：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_android_release.ps1
```

## Android 渠道

| Flavor | Application ID | 用途 |
| --- | --- | --- |
| `development` | `com.gsc.appall.dev` | 开发与真机回归 |
| `staging` | `com.gsc.appall.staging` | 预发布环境 |
| `production` | `com.gsc.appall` | 应用市场正式包 |

## 当前边界

- 朗读/背诵正式评分仍使用 `MockSpeechAssessmentProvider`，需接入真实语音评测厂商。
- 同步协议、HTTP transport、SQLite/Postgres proxy 和回放链路已实现；生产身份源、部署、监控和备份恢复尚未收口。
- iOS 尚未在 macOS + Xcode 上完成首次编译、权限和真机回归。
- Windows 可构建运行，但音频播放和语音识别能力仍有平台限制。
- Android arm64 Release APK 约 75.9 MB，其中离线语音模型约 25.4 MB、原生库约 48.9 MB。

## 主要文档

- [当前状态](docs/current_status.md)
- [运行指南](docs/run_guide.md)
- [Android 发布](docs/android_release.md)
- [架构决策](docs/architecture_decision.md)
- [同步生产化](docs/sync_productionization_plan.md)
- [回归清单](docs/regression_checklist.md)
