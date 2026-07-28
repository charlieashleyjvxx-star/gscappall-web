# 本关证据 UI 规范

本规范用于统一成长报告、闯关地图、报告详情、错题详情、学习记录详情中的“本关证据”表达。

## 共享组件

- `StageProgressEvidenceCard`：用于展示单条推进证据，例如趋势点练习记录、章节详情最近推进记录。
- `StageContributionCard`：用于展示这条记录如何贡献到关卡，例如句数贡献、分数贡献、错题改善。
- `StageScopeDetailEvidencePanel`：用于详情页落点，统一展示本关说明、反查证据按钮和回到地图/成长报告入口。
- `StageScopeEvidenceActions`：用于“查看本关报告 / 查看本关错题 / 查看学习历史”等反查按钮区。

## 页面接入规则

- 成长报告趋势点和章节详情最近推进记录，应优先使用 `StageProgressEvidenceCard`。
- 报告详情、错题详情、学习记录详情，应使用 `StageScopeDetailEvidencePanel` 承载本关证据说明。
- 详情页里的反查按钮应使用 `StageScopeEvidenceActions`，不要在页面内重复手写一套按钮布局。
- 来源提示仍使用 `StageScopeDetailSourcePanel` 或 `StageScopeFloatingBanner`，并允许 4 秒后自动收起。

## 文案规则

- 标题使用“本关报告证据 / 本关错题证据 / 本关学习证据 / 推进证据卡 / 趋势点推进证据”。
- 关卡统一显示为 `推进关卡：<关卡名>`。
- 贡献标签统一使用“句数贡献 / 分数贡献 / 错题改善 / 报告/错题已回流”。
- 反查入口优先包含：`查看本关报告`、`查看本关错题`、`查看学习历史`。

## 回归要求

- 修改成长报告趋势点弹层时，优先跑 `-GrowthTrendOnly -ArchiveArtifacts`。
- 修改闯关地图、章节详情、来源浮层时，优先跑 `-ChallengeMapReturnOnly -ArchiveArtifacts`。
- 修改详情页落点模板或同步日志深链时，跑 `-ShortSuite -ArchiveArtifacts` 做组合回归。
