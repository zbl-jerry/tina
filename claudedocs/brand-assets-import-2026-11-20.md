# Tina 图标素材导入记录（2026-11-20）

来源：`~/Downloads/tina-assets/`（完整内容以 `tina-assets.zip` 为准；解压目录里少了 `menu-bar/`，本次按 zip 导入）。

## 导入映射

| 素材 | 仓库位置 | 用途 |
|---|---|---|
| `app-icons/lavender/icon-1024.png` | `Resources/Brand/AppIcon-Default.png` | 主 App 图标（构建时生成 iconset/.icns） |
| 六套 1024 配色 | `Resources/Brand/AppIcon-Variants/{blue,cream,dark,lavender,mint,pink}-1024.png` | 备用主色，构建时替换 `AppIcon-Default.png` 即可切换 |
| `menu-bar/menubar-black-256.png` | `Resources/Brand/MenuBarIcon-Black.png` | 菜单栏模板源（`MakeIcon` 生成 1x/2x） |
| `menu-bar/menubar-white-256.png` | `Resources/Brand/MenuBarIcon-White.png` | 白色剪影参考 |
| `source/portrait-transparent-1024.png` | `Resources/Brand/logo.png`、`Resources/Brand/Source/` | DMG 背景水印与原始透明人像 |
| `source/portrait-scalable-wrapper.svg` | `Resources/Brand/Source/` | 原始 SVG 包装（内嵌位图，不是可编辑矢量路径） |
| `github/readme-banner-1200x360.png` | `docs/assets/readme/tina-banner.png` | README 顶部横幅 |
| `github/social-preview-1280x640.png` | `docs/assets/github/social-preview.png` | GitHub 仓库社交预览卡 |
| `github/avatar-512.png` | `docs/assets/github/avatar-512.png` | GitHub 个人/组织头像 |

## 构建管线调整

- **App 图标**：`Tools/MakeIcon.swift` 继续从 `AppIcon-Default.png` 生成 `.iconset`/`AppIcon.icns`。删除了旧的 `Resources/Brand/AppIcon.icon`（旧星球 mark 的 Icon Composer 工程）和 build.sh 中的 adaptive AppIcon actool 分支，并移除 `Info.plist` 的 `CFBundleIconName`。macOS 现在统一使用新 `.icns`，不会再有旧 `Assets.car` 覆盖新图标。
- **菜单栏图标**：`MakeIcon` 从 `MenuBarIcon-Black.png` 取剪影，裁掉透明边距后按 17pt 墨高渲染到现有 26×20pt 画布；`StatusItemController` 继续设置 `isTemplate = true`，系统负责浅色/深色着色。
- **应用内 mark**：`BrandMark.png` 改由同一剪影生成；面板头部、设置、截图编辑器等使用处自动换成新人像。
- **DMG 背景**：`Tools/MakeDMGBackground.swift` 仍读取 `logo.png`，内容已换成透明人像。
- **Launchpad**：`LaunchpadIcon.icon` 是独立的分区网格图标，继续保留 adaptive 编译。

## GitHub 仓库图标

GitHub 的仓库图标就是仓库所有者的头像，**不能按仓库单独设置**；`avatar-512.png` 只能上传到个人/组织资料。仓库级别的图片是 **Social preview**：

1. 打开 `https://github.com/zbl-jerry/tina/settings`。
2. General → Social preview → Upload an image。
3. 选择 `docs/assets/github/social-preview.png`（1280×640）。

README 顶部横幅已在本次提交中引用 `docs/assets/readme/tina-banner.png`。

## 验证

- `./build.sh --dev`：通过；`build/AppIcon.iconset/icon_512x512@2x.png` 为新 lavender 人像，`build/MenuBarIcon*.png` 为 26×20 / 52×40 剪影。
- `Tina (Developer) --selftest`：**SELFTEST OK**。
- `./build.sh --test`：**TESTS OK（123,836 checks）**。
- `swift Tools/MakeDMGBackground.swift`：正常生成 1200×800 背景。

## 如何切换配色

```sh
cp Resources/Brand/AppIcon-Variants/blue-1024.png Resources/Brand/AppIcon-Default.png
./build.sh --dev
```

菜单栏剪影则替换 `Resources/Brand/MenuBarIcon-Black.png` 后重新构建。不要重新加入 `AppIcon.icon`，除非同时提供可编译的 Icon Composer 工程。
