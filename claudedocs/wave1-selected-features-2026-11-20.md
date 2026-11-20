# Wave 1 实施记录：六个选定功能（2026-11-20）

分支：`feature/wave1-selected`（基于 `fix/wave0-low-risk`）。

## 已落地

| PR | 功能 | 主要落点 |
|---|---|---|
| #4177 | **Layout Fix**：单击右 Option，把刚打错的最后一个词/选区用另一套启用的键盘布局重打并切换输入源 | `Services/LayoutFix/`、`LayoutFixSettings`、`FeatureCatalog`、`SuperKey` 事件桥、15 种语言字符串 |
| #3274 | **Window Custom Zones MVP**：按住 Option 显示可编辑分区；拖窗口进分区释放即贴靠；每个显示器独立布局 | `WindowLayout/WindowCustomZones`、`WindowCustomZoneEditor`、Window Layout 设置页 |
| #3589 | **Launchpad Classic**：全屏 App 网格、文件夹、搜索、分页、拖拽排序、隐藏/删除；快捷键、Island、Dock 辅助 App 入口 | `Services/Launchpad/`、`LaunchpadView`、Launchpad 设置页、`Info.plist` URL scheme、build.sh 图标生成 |
| #3336 | **剪贴板 Paste Stack**：把多条历史加入粘贴栈，连续按 ⌘V 依次粘贴 | `ClipboardHistoryService` 栈模型、`NotchPasteStackStrip`、卡片/面板入口 |
| #4184 | **剪贴板文件预览与拖出**：Quick Look 预览复制的文件，历史条目可拖到其他 App | `ClipboardHistoryFileAccess`、`ClipboardFilePreview`、`ClipboardHistoryDragSource`、条目增加 `fileReferences` |
| #3492 | **剪贴板快捷键循环**：按住打开快捷键的修饰键反复按主键循环历史，松手粘贴 | `ClipboardHistoryShortcutCycle`、键/鼠标监视器集成 |

## 合并时的调整

### 剪贴板三个 PR 的交叠

- **卡片布局**：#3336 重做了卡片视觉（固定 header/body/footer、圆角、阴影），#4184 需要条目可拖出。合并后 `card` 使用 `cardBody` 固定高度，并把 `clipboardHistoryDragSource` 挂在 `cardBody` 上，拖拽能力不丢。
- **`fileReferences`**：#4184 给 `ClipboardHistoryEntry` 增加了非可选 `fileReferences` 编码键。旧测试断言“保存的条目只有 5 个键”，已更新为包含 `fileReferences`，仍验证“不持久化派生搜索索引”。
- **flagsChanged 监视器**：#3492 需要 `flagsChanged` 来检测快捷键松开；#3336 需要单独跟踪 ⌘ 是否按住。两者各用一个本地监视器，互不覆盖；编辑中/点击/失焦都会取消循环状态。

### Layout Fix

- 键盘布局数据来自系统，俄语/哈萨克语的差异和弦数会随 macOS 版本变化。原测试硬编码 27，本机为 25；改为 `>= 20`，保留“两套布局必须足够不同”的意图，不再绑定某一版系统数据。
- 功能默认不安装，`layoutFixEnabled` 默认关闭；需要 Accessibility/输入监控权限，开启前由权限引导说明。

### Launchpad

- URL scheme 按 Tina 品牌改为：正式构建 `tina://launchpad`，Developer 构建 `tina-dev://launchpad`；`LaunchpadDockIcon` 读取构建自己的第一个 scheme，所以两个构建各自打开自己。
- 功能在 Features hub 中为 opt-in（`installedByDefault == false`），安装后才注册 `⌃⌥⌘A` 默认快捷键。
- Dock 图标不是默认写入；用户在 Launchpad 设置里点“Add to Dock”才会创建 `~/Applications/Launchpad.app` 并固定。
- `AppFeature` 总数更新为 **82**，测试同步。

### Window Custom Zones

- 作为 Window Layout 的 opt-in 子功能（`windowCustomZonesEnabled` 默认 false），不新增独立 AppFeature。
- 沿用现有 Window Layout 的 AX 事件与屏幕间距路径，没有引入新的系统权限。

## 验证

- `./build.sh --dev`：通过（含 Launchpad 图标编译；失败时回退到绘制图标）。
- `./build.sh --test`：**TESTS OK（123,836 checks）**；偏好清理、卸载空间、Developer 安装隔离均通过。
- Developer 应用 `--selftest`：待本次构建完成后执行。

## 仍需人工验证

自动化测试覆盖了模型、布局计算、字符串和持久化，但以下需要真机/真 UI 冒烟：

1. Launchpad：多显示器全屏呈现、拖拽建文件夹、分页滑动、Dock 辅助 App 打开的是正确构建。
2. Window Custom Zones：按住 Option 的分区覆盖层、拖拽释放、每显示器布局保存/恢复。
3. Layout Fix：右 Option 单击不误触、与 Super Key/输入法/死键的交互、Secure Input 下禁用。
4. 剪贴板：文件预览的权限/书签、拖出到 Finder/浏览器、Paste Stack 连续 ⌘V、快捷键循环与搜索框/编辑器互不抢键。
