# 把当前显示器的窗口平铺成网格（Tile All / Rows / Columns）

> 调研日期 2026-11-20 · 上游 <https://github.com/rxhanson/Rectangle> @ v2.0.4
> 决策：**MVP** · 建议标签：`enhancement`

### 问题或动机

Tina 的窗口布局已经有 60 多个单窗口动作（半屏、三分、六分、四角）、边缘吸附、自定义区域和拖拽手势，但所有动作都只作用于“当前窗口”。当屏幕上散着 5–8 个窗口时，想快速把它们排成整齐的两列或 3×2 网格，只能一个个按快捷键再手动微调；现在没有“一次排好所有窗口”的动作。

### 期望的解决方案

**MVP**

- 新增三个布局动作：平铺成网格（Tile All）、按行平铺（Rows）、按列平铺（Columns），作用于焦点窗口所在显示器上的所有普通窗口。
- 重复按同一动作时循环切换不同网格（如 5 个窗口在 `1×5`、`2+3`、`3+2` 之间切换），跳过重复布局。
- 从窗口左上角位置推导初始顺序；默认每行/每列上限 3，可在设置里分别调整。
- 尊重现有边缘间距、菜单栏与 Dock 预留区；忽略现有“布局忽略 App”列表里的应用。
- 某个 App 不响应时保持原样，不阻塞其他窗口；结束后给出轻量提示。

**后续可选**

- 堆叠窗口循环（Cycle Stacked Windows）。
- 为窗口动作绑定鼠标侧键（Tina 已有鼠标按键能力，但尚未接入窗口动作）。

第一版明确不做：跨显示器一起平铺、级联（Cascade）、动画过渡、持久化布局网格。

### 功能区域

窗口与程序坞（Windows and Dock）

### 草图 / 参考

- 上游：<https://github.com/rxhanson/Rectangle>（v2.0.4，2026-10-20）
- 关键参考：README 的「Tile windows in rows or columns」「Tile All」「Cycle stacked windows」「Ignore an app」
- 与 Tina 现有功能的入口关系：扩展 `Services/WindowLayout`（`WindowLayoutAction` 枚举 + `WindowLayoutService.apply`），复用现有的 AX frame 设置、settle/verify 重试与忽略 App 逻辑；入口仍是「窗口与程序坞 → 窗口布局」的快捷键页。

### 开源参考（可选）

- 来源：<https://github.com/rxhanson/Rectangle> @ v2.0.4
- 调研 skill：`/tina-feature-research`
- 结论：MVP（仅多窗口平铺）

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass | 上游 v2 要求 macOS 14+；Tina 14 可用，无 15+ API |
| 原生实现 | pass | Swift 原生；Tina 直接在现有 AX 管线上扩展 |
| 上游 Release 体积（若有） | pass | `Rectangle2.0.4.dmg` 4.7 MB |
| 复杂度 | pass | 只用 Accessibility 设置窗口 frame，无新权限/服务；难点是“窗口不响应”时的超时处理，Tina 已有 settle 逻辑 |
| 不重复 | enhancement | 单窗口布局、边缘吸附、自定义区域已有；完全没有多窗口平铺 |

#### 上游产品价值

- JTBD：把桌面上的一堆窗口一次排整齐，而不是逐个摆放。
- 频率与痛点：多窗口工作者每天多次；痛点中高（手工对齐费时且不精确）。
- 替代品：Rectangle（免费）、Magnet（付费）、系统 Sequoia 的窗口拖拽（只能单个）。
- 可核实信号：Rectangle 把 Rows/Columns 与 Tile All 作为 2.x 的重点特性详细介绍，说明用户确实在要求多窗口布局；用户量 unknown。

#### Tina 用户增量收益

- 新增能力：从“摆一个窗口”升级为“摆一组窗口”。
- 协同：完全复用窗口布局服务、快捷键注册、忽略 App 与边缘区域设置。
- 替代：可少装 Rectangle 的这部分能力。
- 代价：窗口数量多时 AX 调用变慢；部分 App 有最小尺寸/宽高比限制。

#### 成本、风险与 MVP

- 规模：M（布局算法 + 多窗口枚举 + 超时 + 设置项）
- Tina 增量体积：< 0.2 MB
- 主要风险：不响应窗口让动作看起来“卡住”；App 最小尺寸导致网格不整齐
- MVP 边界：只做当前显示器的 Tile All / Rows / Columns 与循环布局；不做跨屏、级联、动画
- 决策：**MVP**——与现有窗口布局高度同源，是用户最容易感知的补齐

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | 5 | 3 万 star、长期维护、多窗口刚需 |
| Tina 用户收益 | 4 | 现有能力的明显缺口，使用频率高 |
| 契合度 | 5 | 复用 WindowLayout 服务与快捷键 |
| 实现成本（反向） | 4 | M，无新权限 |
| 风险（反向） | 4 | AX 超时可控，最坏情况是部分窗口不动 |
