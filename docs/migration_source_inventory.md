# 迁移来源清单

## 结论

`GSCapp` 中最值得迁移的是数据、规则和业务流程，不值得直接复用的是 React 组件层、Tauri 壳和浏览器语音实现。新项目已经把核心 seed 数据抽取到 `GSCAPPALL/assets/seed`，并把服务与 repository 结构改写为 Flutter 可继续接入的形式。

## 可复用数据源

### 一级数据源

- `D:\GSCapp\gushici-app\src\data\poemsData.ts`
  价值：当前质量最高、字段最完整的诗词主数据源。
  已提取字段：标题、作者、朝代、年级、主题、原文、拼音、注释、译文、赏析、作者介绍、拓展、难度、可选音频/图片字段。
  本轮处理结果：已自动提取为 `assets/seed/poems_seed.json`，共 165 首。

### 二级数据源

- `D:\GSCapp\gushici-app\public\poems.json`
  价值：旧项目分发用 JSON，可用于交叉核对。
  风险：内容完整度和编码质量不如 `poemsData.ts`。
- `D:\GSCapp\poems_basic_info.json`
  价值：补充年级/基础目录信息。
  风险：编码存在明显异常，本轮不作为主 seed。
- `D:\GSCapp\gushici-app\poems_data_template.json`
  价值：导入模板参考。
  风险：编码异常、结构混杂。
- `D:\GSCapp\诗词数据模板.csv`
- `D:\GSCapp\诗词数据模板.xlsx`
  价值：人工校对模板和后续内容运营入口。

## 可迁移规则与算法

### P0 直接吸收

- `D:\GSCapp\gushici-app\src\services\database.ts`
  吸收内容：收藏、学习记录、每日一诗、打卡、历史记录、用户设置的业务边界。
- `D:\GSCapp\gushici-app\src\utils\speechScoring.ts`
  吸收内容：基于文本对齐、完整度和准确率的朗读评分思路。
- `D:\GSCapp\gushici-app\src\components\HomePage.tsx`
  吸收内容：首页信息架构，包含搜索入口、每日一诗、分类入口、学习卡片入口。
- `D:\GSCapp\gushici-app\src\components\PoemList.tsx`
  吸收内容：按主题、朝代、学习阶段筛选诗词库。
- `D:\GSCapp\gushici-app\src\components\PoemDetail.tsx`
  吸收内容：详情页以原文、注释、译文、赏析、作者、拓展为核心层次。
- `D:\GSCapp\gushici-app\src\components\DailyPoemPage.tsx`
  吸收内容：每日一诗、打卡和历史回顾的主流程。
- `D:\GSCapp\gushici-app\src\components\FlashcardMode.tsx`
  吸收内容：学习卡片、收藏过滤、复习节奏的业务方向。
- `D:\GSCapp\gushici-app\src\components\ProfilePage.tsx`
  吸收内容：学习统计、收藏、成就、设置的组织方式。

### P1/P2 继续迁移

- `D:\GSCapp\gushici-app\src\services\assessmentService.ts`
  吸收内容：题目生成、错题分类、知识点映射、基础报告结构。
- `D:\GSCapp\gushici-app\src\services\challengeService.ts`
  吸收内容：章节关卡、星级通关和挑战关设计。
- `D:\GSCapp\gushici-app\src\services\jielongService.ts`
  吸收内容：接龙首尾字规则、同音兜底、AI 接句策略。
- `D:\GSCapp\gushici-app\src\services\feihualingService.ts`
  吸收内容：飞花令主题字池、句子提取、基础校验逻辑。

## 不可直接复用的实现

- `D:\GSCapp\gushici-app\src\**\*.tsx`
  原因：React 组件树、状态写法、事件模型与 Flutter 完全不同，只能迁移交互结构，不能复制代码。
- `D:\GSCapp\gushici-app\src-tauri\**\*`
  原因：Tauri/Rust 桌面壳与 Flutter 多端工程不兼容。
- `D:\GSCapp\gushici-app\src\types\speech-recognition.d.ts`
- `window.speechSynthesis`
- Web Speech API 相关浏览器实现
  原因：新项目明确要求 iOS / Android 走原生能力，Windows 只保留接口层，不复制 Web 方案。
- `@tauri-apps/plugin-sql`、`@tauri-apps/plugin-dialog`、`@tauri-apps/plugin-fs`
  原因：属于旧壳层插件能力，不应带入 Flutter 主线。
- `node_modules`、`dist`、`src-tauri/target`、`古诗词学习.exe`
  原因：全部是构建产物或旧运行时依赖，不具有迁移价值。

## 本轮迁移产物

- `D:\GSCAPPALL\assets\seed\poems_seed.json`
- `D:\GSCAPPALL\assets\seed\seed_manifest.json`
- `D:\GSCAPPALL\tools\extract_seed.ps1`

