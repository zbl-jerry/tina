// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct LaunchItemsStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let sectionUser: String
    let sectionSystem: String
    let loaded: String
    let loadedIdle: String
    let unloaded: String
    let unreadable: String
    let disabled: String
    let readOnly: String
    let stop: String
    let start: String
    let enable: String
    let disable: String
    let reveal: String
    let reload: String
    let failed: String
}

extension FeatureStrings {
    static func launchItems(_ language: AppLanguage) -> LaunchItemsStrings {
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

extension LaunchItemsStrings {
    static let enUS = LaunchItemsStrings(
        title: "Launch Items",
        hubDescription: "See what starts with your Mac and stop the background agents you own.",
        caption: "These agents and daemons start without a window. Only your own user agents can be stopped here; nothing is deleted.",
        sectionUser: "Your agents",
        sectionSystem: "System items (read-only)",
        loaded: "Running",
        loadedIdle: "Loaded, not running",
        unloaded: "Not loaded",
        unreadable: "Could not read status or items.",
        disabled: "Disabled across logins",
        readOnly: "Read-only",
        stop: "Unload for this session",
        start: "Load for this session",
        enable: "Enable across logins",
        disable: "Disable across logins",
        reveal: "Show in Finder",
        reload: "Reload",
        failed: "The change could not be verified."
    )

    static let ptBR = LaunchItemsStrings(
        title: "Itens de inicio",
        hubDescription: "Veja o que inicia com o Mac e pare os agentes em segundo plano que são seus.",
        caption: "Estes agentes e daemons iniciam sem janela. Apenas os seus próprios agentes podem ser parados aqui; nada é apagado.",
        sectionUser: "Seus agentes",
        sectionSystem: "Itens do sistema (somente leitura)",
        loaded: "Em execução",
        loadedIdle: "Carregado, sem execução",
        unloaded: "Não carregado",
        unreadable: "Não foi possível ler o estado ou os itens.",
        disabled: "Desativado entre sessões",
        readOnly: "Somente leitura",
        stop: "Descarregar nesta sessão",
        start: "Carregar nesta sessão",
        enable: "Ativar entre sessões",
        disable: "Desativar entre sessões",
        reveal: "Mostrar no Finder",
        reload: "Recarregar",
        failed: "Não foi possível verificar a alteração."
    )

    static let tr = LaunchItemsStrings(
        title: "Başlangıç Öğeleri",
        hubDescription: "Mac ile neyin başladığını görün ve size ait arka plan ajanlarını durdurun.",
        caption: "Bu ajanlar ve daemon’lar pencere olmadan başlar. Burada yalnızca kendi kullanıcı ajanlarınızı durdurabilirsiniz; hiçbir şey silinmez.",
        sectionUser: "Ajanlarınız",
        sectionSystem: "Sistem öğeleri (salt okunur)",
        loaded: "Çalışıyor",
        loadedIdle: "Yüklü, çalışmıyor",
        unloaded: "Yüklü değil",
        unreadable: "Durum veya öğeler okunamadı.",
        disabled: "Oturumlar arasında devre dışı",
        readOnly: "Salt okunur",
        stop: "Bu oturumda kaldır",
        start: "Bu oturumda yükle",
        enable: "Oturumlar arasında etkinleştir",
        disable: "Oturumlar arasında devre dışı bırak",
        reveal: "Finder’da göster",
        reload: "Yenile",
        failed: "Değişiklik doğrulanamadı."
    )

    static let ru = LaunchItemsStrings(
        title: "Элементы запуска",
        hubDescription: "Посмотрите, что запускается вместе с Mac, и остановите свои фоновые агенты.",
        caption: "Эти агенты и демоны запускаются без окна. Здесь можно остановить только ваших пользовательских агентов; ничего не удаляется.",
        sectionUser: "Ваши агенты",
        sectionSystem: "Системные элементы (только чтение)",
        loaded: "Работает",
        loadedIdle: "Загружено, не запущено",
        unloaded: "Не загружено",
        unreadable: "Не удалось прочитать состояние или элементы.",
        disabled: "Отключено между сеансами",
        readOnly: "Только чтение",
        stop: "Выгрузить в этом сеансе",
        start: "Загрузить в этом сеансе",
        enable: "Включить для всех сеансов",
        disable: "Отключить для всех сеансов",
        reveal: "Показать в Finder",
        reload: "Обновить",
        failed: "Не удалось подтвердить изменение."
    )

    static let es = LaunchItemsStrings(
        title: "Elementos de inicio",
        hubDescription: "Mira qué se inicia con tu Mac y detén los agentes en segundo plano que son tuyos.",
        caption: "Estos agentes y demonios se inician sin ventana. Aquí solo puedes detener tus propios agentes de usuario; no se elimina nada.",
        sectionUser: "Tus agentes",
        sectionSystem: "Elementos del sistema (solo lectura)",
        loaded: "En ejecución",
        loadedIdle: "Cargado, sin ejecutar",
        unloaded: "No cargado",
        unreadable: "No se ha podido leer el estado o los elementos.",
        disabled: "Desactivado entre sesiones",
        readOnly: "Solo lectura",
        stop: "Descargar en esta sesión",
        start: "Cargar en esta sesión",
        enable: "Activar entre sesiones",
        disable: "Desactivar entre sesiones",
        reveal: "Mostrar en Finder",
        reload: "Recargar",
        failed: "No se ha podido verificar el cambio."
    )

    static let sk = LaunchItemsStrings(
        title: "Spúšťacie položky",
        hubDescription: "Pozrite, čo sa spúšťa s Macom, a zastavte vlastných agentov na pozadí.",
        caption: "Títo agenti a démoni sa spúšťajú bez okna. Tu môžete zastaviť iba svojich používateľských agentov; nič sa neodstraňuje.",
        sectionUser: "Vaši agenti",
        sectionSystem: "Systémové položky (iba na čítanie)",
        loaded: "Beží",
        loadedIdle: "Načítané, nebeží",
        unloaded: "Nenačítané",
        unreadable: "Stav alebo položky sa nepodarilo načítať.",
        disabled: "Vypnuté aj po prihlásení",
        readOnly: "Iba na čítanie",
        stop: "Uvoľniť v tejto relácii",
        start: "Načítať v tejto relácii",
        enable: "Povoliť aj po prihlásení",
        disable: "Zakázať aj po prihlásení",
        reveal: "Zobraziť vo Finderi",
        reload: "Znova načítať",
        failed: "Zmenu sa nepodarilo overiť."
    )

    static let de = LaunchItemsStrings(
        title: "Startobjekte",
        hubDescription: "Sehen Sie, was mit dem Mac startet, und stoppen Sie Ihre eigenen Hintergrundagenten.",
        caption: "Diese Agenten und Daemons starten ohne Fenster. Nur Ihre eigenen Benutzeragenten lassen sich hier stoppen; nichts wird gelöscht.",
        sectionUser: "Ihre Agenten",
        sectionSystem: "Systemobjekte (nur lesen)",
        loaded: "Läuft",
        loadedIdle: "Geladen, läuft nicht",
        unloaded: "Nicht geladen",
        unreadable: "Status oder Objekte konnten nicht gelesen werden.",
        disabled: "Über Sitzungen hinweg deaktiviert",
        readOnly: "Nur lesen",
        stop: "Für diese Sitzung entladen",
        start: "Für diese Sitzung laden",
        enable: "Sitzungsübergreifend aktivieren",
        disable: "Sitzungsübergreifend deaktivieren",
        reveal: "Im Finder zeigen",
        reload: "Neu laden",
        failed: "Die Änderung konnte nicht überprüft werden."
    )

    static let fr = LaunchItemsStrings(
        title: "Éléments de démarrage",
        hubDescription: "Voyez ce qui démarre avec votre Mac et arrêtez les agents d’arrière-plan qui vous appartiennent.",
        caption: "Ces agents et démons démarrent sans fenêtre. Seuls vos propres agents utilisateur peuvent être arrêtés ici ; rien n’est supprimé.",
        sectionUser: "Vos agents",
        sectionSystem: "Éléments système (lecture seule)",
        loaded: "En cours",
        loadedIdle: "Chargé, non exécuté",
        unloaded: "Non chargé",
        unreadable: "Impossible de lire l’état ou les éléments.",
        disabled: "Désactivé entre les sessions",
        readOnly: "Lecture seule",
        stop: "Décharger pour cette session",
        start: "Charger pour cette session",
        enable: "Activer entre les sessions",
        disable: "Désactiver entre les sessions",
        reveal: "Afficher dans le Finder",
        reload: "Recharger",
        failed: "La modification n’a pas pu être vérifiée."
    )

    static let it = LaunchItemsStrings(
        title: "Elementi di avvio",
        hubDescription: "Vedi cosa si avvia con il Mac e interrompi gli agenti in background che possiedi.",
        caption: "Questi agenti e daemon si avviano senza finestra. Qui puoi interrompere solo i tuoi agenti utente; nulla viene eliminato.",
        sectionUser: "I tuoi agenti",
        sectionSystem: "Elementi di sistema (sola lettura)",
        loaded: "In esecuzione",
        loadedIdle: "Caricato, non in esecuzione",
        unloaded: "Non caricato",
        unreadable: "Impossibile leggere lo stato o gli elementi.",
        disabled: "Disattivato tra le sessioni",
        readOnly: "Sola lettura",
        stop: "Scarica per questa sessione",
        start: "Carica per questa sessione",
        enable: "Attiva tra le sessioni",
        disable: "Disattiva tra le sessioni",
        reveal: "Mostra nel Finder",
        reload: "Ricarica",
        failed: "Non è stato possibile verificare la modifica."
    )

    static let ja = LaunchItemsStrings(
        title: "起動項目",
        hubDescription: "Mac と一緒に起動するものと、自分のバックグラウンドエージェントを確認して停止できます。",
        caption: "これらのエージェントとデーモンはウインドウなしで起動します。ここで停止できるのは自分のユーザーエージェントだけです。何も削除されません。",
        sectionUser: "自分のエージェント",
        sectionSystem: "システム項目（読み取り専用）",
        loaded: "実行中",
        loadedIdle: "読み込み済み、実行されていません",
        unloaded: "未読み込み",
        unreadable: "状態または項目を読み込めませんでした。",
        disabled: "ログインをまたいで無効",
        readOnly: "読み取り専用",
        stop: "このセッションで読み込みを解除",
        start: "このセッションで読み込む",
        enable: "ログインをまたいで有効にする",
        disable: "ログインをまたいで無効にする",
        reveal: "Finder に表示",
        reload: "再読み込み",
        failed: "変更を確認できませんでした。"
    )

    static let ko = LaunchItemsStrings(
        title: "시동 항목",
        hubDescription: "Mac과 함께 시작되는 항목을 보고 내 백그라운드 에이전트를 중지할 수 있습니다.",
        caption: "이 에이전트와 데몬은 창 없이 시작됩니다. 여기서는 내 사용자 에이전트만 중지할 수 있으며 아무것도 삭제되지 않습니다.",
        sectionUser: "내 에이전트",
        sectionSystem: "시스템 항목(읽기 전용)",
        loaded: "실행 중",
        loadedIdle: "로드됨, 실행 중 아님",
        unloaded: "로드되지 않음",
        unreadable: "상태 또는 항목을 읽을 수 없습니다.",
        disabled: "로그인 후에도 비활성화",
        readOnly: "읽기 전용",
        stop: "이 세션에서 언로드",
        start: "이 세션에서 로드",
        enable: "로그인 후에도 활성화",
        disable: "로그인 후에도 비활성화",
        reveal: "Finder에서 보기",
        reload: "다시 불러오기",
        failed: "변경 사항을 확인할 수 없습니다."
    )

    static let zhHans = LaunchItemsStrings(
        title: "启动项",
        hubDescription: "查看随 Mac 启动的内容，并停止属于你的后台代理。",
        caption: "这些代理和守护进程在后台启动，不显示窗口。这里只能停止你自己的用户代理，不会删除任何内容。",
        sectionUser: "你的代理",
        sectionSystem: "系统项（只读）",
        loaded: "运行中",
        loadedIdle: "已加载，未运行",
        unloaded: "未加载",
        unreadable: "无法读取状态或项目。",
        disabled: "跨登录已停用",
        readOnly: "只读",
        stop: "仅在本次会话卸载",
        start: "仅在本次会话加载",
        enable: "跨登录启用",
        disable: "跨登录停用",
        reveal: "在访达中显示",
        reload: "重新加载",
        failed: "无法验证这次更改。"
    )

    static let zhTW = LaunchItemsStrings(
        title: "啟動項目",
        hubDescription: "查看隨 Mac 啟動的內容，並停止屬於你的背景代理。",
        caption: "這些代理與守護程序在背景啟動，不顯示視窗。這裡只能停止你自己的使用者代理，不會刪除任何內容。",
        sectionUser: "你的代理",
        sectionSystem: "系統項目（唯讀）",
        loaded: "執行中",
        loadedIdle: "已載入，未執行",
        unloaded: "未載入",
        unreadable: "無法讀取狀態或項目。",
        disabled: "跨登入已停用",
        readOnly: "唯讀",
        stop: "僅在本次工作階段卸載",
        start: "僅在本次工作階段載入",
        enable: "跨登入啟用",
        disable: "跨登入停用",
        reveal: "在 Finder 中顯示",
        reload: "重新載入",
        failed: "無法驗證這次變更。"
    )

    static let zhHK = LaunchItemsStrings(
        title: "啟動項目",
        hubDescription: "查看隨 Mac 啟動的內容，並停止屬於你的背景代理。",
        caption: "這些代理與守護程序在背景啟動，不顯示視窗。這裡只能停止你自己的使用者代理，不會刪除任何內容。",
        sectionUser: "你的代理",
        sectionSystem: "系統項目（唯讀）",
        loaded: "執行中",
        loadedIdle: "已載入，未執行",
        unloaded: "未載入",
        unreadable: "無法讀取狀態或項目。",
        disabled: "跨登入已停用",
        readOnly: "唯讀",
        stop: "僅在本次連線階段卸載",
        start: "僅在本次連線階段載入",
        enable: "跨登入啟用",
        disable: "跨登入停用",
        reveal: "在 Finder 中顯示",
        reload: "重新載入",
        failed: "無法驗證這次變更。"
    )

    static let uk = LaunchItemsStrings(
        title: "Елементи запуску",
        hubDescription: "Подивіться, що запускається разом із Mac, і зупиніть свої фонові агенти.",
        caption: "Ці агенти й демони запускаються без вікна. Тут можна зупинити лише ваших користувацьких агентів; нічого не видаляється.",
        sectionUser: "Ваші агенти",
        sectionSystem: "Системні елементи (лише читання)",
        loaded: "Працює",
        loadedIdle: "Завантажено, не запущено",
        unloaded: "Не завантажено",
        unreadable: "Не вдалося прочитати стан або елементи.",
        disabled: "Вимкнено між сеансами",
        readOnly: "Лише читання",
        stop: "Вивантажити в цьому сеансі",
        start: "Завантажити в цьому сеансі",
        enable: "Увімкнути для всіх сеансів",
        disable: "Вимкнути для всіх сеансів",
        reveal: "Показати у Finder",
        reload: "Оновити",
        failed: "Не вдалося підтвердити зміну."
    )
}
