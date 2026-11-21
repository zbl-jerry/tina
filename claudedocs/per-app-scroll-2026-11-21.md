# 按 App 的滚动配置与按住修饰键临时修正：需求、产品与系统设计

> 对应 issue：[#6 按 App 的滚动配置与按住修饰键临时修正滚动](https://github.com/zbl-jerry/tina/issues/6)
> 上游参考：<https://github.com/Caldis/Mos> @ 4.2.1
> 日期：2026-11-21 · 结论：**MVP 实施** · 宿主功能：`smoothScroll`

## 1. 需求调研

### 1.1 用户与任务

同一台 Mac 上，不同 App 对滚轮手感的要求相反：

- 设计、CAD、远程桌面需要原始精度，平滑滚动会拖慢定位；
- 浏览器、编辑器、长文档希望更顺滑；
- 临时查看代码或对齐像素时，希望按住一个键立刻回到原始滚动，松开即恢复。

当前 Tina 的所有滚动设置都是全局的。用户只能反复进设置改动，或者放弃平滑滚动。上游 Mos 把「按应用配置」和「滚动功能键」列为两个主打功能，说明这是长期存在的真实需求，而不是单一用户的偏好。

### 1.2 现有实现事实（本次改动前）

| 能力 | 位置 | 现状 |
|---|---|---|
| 平滑滚动 | `Services/SmoothScrollService.swift` | 头部事件 tap，按步长/响应/惯性生成像素 glide |
| 线性滚动 | `ScrollInverter` 尾部 tap | 每格固定行数，独立例外列表 |
| 方向反转 / 横向滚动 / 捏合缩放 | `ScrollInverter` | 全局开关，独立例外列表 |
| 按住修饰键加速 | `ScrollSpeedPreferences` | 一个修饰键 × 倍率，全局生效 |
| 按 App 排除 | `MouseAppExceptions` | 每个功能一份 bundle id 列表，指针下窗口解析 |
| App 选择器 | `AppBundleList` + `AppPickerView` | 已有的选择、图标、删除行组件 |

结论：缺的不是滚动算法，而是「按 App 解析参数」和「按修饰键解析临时参数」这两层配置。二者都可以放在现有 tap 内，不新增权限、后台服务或事件 tap。

### 1.3 调研结论与取舍

- 上游 Mos 4.2.1 为 Swift 事件 tap 实现，支持按 App 配置与滚动功能键；Tina 复用同一类机制，无版本 API 依赖。
- Tina 已有平滑、线性、方向、速度四项能力，本次只补「按 App 参数」与「按住键修正」，不重做算法。
- 明确不做：按设备区分、罗技 HID++ 私有协议、鼠标按键动作库、脚本动作。
- 不做全局的「按 App 配置线性滚动 / 滚动加速」：它们与本次目标不同源，先保持全局，避免配置面失控。

## 2. 产品设计

### 2.1 信息模型

每个 App 一条覆盖记录，以 bundle id 标识：

| 字段 | 取值 | 含义 |
|---|---|---|
| App | bundle id | 复用 `AppPickerView`，只收 `.app`，不收可执行文件路径 |
| 平滑 | 跟随全局 / 关闭 / 自定义 | `inherit` / `off` / `custom` |
| 步长 | 20–100 像素 | 仅 `custom`；未设置时继承全局 |
| 速度 | 25%–400% | 仅 `custom`；相对全局速度的倍率，100% 等于全局 |
| 反转方向 | 开 / 关 / 跟随全局 | 只覆盖垂直方向；水平反转仍按全局 |

「跟随全局」是默认值，也是删除该行后的行为。清空覆盖表与从未配置完全等价。

按住修饰键修正是一组全局设置（不按 App 区分）：

| 字段 | 取值 | 含义 |
|---|---|---|
| 启用 | 开 / 关 | 仅在平滑滚动开启时可用 |
| 按键 | ⌃ / ⌥ / ⌘ | 不用 ⇧：Shift+滚轮在平滑 tap 之前已被横向滚动语义占用 |
| 动作 | 暂停平滑 / 更慢 / 更快 | `precise` 直接把原始事件交给 App |
| 倍率 | 2–15 | 仅更慢/更快；更慢为 1/倍率 |

### 2.2 优先级

配置越多，越需要一条确定的优先级。事件路径按下列顺序解析，前者胜出：

1. **功能未安装或开关关闭**：不监听，不生效。
2. **功能自己的「不处理的 App」列表**：原样放行，任何按 App 覆盖都不再生效（这是明确的「别碰这个 App」）。
3. **按住键修正**：只影响平滑距离与是否平滑，不改变方向设置。
4. **按 App 覆盖**：关闭平滑、自定义步长/速度、单独反转垂直方向。
5. **全局设置**：其余参数。

已知冲突及处理：

- 按住键与「按住加速」用同一个键：平滑 tap 内按住键修正先消费该修饰键，加速不再生效。原始滚轮路径（平滑关闭的 App）没有修正逻辑，仍由「按住加速」处理。
- 按住键与横向滚动键相同：横向滚动先执行，因为它是方向语义；该次滚动不再被视为「暂停平滑」。
- 按住键与捏合缩放键相同：已配置的缩放动作先消费该事件，修正不生效。
- 按 App 反转与全局方向例外列表冲突：例外列表优先，App 保持系统方向。

### 2.3 主要流程

**给某个 App 单独设置**

1. 设置 → 鼠标与键盘 → 平滑滚动。
2. 在「按 App 覆盖」中点「添加 App」，选择应用。
3. 新行默认「关闭」，也可选「自定义」后调步长与速度，或单独打开「反转方向」。
4. 下一次滚轮事件即按新设置执行，不需要重启或重新授权。

**临时修正**

1. 打开「按住键修正」，选按键与动作。
2. 按住该键滚动：暂停平滑时事件原样到达 App；更慢/更快时 glide 距离按倍率缩放。
3. 松开后，下一次滚轮事件恢复原设置。

### 2.4 界面与文案

- 入口只在现有「平滑滚动」卡片内，不新增设置页、侧边栏项或功能中心条目。
- App 行复用 `AppBundleList`：图标、名称、添加/删除与既有排除列表一致；行尾增加模式菜单、反转开关，`custom` 时展开步长与速度滑杆。
- 文案强调「只影响平滑滚动」「跟随时使用全局设置」「松开按键即恢复」，避免用户误以为会改动系统滚动。

### 2.5 验证目标（产品）

- 同一个 App 可在平滑、速度、方向三个维度独立于全局。
- 临时修正只持续按住期间，且不会留在合成事件上。
- 配置立即生效，覆盖表与按住键设置都进入设置备份。
- 例外列表语义不变：列在「不处理的 App」里的应用仍完全不被打扰。

## 3. 系统设计

### 3.1 数据模型与持久化

新增纯值类型 `ScrollPerAppOverride`，以 JSON 数组存于 `UserDefaults`：

```json
[{"bundleID":"com.apple.dt.Xcode","smoothing":"off"},
 {"bundleID":"com.apple.Safari","smoothing":"custom","step":55,"speedPercent":140,"invertVertical":true}]
```

- 存储键：`scrollPerAppOverrides`（String，默认空串），已注册默认值，因此自动进入设置备份。
- 解析是纯函数：忽略未知 `smoothing`、非有限数值、重复 bundle id、空 bundle id；步长夹在 20–100，速度夹在 25–400。
- `nil` 与显式 0 区分：`step`/`invertVertical` 用可选类型表达「跟随全局」。

新增按住键设置：

| 键 | 默认 | 说明 |
|---|---|---|
| `scrollHoldEnabled` | false | 与平滑滚动开关独立 |
| `scrollHoldModifier` | `control` | 字符值与现有修饰键枚举一致 |
| `scrollHoldAction` | `precise` | `precise` / `slower` / `faster` |
| `scrollHoldFactor` | 4 | 2–15 |

`ScrollHoldPreferences` 是纯结构体，读取时检查 `AppFeature.smoothScroll.isAvailable`，与 `ScrollSpeedPreferences` 的卸载语义一致。

### 3.2 事件路径

```
HID → SmoothScrollService (head tap, main run loop)
        ├─ ScrollWheelHIDStage / 合成事件 / 触摸设备 过滤
        ├─ 功能例外列表 → raw
        ├─ zoom / 横向滚动修饰键（既有）
        ├─ 解析 per-app override（按 eventTargetUnixProcessID）
        ├─ 解析 hold modifier（全局）
        ├─ 关闭平滑 / 暂停修正 → stopGlide + raw
        └─ 计算 step × percent × hold × speed → glide
     → ScrollInverter (tail tap, pointer thread)
        ├─ 线性滚动（既有，全局）
        └─ 方向：per-app 反转优先于全局垂直反转
```

两条 tap 的线程模型不同，因此解析器必须无阻塞：

- `ScrollPerAppOverrides` 在 `NSLock` 下保存 `bundleID → override` 与 `pid → bundleID` 两张表；
- 表在 `reload()`、设置写入、`NSWorkspace.runningApplications` 变化时重建；
- tap 回调只做锁内字典查询，不调用 AppKit、不等待主线程；
- 覆盖表为空时是单次集合判空，事件路径成本可忽略。

### 3.3 按 App 解析

接收方进程来自 `eventTargetUnixProcessID`（注释 tap 阶段已带目标信息），经 `pid → bundleID` 表映射。选择目标进程而不是「指针下窗口」的原因：

- 它就是最终接收事件的 App，与 glide 的 `postToPid` 一致；
- 不额外查询窗口服务器，指针线程上无阻塞；
- 与 `MouseAppExceptions` 的源进程缓存采用同一类数据。

进程表只包含覆盖表中出现的 App；App 启动/退出由 workspace 观察更新。覆盖表为空时不安装观察者。

例外列表先于按 App 覆盖：`excludesPointerTarget` 已经解析了指针下窗口/来源进程，语义保持不变。

### 3.4 事件路径改动

**SmoothScrollService.handle**

1. 提前解析 `targetProcessID` 与 `perAppOverride`。
2. 例外列表命中时保持原行为。
3. 解析 hold：仅当修饰键「单独按住」且未被横向滚动/缩放消费；命中后从事件 flags 中移除该键，避免 App 与按住加速二次解释。
4. `smoothing == .off` 或 `hold == .precise`：停止当前 glide，原样放行；若方向 tap 未运行且该 App 显式反转，则只对原始事件应用垂直反转（避免与尾部 tap 重复）。
5. 有效参数：
   - `step = override.step ?? globalStep`
   - `speedScale = override.speedPercent / 100`（未自定义时为 1）
   - `holdScale = faster ? factor : slower ? 1/factor : 1`
   - `verticalDistance = ticks × step × speedScale × holdScale × existingSpeedMultiplier`
   - `invertVertical = override.invertVertical ?? (方向功能开启且未被例外时的全局值)`
   - 水平反转保持全局语义。
6. 与新参数不一致的旧 glide 仍按现有规则（切换 Shift、连续/离散、目标变化）重置；按住键切换也触发同样的重置，避免旧尾巴按旧倍率继续。

**ScrollInverter.handle / directionApplied**

1. 在既有方向例外判断之后解析 `perAppOverride`。
2. 即使方向功能整体关闭，只要 override 显式反转垂直方向且方向例外未命中，就调用 `applyDirection`（尾部 tap 可能在为线性滚动而运行）。
3. 水平反转与横向滚动修饰键仍只由全局设置决定。

### 3.5 性能与线程

- 每个滚轮事件新增：一次可用性读取与一到两次锁内字典查询；覆盖表为空时没有窗口服务器查询，也没有额外对象分配。
- 主线程 tap 不新增窗口服务器查询。
- 指针线程不引入新的锁竞争点：`pid → bundleID` 表只在覆盖表或运行中应用变化时写。
- 观察者与进程表只在覆盖表非空时存在，空表是默认状态。

### 3.6 数据、备份与卸载

| 数据 | 位置 | 备份 |
|---|---|---|
| 按 App 覆盖表 | `UserDefaults.scrollPerAppOverrides` | 是 |
| 按住键设置 | `UserDefaults.scrollHold*` | 是 |
| 运行中进程映射 | 内存 | 否（可重建） |

- 全部键注册默认值，`SettingsBackupSupport.exportKeys()` 自动包含，无需单独列入。
- 关闭或从功能中心卸载平滑滚动后，tap 与服务一起停止，覆盖数据保留；重新安装后继续生效，与现有滚动设置一致。
- 卸载不会改写系统滚动设置，也不新增权限。

### 3.7 失败模式

| 情况 | 行为 |
|---|---|
| 覆盖 JSON 损坏 | 解析出空表并按空表运行；不崩溃、不清空原始字符串（下次成功写入时覆盖） |
| 目标进程未知（pid 0 / 已退出） | 视为无覆盖，按全局设置 |
| App 启动/退出竞态 | 映射由 workspace 观察重建；最多一次滚动按全局设置 |
| 覆盖表包含已卸载 App | 保留记录，App 再次运行时生效 |
| 修饰键与其他滚动快捷键冲突 | 按 2.2 的固定优先级处理并在文档中说明 |

### 3.8 测试策略

- **纯模型测试**：JSON 往返、非法值清洗、重复 bundle id、百分比/步长边界、默认值、备份键覆盖。
- **解析测试**：有效 step/speed/invert 组合；`nil` 表示继承；按住动作的倍率换算。
- **事件路径测试**（沿用现有生成式路由测试）：
  - 覆盖为 `off` 时滚轮原样放行、不排队 glide；
  - 覆盖为 `custom` 时距离按步长与百分比缩放；
  - 覆盖反转在平滑 tap 内只应用一次；
  - 按住暂停平滑时原样放行并移除修饰键；
  - 按住更快/更慢时距离缩放，松开后恢复；
  - 例外列表优先于覆盖表；
  - 尾部 tap 在方向功能关闭、仅线性滚动运行时仍应用按 App 反转。
- **本地验证**：`./build.sh --test`、`./build.sh --dev`、`./build/TinaDeveloper --selftest`。
- **人工验证**（主会话执行）：设置页添加/删除 App、切换模式、按住键滚动的实际手感。

### 3.9 明确未覆盖

- 按设备（不同鼠标）配置；
- 罗技 HID++、厂商私有按键；
- 按 App 配置线性滚动、按住加速、横向滚动修饰键、捏合缩放；
- 水平方向按 App 反转；
- 菜单面板快捷开关（本次只有设置页入口）。
