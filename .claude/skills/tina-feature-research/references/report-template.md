# Feature issue 报告模板

按 `.github/ISSUE_TEMPLATE/feature_request.yml` 的字段输出；先写用户问题，再写方案，最后附开源调研证据。不要先讲上游项目有多好。

```markdown
### 问题或动机

<!-- 谁、在什么场景、现在怎么做、痛在哪里。不要写“这个项目很火”。 -->

### 期望的解决方案

<!-- 用户看到的行为；先写 MVP，再写可选增强。明确不做什么。 -->

**MVP**

- ...

**后续可选**

- ...

### 功能区域

<!-- 从模板选项中原样选一个：基础功能 / 实用工具 / 声音 / 能耗与显示 / 窗口与程序坞 / 鼠标与键盘 / 文件 / App 管理 / App / 其他 -->

能耗与显示（Energy and display）

### 草图 / 参考

<!-- 上游仓库、README、release、相关 issue；注明只借鉴产品行为，代码按 Tina 架构重写。 -->

- 上游：<repo URL>（<commit/tag>）
- 关键参考：<README 章节 / release notes / issue>
- 与 Tina 现有功能的入口关系：<设置页 / 菜单面板 / Island / 快捷键>

### 开源参考（可选）

<!-- 来自开源调研时填写；不是开源项目可留空。 -->

- 来源：<repo URL> @ <commit/tag>
- 调研 skill：`/tina-feature-research`
- 结论：pursue / MVP / defer / reject

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass / conditional / fail | <部署目标 / API / 14 降级方案> |
| 原生实现 | pass / conditional / fail | <语言、可重写模块、依赖> |
| 上游 Release 体积（若有） | pass / caution / n/a | <上游主产物名与大小；无 release 写 n/a 并跳过> |
| 复杂度 | pass / conditional / fail | <新 helper/扩展/服务/私有 API> |
| 不重复 | new / enhancement / duplicate | <对应 Tina 现有功能> |

#### 上游产品价值

- JTBD：<用户任务>
- 频率与痛点：<高/中/低 + 依据>
- 替代品：<系统功能 / 付费 App / Tina 现有功能>
- 可核实信号：<issue/release/迁移诉求；没有就写 unknown>

#### Tina 用户增量收益

- 新增能力：<以前做不到什么>
- 协同：<复用的现有服务/权限/入口>
- 替代：<能否少装一个 App>
- 代价：<权限、维护、支持、冲突>

#### 成本、风险与 MVP

- 规模：S / M / L / XL（依据）
- Tina 增量体积：<估计区间与依据；与上游 release 体积分开>
- 主要风险：<私有 API / 权限 / 体积 / 维护>
- MVP 边界：<第一版只做什么，明确不做什么>
- 决策：pursue / MVP / defer / reject + 一句话理由

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | | |
| Tina 用户收益 | | |
| 契合度 | | |
| 实现成本（反向） | | |
| 风险（反向） | | |
```

## 写作要求

- 先给结论，再给证据；不要用“可能”“也许”掩盖未验证的事实。
- 所有数字给出来源或写 `unknown`；不编造用户量、性能提升、付费意愿。
- 方案按用户可见行为描述，不写上游类名/文件名。
- 明确 MVP 不做什么，避免第一版变成完整复刻。
- 涉及私有 API、特权 helper、系统扩展时，必须写失败/权限被拒时的降级行为。
- 默认不直接创建 issue；用户确认标题、标签、正文后再执行 `gh issue create`。
