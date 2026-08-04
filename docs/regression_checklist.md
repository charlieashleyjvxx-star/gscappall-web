# P0 / P1 / P3 回归清单

本清单用于 Windows 桌面、Android 模拟器、Android 真机，以及后续 iOS 真机的统一回归。日常开发优先跑短入口，发布前再跑完整脚本兜底。

## 自动化优先级

1. 静态检查：`flutter analyze`
2. 全量测试：`flutter test`
3. 信息架构收口专项：`flutter test test\product_ia_widget_test.dart test\wrong_book_stage_filter_test.dart`
4. Android 稳定短套件：
   `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ShortSuite -ArchiveArtifacts`
5. 备份服务端全资源 Postgres smoke：
   `powershell -ExecutionPolicy Bypass -File tools\sync_proxy_postgres_smoke.ps1`
6. 备份服务端管理 smoke：
   `powershell -ExecutionPolicy Bypass -File tools\sync_proxy_management_smoke.ps1`
7. 地图/章节详情/来源浮层专项：
   `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -ChallengeMapReturnOnly -ArchiveArtifacts`
8. 成长报告趋势点专项：
   `powershell -ExecutionPolicy Bypass -File tools\android_reading_regression.ps1 -Serial <device-serial> -SkipBuild -SkipInstall -GrowthTrendOnly -ArchiveArtifacts`
9. 朗读专项按需单跑：`-ReadingScoreOnly`、`-ReadingControlsOnly`、`-PermissionOnly`

## ShortSuite 超时建议

- `-ShortSuite -ArchiveArtifacts` 当前包含同步日志详情链路和成长报告趋势点链路，真机缺少 `sqlite3` 时会额外执行本机 SQLite 注入。
- 本地或 CI 命令超时建议设置为 `25 分钟` 以上；`15 分钟` 容易把“业务已通过但脚本仍在归档或后续链路”的情况误判为失败。

## 核心验收

- 主链路人工验收：`首页 -> 今日任务 -> 诗词详情 -> 练习 -> 学习卡片 -> 错题本`。
- 儿童端不得出现工程词：同步、回流、Token、Provider、Mock、诊断、服务端、占位。备份与服务状态只在家长高级区出现。
- 首页、诗词详情、练习页、错题本在小屏下不应出现按钮挤压、文字遮挡或入口过多。
- 诗词详情必须能看到“下一步建议”；诗词正文按标点分行且整首诗字形一致，不应出现同一首诗大字/小字混排。
- 练习页仅显露听写模块、同音接龙和飞花初试入口；背诵、其他接龙/飞花/听写关卡和小测验不从练习页展示；朗读仍从诗词详情进入；错题本默认待复习且可切到全部错题。
- 我的页儿童首屏只保留收藏、设置等常用入口；不展示家长管理，孩子切换、改名和学习提醒统一放在设置中。
- 成长报告入口需区分儿童摘要与家长详细版；闯关地图儿童侧只保留进度、星星、继续练，高级说明折叠。
- 小屏视觉专项：首页只保留总入口、今日任务、学习卡片；诗词详情下一步建议不应把按钮挤出屏幕；学习卡首屏只保留卡片、上一张/下一张、我记住了/再看一遍；练习页顶部只保留主操作，报告和错题入口可折叠。
- 主页面和底部导航无红屏、无 FlutterError。
- 多资料切换后，收藏、积分、学习记录、报告、错题、学习卡进度只显示当前资料数据。
- 备份 payload 和回放均保持 profile 维度，不串资料。
- 备份记录可查看成功、失败、冲突详情，并能从记录跳到报告、错题、学习记录和闯关地图。
- 成长报告变化点支持查看当天报告、错题、学习记录，多条记录可选择，返回后能定位刚才点击项。
- 闯关地图支持章节路线、锁定/解锁、星级、奖励、章节详情、最近练习记录和反查入口。
- 朗读评分写入学习记录和报告表；权限撤销后提示明确且不红屏。

## 备份生产化回归

- `tools\sync_proxy_postgres_smoke.ps1` 会创建并重建一次性数据库 `gscappall_sync_smoke`，覆盖 Postgres adapter 建表、账号注册/登录/刷新、profile grant、多设备、全资源 push/pull、超大批量拒绝、冲突策略和账号隔离。
- `tools\sync_proxy_management_smoke.ps1` 覆盖 SQLite 模式下的请求日志分页/筛选/清理、注销和限流，适合服务端调试接口改动后快速复测。
- 发布前建议顺序：`flutter analyze`、`flutter test`、Postgres smoke、management smoke、Android `-ShortSuite -ArchiveArtifacts`。
- 如果本机没有 Postgres，可先跑 `tools\sync_proxy_formal_smoke.ps1` 作为 SQLite 全资源等价验证，但发布验证仍应补跑 Postgres smoke。

## 最近真机回归记录

- 2026-05-29 最终发布前人工 smoke：
  路径：`首页 -> 今日任务 -> 诗词详情 -> 背诵 -> 听写 -> 错题本 -> 我的/家长管理 -> 成长与历史 -> 查看周报`。
  设备：`ALN AL80 / 2MM0224131051743`。结论：通过，首页、诗词详情、背诵、听写、错题本、成长周报均未发现红屏、遮挡、按钮拥挤或工程词回流；成长周报仍位于家长详细层级，儿童侧不直接暴露。
  日志：`logcat` 未发现 `FlutterError`、`FATAL EXCEPTION`、`red screen`、`RenderFlex overflow`；仅有 `uiautomator` 工具自身的 `AndroidRuntime` 启动日志。
  截图：`build/verification/final-smoke-01-home.png`、`build/verification/final-smoke-02-poem-detail.png`、`build/verification/final-smoke-03-recite.png`、`build/verification/final-smoke-04-dictation.png`、`build/verification/final-smoke-05-wrong-book.png`、`build/verification/final-smoke-06-growth-weekly.png`。
- 2026-05-29 发布前 3 个小项修复验证：
  修复：首页“今日任务”加载态补自然文案，避免空卡；背诵页儿童首屏去掉“语音识别/麦克风权限/语音评测”等工程词；诗词显示对《咏鹅》这类短重复逗号句保持同一行，不再拆成三行。
  验证：`flutter analyze`、`flutter test test\poem_pinyin_text_test.dart test\poem_pinyin_normalization_test.dart test\product_ia_widget_test.dart`、`flutter test test\challenge_map_page_test.dart test\growth_report_stage_scope_test.dart test\practice_report_history_test.dart`、`flutter build apk --debug` 通过，并已安装到 `ALN AL80 / 2MM0224131051743`。
  截图：`build/verification/release-fix-01-home.png`、`build/verification/release-fix-02-poem-library.png`、`build/verification/release-fix-03-poem-detail.png`、`build/verification/release-fix-04-recite.png`。
- 2026-05-29 发布前轻量验收：
  路径：`首页 -> 诗词库 -> 诗词详情 -> 读一读 -> 背一背 -> 练习页 -> 听写 -> 错题本 -> 我的 -> 家长管理 -> 成长报告 -> 查看周报`。
  自动检查：`flutter analyze` 通过；`-ShortSuite` 和 `-GrowthTrendOnly` 均已运行到目标页面，但因脚本仍查找旧文案/旧入口断言失败（`闯关地图`、`逐日变化`），归档分别为 `build/android-regression/20260529-133715-2MM0224131051743`、`build/android-regression/20260529-134728-2MM0224131051743`。发布判断以本轮人工小屏截图为准。
  截图：`build/verification/release-smoke-01-home.png` 到 `build/verification/release-smoke-18-growth-weekly.png`。确认诗词详情、练习页、听写页、错题本、我的页和成长周报无红屏、无遮挡；错题本空状态干净；听写页“历史/错题本”默认收在“更多”；成长周报细节默认折叠。
  待修小项：首页“今日任务”卡片出现空内容；背诵页仍有“语音识别/麦克风权限/语音评测”；诗词库预览和《咏鹅》详情前三句呈现偏稀疏。发布前建议只做文案/呈现小修，不改主链路结构。
- 2026-05-29 收尾级小修验证：
  `flutter analyze`、`flutter test test\growth_report_stage_scope_test.dart test\challenge_map_page_test.dart test\practice_report_history_test.dart`、`flutter build apk --debug` 通过，并已安装到 `ALN AL80 / 2MM0224131051743`。
  截图：`build/verification/p9-dictation-compact.png`、`build/verification/p9-growth-weekly.png`。确认听写完成态只保留“重新开始”主按钮，历史和错题本收入“更多”；成长周报详情首屏保留“本周总结/练习表现/建议继续练”，详细变化默认折叠，家长文案更柔和。
- 2026-05-29 主链路人工验收闭环：
  路径：`首页 -> 今日任务 -> 诗词详情 -> 读一读 -> 背一背 -> 练听写 -> 错题本 -> 我的/家长管理 -> 成长报告`。
  截图：`build/verification/p8-01-home.png`、`build/verification/p8-02-detail.png`、`build/verification/p8-03-reading.png`、`build/verification/p8-04-recite.png`、`build/verification/p8-05-dictation.png`、`build/verification/p8-06-wrong-book.png`、`build/verification/p8-07-profile.png`、`build/verification/p8-14-growth-report.png`。
  结论：首页和详情页主链路清楚；朗读/背诵/听写均可进入；错题本空状态不暴露筛选分析；成长报告入口已在家长层，周报详情保留家长分析信息。
- 2026-05-29 儿童端干净度收尾：
  `flutter analyze`、`flutter test test\challenge_map_page_test.dart test\growth_report_stage_scope_test.dart test\practice_report_history_test.dart`、`flutter build apk --debug` 通过，并已安装到 `ALN AL80 / 2MM0224131051743`。
  截图：`build/verification/p7-poem-detail.png`、`build/verification/p7-poem-detail-next-step.png`、`build/verification/p7-reading.png`。确认朗读页不再展示能力状态面板，诗词详情“接下来练什么”在原文后紧跟四个短入口，成长报告和闯关地图测试已同步到新文案。
- 2026-05-29 小屏视觉精修验证：
  `flutter analyze`、`flutter test test\challenge_map_page_test.dart test\growth_report_stage_scope_test.dart`、`flutter test test\practice_report_history_test.dart`、`flutter build apk --debug` 通过，并已安装到 `ALN AL80 / 2MM0224131051743`。
  截图：`build/verification/p6-home.png`、`build/verification/p6-practice.png`、`build/verification/p6-dictation-home.png`。确认练习页四入口在小屏一屏可见，听写页按钮密度收紧，听写题卡英文提示已改为中文。
- 2026-05-28 朗读/听写、错题本、成长报告和闯关地图降噪验证：
  `flutter analyze`、`flutter test test\product_ia_widget_test.dart test\challenge_map_page_test.dart test\wrong_book_stage_filter_test.dart test\stage_contribution_view_test.dart test\growth_report_stage_scope_test.dart`、
  `flutter build apk --debug` 通过并已安装到 `ALN AL80 / 2MM0224131051743`。听写页截图：`build/verification/p5-dictation-home.png`；错题本空状态截图：`build/verification/p5-wrong-book.png`。确认错题本空状态不暴露筛选分析，听写页下拉框无小屏溢出。
- 2026-05-28 下一轮收口自动验证通过：
  `flutter analyze`、`flutter test test\product_ia_widget_test.dart test\widget_test.dart test\poem_pinyin_text_test.dart test\practice_report_history_test.dart`。
  `flutter build apk --debug` 通过并已安装到 `ALN AL80 / 2MM0224131051743`。首页小屏截图：`build/verification/p4-home.png`；学习卡片首屏截图：`build/verification/p4-study-card.png`；练习四入口截图：`build/verification/p4-practice-tab.png`。
  待继续人工点验：错题本真机入口和空状态截图，重点确认默认只看待复习、空状态不暴露筛选分析。
- 2026-05-27 页面级真机人工路径待复核：
  `诗词详情长诗/词牌显示 -> 首页小屏 -> 练习页四入口 -> 学习卡翻面 -> 错题本筛选折叠/空状态`。
  重点确认：诗词正文无大字/小字混排；首页无学习概览/最近学习；错题本空状态只显示下一步练习入口；我的页家长管理默认折叠；成长报告和闯关地图儿童侧不暴露工程味文案。
- 2026-05-27 本轮收口自动验证通过：
  `flutter analyze`、`flutter test`、`flutter build apk --debug`；已安装到 `ALN AL80 / 2MM0224131051743`。
- 2026-05-27 视觉精修与高级区折叠专项通过：
  `flutter analyze`、`flutter test test\product_ia_widget_test.dart test\challenge_map_page_test.dart test\wrong_book_stage_filter_test.dart test\stage_contribution_view_test.dart test\growth_report_stage_scope_test.dart`。
- 2026-05-27 视觉精修全量验证通过：
  `flutter test`、`flutter build apk --debug`；已安装到 `ALN AL80 / 2MM0224131051743`。
- 2026-05-27 Android 短回归通过：`-ShortSuite -ArchiveArtifacts`
  归档：`build/android-regression/20260527-170642-2MM0224131051743`
  覆盖：家长管理折叠后的数据保护记录、报告/错题/学习记录回跳、成长报告变化点、闯关地图返回。
- 2026-05-27 成长报告专项通过：`-GrowthTrendOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260527-165231-2MM0224131051743`
  脚本同步：先展开“家长管理 -> 成长与历史 -> 家长看详细报告”，再进入周报；报告详情返回后重新打开变化点再查错题/学习记录。
- 轻量短套件通过：`-ShortSuite -ArchiveArtifacts`
  归档：`build/android-regression/20260526-165121-2MM0224131051743`
- 轻量短套件通过：`-ShortSuite -ArchiveArtifacts`
  归档：`build/android-regression/20260526-133712-2MM0224131051743`
- 成长报告到地图章节详情专项通过：`-ChallengeMapReturnOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260526-132723-2MM0224131051743`
- 轻量短套件通过：`-ShortSuite -ArchiveArtifacts`
  归档：`build/android-regression/20260526-101122-2MM0224131051743`
- 成长报告趋势点专项通过：`-GrowthTrendOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260526-095910-2MM0224131051743`
- 成长报告到地图章节详情专项通过：`-ChallengeMapReturnOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260526-065653-2MM0224131051743`
- 成长报告趋势点专项通过：`-GrowthTrendOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260525-103616-2MM0224131051743`
- 成长报告到地图章节详情专项通过：`-ChallengeMapReturnOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260525-105303-2MM0224131051743`
- 成长报告趋势点专项通过：`-GrowthTrendOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260525-060207-2MM0224131051743`
- 成长报告到地图章节详情专项通过：`-ChallengeMapReturnOnly -ArchiveArtifacts`
  归档：`build/android-regression/20260525-062216-2MM0224131051743`
- 轻量短套件通过：`-ShortSuite -ArchiveArtifacts`
  归档：`build/android-regression/20260525-064637-2MM0224131051743`

## 后续平台专项

- Android：继续维护短入口优先、完整脚本兜底的策略。
- 来源提示会在约 4 秒后从完整浮层收起为来源 chip；真机脚本应接受“完整文案”或“来源 chip”任一状态，不应强依赖完整浮层一直存在。
- Windows：保持本地 provider/repository/widget 测试可无设备运行。
- iOS：后续补 Xcode 构建、权限和通知专项验证。
## 2026-05-25 最新回归记录

- `-ChallengeMapReturnOnly -ArchiveArtifacts -SkipBuild -SkipInstall` 通过。
- 归档：`build/android-regression/20260525-124943-2MM0224131051743`
- 覆盖：成长报告进入闯关地图、章节详情最近推进记录、学习记录/报告/错题反查入口、返回章节详情。
- 脚本策略：成长报告关注关卡会动态命中接龙、飞花令或听写，专项注入数据需要覆盖三个候选 stage；返回高亮提示可能自动收起，主断言应以“章节详情 + 最近推进区可见”为准。
