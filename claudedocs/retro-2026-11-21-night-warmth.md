# PR #15（Night warmth）复盘（2026-11-21）

范围：`feature/night-warmth` → `dev`，[PR #15](https://github.com/zbl-jerry/tina/pull/15)，5 个提交：功能本体、过渡行对齐、面板入口可见性、文档截图、删除调研 skill 的截图规则。本文记录可复用的经验，不替代 PR 与提交记录。

## 做对了

- **PR 写清边界**：before/after、包含项、明确不做的四项（Night Shift 检测、快捷键、Dimmer/Brighter、按显示器排除）。评审能直接判断范围。
- **实机验证发现真实回归**：`09fabd3` 修复了「只在开启亮度控制时才显示 Displays 页」的问题。单测覆盖不到入口可见性，这类问题只能靠真实窗口验证。
- **把恢复路径当验收项**：退出、禁用、崩溃恢复都写回 identity gamma 表，并在 PR 里记录了运行时 marker 的验证过程。
- **文案与文档同步**：`docs/NIGHT-WARMTH.md` 写清机制和限制，15 个 locale 一起更新。

## 教训

1. **不要派子 agent 截图。** 截图路径在用户桌面上执行，子 agent 驱动窗口或 `screencapture` 会把宿主 macOS 卡死。已从 `.claude/skills/tina-feature-research` 删除「菜单/设置截图」作为证据来源，并在该 skill 的「必须避免」里加入禁止项。以后截图只在主会话、窗口级执行，不放进无人值守流程。

2. **CI 未转绿就继续推进。** 两次既有 run（44785807544、44797187825）的 `Build & selftest` 都是 `cancelled`，整体结论是 failure。取消不等于通过；合入前必须确认**最新一次** run 全绿。`.github/workflows/ci.yml` 的 `concurrency` 会在新 push 时取消进行中的 PR run，所以要看最新 run。

3. **分支与发布基线假设错误。** 上次 release 从 `main` 构建，容易让人以为发布也从 `main` 走；但 `CONTRIBUTING.md:114` 写明 `dev` 是唯一开发分支，`main` 只用于同步上游，PR #15 的目标分支也是 `dev`。发布必须基于 `dev`。

4. **文档与工具行为漂移。** `build.sh:101` 的注释提到 `release.yml`，但仓库只有 `.github/workflows/ci.yml`。看到这类不一致要顺手修掉或在 issue 里记录，不能当作事实继续引用。

5. **版本 bump 不属于功能 PR。** `Resources/Info.plist` 在功能 PR 里仍是 3.4.4 / build 106；版本升级是 maintainer 动作，应在合并后单独提交，否则 DMG 版本会与上一版重复。

6. **无关改动混入功能 PR。** 删除调研 skill 的截图规则属于流程文档，理想是单独分支、单独 PR；这次按指示并入 #15，扩大了评审边界。以后 docs/skill 改动单独走。

7. **发布流程没有脚本，步骤全靠手工。** bump 版本 → `./build.sh` → `--selftest` → `Tools/make-dmg.sh` → 计算 SHA-256 → 写 release notes → `gh release create`，任何一步漏掉都会产生不一致的发布物。值得补一个 `Tools/release.sh`。

8. **CI 覆盖不到运行时风险。** gamma 表恢复、多显示器热插拔、睡眠唤醒后重新应用，这些只能在实机验证；发布说明必须写清「未 notarize」与首启步骤，避免用户误以为有系统级保障。

## 合并前清单

- [ ] PR 目标分支是 `dev`
- [ ] 最新一次 CI run 全绿（`cancelled` 不算通过）
- [ ] 变更范围与 PR 描述一致；无关改动已拆出
- [ ] 版本号 bump 单独提交（发布时）
- [ ] 运行 `./build/Tina --selftest` 与 `./build.sh --test`

## 发布清单

- [ ] `Resources/Info.plist` 的 `CFBundleShortVersionString` / `CFBundleVersion` 已更新
- [ ] `./build.sh` 成功，`./build/Tina --selftest` 通过
- [ ] `./Tools/make-dmg.sh` 生成 `dist/Tina-<version>.dmg`
- [ ] release notes 含安装步骤、未 notarize 说明、SHA-256
- [ ] tag `v<version>` 指向实际构建的提交（`dev`）

## 后续改进

- 新增 `Tools/release.sh`，串起 bump、build、test、DMG、校验和、发布。
- 为 docs-only 变更提供统一的 `[skip ci]` 约定（已写入 `CLAUDE.md`）。
- 把「最新 CI run 全绿」作为合并硬条件。
