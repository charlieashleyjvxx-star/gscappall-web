# 运行指南

## 本机环境

- Flutter SDK：`D:\dev\flutter`
- Android SDK：`C:\Users\Administrator\AppData\Local\Android\Sdk`
- JDK：`C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot`
- 项目目录：`D:\GSCAPPALL`

## 基础命令

```powershell
cd D:\GSCAPPALL
flutter pub get
flutter analyze
flutter test
```

## Windows 运行

```powershell
cd D:\GSCAPPALL
flutter run -d windows
```

构建 Windows debug 包：

```powershell
flutter build windows --debug
```

产物：

```text
D:\GSCAPPALL\build\windows\x64\runner\Debug\gscappall.exe
```

## Android 构建与安装

构建 debug APK：

```powershell
flutter build apk --flavor development --debug
```

安装到真机：

```powershell
adb devices
adb -s <device-serial> install -r D:\GSCAPPALL\build\app\outputs\flutter-apk\app-development-debug.apk
adb -s <device-serial> shell am start -n com.gsc.appall.dev/com.gsc.appall.MainActivity
```

保持真机常亮：

```powershell
adb -s <device-serial> shell svc power stayon true
```

## Android 回归脚本

日常稳定短套件：

```powershell
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ShortSuite -ArchiveArtifacts
```

专项入口：

```powershell
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -SyncLogOnly -ArchiveArtifacts
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -GrowthTrendOnly -ArchiveArtifacts
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ChallengeMapReturnOnly -ArchiveArtifacts
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ReadingScoreOnly -ArchiveArtifacts
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ReadingControlsOnly -ArchiveArtifacts
powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -PermissionOnly -ArchiveArtifacts
```

说明：

- `-ShortSuite -ArchiveArtifacts` 建议超时设置为 `25 分钟` 以上。
- `-ArchiveArtifacts` 会保存 transcript、UI XML、截图和 logcat 到 `build/android-regression/<时间>-<设备>/`。
- 修改地图、章节详情、来源浮层时优先跑 `-ChallengeMapReturnOnly`。
- 修改成长报告趋势点弹层时优先跑 `-GrowthTrendOnly`。

## iOS

Windows 环境不能完成 iOS 编译和签名。后续需要在 macOS + Xcode 环境执行：

```bash
flutter pub get
flutter run -d ios
```

## 常见排查

Android 依赖不稳定：

```powershell
flutter precache --android --force
```

设备未连接：

```powershell
adb devices
flutter devices
```

全量重建：

```powershell
flutter clean
flutter pub get
flutter build apk --flavor development --debug
```
