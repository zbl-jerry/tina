# 开源项目需求调研汇总（2026-11-20）

调研 skill：`/tina-feature-research`。12 个上游各出一份可提交的 feature issue 草稿，字段对齐 `.github/ISSUE_TEMPLATE/feature_request.yml`。

## 结论

| # | 上游 | 建议标题 | 决策 | 规模 | 上游体积 | 重复性 | 报告 |
|---|---|---|---|---:|---|---|---|
| 01 | oldj/SwitchHosts | 支持 hosts 配置切换（本地 profile + 一键应用） | MVP | M | 4.5–9.1 MB | new | [01](01-switchhosts.md) |
| 02 | zbl-jerry/TypeLock | 按 App 自动切换输入法（含浏览器域名与终端程序规则） | MVP | S–M | 5.6 MB | new/enh | [02](02-typelock.md) |
| 03 | charlie0129/batt | 限制电池充电上限（如 80%） | defer | L | 2.7 MB | new | [03](03-batt.md) |
| 04 | Caldis/Mos | 按 App 的滚动配置与按住修饰键临时修正滚动 | MVP | S–M | 11.5 MB | enhancement | [04](04-mos.md) |
| 05 | jerry-pond/TOTPBar | 菜单栏 TOTP 验证码（本地 Keychain 存储） | MVP | M | 0.5 MB | new | [05](05-totpbar.md) |
| 06 | lihaoyun6/Logoer | 自定义菜单栏 Apple 标志样式 | reject | S | 1.9 MB | new | [06](06-logoer.md) |
| 07 | lihaoyun6/QuickRecorder | 录屏时叠加摄像头画中画（presenter overlay） | MVP | M | 4.4 MB | enhancement | [07](07-quickrecorder.md) |
| 08 | keycastr/keycastr | 录制时显示按键（可选按键浮层） | MVP | M | 2.5 MB | enhancement | [08](08-keycastr.md) |
| 09 | didriksg/Crisp | 显示器预设（分辨率/亮度/开关） | MVP | M | 4.9 MB | enhancement | [09](09-crisp.md) |
| 10 | rxhanson/Rectangle | 把当前显示器的窗口平铺成网格 | MVP | M | 4.7 MB | enhancement | [10](10-rectangle.md) |
| 11 | jordanbaird/Ice | 收起/展开第三方菜单栏图标 | defer | L–XL | 3.3 MB | new | [11](11-ice.md) |
| 12 | Contexts + 3 个开源窗口条 | 窗口分组（按项目整组切换） | defer | M（常驻条 L） | 0.5 / 2.1 MB | enhancement/duplicate | [12](12-contexts.md) |

## 优先顺序（用户收益 / 成本）

1. **按 App 切换输入法**（02）——高频、无新权限、复用现有 TIS 代码。
2. **窗口网格平铺**（10）——现有窗口布局的直接缺口。
3. **TOTP 验证码**（05）——新能力、体积小，但需要一次安全审查。
4. **hosts 切换**（01）——开发场景明确，一次性授权替代常驻 helper。
5. **按 App 滚动配置**（04）——低成本增强。
6. **显示器预设**（09）——复用现有 DDC。
7. **摄像头画中画**（07）／**按键浮层**（08）——录屏增强，需新增一种权限（08）。
8. **batt / Ice / Contexts** 维持 defer：分别是特权 SMC、未公开菜单栏 API、重复 UI + 未验证需求。
9. **Logoer** reject：一次性装饰 + 未公开菜单栏结构。

## 已提交 issue

| # | Issue |
|---|---|
| 01 | [#3](https://github.com/zbl-jerry/tina/issues/3) 支持 hosts 配置切换 |
| 02 | [#4](https://github.com/zbl-jerry/tina/issues/4) 按 App 自动切换输入法 |
| 03 | [#5](https://github.com/zbl-jerry/tina/issues/5) [defer] 限制电池充电上限 |
| 04 | [#6](https://github.com/zbl-jerry/tina/issues/6) 按 App 的滚动配置 |
| 05 | [#7](https://github.com/zbl-jerry/tina/issues/7) 菜单栏 TOTP 验证码 |
| 06 | [#8](https://github.com/zbl-jerry/tina/issues/8) [reject] 自定义 Apple 标志 |
| 07 | [#9](https://github.com/zbl-jerry/tina/issues/9) 录屏摄像头画中画 |
| 08 | [#10](https://github.com/zbl-jerry/tina/issues/10) 录制时显示按键 |
| 09 | [#11](https://github.com/zbl-jerry/tina/issues/11) 显示器预设 |
| 10 | [#12](https://github.com/zbl-jerry/tina/issues/12) 窗口网格平铺 |
| 11 | [#13](https://github.com/zbl-jerry/tina/issues/13) [defer] 收起第三方菜单栏图标 |
| 12 | [#14](https://github.com/zbl-jerry/tina/issues/14) [defer] 窗口分组 |

## 备注

- 所有体积均为上游 release 产物，不是 Tina 的 DMG；Tina 增量在各自报告里单列。
- 未评估 license 兼容性（超出 skill 范围）。
- 未核实用户量、迁移意愿等无法验证的指标，相关处写 unknown。
