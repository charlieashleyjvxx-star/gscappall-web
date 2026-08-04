# Android 发布构建

## 渠道与包名

| Flavor | Application ID | 用途 |
| --- | --- | --- |
| `development` | `com.gsc.appall.dev` | 本地开发与内部调试 |
| `staging` | `com.gsc.appall.staging` | 预发布环境验证 |
| `production` | `com.gsc.appall` | 正式发布 |

当前正式版本由 `pubspec.yaml` 管理。Release 构建不允许回退到 Android Debug key。

## 签名配置

本机使用 `android/key.properties` 和 `android/app/gscappall-release.jks`。两者均被 `.gitignore` 排除。

新环境复制 `android/key.properties.example`，填写签名信息；也可以设置：

- `GSC_RELEASE_STORE_FILE`
- `GSC_RELEASE_STORE_PASSWORD`
- `GSC_RELEASE_KEY_ALIAS`
- `GSC_RELEASE_KEY_PASSWORD`

密钥文件必须离线备份。丢失生产密钥后将无法为同一应用 ID 发布兼容升级。

## 正式构建

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_android_release.ps1
```

脚本先执行静态分析和全量测试，再生成按 ABI 拆分、Dart 混淆的 Release APK 与 AAB。每次构建都会生成唯一 `releaseId`，写入应用崩溃记录，并将符号文件保存在 `build/symbols/production/<releaseId>`。目录中的 `release-manifest.json` 记录了符号路径和还原命令，发布后必须和对应 AAB 一起归档。

快速复建且跳过重复测试：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_android_release.ps1 -SkipTests
```

收到脱敏崩溃堆栈后，使用同一 `releaseId` 目录中的架构符号文件还原，例如：

```powershell
flutter symbolize -i stack-trace.txt -d build\symbols\production\<releaseId>\app.android-arm64.symbols
```
