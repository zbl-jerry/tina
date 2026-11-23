// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Chinese readings of the changelog the app ships in English.
///
/// `CHANGELOG.md` stays the only list of what changed, and its English wording
/// stays the input `ReleaseChangeAliases` reads to tell which features an entry
/// belongs to. A translation is looked up by the entry's English text when a
/// screen draws it, so the feature routing and the Chinese wording cannot drift
/// apart. An entry with no translation reads in English, and every language
/// other than Chinese reads the English changelog.
enum ReleaseNoteLocalization {
    static func text(_ english: String, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            return zhHans[english] ?? english
        case .zhTW, .zhHK:
            return zhHant[english] ?? english
        default:
            return english
        }
    }

    /// A `###` section title, as the release-notes screens head a list. The
    /// post-update window's own headings come from `WhatsNewStrings`.
    static func sectionTitle(_ english: String, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            return zhHansTitles[english] ?? english
        case .zhTW, .zhHK:
            return zhHantTitles[english] ?? english
        default:
            return english
        }
    }

    /// The English entries a language has a reading for. The tests compare
    /// this with the changelog so a release cannot ship an English-only entry
    /// to Chinese readers, and so a removed entry does not leave a stale
    /// translation behind.
    static func translatedKeys(for language: AppLanguage) -> Set<String> {
        switch language {
        case .zhHans:
            return Set(zhHans.keys)
        case .zhTW, .zhHK:
            return Set(zhHant.keys)
        default:
            return []
        }
    }

    private static let zhHans: [String: String] = [
        // 3.7.3
        "Microphone mute keeps its listeners across normal input changes, registers them again after the audio service restarts, and holds a requested mute on a device until that device comes back.": "静音麦克风会在正常的输入设备变化后保留监听，在音频服务重启后重新注册，并在设备重新出现前保持对该设备的静音请求。",
        "The window switcher waits until an interrupted session can be dismissed before it filters keys and clicks again after macOS pauses its input tap. Suspending the feature or installing a newer switcher supersedes a stale restart.": "窗口切换器在 macOS 暂停其输入监听后会等待被中断的会话可以关闭，然后再恢复过滤按键和点击。暂停该功能或安装更新的切换器会取代已经过时的重启。",
        "Volume keys on USB outputs without a compatible main volume control are handed to macOS when a reliable step or confirmation is not available, including fine repeats. Dynamic Island reports the level that same output confirmed.": "对于没有兼容主音量控制的 USB 输出，当无法获得可靠的步进或确认时（包括精细重复），音量键会交还给 macOS 处理。Dynamic Island 会报告同一输出确认的音量。",

        // 3.7.2
        "Built-in updates install again. Releases are self-signed, but the installer required an Apple-anchored Developer ID signature that no release could carry, so every attempt stopped at fail-dmg-verify. The disk image is now signed by the same certificate as the app, and the installer pins that certificate instead of a team ID. Releases up to 3.7.1 still need one manual install.": "内置更新恢复可用。发布包使用自签名，但安装器原本要求带 Apple 根信任的 Developer ID 签名，而任何发布包都无法具备，因此每次尝试都停在 fail-dmg-verify。现在磁盘映像与应用使用同一张证书签名，安装器固定该证书而不是团队 ID。3.7.1 及更早的版本仍需手动安装一次。",
        "The fan-control helper's XPC peer requirement pins the signing certificate of the running app instead of a Developer ID team, matching how releases are actually signed.": "风扇控制辅助程序的 XPC 对端要求改为固定正在运行的应用的签名证书，而不是 Developer ID 团队，与实际发布签名方式一致。",

        // 3.7.1
        "Dynamic Island AI Agents count Cursor token usage from a dated response with usage counts in a local transcript. Cursor plan credits are still not read from the network.": "Dynamic Island 的 AI Agents 会从本地记录中带日期和使用量统计的响应里统计 Cursor token 用量。Cursor 套餐额度仍不会从网络读取。",
        "Cleaner keeps preferences, support files and caches it can match to audio plugins installed in the standard plugin folders, and checks again before moving a selected item to the Trash.": "清理工具会保留能对应到标准插件目录中已安装音频插件的偏好设置、支持文件和缓存，并在将所选项目移到废纸篓前再次检查。",

        // 3.7.0 Added
        "Window pinning: keep any window visible above other apps as a live, resizable mirror. Pinned windows follow their source, pause while minimized, on another Space or fully covered, and hand control back to the real window on click or hover. The feature is installed from the Hub, uses Screen Recording and Accessibility, and its settings join Settings backup.": "窗口固定：将任意窗口作为可调整大小的实时镜像，始终保持在其他 App 之上。固定的窗口会跟随源窗口，在源窗口最小化、位于其他空间或被完全遮挡时暂停，并在点击或悬停时把控制权交还真实窗口。该功能从功能中心安装，需要屏幕录制和辅助功能权限，其设置会纳入设置备份。",
        "Live captions: turn the sound your Mac is playing into on-screen captions with on-device Speech recognition, a draggable click-through caption bar, a menu bar indicator and a global shortcut. Sessions are saved locally and can be exported as SRT, Markdown or plain text, copied, or removed, and captions stop cleanly when a screen recording starts because the two cannot share the system audio tap.": "实时字幕：用设备端语音识别把 Mac 正在播放的声音变成屏幕字幕，并提供可拖动、可点击穿透的字幕条、菜单栏指示器和全局快捷键。会话保存在本地，可导出为 SRT、Markdown 或纯文本，也可复制或删除；由于两者无法共用系统音频捕获，屏幕录制开始时字幕会干净地停止。",
        "Quick toggles can restart the Dock, the Finder, the menu bar or the third-party input method in use. Each row confirms first, explains what disappears for a moment, and reports whether the component came back. The input method row stays disabled with a reason when no third-party input method is running, and every action follows the Kill Process protection rules with no new permission or helper.": "快捷开关可以重启 Dock、访达、菜单栏或正在使用的第三方输入法。每一行都会先确认，说明会短暂消失的是什么，并报告该组件是否恢复。没有第三方输入法运行时，输入法一行会保持禁用并说明原因；所有操作都遵循强制退出进程的保护规则，且不需要新的权限或辅助程序。",
        "Dynamic Island AI Agents now follow Cursor's live turns, project names and completion notices by reading its local agent transcripts, with no network requests and no plan credits read.": "Dynamic Island 的 AI Agents 现在通过读取 Cursor 本地的 Agent 记录，跟随其实时会话轮次、项目名称和完成通知，不发起网络请求，也不读取套餐额度。",

        // 3.7.0 Changed
        "Tina no longer builds services for features that are turned off when it launches, so startup does less work without changing what is available. Display recovery for screens a previous run left off still runs before the rest of launch.": "Tina 启动时不再为已关闭的功能构建服务，因此启动工作量更少，而可用功能不变。针对上次运行未恢复的显示器的显示恢复仍会在启动的其余步骤之前执行。",
        "Window gestures and edge snapping share one pointer tap, so a drag that needs both keeps an in-progress gesture and cancels a pending snap correctly when the drag is handed to macOS.": "窗口手势与边缘吸附共用同一个指针监听，因此同时需要两者的拖动会保留进行中的手势，并在拖动交还给 macOS 时正确取消待处理的吸附。",
        "Microphone mute can follow an unmute made from a call app when the opt-in option in Settings → Quick panel is turned on. Mute enforcement stays the default.": "开启“设置 → 快捷面板”中的可选选项后，静音麦克风可以跟随通话 App 中执行的取消静音。默认仍是强制执行静音。",

        // 3.7.0 Fixed
        "Update checks ask the repository the app is built from, so they no longer fail against a renamed repository. A response GitHub rejects now reports its HTTP status instead of a placeholder.": "更新检查会询问应用构建时所用的仓库，因此在仓库改名后不再失败。GitHub 拒绝的响应现在会报告其 HTTP 状态，而不是占位内容。",
        "The post-update What's New window reads the changelog bundled with the app again, so it lists the changes made in every version between the previous install and the current one.": "更新后的“新功能”窗口重新读取随应用打包的更新日志，因此会列出上次安装版本与当前版本之间每个版本的改动。",
        "Screen recording keeps the camera bubble in the editor preview and in every video, GIF and shared export by drawing it after the automatic zoom instead of baking it into the recording.": "屏幕录制在自动缩放之后绘制摄像头气泡，而不是把它烘焙进录制内容，因此编辑器预览以及每个视频、GIF 和共享导出中都会保留摄像头气泡。",
        "The live key row stays inside the recorded window or area, the key switch asks for Input Monitoring when it is turned on, and a missing grant is reported when recording starts instead of silently omitting the keys.": "实时按键行会保持在录制的窗口或区域之内；按键开关开启时会请求输入监控权限；缺少授权时会在录制开始时报告，而不是静默省略按键。",
        "The screen-capture chooser offers full-screen recording, and a shortcut's recorder row is hidden while that shortcut is turned off.": "屏幕捕获选择器提供全屏录制；快捷键关闭期间，该快捷键的录制器一行会隐藏。",
        "Fan control keeps a verified curve through a GPU power-down, retries a refused fan write while every fan still holds its target, and returns all fans to system control when a safe configuration cannot be verified. The panel reports a curve it could not restore.": "风扇控制在 GPU 断电期间保持已验证的曲线；在所有风扇仍保持目标转速时重试被拒绝的风扇写入；无法验证安全配置时让所有风扇回到系统控制。面板会报告无法恢复的曲线。",
        "Clipboard history prefers the text in a copy that also carries rich text, so copied spreadsheet cells keep their text and separators instead of becoming a preview image. Image and file copies are unchanged.": "剪贴板历史在同时带有富文本的复制内容中优先取文本，因此复制的表格单元格会保留文字和分隔符，而不会变成预览图片。图片和文件复制不受影响。",
        "Low disk space alerts repeat at most once every six hours per volume, with one earlier alert when free space drops below half the limit.": "磁盘空间不足提醒在每个宗卷上最多每六小时重复一次；当可用空间降到阈值的一半以下时会提前提醒一次。",
        "Super Key waits for a keyboard after login or wake instead of treating the missing mapping as refused, and captures F18 only once the mapping is written and read back.": "Super Key 在登录或唤醒后会等待键盘，而不再把缺少映射当作被拒绝；只有映射写入并读回后才会捕获 F18。",
        "The window switcher hands ⌘Tab back to macOS while an exclusive full-screen game covers the display, and resumes suppression when the game leaves full screen.": "当独占全屏游戏覆盖显示器时，窗口切换器会把 ⌘Tab 交还给 macOS；游戏退出全屏后会恢复拦截。",

        // 3.6.0
        "Auto input source: assign an input method per app, with separate choices for the first activation after launch and later returns. Rules can be exported and imported as JSON, and a \"never switch\" list takes precedence over every rule.": "自动输入源：为每个 App 指定输入法，并可分别为启动后的首次激活和之后回到应用设置选择。规则可导出和导入为 JSON，“永不切换”列表优先于所有规则。",
        "Battery charge limit: Apple Silicon MacBooks can stop charging at a chosen level between 60% and 100%, resume 5 points below it and charge to full once on demand. Turning the feature off, quitting or a helper crash restores normal charging.": "电池充电上限：Apple 芯片 MacBook 可以在 60% 到 100% 之间选定的电量停止充电，低于该值 5 个百分点时恢复充电，并可按需充满一次。关闭该功能、退出应用或辅助程序崩溃都会恢复正常充电。",
        "Per-app scrolling: choose follow-global, off, or a custom step and speed for each app, invert scrolling for one app only, and return to the raw wheel while a chosen key is held.": "按 App 滚动：为每个 App 选择跟随全局、关闭，或自定义步进和速度；可只反转某一个 App 的滚动；按住指定按键时恢复原始滚轮。",
        "Verification codes: standard TOTP codes in the menu bar panel and Quick panel, copied with one click, masked until the pointer rests on them and stored in the Keychain only.": "验证码：在菜单栏面板和快捷面板中显示标准 TOTP 验证码，一键复制，指针停留前保持隐藏，并且只存储在钥匙串中。",
        "Window tiling: arrange every normal window on the current display as a balanced grid, by rows or by columns. Repeating the same action cycles to the next layout, and each row or column can hold 1–6 windows.": "窗口平铺：把当前显示器上的所有普通窗口按行或按列排列成均衡网格。重复同一操作会循环切换下一种布局，每行或每列可容纳 1–6 个窗口。",
        "Displays presets: save resolution, brightness, display volume and mute, and the main display, then restore them from the panel, a shortcut, or automatically when a display connects or disconnects, with a report of anything that could not be restored.": "显示器预设：保存分辨率、亮度、显示器音量和静音状态以及主显示器，然后可从面板、快捷键恢复，或在显示器连接、断开时自动恢复，并报告任何无法恢复的项目。",
        "Keystroke overlay for screen recording: show the keys being pressed in a corner or beside the pointer, with three sizes, a dwell time and light or dark appearance, included in the editor preview and in video and GIF exports.": "屏幕录制的按键显示：在角落或指针旁显示正在按下的按键，提供三种大小、停留时间和浅色或深色外观，并会出现在编辑器预览以及视频和 GIF 导出中。",
        "Camera bubble for screen recording: composite the camera into the recording as a round or rounded bubble with mirroring and a shadow, switch cameras during the recording, and skip a second app afterwards.": "屏幕录制的摄像头气泡：把摄像头以圆形或圆角气泡合成到录制内容中，可镜像并带阴影；录制期间可切换摄像头，之后无需再开第二个 App。",

        // 3.5.0
        "Hosts profiles: keep several hosts configurations in Utilities, enable only the combinations you need and apply them at once. Only Tina's marked block in /etc/hosts is replaced, each write is backed up and the last ten are kept, and lines are validated before an admin prompt applies them.": "Hosts 配置：在实用工具中保存多套 hosts 配置，只启用你需要的组合并一次应用。只会替换 Tina 在 /etc/hosts 中标记的区块，每次写入都会备份并保留最近十次，且在弹出管理员授权前会校验每一行。",

        // 3.4.5
        "Night warmth: overlay a schedule-driven colour temperature on every display, warmer at sunset and warmer still before bed, with pause by the hour or until sunrise, presets and warmer/cooler nudges. The original gamma tables are restored when the feature is turned off, when Tina quits or after a crash.": "夜间暖色：在所有显示器上叠加按时间表变化的色温，日落后更暖，睡前更暖；可按小时暂停或暂停到日出，提供预设以及更暖或更冷的微调。关闭该功能、退出 Tina 或崩溃后都会恢复原始伽马表。",
        "Tina is an independent project: the license is MIT throughout and no fork or upstream references remain.": "Tina 是一个独立项目：全部采用 MIT 许可证，不再保留任何分支或上游引用。",
        "Documentation now explains how night warmth works and its limits, and records the repository rules for coding agents.": "文档现在说明了夜间暖色的工作方式和限制，并记录了代码智能体需要遵守的仓库规则。",
    ]

    private static let zhHant: [String: String] = [
        // 3.7.3
        "Microphone mute keeps its listeners across normal input changes, registers them again after the audio service restarts, and holds a requested mute on a device until that device comes back.": "靜音麥克風會在正常的輸入裝置變化後保留監聽，在音訊服務重新啟動後重新註冊，並在裝置重新出現前保持對該裝置的靜音請求。",
        "The window switcher waits until an interrupted session can be dismissed before it filters keys and clicks again after macOS pauses its input tap. Suspending the feature or installing a newer switcher supersedes a stale restart.": "視窗切換器在 macOS 暫停其輸入監聽後會等待被中斷的工作階段可以關閉，然後再恢復過濾按鍵和點擊。暫停該功能或安裝較新的切換器會取代已經過時的重啟。",
        "Volume keys on USB outputs without a compatible main volume control are handed to macOS when a reliable step or confirmation is not available, including fine repeats. Dynamic Island reports the level that same output confirmed.": "對於沒有相容主音量控制的 USB 輸出，當無法取得可靠的步進或確認時（包括精細重複），音量鍵會交還給 macOS 處理。Dynamic Island 會報告同一輸出確認的音量。",

        // 3.7.2
        "Built-in updates install again. Releases are self-signed, but the installer required an Apple-anchored Developer ID signature that no release could carry, so every attempt stopped at fail-dmg-verify. The disk image is now signed by the same certificate as the app, and the installer pins that certificate instead of a team ID. Releases up to 3.7.1 still need one manual install.": "內建更新恢復可用。發佈包使用自簽章，但安裝器原本要求帶 Apple 根信任的 Developer ID 簽章，而任何發佈包都無法具備，因此每次嘗試都停在 fail-dmg-verify。現在磁碟映像與應用程式使用同一張憑證簽署，安裝器固定該憑證而不是團隊 ID。3.7.1 及更早的版本仍需手動安裝一次。",
        "The fan-control helper's XPC peer requirement pins the signing certificate of the running app instead of a Developer ID team, matching how releases are actually signed.": "風扇控制輔助程式的 XPC 對端要求改為固定正在執行中的應用程式簽章憑證，而不是 Developer ID 團隊，與實際發佈簽章方式一致。",

        // 3.7.1
        "Dynamic Island AI Agents count Cursor token usage from a dated response with usage counts in a local transcript. Cursor plan credits are still not read from the network.": "Dynamic Island 的 AI Agents 會從本機記錄中帶日期和使用量統計的回應裡統計 Cursor token 用量。Cursor 方案額度仍不會從網路讀取。",
        "Cleaner keeps preferences, support files and caches it can match to audio plugins installed in the standard plugin folders, and checks again before moving a selected item to the Trash.": "清理工具會保留能對應到標準外掛程式資料夾中已安裝音訊外掛程式的偏好設定、支援檔案和快取，並在將所選項目移到垃圾桶前再次檢查。",

        // 3.7.0 Added
        "Window pinning: keep any window visible above other apps as a live, resizable mirror. Pinned windows follow their source, pause while minimized, on another Space or fully covered, and hand control back to the real window on click or hover. The feature is installed from the Hub, uses Screen Recording and Accessibility, and its settings join Settings backup.": "視窗固定：將任意視窗作為可調整大小的即時鏡像，始終保持在其他應用程式之上。固定的視窗會跟隨來源視窗，在來源視窗最小化、位於其他空間或被完全遮蓋時暫停，並在點擊或懸停時把控制權交還真實視窗。該功能從功能中心安裝，需要螢幕錄製和輔助使用權限，其設定會納入設定備份。",
        "Live captions: turn the sound your Mac is playing into on-screen captions with on-device Speech recognition, a draggable click-through caption bar, a menu bar indicator and a global shortcut. Sessions are saved locally and can be exported as SRT, Markdown or plain text, copied, or removed, and captions stop cleanly when a screen recording starts because the two cannot share the system audio tap.": "即時字幕：用裝置端語音辨識把 Mac 正在播放的聲音變成螢幕字幕，並提供可拖曳、可點擊穿透的字幕列、選單列指示器和全域快速鍵。工作階段會儲存在本機，可匯出為 SRT、Markdown 或純文字，也可拷貝或刪除；由於兩者無法共用系統音訊擷取，螢幕錄製開始時字幕會乾淨地停止。",
        "Quick toggles can restart the Dock, the Finder, the menu bar or the third-party input method in use. Each row confirms first, explains what disappears for a moment, and reports whether the component came back. The input method row stays disabled with a reason when no third-party input method is running, and every action follows the Kill Process protection rules with no new permission or helper.": "快速開關可以重新啟動 Dock、Finder、選單列或正在使用的第三方輸入法。每一列都會先確認，說明會短暫消失的是什麼，並回報該元件是否恢復。沒有第三方輸入法執行時，輸入法一列會保持停用並說明原因；所有操作都遵循強制結束程序的保護規則，且不需要新的權限或輔助程式。",
        "Dynamic Island AI Agents now follow Cursor's live turns, project names and completion notices by reading its local agent transcripts, with no network requests and no plan credits read.": "Dynamic Island 的 AI Agents 現在透過讀取 Cursor 本機的 Agent 記錄，跟隨其實際工作階段輪次、專案名稱和完成通知，不發起網路請求，也不讀取方案額度。",

        // 3.7.0 Changed
        "Tina no longer builds services for features that are turned off when it launches, so startup does less work without changing what is available. Display recovery for screens a previous run left off still runs before the rest of launch.": "Tina 啟動時不再為已關閉的功能建置服務，因此啟動工作量更少，而可用功能不變。針對上次執行未恢復的顯示器的顯示恢復仍會在啟動的其餘步驟之前執行。",
        "Window gestures and edge snapping share one pointer tap, so a drag that needs both keeps an in-progress gesture and cancels a pending snap correctly when the drag is handed to macOS.": "視窗手勢與邊緣貼齊共用同一個指標監聽，因此同時需要兩者的拖曳會保留進行中的手勢，並在拖曳交還給 macOS 時正確取消待處理的貼齊。",
        "Microphone mute can follow an unmute made from a call app when the opt-in option in Settings → Quick panel is turned on. Mute enforcement stays the default.": "開啟「設定 → 快速面板」中的選用選項後，靜音麥克風可以跟隨通話 App 中執行的取消靜音。預設仍是強制執行靜音。",

        // 3.7.0 Fixed
        "Update checks ask the repository the app is built from, so they no longer fail against a renamed repository. A response GitHub rejects now reports its HTTP status instead of a placeholder.": "更新檢查會詢問應用程式建置時所用的儲存庫，因此在儲存庫改名後不再失敗。GitHub 拒絕的回應現在會回報其 HTTP 狀態，而不是預留內容。",
        "The post-update What's New window reads the changelog bundled with the app again, so it lists the changes made in every version between the previous install and the current one.": "更新後的「新功能」視窗重新讀取隨應用程式封裝的更新日誌，因此會列出上次安裝版本與目前版本之間每個版本的改動。",
        "Screen recording keeps the camera bubble in the editor preview and in every video, GIF and shared export by drawing it after the automatic zoom instead of baking it into the recording.": "螢幕錄製在自動縮放之後繪製相機泡泡，而不是把它烘焙進錄製內容，因此編輯器預覽以及每個影片、GIF 和共享匯出中都會保留相機泡泡。",
        "The live key row stays inside the recorded window or area, the key switch asks for Input Monitoring when it is turned on, and a missing grant is reported when recording starts instead of silently omitting the keys.": "即時按鍵列會保持在錄製的視窗或區域之內；按鍵開關開啟時會要求輸入監控權限；缺少授權時會在錄製開始時回報，而不是靜默省略按鍵。",
        "The screen-capture chooser offers full-screen recording, and a shortcut's recorder row is hidden while that shortcut is turned off.": "螢幕擷取選擇器提供全螢幕錄製；快速鍵關閉期間，該快速鍵的錄製器一列會隱藏。",
        "Fan control keeps a verified curve through a GPU power-down, retries a refused fan write while every fan still holds its target, and returns all fans to system control when a safe configuration cannot be verified. The panel reports a curve it could not restore.": "風扇控制在 GPU 斷電期間保持已驗證的曲線；在所有風扇仍保持目標轉速時重試被拒絕的風扇寫入；無法驗證安全設定時讓所有風扇回到系統控制。面板會回報無法恢復的曲線。",
        "Clipboard history prefers the text in a copy that also carries rich text, so copied spreadsheet cells keep their text and separators instead of becoming a preview image. Image and file copies are unchanged.": "剪貼簿記錄在同時帶有富文字的拷貝內容中優先取文字，因此拷貝的試算表儲存格會保留文字和分隔符號，而不會變成預覽圖片。圖片和檔案拷貝不受影響。",
        "Low disk space alerts repeat at most once every six hours per volume, with one earlier alert when free space drops below half the limit.": "磁碟空間不足提醒在每個卷宗上最多每六小時重複一次；當可用空間降到門檻的一半以下時會提前提醒一次。",
        "Super Key waits for a keyboard after login or wake instead of treating the missing mapping as refused, and captures F18 only once the mapping is written and read back.": "Super Key 在登入或喚醒後會等待鍵盤，而不再把缺少對應視為被拒絕；只有在對應寫入並讀回後才會擷取 F18。",
        "The window switcher hands ⌘Tab back to macOS while an exclusive full-screen game covers the display, and resumes suppression when the game leaves full screen.": "當獨佔全螢幕遊戲覆蓋顯示器時，視窗切換器會把 ⌘Tab 交還給 macOS；遊戲離開全螢幕後會恢復攔截。",

        // 3.6.0
        "Auto input source: assign an input method per app, with separate choices for the first activation after launch and later returns. Rules can be exported and imported as JSON, and a \"never switch\" list takes precedence over every rule.": "自動輸入來源：為每個 App 指定輸入法，並可分別為啟動後的首次啟用和之後回到應用程式設定選擇。規則可匯出和匯入為 JSON，「永不切換」清單優先於所有規則。",
        "Battery charge limit: Apple Silicon MacBooks can stop charging at a chosen level between 60% and 100%, resume 5 points below it and charge to full once on demand. Turning the feature off, quitting or a helper crash restores normal charging.": "電池充電上限：Apple 晶片 MacBook 可以在 60% 到 100% 之間選定的電量停止充電，低於該值 5 個百分點時恢復充電，並可依需求充滿一次。關閉該功能、結束應用程式或輔助程式當機都會恢復正常充電。",
        "Per-app scrolling: choose follow-global, off, or a custom step and speed for each app, invert scrolling for one app only, and return to the raw wheel while a chosen key is held.": "依 App 捲動：為每個 App 選擇跟隨全域、關閉，或自訂步進和速度；可只反轉某一個 App 的捲動；按住指定按鍵時恢復原始滾輪。",
        "Verification codes: standard TOTP codes in the menu bar panel and Quick panel, copied with one click, masked until the pointer rests on them and stored in the Keychain only.": "驗證碼：在選單列面板和快速面板中顯示標準 TOTP 驗證碼，一鍵拷貝，指標停留前保持隱藏，並且只儲存在鑰匙圈中。",
        "Window tiling: arrange every normal window on the current display as a balanced grid, by rows or by columns. Repeating the same action cycles to the next layout, and each row or column can hold 1–6 windows.": "視窗並排：把目前顯示器上的所有一般視窗按列或按欄排列成均衡格線。重複同一操作會循環切換下一種版面，每列或每欄可容納 1–6 個視窗。",
        "Displays presets: save resolution, brightness, display volume and mute, and the main display, then restore them from the panel, a shortcut, or automatically when a display connects or disconnects, with a report of anything that could not be restored.": "顯示器預設：儲存解析度、亮度、顯示器音量和靜音狀態以及主顯示器，然後可從面板、快速鍵恢復，或在顯示器連接、中斷時自動恢復，並回報任何無法恢復的項目。",
        "Keystroke overlay for screen recording: show the keys being pressed in a corner or beside the pointer, with three sizes, a dwell time and light or dark appearance, included in the editor preview and in video and GIF exports.": "螢幕錄製的按鍵顯示：在角落或指標旁顯示正在按下的按鍵，提供三種大小、停留時間和淺色或深色外觀，並會出現在編輯器預覽以及影片和 GIF 匯出中。",
        "Camera bubble for screen recording: composite the camera into the recording as a round or rounded bubble with mirroring and a shadow, switch cameras during the recording, and skip a second app afterwards.": "螢幕錄製的相機泡泡：把相機以圓形或圓角泡泡合成到錄製內容中，可鏡像並帶陰影；錄製期間可切換相機，之後無需再開第二個 App。",

        // 3.5.0
        "Hosts profiles: keep several hosts configurations in Utilities, enable only the combinations you need and apply them at once. Only Tina's marked block in /etc/hosts is replaced, each write is backed up and the last ten are kept, and lines are validated before an admin prompt applies them.": "Hosts 設定：在公用程式中儲存多套 hosts 設定，只啟用你需要的組合並一次套用。只會替換 Tina 在 /etc/hosts 中標記的區塊，每次寫入都會備份並保留最近十次，且在顯示管理員授權前會驗證每一行。",

        // 3.4.5
        "Night warmth: overlay a schedule-driven colour temperature on every display, warmer at sunset and warmer still before bed, with pause by the hour or until sunrise, presets and warmer/cooler nudges. The original gamma tables are restored when the feature is turned off, when Tina quits or after a crash.": "夜間暖色：在所有顯示器上疊加依時間表變化的色溫，日落後更暖，睡前更暖；可依小時暫停或暫停到日出，提供預設以及更暖或更冷的微調。關閉該功能、結束 Tina 或當機後都會恢復原始伽馬表。",
        "Tina is an independent project: the license is MIT throughout and no fork or upstream references remain.": "Tina 是一個獨立專案：全部採用 MIT 授權條款，不再保留任何分支或上游引用。",
        "Documentation now explains how night warmth works and its limits, and records the repository rules for coding agents.": "文件現在說明了夜間暖色的運作方式和限制，並記錄了程式碼代理需要遵守的儲存庫規則。",
    ]

    private static let zhHansTitles: [String: String] = [
        "Added": "新增",
        "Changed": "变更",
        "Fixed": "修复",
        "Summary": "摘要",
        "Highlights": "亮点",
        "Highlight": "亮点",
        "Feature highlights": "功能亮点",
        "Dynamic Island": "Dynamic Island",
        "Performance": "性能",
        "Removed": "移除",
        "Migration": "迁移",
        "Hotfix": "紧急修复",
        "Safety and reliability": "安全与可靠性",
        "Contributors": "贡献者",
        "Docs": "文档",
        "Details": "详情",
    ]

    private static let zhHantTitles: [String: String] = [
        "Added": "新增",
        "Changed": "變更",
        "Fixed": "修正",
        "Summary": "摘要",
        "Highlights": "亮點",
        "Highlight": "亮點",
        "Feature highlights": "功能亮點",
        "Dynamic Island": "Dynamic Island",
        "Performance": "效能",
        "Removed": "移除",
        "Migration": "移轉",
        "Hotfix": "緊急修正",
        "Safety and reliability": "安全與可靠性",
        "Contributors": "貢獻者",
        "Docs": "文件",
        "Details": "詳情",
    ]
}
