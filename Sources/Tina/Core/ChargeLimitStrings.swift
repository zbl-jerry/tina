// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Copy for the charge limit card in Energy settings and its hub entry.
struct ChargeLimitStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let toggle: String
    let upperLimit: String
    /// "Charging resumes below %d%%"
    let lowerBoundFormat: String
    let chargeToFull: String
    let chargeToFullActive: String
    /// "Holding at %d%%"
    let holdingFormat: String
    /// "Charging · limit %d%%"
    let chargingFormat: String
    let onBattery: String
    let approvalRequired: String
    let openLoginItems: String
    let restoreCaption: String
    let unsupported: String
    let errorControlFailed: String
    let errorVerificationFailed: String
    let runningWhileTina: String
}

extension FeatureStrings {
    static func chargeLimit(_ language: AppLanguage) -> ChargeLimitStrings {
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

private extension ChargeLimitStrings {
    static let enUS = ChargeLimitStrings(
        title: "Charge limit",
        hubDescription: "Stop charging at a chosen level to slow battery ageing.",
        caption: "Charging stops when the battery reaches this level and resumes a few points lower, so it does not toggle on and off.",
        toggle: "Hold charging at a limit",
        upperLimit: "Upper limit",
        lowerBoundFormat: "Charging resumes below %d%%",
        chargeToFull: "Charge to full once",
        chargeToFullActive: "Charging to full for this session.",
        holdingFormat: "Holding at %d%%",
        chargingFormat: "Charging · limit %d%%",
        onBattery: "On battery · the limit applies when you plug in",
        approvalRequired: "Approve Tina’s helper in Login Items to hold the limit.",
        openLoginItems: "Open Login Items",
        restoreCaption: "Turning this off, or quitting Tina, restores normal charging.",
        unsupported: "This Mac does not expose battery charge control.",
        errorControlFailed: "The helper could not change the charging state.",
        errorVerificationFailed: "The charging state did not stick, so normal charging was restored.",
        runningWhileTina: "Active while Tina is running.")

    static let de = ChargeLimitStrings(
        title: "Ladegrenze",
        hubDescription: "Beim Laden bei einem gewählten Stand stoppen, um die Batterie zu schonen.",
        caption: "Der Ladevorgang stoppt bei diesem Stand und beginnt einige Prozentpunkte tiefer erneut, damit er nicht ständig umschaltet.",
        toggle: "Laden bei einer Grenze anhalten",
        upperLimit: "Obergrenze",
        lowerBoundFormat: "Weiterladen unter %d%%",
        chargeToFull: "Einmal voll laden",
        chargeToFullActive: "Lädt für diese Sitzung vollständig.",
        holdingFormat: "Hält bei %d%%",
        chargingFormat: "Lädt · Grenze %d%%",
        onBattery: "Im Akkubetrieb · die Grenze gilt beim Anschließen",
        approvalRequired: "Tinas Helfer in den Login-Objekten erlauben, um die Grenze zu halten.",
        openLoginItems: "Login-Objekte öffnen",
        restoreCaption: "Ausschalten oder Tina beenden stellt das normale Laden wieder her.",
        unsupported: "Dieser Mac bietet keine Steuerung des Ladevorgangs.",
        errorControlFailed: "Der Helfer konnte den Ladezustand nicht ändern.",
        errorVerificationFailed: "Der Ladezustand blieb nicht bestehen; normales Laden wurde wiederhergestellt.",
        runningWhileTina: "Aktiv, solange Tina läuft.")

    static let fr = ChargeLimitStrings(
        title: "Limite de charge",
        hubDescription: "Arrêter la charge à un niveau choisi pour ralentir le vieillissement de la batterie.",
        caption: "La charge s’arrête à ce niveau et reprend quelques points plus bas, pour éviter les allers-retours.",
        toggle: "Limiter la charge",
        upperLimit: "Limite supérieure",
        lowerBoundFormat: "Reprise de la charge sous %d%%",
        chargeToFull: "Charger à fond une fois",
        chargeToFullActive: "Charge complète pour cette session.",
        holdingFormat: "Maintien à %d%%",
        chargingFormat: "En charge · limite %d%%",
        onBattery: "Sur batterie · la limite s’applique une fois branché",
        approvalRequired: "Autorisez l’assistant de Tina dans les éléments de connexion pour maintenir la limite.",
        openLoginItems: "Ouvrir les éléments de connexion",
        restoreCaption: "Désactiver cette option ou quitter Tina rétablit la charge normale.",
        unsupported: "Ce Mac n’expose pas le contrôle de la charge.",
        errorControlFailed: "L’assistant n’a pas pu modifier l’état de charge.",
        errorVerificationFailed: "L’état de charge n’a pas tenu\u{00A0}; la charge normale a été rétablie.",
        runningWhileTina: "Actif tant que Tina est ouvert.")

    static let es = ChargeLimitStrings(
        title: "Límite de carga",
        hubDescription: "Detener la carga en un nivel elegido para frenar el desgaste de la batería.",
        caption: "La carga se detiene al llegar a este nivel y se reanuda unos puntos más abajo para no alternar.",
        toggle: "Limitar la carga",
        upperLimit: "Límite superior",
        lowerBoundFormat: "La carga se reanuda por debajo del %d%%",
        chargeToFull: "Cargar al 100 % una vez",
        chargeToFullActive: "Cargando al máximo en esta sesión.",
        holdingFormat: "Mantenida al %d%%",
        chargingFormat: "Cargando · límite %d%%",
        onBattery: "Con batería · el límite se aplica al enchufar",
        approvalRequired: "Aprueba el asistente de Tina en Ítems de inicio para mantener el límite.",
        openLoginItems: "Abrir Ítems de inicio",
        restoreCaption: "Desactivar esto o salir de Tina restablece la carga normal.",
        unsupported: "Este Mac no permite controlar la carga.",
        errorControlFailed: "El asistente no pudo cambiar el estado de carga.",
        errorVerificationFailed: "El estado de carga no se mantuvo; se restableció la carga normal.",
        runningWhileTina: "Activo mientras Tina esté abierto.")

    static let it = ChargeLimitStrings(
        title: "Limite di carica",
        hubDescription: "Fermare la carica a un livello scelto per rallentare l’invecchiamento della batteria.",
        caption: "La carica si ferma a questo livello e riprende qualche punto più in basso, senza continui cambi.",
        toggle: "Limita la carica",
        upperLimit: "Limite superiore",
        lowerBoundFormat: "La carica riprende sotto il %d%%",
        chargeToFull: "Carica al 100% una volta",
        chargeToFullActive: "Carica completa per questa sessione.",
        holdingFormat: "Mantenuta al %d%%",
        chargingFormat: "In carica · limite %d%%",
        onBattery: "A batteria · il limite si applica quando colleghi",
        approvalRequired: "Approva l’helper di Tina in Elementi di login per mantenere il limite.",
        openLoginItems: "Apri Elementi di login",
        restoreCaption: "Disattivando questa opzione o chiudendo Tina torna la carica normale.",
        unsupported: "Questo Mac non espone il controllo della carica.",
        errorControlFailed: "L’helper non ha potuto cambiare lo stato di carica.",
        errorVerificationFailed: "Lo stato di carica non è rimasto; è stata ripristinata la carica normale.",
        runningWhileTina: "Attivo finché Tina è in esecuzione.")

    static let ptBR = ChargeLimitStrings(
        title: "Limite de carga",
        hubDescription: "Parar a carga em um nível escolhido para retardar o desgaste da bateria.",
        caption: "A carga para ao atingir este nível e volta alguns pontos abaixo, para não ficar alternando.",
        toggle: "Limitar a carga",
        upperLimit: "Limite superior",
        lowerBoundFormat: "A carga volta abaixo de %d%%",
        chargeToFull: "Carregar até 100% uma vez",
        chargeToFullActive: "Carregando até o máximo nesta sessão.",
        holdingFormat: "Mantida em %d%%",
        chargingFormat: "Carregando · limite %d%%",
        onBattery: "Na bateria · o limite vale ao conectar",
        approvalRequired: "Aprove o assistente da Tina em Itens de Início para manter o limite.",
        openLoginItems: "Abrir Itens de Início",
        restoreCaption: "Desativar isto ou sair da Tina restaura a carga normal.",
        unsupported: "Este Mac não expõe controle de carga.",
        errorControlFailed: "O assistente não conseguiu mudar o estado de carga.",
        errorVerificationFailed: "O estado de carga não se manteve; a carga normal foi restaurada.",
        runningWhileTina: "Ativo enquanto a Tina estiver em execução.")

    static let ru = ChargeLimitStrings(
        title: "Предел заряда",
        hubDescription: "Останавливать зарядку на выбранном уровне, чтобы замедлить износ батареи.",
        caption: "Зарядка останавливается на этом уровне и возобновляется чуть ниже, чтобы не переключаться постоянно.",
        toggle: "Ограничивать зарядку",
        upperLimit: "Верхний предел",
        lowerBoundFormat: "Зарядка возобновится ниже %d%%",
        chargeToFull: "Один раз зарядить полностью",
        chargeToFullActive: "Полная зарядка в этой сессии.",
        holdingFormat: "Удерживается на %d%%",
        chargingFormat: "Зарядка · предел %d%%",
        onBattery: "От батареи · предел применяется при подключении",
        approvalRequired: "Разрешите помощник Tina в объектах входа, чтобы удерживать предел.",
        openLoginItems: "Открыть объекты входа",
        restoreCaption: "Отключение или выход из Tina вернёт обычную зарядку.",
        unsupported: "Этот Mac не предоставляет управление зарядкой.",
        errorControlFailed: "Помощник не смог изменить состояние зарядки.",
        errorVerificationFailed: "Состояние зарядки не сохранилось; обычная зарядка восстановлена.",
        runningWhileTina: "Работает, пока запущена Tina.")

    static let uk = ChargeLimitStrings(
        title: "Межа заряджання",
        hubDescription: "Зупиняти заряджання на вибраному рівні, щоб сповільнити зношування батареї.",
        caption: "Заряджання зупиняється на цьому рівні й відновлюється трохи нижче, щоб не перемикатися постійно.",
        toggle: "Обмежувати заряджання",
        upperLimit: "Верхня межа",
        lowerBoundFormat: "Заряджання відновиться нижче %d%%",
        chargeToFull: "Один раз зарядити повністю",
        chargeToFullActive: "Повне заряджання в цьому сеансі.",
        holdingFormat: "Утримується на %d%%",
        chargingFormat: "Заряджання · межа %d%%",
        onBattery: "Від батареї · межа діє після підключення",
        approvalRequired: "Дозвольте помічник Tina в об’єктах входу, щоб утримувати межу.",
        openLoginItems: "Відкрити об’єкти входу",
        restoreCaption: "Вимкнення або вихід із Tina відновить звичайне заряджання.",
        unsupported: "Цей Mac не надає керування заряджанням.",
        errorControlFailed: "Помічник не зміг змінити стан заряджання.",
        errorVerificationFailed: "Стан заряджання не зберігся; звичайне заряджання відновлено.",
        runningWhileTina: "Працює, поки запущено Tina.")

    static let tr = ChargeLimitStrings(
        title: "Şarj sınırı",
        hubDescription: "Pil yaşlanmasını yavaşlatmak için şarjı seçilen düzeyde durdurun.",
        caption: "Şarj bu düzeye ulaşınca durur ve birkaç puan altında yeniden başlar; böylece sürekli açılıp kapanmaz.",
        toggle: "Şarjı sınırda tut",
        upperLimit: "Üst sınır",
        lowerBoundFormat: "%d%% altında şarj yeniden başlar",
        chargeToFull: "Bir kez tam şarj et",
        chargeToFullActive: "Bu oturum için tam şarj ediliyor.",
        holdingFormat: "%d%% düzeyinde tutuluyor",
        chargingFormat: "Şarj oluyor · sınır %d%%",
        onBattery: "Pilde · sınır prize takınca geçerli olur",
        approvalRequired: "Sınırı tutmak için Giriş Öğeleri’nde Tina’nın yardımcısını onaylayın.",
        openLoginItems: "Giriş Öğeleri’ni aç",
        restoreCaption: "Bunu kapatmak veya Tina’dan çıkmak normal şarjı geri getirir.",
        unsupported: "Bu Mac şarj denetimini sunmuyor.",
        errorControlFailed: "Yardımcı şarj durumunu değiştiremedi.",
        errorVerificationFailed: "Şarj durumu kalıcı olmadı; normal şarj geri yüklendi.",
        runningWhileTina: "Tina çalışırken etkin.")

    static let sk = ChargeLimitStrings(
        title: "Limit nabíjania",
        hubDescription: "Zastaviť nabíjanie na zvolenej úrovni, aby batéria starla pomalšie.",
        caption: "Nabíjanie sa zastaví na tejto úrovni a obnoví sa o niekoľko bodov nižšie, takže sa neprepína.",
        toggle: "Obmedziť nabíjanie",
        upperLimit: "Horný limit",
        lowerBoundFormat: "Nabíjanie sa obnoví pod %d%%",
        chargeToFull: "Raz nabiť na plno",
        chargeToFullActive: "Nabíjanie na plno v tejto relácii.",
        holdingFormat: "Podržané na %d%%",
        chargingFormat: "Nabíja sa · limit %d%%",
        onBattery: "Na batérii · limit platí po pripojení",
        approvalRequired: "Povoľte pomocníka Tiny v prihlasovacích položkách, aby sa limit udržal.",
        openLoginItems: "Otvoriť prihlasovacie položky",
        restoreCaption: "Vypnutie alebo ukončenie Tiny obnoví normálne nabíjanie.",
        unsupported: "Tento Mac neposkytuje ovládanie nabíjania.",
        errorControlFailed: "Pomocník nedokázal zmeniť stav nabíjania.",
        errorVerificationFailed: "Stav nabíjania sa neudržal; normálne nabíjanie bolo obnovené.",
        runningWhileTina: "Aktívne, kým je Tina spustená.")

    static let ja = ChargeLimitStrings(
        title: "充電上限",
        hubDescription: "選んだ残量で充電を止め、バッテリーの劣化をゆるやかにします。",
        caption: "この残量に達すると充電を止め、数ポイント下がると再開します。頻繁な切り替えを防ぎます。",
        toggle: "充電を上限で止める",
        upperLimit: "上限",
        lowerBoundFormat: "%d%% を下回ると充電を再開",
        chargeToFull: "今回だけ満充電にする",
        chargeToFullActive: "このセッションでは満充電まで充電しています。",
        holdingFormat: "%d%% で保持中",
        chargingFormat: "充電中 · 上限 %d%%",
        onBattery: "バッテリー駆動 · 電源接続時に上限を適用",
        approvalRequired: "上限を保持するには、ログイン項目で Tina のヘルパーを承認してください。",
        openLoginItems: "ログイン項目を開く",
        restoreCaption: "これをオフにするか Tina を終了すると、通常の充電に戻ります。",
        unsupported: "この Mac は充電制御に対応していません。",
        errorControlFailed: "ヘルパーが充電状態を変更できませんでした。",
        errorVerificationFailed: "充電状態が維持されなかったため、通常の充電に戻しました。",
        runningWhileTina: "Tina の実行中のみ有効です。")

    static let ko = ChargeLimitStrings(
        title: "충전 한도",
        hubDescription: "선택한 수준에서 충전을 멈춰 배터리 노화를 늦춥니다.",
        caption: "이 수준에 도달하면 충전을 멈추고 몇 퍼센트 낮아지면 다시 시작하므로 반복해서 켜고 끄지 않습니다.",
        toggle: "한도에서 충전 유지",
        upperLimit: "상한",
        lowerBoundFormat: "%d%% 아래로 내려가면 충전 재개",
        chargeToFull: "이번 한 번만 완충",
        chargeToFullActive: "이번 세션에서는 완충까지 충전합니다.",
        holdingFormat: "%d%%에서 유지 중",
        chargingFormat: "충전 중 · 한도 %d%%",
        onBattery: "배터리 사용 중 · 전원을 연결하면 한도가 적용됩니다",
        approvalRequired: "한도를 유지하려면 로그인 항목에서 Tina 도우미를 승인하세요.",
        openLoginItems: "로그인 항목 열기",
        restoreCaption: "이 기능을 끄거나 Tina를 종료하면 정상 충전으로 돌아갑니다.",
        unsupported: "이 Mac은 충전 제어를 지원하지 않습니다.",
        errorControlFailed: "도우미가 충전 상태를 변경하지 못했습니다.",
        errorVerificationFailed: "충전 상태가 유지되지 않아 정상 충전으로 되돌렸습니다.",
        runningWhileTina: "Tina가 실행되는 동안에만 작동합니다.")

    static let zhHans = ChargeLimitStrings(
        title: "充电上限",
        hubDescription: "在选定的电量停止充电，减缓电池老化。",
        caption: "达到该电量后停止充电，低于几个百分点后再恢复，避免反复开关。",
        toggle: "按上限保持电量",
        upperLimit: "上限",
        lowerBoundFormat: "低于 %d%% 时恢复充电",
        chargeToFull: "本次充满",
        chargeToFullActive: "本次会话充电至满电。",
        holdingFormat: "保持在 %d%%",
        chargingFormat: "充电中 · 上限 %d%%",
        onBattery: "正在使用电池 · 接通电源后生效",
        approvalRequired: "请在“登录项”中允许 Tina 的辅助程序以保持上限。",
        openLoginItems: "打开登录项",
        restoreCaption: "关闭此功能或退出 Tina 会恢复系统默认充电。",
        unsupported: "此 Mac 不提供充电控制。",
        errorControlFailed: "辅助程序无法更改充电状态。",
        errorVerificationFailed: "充电状态未生效，已恢复默认充电。",
        runningWhileTina: "仅在 Tina 运行时生效。")

    static let zhTW = ChargeLimitStrings(
        title: "充電上限",
        hubDescription: "在選定的電量停止充電，減緩電池老化。",
        caption: "達到此電量後停止充電，低於幾個百分點後再恢復，避免反覆切換。",
        toggle: "依上限保持電量",
        upperLimit: "上限",
        lowerBoundFormat: "低於 %d%% 時恢復充電",
        chargeToFull: "本次充飽",
        chargeToFullActive: "本次工作階段充電至充飽。",
        holdingFormat: "保持在 %d%%",
        chargingFormat: "充電中 · 上限 %d%%",
        onBattery: "正在使用電池 · 接上電源後生效",
        approvalRequired: "請在「登入項目」中允許 Tina 的輔助程式以維持上限。",
        openLoginItems: "打開登入項目",
        restoreCaption: "關閉此功能或結束 Tina 會恢復系統預設充電。",
        unsupported: "此 Mac 不提供充電控制。",
        errorControlFailed: "輔助程式無法變更充電狀態。",
        errorVerificationFailed: "充電狀態未能維持，已恢復預設充電。",
        runningWhileTina: "僅在 Tina 執行時生效。")

    static let zhHK = ChargeLimitStrings(
        title: "充電上限",
        hubDescription: "在選定的電量停止充電，減慢電池老化。",
        caption: "達到此電量後停止充電，低於數個百分點後再恢復，避免反覆切換。",
        toggle: "按上限保持電量",
        upperLimit: "上限",
        lowerBoundFormat: "低於 %d%% 時恢復充電",
        chargeToFull: "本次充滿",
        chargeToFullActive: "本次作業階段充電至充滿。",
        holdingFormat: "保持在 %d%%",
        chargingFormat: "充電中 · 上限 %d%%",
        onBattery: "正在使用電池 · 接上電源後生效",
        approvalRequired: "請在「登入項目」中允許 Tina 的輔助程式以維持上限。",
        openLoginItems: "開啟登入項目",
        restoreCaption: "關閉此功能或結束 Tina 會恢復系統預設充電。",
        unsupported: "此 Mac 不提供充電控制。",
        errorControlFailed: "輔助程式無法更改充電狀態。",
        errorVerificationFailed: "充電狀態未能維持，已恢復預設充電。",
        runningWhileTina: "僅在 Tina 執行時生效。")
}
