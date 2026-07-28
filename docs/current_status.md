# 当前项目状态

更新时间：2026-07-27

## 阶段结论

GSCAPPALL 的儿童古诗词学习主链路和 Android Release 工程基线已形成。当前定位为“Android Release Candidate，待正式包真机验收”，不再是页面占位或仅 Debug 可运行阶段。

## 已完成

- 主链路：首页、诗词库、诗词详情、朗读、背诵、听写、小测验、报告、错题本、成长报告、我的、设置。
- 学习与游戏：学习卡、每日一诗、诗词接龙、飞花令、闯关地图、积分、徽章、周/月报。
- 数据层：Drift + SQLite、165 首 seed、schema version 10、多资料隔离、本地同步 delta/checkpoint/log。
- 同步原型：多资源 push/pull、冲突策略、HTTP transport、SQLite/Postgres adapter、账号与 profile grant。
- Android 能力：录音、TTS、本地通知、`sherpa_onnx` 离线辅助识别。
- 关卡来源提示的预期交互已确认：保留来源和定位信息，使用儿童化短文案，约 4 秒后收起；家长记录入口保持折叠。

## 2026-07-27 验证基线

- `dart analyze`：通过，无静态问题。
- `flutter test --no-pub`：151/151 通过。
- Android 版本：`1.0.0+1`。
- Android 渠道：`development` / `staging` / `production`。
- 正式 Application ID：`com.gsc.appall`。
- Release 使用独立 4096 位 RSA 签名，APK Signature Scheme v2 验证通过。
- Production APK：armeabi-v7a 65.2 MB、arm64-v8a 75.9 MB、x86_64 82.9 MB。
- Production AAB：116.4 MB，签名验证通过。

## 包体结论与目标

arm64 APK 压缩后主要构成：

| 类别 | 大小 |
| --- | ---: |
| 原生库 | 48.9 MB |
| 离线语音模型 | 25.4 MB |
| DEX | 1.0 MB |
| 其他 Flutter 资源 | 0.3 MB |
| 诗词 seed | 0.14 MB |

发布目标：

- AAB 上传包保持 `<= 120 MB`。
- arm64 独立 APK 保持 `<= 80 MB`。
- 禁止恢复通用多 ABI APK 作为正式分发产物。
- `tools/tmp_sherpa` 和真机回归产物不得进入 Git 或 APK/AAB。
- 若要继续显著降低包体，应优先评估“离线语音动态下载/Play Asset Delivery”，不应优先压缩业务 Dart 代码。

## 当前边界

- 正式语音评分仍是 Mock Provider，不是发音评测厂商结果。
- 同步服务端已可联调，但生产身份源、正式部署、观测和灾备尚未完成。
- iOS 仍缺 macOS + Xcode 首次编译、权限和真机验收。
- Windows 语音/音频能力仍有平台差异。
- 正式包名从旧 Debug ID 切换为 `com.gsc.appall`，发布前需完成一轮 production APK 真机安装与数据升级验收。

## 下一阶段

1. 在至少一台 arm64 Android 真机安装 production APK，验证启动、录音、TTS、通知、数据库和主链路。
2. 将 production key 和 Dart 混淆符号文件做离线备份。
3. 部署 staging 同步服务，完成 Postgres 迁移和备份恢复演练。
4. 用真实音频完成语音评测 Provider POC。
