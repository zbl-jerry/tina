# 支持 hosts 配置切换（本地 profile + 一键应用）

> 调研日期 2026-11-20 · 上游 <https://github.com/oldj/SwitchHosts> @ v5.0.3
> 决策：**MVP** · 建议标签：`enhancement`

### 问题或动机

开发、测试同学经常要改 `/etc/hosts`：本地联调把域名指到 `127.0.0.1`，切到测试环境又指向内网网关，切回生产还要清掉。现在只能手写 `sudo vim /etc/hosts`，或者装 SwitchHosts。手工改的问题是：没有备份、容易忘删、多套配置无法保存、每次都要输密码。

### 期望的解决方案

**MVP**

- 在「实用工具」里新增 hosts 配置：每条配置有名称和内容，可启用/停用、可排序。
- 一次“应用”把启用的配置按顺序拼接到系统 hosts 文件，写入前自动备份当前 hosts，提供一键恢复。
- 只在应用时请求一次管理员授权（一次系统密码框），不安装常驻 helper、不加 sudoers 规则。
- 菜单面板里能快速切换启用组合，并在应用后显示实际生效的行数。
- 写入前做静态校验：只接受 IP + 主机名 + 注释格式，拒绝换行注入、重定向和路径穿越。

**后续可选**

- 远程 hosts 订阅与定时刷新（会引入网络与失败重试）。
- 分组/文件夹、语法高亮编辑器、查找替换、历史版本。

第一版明确不做：远程订阅、HTTP API、多用户共享、自动切换网络环境。

### 功能区域

实用工具（Utilities）

### 草图 / 参考

- 上游：<https://github.com/oldj/SwitchHosts>（v5.0.3，2026-10-20）
- 关键参考：README 的「Organize local and remote hosts in groups and folders」「Switch hosts from the main window or system tray」；`docs/guide.md` 的保存/恢复流程
- 与 Tina 现有功能的入口关系：「实用工具」设置页新增 hosts 卡片，菜单面板提供启用组合的快速开关；与 Port Manager、Homebrew 同属开发工具场景，但不复用它们的服务。

### 开源参考（可选）

- 来源：<https://github.com/oldj/SwitchHosts> @ v5.0.3
- 调研 skill：`/tina-feature-research`
- 结论：MVP

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass | 功能只需要文件读写与普通授权，不依赖 15+ API；Tina 的 14 最低版本无影响 |
| 原生实现 | conditional | 上游是 Tauri + React（`package.json`、`src-tauri/`）。Tina 只重写数据模型、拼接与写入，约 S–M；编辑器可用 AppKit `NSTextView`。运行时和 WebView 全部丢弃 |
| 上游 Release 体积（若有） | pass | v5.0.3 主产物 macOS aarch64 DMG 4.5 MB、universal 9.1 MB |
| 复杂度 | conditional | 需要写 `/etc/hosts`（root）。上游通过 XPC helper（`net.oldj.switchhosts.helper.plist`）+ elevation 实现；Tina MVP 改为一次性管理员授权，不新增常驻 helper |
| 不重复 | new | Tina 没有 hosts 或系统配置文件管理；与 Port Manager/Homebrew 只是同场景 |

#### 上游产品价值

- JTBD：开发者在本地/测试/生产之间切换域名解析。
- 频率与痛点：中高频（每次联调都要切）；手工编辑易残留、无备份，痛点中高。
- 替代品：手动 `sudo vim`、Gas Mask（已停更）、SwitchHosts 本身。
- 可核实信号：v5.0.3 仍在更新（2026-10），项目有完整 e2e 覆盖（`e2e/system-hosts.spec.ts`）；用户量、付费意愿 unknown。

#### Tina 用户增量收益

- 新增能力：以前在 Tina 里完全做不到；现在无需离开菜单栏即可切换解析。
- 协同：复用菜单面板、设置页、Feature Hub 的安装/卸载模型；与 Port Manager（本地服务）场景相邻。
- 替代：可少装一个 Electron/Tauri 常驻 App。
- 代价：一次管理员授权；写错 hosts 会影响网络，必须有备份与校验。

#### 成本、风险与 MVP

- 规模：M（数据模型 + 写入 + 授权 + 备份/恢复 + 设置与面板 UI + 本地化）
- Tina 增量体积：约 0.2–0.5 MB（纯代码与界面，无资源包）
- 主要风险：root 写系统文件（注入/误删）、管理员弹窗的 UX、恢复路径必须可靠
- MVP 边界：本地 profile + 启用组合 + 一次授权 + 备份/恢复 + 校验；不做远程订阅、分组、语法高亮、API
- 决策：**MVP**——用户价值明确、体积可控；把“常驻特权 helper”换成一次性授权后风险可接受

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | 4 | 开发场景明确，长期维护，替代品少 |
| Tina 用户收益 | 4 | 新增能力，且能少装一个常驻 App |
| 契合度 | 4 | 复用面板/设置/Feature Hub；新增一次性授权流程 |
| 实现成本（反向） | 3 | M 规模，主要是授权与恢复路径 |
| 风险（反向） | 3 | root 写系统文件，但可校验、可备份、无常驻权限 |
