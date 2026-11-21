# 按 App 自动切换输入法（含浏览器域名与终端程序规则）

> 调研日期 2026-11-20 · 上游 <https://github.com/zbl-jerry/TypeLock> @ v1.0.0
> 决策：**MVP**（先做按 App 规则）· 建议标签：`enhancement`

### 问题或动机

中英混用的用户每天都在重复同一个动作：在编辑器里用英文输入法，切到微信/浏览器又得切回中文。系统「自动切换到文稿的输入源」只按 App 记住一个源，不区分“刚启动”和“切回前台”，也处理不了“浏览器里写代码时用英文、看文档时用中文”这种同一 App 内不同页面的情况。每次切错都要先删掉半句话再重打。

### 期望的解决方案

**MVP**

- 每条规则绑定一个 App，可分别设置两种时机：启动后首次激活、之后再次激活。
- 每条规则可从四种行为里选：跟随全局默认、固定某个输入源、记住上次使用的源、不切换。
- 全局默认规则 + 排除列表（某些 App 永不自动切换）。
- 规则可导入/导出为 JSON，便于换机和放在 dotfiles 里。
- 菜单面板提供当前输入法状态和手动切换入口；切换发生在 App 激活之后，绝不在按键过程中抢占。

**后续可选**

- 浏览器域名规则（精确域名/后缀/URL 正则）。
- 终端前台程序规则（tmux/WezTerm/iTerm2）。
- 光标旁的输入法浮标。

第一版明确不做：浏览器与终端规则、浮标动画、CJKV 焦点修复、统计。

### 功能区域

鼠标与键盘（Mouse and keyboard）

### 草图 / 参考

- 上游：<https://github.com/zbl-jerry/TypeLock>（v1.0.0，2026-11-18，MIT）
- 关键参考：README 的「Per-app rules with two timings」「Switching Precedence」「Browser Support」「Terminal Support」
- 与 Tina 现有功能的入口关系：复用 `Core/InputSourceSelection.swift`（Super Key 与 Command Bar 已在用的 TIS 封装）；设置页放在「鼠标与键盘」；控制器只监听前台 App 变化。

### 开源参考（可选）

- 来源：<https://github.com/zbl-jerry/TypeLock> @ v1.0.0
- 调研 skill：`/tina-feature-research`
- 结论：MVP

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass | 上游要求 macOS 14.0+；TIS API 长期可用，无 15+ 依赖，14 无需门控 |
| 原生实现 | pass | Swift/AppKit；Tina 域的代码量约 S |
| 上游 Release 体积（若有） | pass | v1.0.0 `TypeLock-macOS-universal.zip` 5.6 MB |
| 复杂度 | pass | 只需 Accessibility 读取前台 App；不写系统文件、不加 helper、无私有 API |
| 不重复 | new / enhancement | Tina 只按需切换输入源（Super Key 循环、Command Bar 借拉丁布局），没有“按 App 自动切换” |

#### 上游产品价值

- JTBD：让输入法跟着“我在做什么”走，而不是手动按 ⌃Space。
- 频率与痛点：每天几十次；切错的成本是删字重打，痛点高，中文用户尤其明显。
- 替代品：系统「自动切换到文稿的输入源」（行为有限）、TypeSwitch、KeyboardHolder 一类工具。
- 可核实信号：上游 README 明确列出浏览器/终端支持矩阵和降级策略；用户量 unknown。

#### Tina 用户增量收益

- 新增能力：以前只能全局手动切；现在按 App 和时机自动切。
- 协同：直接复用现有 TIS 选择逻辑、Accessibility 权限模型、设置页与 Feature Hub。
- 替代：可少装 TypeSwitch/TypeLock。
- 代价：多监听一个前台 App 通知；必须避免在打字过程中切换导致丢失按键。

#### 成本、风险与 MVP

- 规模：S–M（规则模型 + 前台监听 + 设置 UI + JSON 导入导出 + 本地化）
- Tina 增量体积：约 0.2–0.5 MB
- 主要风险：与 Super Key/Command Bar 的输入源切换互相打架；切换时机不当会吞键
- MVP 边界：只做按 App 的启动/激活两条规则 + 全局默认 + 排除；浏览器/终端/浮标后置
- 决策：**MVP**——核心价值集中在按 App 规则，成本低、与现有输入源代码同源

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | 5 | 高频刚需，行为边界清晰 |
| Tina 用户收益 | 5 | 新增核心能力，且中文用户基数大 |
| 契合度 | 5 | 复用 InputSourceSelection、Accessibility、设置与 Feature Hub |
| 实现成本（反向） | 4 | S–M，无新权限、无私有 API |
| 风险（反向） | 4 | 只需处理与现有切换逻辑的互斥与时机 |
