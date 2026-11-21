# 录屏时叠加摄像头画中画（presenter overlay）

> 调研日期 2026-11-20 · 上游 <https://github.com/lihaoyun6/QuickRecorder> @ 1.6.9
> 决策：**MVP**（仅摄像头画中画）· 建议标签：`enhancement`

### 问题或动机

用 Tina 录教程、演示或 bug 复现时，画面里只有屏幕，没有人脸。讲解类视频希望有一个小的摄像头窗口叠在角落，让观众看到讲解者；现在只能录完再导进剪辑软件二次合成，或者额外开一个悬浮摄像头 App 再靠录屏把它录进去（位置、镜像、大小都难控，还容易录到别的窗口）。

### 期望的解决方案

**MVP**

- 录屏设置里增加「叠加摄像头」开关，默认关闭；开启后选择摄像头。
- 录制时在画面角落显示圆形/圆角矩形画中画，可拖动定位、可调大小、可水平镜像、可选择是否带阴影。
- 画中画由 Tina 的录制合成器直接烧录进输出文件，同时出现在实时预览里；暂停/继续与主画面同步。
- 录制结束后保留原视频，画中画不可事后移除（MVP 取舍），设置里说明这一点。
- 摄像头被占用或权限被拒时，录制正常进行，只在界面提示“画中画未启用”。

**后续可选**

- 录 iPhone/iPad 屏幕（需要 CoreMediaIO 采集插件）。
- HEVC with Alpha、独立摄像头音轨、会后编辑画中画位置。

第一版明确不做：iOS 设备录制、绿幕/背景替换、独立摄像头轨道。

### 功能区域

实用工具（Utilities）

### 草图 / 参考

- 上游：<https://github.com/lihaoyun6/QuickRecorder>（1.6.9，2025-06-11，AGPL-3.0）
- 关键参考：README 的「Presenter Overlay」「mouse highlighting」「screen magnifier」「HEVC with Alpha」
- 与 Tina 现有功能的入口关系：`Services/Recorder` 已有屏幕/窗口/区域采集、光标与点击可视化、图片/文字叠加层与合成器；摄像头权限与 `cameraPreview` 功能已存在，只需把 AVCaptureSession 的输出接进合成器。

### 开源参考（可选）

- 来源：<https://github.com/lihaoyun6/QuickRecorder> @ 1.6.9
- 调研 skill：`/tina-feature-research`
- 结论：MVP（只取画中画；录屏本身与 Tina 重复）

### 开源调研结论

#### 硬约束

| 约束 | 结论 | 依据 |
|---|---|---|
| macOS 15 | pass | 上游支持 macOS 12.3+；摄像头叠加不依赖 15+ API，14 可做（无系统 Presenter Overlay 时用自绘） |
| 原生实现 | pass | 上游 Swift + ScreenCaptureKit；Tina 复用自有录制管线与 AVCapture |
| 上游 Release 体积（若有） | pass | `QuickRecorder_v1.6.9.dmg` 4.4 MB |
| 复杂度 | conditional | 需要在录制合成器中以稳定帧率混合摄像头帧；涉及摄像头权限、设备热插拔、性能预算 |
| 不重复 | enhancement | 录屏/截图/光标可视化/系统声与麦克风分轨在 Tina 已存在；缺的是摄像头画中画 |

#### 上游产品价值

- JTBD：录教程/演示时把自己叠进画面。
- 频率与痛点：做教程、汇报、issue 复现的人群；频率中，痛点中（二次合成麻烦）。
- 替代品：macOS 14 的 FaceTime Presenter Overlay（只在会议里有效）、ScreenFlow/Camtasia（付费）、录完再剪。
- 可核实信号：上游把 Presenter Overlay 单独列为特性，并在 README 解释 12/13 的降级方案，说明这是真实使用路径；用户量 unknown。

#### Tina 用户增量收益

- 新增能力：一次录屏就得到带讲解者的成片，无需二次剪辑。
- 协同：复用现有录制合成、图片叠加、实时预览与摄像头权限；`cameraPreview` 已能列出设备。
- 替代：可少装 QuickRecorder/ScreenFlow 的这项能力。
- 代价：录制时的额外 CPU/GPU 与摄像头占用；摄像头权限的使用说明要更新。

#### 成本、风险与 MVP

- 规模：M（采集、镜像/遮罩、合成、预览、设置 UI、本地化）
- Tina 增量体积：约 0.2–0.5 MB（无新框架）
- 主要风险：合成时序导致画中画抖动/延迟；摄像头被其他 App 占用；录制性能下降
- MVP 边界：只做屏幕/窗口录制上的摄像头气泡，烧录进成片；不做 iOS 录制与会后编辑
- 决策：**MVP**——与现有录制管线高度协同，用户价值集中在一个开关上

#### 评分

| 维度 | 分数（1–5） | 理由 |
|---|---:|---|
| 上游产品价值 | 4 | 录屏场景真实，但属于进阶需求 |
| Tina 用户收益 | 3 | 增强现有录屏，不是新能力 |
| 契合度 | 5 | 直接复用录制合成器与摄像头权限 |
| 实现成本（反向） | 4 | M，无新权限类型 |
| 风险（反向） | 4 | 性能与设备占用可控，失败可降级为纯录屏 |
