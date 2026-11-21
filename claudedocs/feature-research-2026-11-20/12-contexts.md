# 窗口分组：把窗口按“上下文/项目”分组，在切换器里整组切换

> 调研日期 2026-11-20 · 参照闭源 Contexts 3.9 与 3 个开源 per-window 任务栏实现
> 决策：**defer**（常驻窗口条）；分组作为切换器增强可另行评估 · 建议标签：`enhancement`

### 问题或动机

同时开 20+ 个窗口时，Tina 的 App 切换器和程序坞悬停预览已经能按 App 列出窗口，但用户真正的心智单位常常是“项目”而不是 App：一个项目 = 编辑器 + 两个终端 + 浏览器里三个标签页 + 设计稿。现在切回去要分别找每个窗口；按 ⌘Tab 在 App 之间跳，跳完还得再找窗口。常驻窗口任务栏（uBar/Contexts 一类）想解决的就是“所有窗口一眼可见、一键可达”。

### 期望的解决方案

**MVP（若做）**

- 在切换器中增加“窗口组”：用户把窗口加入命名组（如“Tina 开发”“客户 A”），组在切换器/菜单面板里作为一条入口。
- 激活组时按用户设定顺序依次唤起组内窗口（不隐藏其他窗口，不移动窗口）。
- 组配置保存在本地，窗口用 App + 标题特征匹配，避免依赖易变的 windowID。
- 组内窗口已关闭时显示占位并允许清理。

**后续可选**

- 常驻窗口条（屏幕边缘，一窗口一按钮，点击唤起/最小化）——这是 Contexts 与三个参考项目的核心 UI。
- 跨 Space/跨显示器分组、自动按项目目录分组。

第一版明确不做：常驻任务栏、自动推断分组、替换程序坞、窗口缩略图墙。

### 功能区域

窗口与程序坞（Windows and Dock）

### 草图 / 参考

- 闭源参考：<https://contexts.co/>（Contexts 3.9，$9.99，窗口搜索/切换、侧边栏、多 Space/多显示器）
- 开源参考（per-window 任务栏）：
  - <https://github.com/moonbai-studio/tungsten-edge>（Swift，GitHub 无 release 资产，官网分发）
  - <https://github.com/turhe123/window-taskbar-strip>（MIT，v1.0.0，`WindowTaskbarStrip-macOS.zip` 0.5 MB）
  - <https://github.com/saenai255/openbar>（MIT，v1.2.1，DMG 2.1 MB，要求 macOS 26）
- 关键参考：tungsten-edge 的「one card per window / minimized card stays in place」；window-taskbar-strip 的「click to raise, click again to minimize」「graceful fallback without Accessibility」
- 与 Tina 现有功能的入口关系：Tina 已有 App 切换器（搜索、实时预览、显示器过滤、App 分组）、程序坞悬停预览（切/关/移/吸附）。分组是切换器之上的一层组织方式，不需要新窗口服务。

### 开源参考（可选）

- 来源：Contexts 3.9（闭源）；tungsten-edge；window-taskbar-strip；openbar
- 调研 skill：`/tina-feature-research`
- 结论：defer（常驻窗口条）；分组功能属于现有切换器的增强，需先验证需求

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass | 分组与切换都基于现有 Accessibility/窗口枚举；Tina 14 可用 |
| 原生实现 | pass | 三个开源参考均为 Swift；openbar 的窗口预览用 ScreenCaptureKit |
| 上游 Release 体积（若有） | pass / n/a | tungsten-edge 无 GitHub release（跳过）；window-taskbar-strip 0.5 MB；openbar 2.1 MB |
| 复杂度 | conditional | 分组本身只需 AX + 本地存储（pass）；常驻任务栏需要常驻面板、跨 Space 跟随、窗口身份跟踪与缩略图，属于新的常驻 UI 子系统 |
| 不重复 | enhancement / duplicate | 窗口切换、搜索、预览、跨 Space 已由 Switcher 与 Dock Preview 覆盖；“常驻窗口条”是同一能力的另一种 UI |

#### 上游产品价值

- JTBD：在多个项目间切换时，一次回到某个项目的一组窗口。
- 频率与痛点：窗口极多的用户高频；普通用户低频。痛点中高，但人群窄。
- 替代品：macOS Mission Control/Stage Manager（整理而非切换）、uBar/Contexts（付费）、Tina 现有切换器与程序坞预览。
- 可核实信号：Contexts 以 $9.99 售卖多年，说明有人付费；但三个开源实现 star 很少（1/2/669），且 openbar 要求 macOS 26，说明需求存在但实现分散、成熟度不一。

#### Tina 用户增量收益

- 新增能力：按“项目/上下文”而非 App 组织窗口；一次恢复一组窗口。
- 协同：复用 Switcher 的窗口枚举、AX 激活、跨 Space 逻辑与菜单面板入口。
- 替代：可少装 Contexts/uBar（但仅覆盖“分组”，不覆盖常驻任务栏）。
- 代价：常驻条与 Tina“单菜单栏图标”的产品形态冲突；窗口身份（ID/标题）易变，分组需要模糊匹配与清理逻辑。

#### 成本、风险与 MVP

- 规模：分组 M；常驻任务栏 L
- Tina 增量体积：分组约 0.2–0.4 MB；常驻条另加 0.5 MB 以上与缩略图开销
- 主要风险：分组维护成本（窗口关闭/重开/标题变化）、常驻 UI 与全屏/Space 的交互、用户对“另一个任务栏”的接受度
- MVP 边界：只做“命名窗口组 + 在切换器中整组唤起”，不做常驻窗口条与自动分组
- 决策：**defer**——现有 Switcher/Dock Preview 已覆盖“切到任意窗口”的核心任务，常驻窗口条属于重复 UI 且违反“单菜单栏图标”的形态；分组是唯一增量，但价值尚未验证。触发条件：出现持续的用户请求，或分组能在不引入常驻 UI 的前提下被验证为高频使用

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | 4 | Contexts 付费验证了窗口切换需求，但人群窄 |
| Tina 用户收益 | 2 | 核心切换能力已存在，增量偏边际 |
| 契合度 | 3 | 分组可复用切换器；常驻条是新子系统 |
| 实现成本（反向） | 3 | 分组 M；常驻条 L |
| 风险（反向） | 3 | 窗口身份不稳定，UI 形态冲突 |
