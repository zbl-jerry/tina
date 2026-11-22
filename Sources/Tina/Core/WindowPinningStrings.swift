// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for window pinning. Same contract as the other FeatureStrings
/// structs: memberwise init in declaration order, one static per language, all
/// in this file, and no em dash in visible text.
struct WindowPinningStrings {
    let title: String
    let caption: String
    let enable: String
    let enableCaption: String
    let pinWindow: String
    let pickerTitle: String
    let pickerCaption: String
    let pickerSearch: String
    let pickerEmpty: String
    let pin: String
    let pinned: String
    let refresh: String
    let close: String
    let frameRate: String
    let frameRateCaption: String
    let frameRateValue: String
    let handoff: String
    let handoffClick: String
    let handoffHover: String
    let handoffCaption: String
    let keepFocus: String
    let keepFocusCaption: String
    let pauseHidden: String
    let pauseHiddenCaption: String
    let unpin: String
    let pause: String
    let resume: String
    let useWindow: String
    let closeAll: String
    let paused: String
    let clickHint: String
    let permissionNote: String
    let pinnedCount: String
}

extension FeatureStrings {
    static func windowPinning(_ language: AppLanguage) -> WindowPinningStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension WindowPinningStrings {
    static let enUS = WindowPinningStrings(
        title: "Window pinning",
        caption: "Keep any window visible above other apps as a live mirror you can still use.",
        enable: "Pin windows above other apps",
        enableCaption: "A pinned window follows the real one. Click the mirror to hand control back to the actual window.",
        pinWindow: "Pin a window",
        pickerTitle: "Pin a window",
        pickerCaption: "Choose an open window. Pinned windows stay above other apps until you unpin them.",
        pickerSearch: "Search windows",
        pickerEmpty: "No windows can be pinned right now.",
        pin: "Pin",
        pinned: "Pinned",
        refresh: "Refresh",
        close: "Close",
        frameRate: "Frame rate",
        frameRateCaption: "How often the mirror updates. Lower rates save power.",
        frameRateValue: "%1$d fps",
        handoff: "Hand off control",
        handoffClick: "On click",
        handoffHover: "On hover",
        handoffCaption: "Clicking a mirror hides it and raises the real window so you can type and drag there.",
        keepFocus: "Keep keyboard focus where it is",
        keepFocusCaption: "Raises the real window without switching the active app.",
        pauseHidden: "Pause while the source is hidden",
        pauseHiddenCaption: "Stops capturing when the window is minimized, on another Space, or fully covered.",
        unpin: "Unpin",
        pause: "Pause",
        resume: "Resume",
        useWindow: "Use the window",
        closeAll: "Unpin all windows",
        paused: "Paused",
        clickHint: "Click to use the window. Drag to move.",
        permissionNote: "Window pinning needs Screen Recording to capture the window and Accessibility to raise it.",
        pinnedCount: "%1$d pinned"
    )

    static let zhHans = WindowPinningStrings(
        title: "窗口置顶",
        caption: "把任意窗口以实时镜像固定在其他应用之上，同时保持可用。",
        enable: "将窗口固定在其他应用之上",
        enableCaption: "置顶窗口会跟随真实窗口变化。点击镜像即可把操作交还给真实窗口。",
        pinWindow: "置顶一个窗口",
        pickerTitle: "置顶一个窗口",
        pickerCaption: "选择一个已打开的窗口。置顶后会一直显示在其他应用之上，直到你取消置顶。",
        pickerSearch: "搜索窗口",
        pickerEmpty: "当前没有可置顶的窗口。",
        pin: "置顶",
        pinned: "已置顶",
        refresh: "刷新",
        close: "关闭",
        frameRate: "帧率",
        frameRateCaption: "镜像的刷新频率。较低帧率更省电。",
        frameRateValue: "%1$d 帧/秒",
        handoff: "交还控制",
        handoffClick: "点击时",
        handoffHover: "悬停时",
        handoffCaption: "点击镜像会隐藏镜像并抬起真实窗口，之后可以直接输入和拖动。",
        keepFocus: "保持当前键盘焦点",
        keepFocusCaption: "只抬起真实窗口，不切换当前应用。",
        pauseHidden: "源窗口隐藏时暂停",
        pauseHiddenCaption: "窗口最小化、位于其他桌面或被完全遮挡时停止采集。",
        unpin: "取消置顶",
        pause: "暂停",
        resume: "恢复",
        useWindow: "使用此窗口",
        closeAll: "取消全部置顶",
        paused: "已暂停",
        clickHint: "点击使用窗口，拖动可移动镜像。",
        permissionNote: "窗口置顶需要屏幕录制权限来采集画面，以及辅助功能权限来抬起窗口。",
        pinnedCount: "已置顶 %1$d 个"
    )

    static let zhTW = WindowPinningStrings(
        title: "視窗置頂",
        caption: "把任意視窗以即時鏡像固定在其他 App 之上，同時保持可用。",
        enable: "將視窗固定在其他 App 之上",
        enableCaption: "置頂視窗會跟隨真實視窗變化。點擊鏡像即可把操作交還給真實視窗。",
        pinWindow: "置頂一個視窗",
        pickerTitle: "置頂一個視窗",
        pickerCaption: "選擇一個已開啟的視窗。置頂後會一直顯示在其他 App 之上，直到你取消置頂。",
        pickerSearch: "搜尋視窗",
        pickerEmpty: "目前沒有可置頂的視窗。",
        pin: "置頂",
        pinned: "已置頂",
        refresh: "重新整理",
        close: "關閉",
        frameRate: "影格率",
        frameRateCaption: "鏡像的更新頻率。較低影格率更省電。",
        frameRateValue: "%1$d 影格/秒",
        handoff: "交還控制",
        handoffClick: "點擊時",
        handoffHover: "懸停時",
        handoffCaption: "點擊鏡像會隱藏鏡像並抬起真實視窗，之後可以直接輸入和拖曳。",
        keepFocus: "保持目前鍵盤焦點",
        keepFocusCaption: "只抬起真實視窗，不切換目前 App。",
        pauseHidden: "來源視窗隱藏時暫停",
        pauseHiddenCaption: "視窗最小化、位於其他桌面或被完全遮擋時停止擷取。",
        unpin: "取消置頂",
        pause: "暫停",
        resume: "繼續",
        useWindow: "使用此視窗",
        closeAll: "取消全部置頂",
        paused: "已暫停",
        clickHint: "點擊使用視窗，拖曳可移動鏡像。",
        permissionNote: "視窗置頂需要螢幕錄製權限來擷取畫面，以及輔助使用權限來抬起視窗。",
        pinnedCount: "已置頂 %1$d 個"
    )

    static let zhHK = WindowPinningStrings(
        title: "視窗置頂",
        caption: "把任何視窗以即時鏡像固定在其他 App 之上，同時保持可用。",
        enable: "將視窗固定在其他 App 之上",
        enableCaption: "置頂視窗會跟隨真實視窗變化。點擊鏡像即可把操作交還給真實視窗。",
        pinWindow: "置頂一個視窗",
        pickerTitle: "置頂一個視窗",
        pickerCaption: "選擇一個已開啟的視窗。置頂後會一直顯示在其他 App 之上，直到你取消置頂。",
        pickerSearch: "搜尋視窗",
        pickerEmpty: "目前沒有可置頂的視窗。",
        pin: "置頂",
        pinned: "已置頂",
        refresh: "重新整理",
        close: "關閉",
        frameRate: "影格率",
        frameRateCaption: "鏡像的更新頻率。較低影格率更省電。",
        frameRateValue: "%1$d 影格/秒",
        handoff: "交還控制",
        handoffClick: "點擊時",
        handoffHover: "懸停時",
        handoffCaption: "點擊鏡像會隱藏鏡像並抬起真實視窗，之後可以直接輸入和拖曳。",
        keepFocus: "保持目前鍵盤焦點",
        keepFocusCaption: "只抬起真實視窗，不切換目前 App。",
        pauseHidden: "來源視窗隱藏時暫停",
        pauseHiddenCaption: "視窗最小化、位於其他桌面或被完全遮擋時停止擷取。",
        unpin: "取消置頂",
        pause: "暫停",
        resume: "繼續",
        useWindow: "使用此視窗",
        closeAll: "取消全部置頂",
        paused: "已暫停",
        clickHint: "點擊使用視窗，拖曳可移動鏡像。",
        permissionNote: "視窗置頂需要螢幕錄製權限來擷取畫面，以及輔助使用權限來抬起視窗。",
        pinnedCount: "已置頂 %1$d 個"
    )

    static let ja = WindowPinningStrings(
        title: "ウインドウを最前面に固定",
        caption: "任意のウインドウをライブミラーとして他の App より前面に表示し、そのまま使えるようにします。",
        enable: "ウインドウを他の App より前面に固定",
        enableCaption: "固定したウインドウは元のウインドウに追従します。ミラーをクリックすると実際のウインドウに操作を戻します。",
        pinWindow: "ウインドウを固定",
        pickerTitle: "ウインドウを固定",
        pickerCaption: "開いているウインドウを選択してください。固定を解除するまで他の App より前面に表示されます。",
        pickerSearch: "ウインドウを検索",
        pickerEmpty: "固定できるウインドウがありません。",
        pin: "固定",
        pinned: "固定済み",
        refresh: "更新",
        close: "閉じる",
        frameRate: "フレームレート",
        frameRateCaption: "ミラーの更新頻度です。低いほど省電力になります。",
        frameRateValue: "%1$d fps",
        handoff: "操作を戻す",
        handoffClick: "クリック時",
        handoffHover: "ホバー時",
        handoffCaption: "ミラーをクリックするとミラーを隠して実際のウインドウを前面に出し、そのまま入力やドラッグができます。",
        keepFocus: "キーボードフォーカスを維持",
        keepFocusCaption: "現在の App を切り替えずに実際のウインドウだけを前面に出します。",
        pauseHidden: "元のウインドウが隠れたら一時停止",
        pauseHiddenCaption: "最小化、別のスペース、完全に隠れた状態ではキャプチャを停止します。",
        unpin: "固定を解除",
        pause: "一時停止",
        resume: "再開",
        useWindow: "このウインドウを使う",
        closeAll: "すべての固定を解除",
        paused: "一時停止中",
        clickHint: "クリックでウインドウを使用、ドラッグでミラーを移動。",
        permissionNote: "ウインドウの固定には画面収録とアクセシビリティの許可が必要です。",
        pinnedCount: "%1$d 件を固定中"
    )

    static let ko = WindowPinningStrings(
        title: "윈도우 고정",
        caption: "모든 윈도우를 실시간 미러로 다른 앱 위에 계속 표시하고 그대로 사용할 수 있습니다.",
        enable: "윈도우를 다른 앱 위에 고정",
        enableCaption: "고정된 윈도우는 원래 윈도우를 따라갑니다. 미러를 클릭하면 실제 윈도우로 조작을 돌려줍니다.",
        pinWindow: "윈도우 고정",
        pickerTitle: "윈도우 고정",
        pickerCaption: "열려 있는 윈도우를 선택하세요. 고정을 해제할 때까지 다른 앱 위에 표시됩니다.",
        pickerSearch: "윈도우 검색",
        pickerEmpty: "지금 고정할 수 있는 윈도우가 없습니다.",
        pin: "고정",
        pinned: "고정됨",
        refresh: "새로 고침",
        close: "닫기",
        frameRate: "프레임률",
        frameRateCaption: "미러가 업데이트되는 빈도입니다. 낮을수록 전력을 아낍니다.",
        frameRateValue: "%1$d fps",
        handoff: "조작 넘기기",
        handoffClick: "클릭 시",
        handoffHover: "가리킬 때",
        handoffCaption: "미러를 클릭하면 미러를 숨기고 실제 윈도우를 올려 바로 입력하고 드래그할 수 있습니다.",
        keepFocus: "키보드 포커스 유지",
        keepFocusCaption: "현재 앱을 전환하지 않고 실제 윈도우만 올립니다.",
        pauseHidden: "원본 윈도우가 가려지면 일시 정지",
        pauseHiddenCaption: "최소화되거나 다른 공간에 있거나 완전히 가려지면 캡처를 멈춥니다.",
        unpin: "고정 해제",
        pause: "일시 정지",
        resume: "재개",
        useWindow: "이 윈도우 사용",
        closeAll: "모든 고정 해제",
        paused: "일시 정지됨",
        clickHint: "클릭하면 윈도우를 사용하고, 드래그하면 미러를 옮깁니다.",
        permissionNote: "윈도우 고정에는 화면 기록과 손쉬운 사용 권한이 필요합니다.",
        pinnedCount: "%1$d개 고정됨"
    )

    static let de = WindowPinningStrings(
        title: "Fenster anheften",
        caption: "Jedes Fenster als Live-Spiegel über anderen Apps sichtbar halten und weiter benutzen.",
        enable: "Fenster über anderen Apps anheften",
        enableCaption: "Ein angeheftetes Fenster folgt dem echten Fenster. Ein Klick auf den Spiegel gibt die Steuerung an das echte Fenster zurück.",
        pinWindow: "Fenster anheften",
        pickerTitle: "Fenster anheften",
        pickerCaption: "Ein geöffnetes Fenster wählen. Angeheftete Fenster bleiben über anderen Apps, bis du sie löst.",
        pickerSearch: "Fenster suchen",
        pickerEmpty: "Im Moment kann kein Fenster angeheftet werden.",
        pin: "Anheften",
        pinned: "Angeheftet",
        refresh: "Aktualisieren",
        close: "Schließen",
        frameRate: "Bildrate",
        frameRateCaption: "Wie oft der Spiegel aktualisiert wird. Niedrigere Raten sparen Energie.",
        frameRateValue: "%1$d fps",
        handoff: "Steuerung übergeben",
        handoffClick: "Beim Klicken",
        handoffHover: "Beim Darüberfahren",
        handoffCaption: "Ein Klick auf den Spiegel blendet ihn aus und holt das echte Fenster nach vorn, sodass du dort tippen und ziehen kannst.",
        keepFocus: "Tastaturfokus beibehalten",
        keepFocusCaption: "Holt das echte Fenster nach vorn, ohne die aktive App zu wechseln.",
        pauseHidden: "Pausieren, wenn die Quelle verdeckt ist",
        pauseHiddenCaption: "Stoppt die Aufnahme, wenn das Fenster minimiert, auf einem anderen Schreibtisch oder vollständig verdeckt ist.",
        unpin: "Lösen",
        pause: "Pausieren",
        resume: "Fortsetzen",
        useWindow: "Fenster verwenden",
        closeAll: "Alle Fenster lösen",
        paused: "Pausiert",
        clickHint: "Klicken, um das Fenster zu verwenden. Ziehen, um den Spiegel zu bewegen.",
        permissionNote: "Fenster anheften benötigt Bildschirmaufnahme zum Erfassen und Bedienungshilfen zum Anheben.",
        pinnedCount: "%1$d angeheftet"
    )

    static let fr = WindowPinningStrings(
        title: "Épinglage de fenêtres",
        caption: "Garder n’importe quelle fenêtre visible au-dessus des autres apps sous forme de miroir en direct, tout en restant utilisable.",
        enable: "Épingler des fenêtres au-dessus des autres apps",
        enableCaption: "Une fenêtre épinglée suit la vraie fenêtre. Cliquez sur le miroir pour rendre le contrôle à la fenêtre réelle.",
        pinWindow: "Épingler une fenêtre",
        pickerTitle: "Épingler une fenêtre",
        pickerCaption: "Choisissez une fenêtre ouverte. Les fenêtres épinglées restent au-dessus des autres apps jusqu’à ce que vous les détachiez.",
        pickerSearch: "Rechercher des fenêtres",
        pickerEmpty: "Aucune fenêtre ne peut être épinglée pour le moment.",
        pin: "Épingler",
        pinned: "Épinglée",
        refresh: "Actualiser",
        close: "Fermer",
        frameRate: "Fréquence d’images",
        frameRateCaption: "Fréquence de mise à jour du miroir. Une fréquence plus basse économise l’énergie.",
        frameRateValue: "%1$d i/s",
        handoff: "Rendre le contrôle",
        handoffClick: "Au clic",
        handoffHover: "Au survol",
        handoffCaption: "Cliquer sur un miroir le masque et place la vraie fenêtre au premier plan pour y taper et glisser.",
        keepFocus: "Conserver le focus clavier",
        keepFocusCaption: "Place la vraie fenêtre au premier plan sans changer d’app active.",
        pauseHidden: "Pause quand la source est masquée",
        pauseHiddenCaption: "Arrête la capture quand la fenêtre est réduite, sur un autre espace ou entièrement couverte.",
        unpin: "Détacher",
        pause: "Pause",
        resume: "Reprendre",
        useWindow: "Utiliser la fenêtre",
        closeAll: "Détacher toutes les fenêtres",
        paused: "En pause",
        clickHint: "Cliquez pour utiliser la fenêtre. Faites glisser pour déplacer le miroir.",
        permissionNote: "L’épinglage nécessite l’enregistrement de l’écran pour capturer la fenêtre et l’accessibilité pour la placer au premier plan.",
        pinnedCount: "%1$d épinglées"
    )

    static let es = WindowPinningStrings(
        title: "Ventanas fijadas",
        caption: "Mantén cualquier ventana visible sobre otras apps como un espejo en vivo que sigue siendo usable.",
        enable: "Fijar ventanas sobre otras apps",
        enableCaption: "Una ventana fijada sigue a la ventana real. Haz clic en el espejo para devolver el control a la ventana real.",
        pinWindow: "Fijar una ventana",
        pickerTitle: "Fijar una ventana",
        pickerCaption: "Elige una ventana abierta. Las ventanas fijadas permanecen sobre otras apps hasta que las sueltes.",
        pickerSearch: "Buscar ventanas",
        pickerEmpty: "Ahora mismo no hay ventanas que fijar.",
        pin: "Fijar",
        pinned: "Fijada",
        refresh: "Actualizar",
        close: "Cerrar",
        frameRate: "Frecuencia de imágenes",
        frameRateCaption: "Con qué frecuencia se actualiza el espejo. Una frecuencia menor ahorra energía.",
        frameRateValue: "%1$d fps",
        handoff: "Devolver el control",
        handoffClick: "Al hacer clic",
        handoffHover: "Al pasar el puntero",
        handoffCaption: "Al hacer clic en un espejo se oculta y se eleva la ventana real para escribir y arrastrar en ella.",
        keepFocus: "Mantener el foco del teclado",
        keepFocusCaption: "Eleva la ventana real sin cambiar la app activa.",
        pauseHidden: "Pausar cuando la fuente está oculta",
        pauseHiddenCaption: "Detiene la captura cuando la ventana está minimizada, en otro escritorio o completamente cubierta.",
        unpin: "Soltar",
        pause: "Pausar",
        resume: "Reanudar",
        useWindow: "Usar la ventana",
        closeAll: "Soltar todas las ventanas",
        paused: "En pausa",
        clickHint: "Haz clic para usar la ventana. Arrastra para mover el espejo.",
        permissionNote: "Fijar ventanas necesita la grabación de pantalla para capturarlas y la accesibilidad para elevarlas.",
        pinnedCount: "%1$d fijadas"
    )

    static let it = WindowPinningStrings(
        title: "Finestre fissate",
        caption: "Mantieni qualsiasi finestra visibile sopra le altre app come specchio dal vivo, ancora utilizzabile.",
        enable: "Fissa le finestre sopra le altre app",
        enableCaption: "Una finestra fissata segue quella reale. Fai clic sullo specchio per restituire il controllo alla finestra reale.",
        pinWindow: "Fissa una finestra",
        pickerTitle: "Fissa una finestra",
        pickerCaption: "Scegli una finestra aperta. Le finestre fissate restano sopra le altre app finché non le rilasci.",
        pickerSearch: "Cerca finestre",
        pickerEmpty: "Al momento non ci sono finestre da fissare.",
        pin: "Fissa",
        pinned: "Fissata",
        refresh: "Aggiorna",
        close: "Chiudi",
        frameRate: "Frequenza fotogrammi",
        frameRateCaption: "Con quale frequenza si aggiorna lo specchio. Una frequenza più bassa risparmia energia.",
        frameRateValue: "%1$d fps",
        handoff: "Restituisci il controllo",
        handoffClick: "Al clic",
        handoffHover: "Al passaggio",
        handoffCaption: "Facendo clic sullo specchio questo si nasconde e la finestra reale sale in primo piano, dove puoi digitare e trascinare.",
        keepFocus: "Mantieni il focus della tastiera",
        keepFocusCaption: "Porta in primo piano la finestra reale senza cambiare l’app attiva.",
        pauseHidden: "Metti in pausa quando la sorgente è nascosta",
        pauseHiddenCaption: "Interrompe la cattura quando la finestra è ridotta a icona, su un altro spazio o completamente coperta.",
        unpin: "Rilascia",
        pause: "Pausa",
        resume: "Riprendi",
        useWindow: "Usa la finestra",
        closeAll: "Rilascia tutte le finestre",
        paused: "In pausa",
        clickHint: "Fai clic per usare la finestra. Trascina per spostare lo specchio.",
        permissionNote: "Per fissare le finestre servono la registrazione dello schermo per catturarle e l’accessibilità per portarle in primo piano.",
        pinnedCount: "%1$d fissate"
    )

    static let ptBR = WindowPinningStrings(
        title: "Janelas fixadas",
        caption: "Mantenha qualquer janela visível sobre outros apps como um espelho ao vivo que continua utilizável.",
        enable: "Fixar janelas sobre outros apps",
        enableCaption: "Uma janela fixada acompanha a janela real. Clique no espelho para devolver o controle à janela real.",
        pinWindow: "Fixar uma janela",
        pickerTitle: "Fixar uma janela",
        pickerCaption: "Escolha uma janela aberta. As janelas fixadas ficam sobre outros apps até você soltá-las.",
        pickerSearch: "Pesquisar janelas",
        pickerEmpty: "Não há janelas para fixar agora.",
        pin: "Fixar",
        pinned: "Fixada",
        refresh: "Atualizar",
        close: "Fechar",
        frameRate: "Taxa de quadros",
        frameRateCaption: "Com que frequência o espelho é atualizado. Taxas menores economizam energia.",
        frameRateValue: "%1$d fps",
        handoff: "Devolver o controle",
        handoffClick: "Ao clicar",
        handoffHover: "Ao passar o ponteiro",
        handoffCaption: "Clicar no espelho o oculta e traz a janela real para frente, onde você pode digitar e arrastar.",
        keepFocus: "Manter o foco do teclado",
        keepFocusCaption: "Traz a janela real para frente sem trocar o app ativo.",
        pauseHidden: "Pausar quando a origem estiver oculta",
        pauseHiddenCaption: "Interrompe a captura quando a janela está minimizada, em outra área de trabalho ou totalmente coberta.",
        unpin: "Soltar",
        pause: "Pausar",
        resume: "Retomar",
        useWindow: "Usar a janela",
        closeAll: "Soltar todas as janelas",
        paused: "Pausado",
        clickHint: "Clique para usar a janela. Arraste para mover o espelho.",
        permissionNote: "Fixar janelas exige a gravação de tela para capturar a janela e a acessibilidade para trazê-la para frente.",
        pinnedCount: "%1$d fixadas"
    )

    static let ru = WindowPinningStrings(
        title: "Закрепление окон",
        caption: "Держите любое окно видимым поверх других программ в виде живой копии, с которой можно работать.",
        enable: "Закреплять окна поверх других программ",
        enableCaption: "Закреплённое окно повторяет настоящее. Нажмите на копию, чтобы вернуть управление настоящему окну.",
        pinWindow: "Закрепить окно",
        pickerTitle: "Закрепить окно",
        pickerCaption: "Выберите открытое окно. Закреплённые окна остаются поверх других программ, пока вы их не открепите.",
        pickerSearch: "Поиск окон",
        pickerEmpty: "Сейчас нет окон для закрепления.",
        pin: "Закрепить",
        pinned: "Закреплено",
        refresh: "Обновить",
        close: "Закрыть",
        frameRate: "Частота кадров",
        frameRateCaption: "Как часто обновляется копия. Меньшая частота экономит энергию.",
        frameRateValue: "%1$d кадр/с",
        handoff: "Вернуть управление",
        handoffClick: "По нажатию",
        handoffHover: "При наведении",
        handoffCaption: "Нажатие на копию скрывает её и выводит настоящее окно вперёд, где можно печатать и перетаскивать.",
        keepFocus: "Сохранять фокус клавиатуры",
        keepFocusCaption: "Выводит настоящее окно вперёд, не переключая активную программу.",
        pauseHidden: "Пауза, когда источник скрыт",
        pauseHiddenCaption: "Останавливает захват, когда окно свёрнуто, находится на другом рабочем столе или полностью закрыто.",
        unpin: "Открепить",
        pause: "Пауза",
        resume: "Продолжить",
        useWindow: "Использовать окно",
        closeAll: "Открепить все окна",
        paused: "Пауза",
        clickHint: "Нажмите, чтобы использовать окно. Перетащите, чтобы переместить копию.",
        permissionNote: "Для закрепления окон нужны запись экрана и универсальный доступ.",
        pinnedCount: "Закреплено: %1$d"
    )

    static let uk = WindowPinningStrings(
        title: "Закріплення вікон",
        caption: "Тримайте будь-яке вікно видимим поверх інших програм як живу копію, з якою можна працювати.",
        enable: "Закріплювати вікна поверх інших програм",
        enableCaption: "Закріплене вікно повторює справжнє. Натисніть на копію, щоб повернути керування справжньому вікну.",
        pinWindow: "Закріпити вікно",
        pickerTitle: "Закріпити вікно",
        pickerCaption: "Виберіть відкрите вікно. Закріплені вікна залишаються поверх інших програм, доки ви їх не відкріпите.",
        pickerSearch: "Пошук вікон",
        pickerEmpty: "Зараз немає вікон для закріплення.",
        pin: "Закріпити",
        pinned: "Закріплено",
        refresh: "Оновити",
        close: "Закрити",
        frameRate: "Частота кадрів",
        frameRateCaption: "Як часто оновлюється копія. Менша частота економить енергію.",
        frameRateValue: "%1$d кадр/с",
        handoff: "Повернути керування",
        handoffClick: "За натисканням",
        handoffHover: "За наведенням",
        handoffCaption: "Натискання на копію ховає її та виводить справжнє вікно вперед, де можна друкувати й перетягувати.",
        keepFocus: "Зберігати фокус клавіатури",
        keepFocusCaption: "Виводить справжнє вікно вперед, не перемикаючи активну програму.",
        pauseHidden: "Пауза, коли джерело приховане",
        pauseHiddenCaption: "Зупиняє захоплення, коли вікно згорнуто, перебуває на іншому робочому столі або повністю закрите.",
        unpin: "Відкріпити",
        pause: "Пауза",
        resume: "Продовжити",
        useWindow: "Використати вікно",
        closeAll: "Відкріпити всі вікна",
        paused: "Пауза",
        clickHint: "Натисніть, щоб використати вікно. Перетягніть, щоб перемістити копію.",
        permissionNote: "Для закріплення вікон потрібні запис екрана та універсальний доступ.",
        pinnedCount: "Закріплено: %1$d"
    )

    static let tr = WindowPinningStrings(
        title: "Pencere sabitleme",
        caption: "Herhangi bir pencereyi diğer uygulamaların üstünde canlı bir ayna olarak görünür tutun ve kullanmaya devam edin.",
        enable: "Pencereleri diğer uygulamaların üstüne sabitle",
        enableCaption: "Sabitlenen pencere gerçek pencereyi izler. Denetimi gerçek pencereye bırakmak için aynaya tıklayın.",
        pinWindow: "Pencere sabitle",
        pickerTitle: "Pencere sabitle",
        pickerCaption: "Açık bir pencere seçin. Sabitlenen pencereler siz çözene kadar diğer uygulamaların üstünde kalır.",
        pickerSearch: "Pencere ara",
        pickerEmpty: "Şu anda sabitlenecek pencere yok.",
        pin: "Sabitle",
        pinned: "Sabitlendi",
        refresh: "Yenile",
        close: "Kapat",
        frameRate: "Kare hızı",
        frameRateCaption: "Aynanın ne sıklıkla güncelleneceği. Düşük hız daha az güç harcar.",
        frameRateValue: "%1$d fps",
        handoff: "Denetimi bırak",
        handoffClick: "Tıklamada",
        handoffHover: "Üzerine gelince",
        handoffCaption: "Aynaya tıklamak onu gizler ve gerçek pencereyi öne çıkarır; orada yazıp sürükleyebilirsiniz.",
        keepFocus: "Klavye odağını koru",
        keepFocusCaption: "Etkin uygulamayı değiştirmeden gerçek pencereyi öne çıkarır.",
        pauseHidden: "Kaynak gizliyken duraklat",
        pauseHiddenCaption: "Pencere simge durumunda, başka bir masaüstünde veya tamamen kapalıyken yakalamayı durdurur.",
        unpin: "Sabitlemeyi kaldır",
        pause: "Duraklat",
        resume: "Sürdür",
        useWindow: "Pencereyi kullan",
        closeAll: "Tüm sabitlemeleri kaldır",
        paused: "Duraklatıldı",
        clickHint: "Pencereyi kullanmak için tıklayın. Aynayı taşımak için sürükleyin.",
        permissionNote: "Pencere sabitleme, pencereyi yakalamak için ekran kaydı ve öne çıkarmak için erişilebilirlik izni ister.",
        pinnedCount: "%1$d sabitlendi"
    )

    static let sk = WindowPinningStrings(
        title: "Pripnutie okien",
        caption: "Nechajte akékoľvek okno viditeľné nad ostatnými aplikáciami ako živé zrkadlo, ktoré sa dá používať.",
        enable: "Pripnúť okná nad ostatné aplikácie",
        enableCaption: "Pripnuté okno sleduje skutočné okno. Kliknutím na zrkadlo vrátite ovládanie skutočnému oknu.",
        pinWindow: "Pripnúť okno",
        pickerTitle: "Pripnúť okno",
        pickerCaption: "Vyberte otvorené okno. Pripnuté okná zostanú nad ostatnými aplikáciami, kým ich neodopnete.",
        pickerSearch: "Hľadať okná",
        pickerEmpty: "Teraz nie je čo pripnúť.",
        pin: "Pripnúť",
        pinned: "Pripnuté",
        refresh: "Obnoviť",
        close: "Zavrieť",
        frameRate: "Frekvencia snímok",
        frameRateCaption: "Ako často sa zrkadlo aktualizuje. Nižšia frekvencia šetrí energiu.",
        frameRateValue: "%1$d fps",
        handoff: "Odovzdať ovládanie",
        handoffClick: "Pri kliknutí",
        handoffHover: "Pri prejdení",
        handoffCaption: "Kliknutie na zrkadlo ho skryje a vynesie skutočné okno dopredu, kde môžete písať a ťahať.",
        keepFocus: "Zachovať fokus klávesnice",
        keepFocusCaption: "Vynesie skutočné okno dopredu bez prepnutia aktívnej aplikácie.",
        pauseHidden: "Pozastaviť, keď je zdroj skrytý",
        pauseHiddenCaption: "Zastaví zachytávanie, keď je okno minimalizované, na inom pracovnom priestore alebo úplne zakryté.",
        unpin: "Odopnúť",
        pause: "Pozastaviť",
        resume: "Pokračovať",
        useWindow: "Použiť okno",
        closeAll: "Odopnúť všetky okná",
        paused: "Pozastavené",
        clickHint: "Kliknutím okno použijete. Ťahaním zrkadlo presuniete.",
        permissionNote: "Pripnutie okien potrebuje snímanie obrazovky a prístupnosť.",
        pinnedCount: "Pripnuté: %1$d"
    )
}
