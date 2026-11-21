# 菜单栏 TOTP 验证码（本地 Keychain 存储）

> 调研日期 2026-11-20 · 上游 <https://github.com/jerry-pond/TOTPBar> @ v0.2.3
> 决策：**MVP** · 建议标签：`enhancement`

### 问题或动机

登录 GitHub、云控制台、公司 VPN 时都要打开手机找 6 位验证码，再手敲到 Mac 上。手机上切换 App、解锁、翻找条目本身就是十几秒；如果手机不在手边，流程直接断掉。Tina 已经在菜单栏常驻，却没有一个本地、无账号的验证码入口。

### 期望的解决方案

**MVP**

- 「实用工具」新增验证器：可粘贴 `otpauth://` 链接添加，或复用现有「识别屏幕文字/二维码」直接扫描屏幕上的二维码。
- 菜单面板和快捷面板列出条目与剩余秒数，点击复制验证码；默认隐藏具体数字，悬停或按住才显示。
- 条目可重命名、排序、删除；密钥只存 Keychain，不写 UserDefaults、不落明文日志。
- 支持标准 TOTP（SHA1/SHA256/SHA512、6/8 位、自定义周期）。
- 复制后按现有「自动清空剪贴板」规则处理；列表在截图/录屏时自动遮罩。

**后续可选**

- 相机扫码新增、导入 Google Authenticator 导出文件。
- 全局快捷键直接填充当前焦点输入框（类似上游的 `⇧⌘0–9`）。

第一版明确不做：任何云同步/账号、本地 HTTP API、passkey/WebAuthn、密码管理器功能。

### 功能区域

实用工具（Utilities）

### 草图 / 参考

- 上游：<https://github.com/jerry-pond/TOTPBar>（v0.2.3，2026-06-07）
- 关键参考：README 的「QR code image scanning」「Local-only storage」「Global fill shortcuts」与 HTTP API 章节
- 与 Tina 现有功能的入口关系：新增「实用工具」卡片与菜单面板分组；直接复用 `Services/Clipboard` 的复制与自动清空、`screenOCR` 的二维码识别、`QuickTools` 的快捷面板。

### 开源参考（可选）

- 来源：<https://github.com/jerry-pond/TOTPBar> @ v0.2.3
- 调研 skill：`/tina-feature-research`
- 结论：MVP

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass | 上游为原生菜单栏 App，无 15+ API；Tina 14 可用 |
| 原生实现 | pass | 上游 Swift/ObjC，release 0.5 MB；Tina 用 CryptoKit/HMAC 重写，无第三方依赖 |
| 上游 Release 体积（若有） | pass | arm64/x86_64 zip 各 0.5 MB |
| 复杂度 | pass | 无新权限（扫码复用现有屏幕录制授权或相机授权）；无 helper、无网络 |
| 不重复 | new | Tina 没有验证器/密钥管理；剪贴板与二维码能力可复用 |

#### 上游产品价值

- JTBD：在 Mac 上快速取得 2FA 验证码，不必掏手机。
- 频率与痛点：每天多次；痛点中高（手机不在手边时直接阻塞）。
- 替代品：手机上的 Google Authenticator/Authy、1Password/Elpass（付费）、Raycast 插件。
- 可核实信号：作者把它作为独立产品维护，README 明确“local-first、无云账号”；用户量 unknown（仓库 star 极少，不作为价值依据）。

#### Tina 用户增量收益

- 新增能力：Tina 第一次具备“安全凭据”类能力，且完全本地。
- 协同：复用剪贴板自动清空、二维码识别、快捷面板、截图遮罩模式。
- 替代：可少装一个验证器 App/浏览器插件。
- 代价：处理密钥的安全责任（Keychain、截图、日志、剪贴板）；需要一次安全审查。

#### 成本、风险与 MVP

- 规模：M（TOTP 算法 + Keychain 存储 + 列表/倒计时 UI + 导入 + 本地化）
- Tina 增量体积：约 0.2–0.4 MB
- 主要风险：密钥泄露面（日志、崩溃报告、剪贴板、录屏）；`otpauth` 解析要防注入
- MVP 边界：标准 TOTP + Keychain + 粘贴/扫码导入 + 复制；不做云同步、HTTP API、快捷键填充
- 决策：**MVP**——价值高、体积小、无新权限；先做只读、无网络的本地实现

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | 5 | 高频、明确的日常需求 |
| Tina 用户收益 | 4 | 新增能力，可替代一个 App |
| 契合度 | 4 | 复用剪贴板/二维码/面板，但引入安全敏感数据 |
| 实现成本（反向） | 4 | S–M，无外部依赖 |
| 风险（反向） | 3 | 安全责任明显，需要审查与遮罩 |
