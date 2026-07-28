# 功能迁移计划

## 迁移原则

- P0 只保核心学习主链路
- 先迁数据和规则，再补高级交互
- 旧项目的 UI 只作参考，不直接复制实现
- 语音与平台能力先抽象接口，再逐步接真实实现

## P0

### 已落地目标

- 项目骨架
- 诗词 seed 数据迁移
- Drift 本地数据库
- 首页
- 诗词库
- 诗词详情
- 收藏
- 我的
- 每日一诗
- 学习卡片
- 本地学习记录
- 本地设置
- 音频 / 录音 / 语音 / 通知 / 同步 / 付费抽象层

### 对应旧项目来源

- `src/data/poemsData.ts`
- `src/components/HomePage.tsx`
- `src/components/PoemList.tsx`
- `src/components/PoemDetail.tsx`
- `src/components/DailyPoemPage.tsx`
- `src/components/FlashcardMode.tsx`
- `src/components/ProfilePage.tsx`
- `src/services/database.ts`
- `src/utils/speechScoring.ts`

## P1

- 朗读模式
- 背诵模式
- 听写模式
- 错题本
- 测评系统
- 基础成就与等级

### 主要迁移来源

- `src/components/ReadMode.tsx`
- `src/components/ReciteMode.tsx`
- `src/components/DictationMode.tsx`
- `src/components/Assessment*.tsx`
- `src/services/assessmentService.ts`
- `src/utils/speechScoring.ts`

## P2

- 诗词接龙
- 飞花令
- 闯关挑战
- 更完整的学习报告

### 主要迁移来源

- `src/components/Jielong*.tsx`
- `src/components/Feihualing*.tsx`
- `src/components/Challenge*.tsx`
- `src/services/jielongService.ts`
- `src/services/feihualingService.ts`
- `src/services/challengeService.ts`

## P3

- 登录注册
- 云同步
- 排行榜
- 家长端
- 教师端
- VIP
- 运营后台
- 内容审核

### 设计边界

P3 只保留接口和 repository 方向，不在当前主线中提前实现。

## 本轮之后建议顺序

1. 在装好 Flutter SDK 的机器上生成原生工程壳并跑通 Windows
2. 接通 `just_audio`、`record`、`flutter_local_notifications`
3. 完成朗读 / 背诵 / 听写真实流程
4. 接入错题分类和测评题型
5. 最后再做云同步与账号体系

