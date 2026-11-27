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
    let stopped: String
    let notRunning: String
    let readOnly: String
    let stop: String
    let start: String
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
        stopped: "Stopped by you",
        notRunning: "Not running",
        readOnly: "Read-only",
        stop: "Stop",
        start: "Start",
        reveal: "Show in Finder",
        reload: "Reload",
        failed: "The command was refused."
    )

    static let ptBR = LaunchItemsStrings(
        title: "Itens de inicio",
        hubDescription: "Veja o que inicia com o Mac e pare os agentes em segundo plano que são seus.",
        caption: "Estes agentes e daemons iniciam sem janela. Apenas os seus próprios agentes podem ser parados aqui; nada é apagado.",
        sectionUser: "Seus agentes",
        sectionSystem: "Itens do sistema (somente leitura)",
        loaded: "Em execução",
        stopped: "Parado por você",
        notRunning: "Não está em execução",
        readOnly: "Somente leitura",
        stop: "Parar",
        start: "Iniciar",
        reveal: "Mostrar no Finder",
        reload: "Recarregar",
        failed: "O comando foi recusado."
    )

    static let tr = LaunchItemsStrings(
        title: "Başlangıç Öğeleri",
        hubDescription: "Mac ile neyin başladığını görün ve size ait arka plan ajanlarını durdurun.",
        caption: "Bu ajanlar ve daemon’lar pencere olmadan başlar. Burada yalnızca kendi kullanıcı ajanlarınızı durdurabilirsiniz; hiçbir şey silinmez.",
        sectionUser: "Ajanlarınız",
        sectionSystem: "Sistem öğeleri (salt okunur)",
        loaded: "Çalışıyor",
        stopped: "Sizin durdurduğunuz",
        notRunning: "Çalışmıyor",
        readOnly: "Salt okunur",
        stop: "Durdur",
        start: "Başlat",
        reveal: "Finder’da göster",
        reload: "Yenile",
        failed: "Komut reddedildi."
    )

    static let ru = LaunchItemsStrings(
        title: "Элементы запуска",
        hubDescription: "Посмотрите, что запускается вместе с Mac, и остановите свои фоновые агенты.",
        caption: "Эти агенты и демоны запускаются без окна. Здесь можно остановить только ваших пользовательских агентов; ничего не удаляется.",
        sectionUser: "Ваши агенты",
        sectionSystem: "Системные элементы (только чтение)",
        loaded: "Работает",
        stopped: "Остановлено вами",
        notRunning: "Не запущено",
        readOnly: "Только чтение",
        stop: "Остановить",
        start: "Запустить",
        reveal: "Показать в Finder",
        reload: "Обновить",
        failed: "Команда отклонена."
    )

    static let es = LaunchItemsStrings(
        title: "Elementos de inicio",
        hubDescription: "Mira qué se inicia con tu Mac y detén los agentes en segundo plano que son tuyos.",
        caption: "Estos agentes y demonios se inician sin ventana. Aquí solo puedes detener tus propios agentes de usuario; no se elimina nada.",
        sectionUser: "Tus agentes",
        sectionSystem: "Elementos del sistema (solo lectura)",
        loaded: "En ejecución",
        stopped: "Detenido por ti",
        notRunning: "No está en ejecución",
        readOnly: "Solo lectura",
        stop: "Detener",
        start: "Iniciar",
        reveal: "Mostrar en Finder",
        reload: "Recargar",
        failed: "El comando fue rechazado."
    )

    static let sk = LaunchItemsStrings(
        title: "Spúšťacie položky",
        hubDescription: "Pozrite, čo sa spúšťa s Macom, a zastavte vlastných agentov na pozadí.",
        caption: "Títo agenti a démoni sa spúšťajú bez okna. Tu môžete zastaviť iba svojich používateľských agentov; nič sa neodstraňuje.",
        sectionUser: "Vaši agenti",
        sectionSystem: "Systémové položky (iba na čítanie)",
        loaded: "Beží",
        stopped: "Zastavené vami",
        notRunning: "Nebeží",
        readOnly: "Iba na čítanie",
        stop: "Zastaviť",
        start: "Spustiť",
        reveal: "Zobraziť vo Finderi",
        reload: "Znova načítať",
        failed: "Príkaz bol odmietnutý."
    )

    static let de = LaunchItemsStrings(
        title: "Startobjekte",
        hubDescription: "Sehen Sie, was mit dem Mac startet, und stoppen Sie Ihre eigenen Hintergrundagenten.",
        caption: "Diese Agenten und Daemons starten ohne Fenster. Nur Ihre eigenen Benutzeragenten lassen sich hier stoppen; nichts wird gelöscht.",
        sectionUser: "Ihre Agenten",
        sectionSystem: "Systemobjekte (nur lesen)",
        loaded: "Läuft",
        stopped: "Von Ihnen gestoppt",
        notRunning: "Läuft nicht",
        readOnly: "Nur lesen",
        stop: "Stoppen",
        start: "Starten",
        reveal: "Im Finder zeigen",
        reload: "Neu laden",
        failed: "Der Befehl wurde abgelehnt."
    )

    static let fr = LaunchItemsStrings(
        title: "Éléments de démarrage",
        hubDescription: "Voyez ce qui démarre avec votre Mac et arrêtez les agents d’arrière-plan qui vous appartiennent.",
        caption: "Ces agents et démons démarrent sans fenêtre. Seuls vos propres agents utilisateur peuvent être arrêtés ici ; rien n’est supprimé.",
        sectionUser: "Vos agents",
        sectionSystem: "Éléments système (lecture seule)",
        loaded: "En cours",
        stopped: "Arrêté par vous",
        notRunning: "Ne s’exécute pas",
        readOnly: "Lecture seule",
        stop: "Arrêter",
        start: "Démarrer",
        reveal: "Afficher dans le Finder",
        reload: "Recharger",
        failed: "La commande a été refusée."
    )

    static let it = LaunchItemsStrings(
        title: "Elementi di avvio",
        hubDescription: "Vedi cosa si avvia con il Mac e interrompi gli agenti in background che possiedi.",
        caption: "Questi agenti e daemon si avviano senza finestra. Qui puoi interrompere solo i tuoi agenti utente; nulla viene eliminato.",
        sectionUser: "I tuoi agenti",
        sectionSystem: "Elementi di sistema (sola lettura)",
        loaded: "In esecuzione",
        stopped: "Interrotto da te",
        notRunning: "Non in esecuzione",
        readOnly: "Sola lettura",
        stop: "Interrompi",
        start: "Avvia",
        reveal: "Mostra nel Finder",
        reload: "Ricarica",
        failed: "Il comando è stato rifiutato."
    )

    static let ja = LaunchItemsStrings(
        title: "起動項目",
        hubDescription: "Mac と一緒に起動するものと、自分のバックグラウンドエージェントを確認して停止できます。",
        caption: "これらのエージェントとデーモンはウインドウなしで起動します。ここで停止できるのは自分のユーザーエージェントだけです。何も削除されません。",
        sectionUser: "自分のエージェント",
        sectionSystem: "システム項目（読み取り専用）",
        loaded: "実行中",
        stopped: "自分が停止",
        notRunning: "停止中",
        readOnly: "読み取り専用",
        stop: "停止",
        start: "開始",
        reveal: "Finder に表示",
        reload: "再読み込み",
        failed: "コマンドが拒否されました。"
    )

    static let ko = LaunchItemsStrings(
        title: "시동 항목",
        hubDescription: "Mac과 함께 시작되는 항목을 보고 내 백그라운드 에이전트를 중지할 수 있습니다.",
        caption: "이 에이전트와 데몬은 창 없이 시작됩니다. 여기서는 내 사용자 에이전트만 중지할 수 있으며 아무것도 삭제되지 않습니다.",
        sectionUser: "내 에이전트",
        sectionSystem: "시스템 항목(읽기 전용)",
        loaded: "실행 중",
        stopped: "내가 중지함",
        notRunning: "실행 중 아님",
        readOnly: "읽기 전용",
        stop: "중지",
        start: "시작",
        reveal: "Finder에서 보기",
        reload: "다시 불러오기",
        failed: "명령이 거부되었습니다."
    )

    static let zhHans = LaunchItemsStrings(
        title: "启动项",
        hubDescription: "查看随 Mac 启动的内容，并停止属于你的后台代理。",
        caption: "这些代理和守护进程在后台启动，不显示窗口。这里只能停止你自己的用户代理，不会删除任何内容。",
        sectionUser: "你的代理",
        sectionSystem: "系统项（只读）",
        loaded: "运行中",
        stopped: "被你停止",
        notRunning: "未运行",
        readOnly: "只读",
        stop: "停止",
        start: "启动",
        reveal: "在访达中显示",
        reload: "重新加载",
        failed: "命令被拒绝。"
    )

    static let zhTW = LaunchItemsStrings(
        title: "啟動項目",
        hubDescription: "查看隨 Mac 啟動的內容，並停止屬於你的背景代理。",
        caption: "這些代理與守護程序在背景啟動，不顯示視窗。這裡只能停止你自己的使用者代理，不會刪除任何內容。",
        sectionUser: "你的代理",
        sectionSystem: "系統項目（唯讀）",
        loaded: "執行中",
        stopped: "被你停止",
        notRunning: "未執行",
        readOnly: "唯讀",
        stop: "停止",
        start: "啟動",
        reveal: "在 Finder 中顯示",
        reload: "重新載入",
        failed: "命令被拒絕。"
    )

    static let zhHK = LaunchItemsStrings(
        title: "啟動項目",
        hubDescription: "查看隨 Mac 啟動的內容，並停止屬於你的背景代理。",
        caption: "這些代理與守護程序在背景啟動，不顯示視窗。這裡只能停止你自己的使用者代理，不會刪除任何內容。",
        sectionUser: "你的代理",
        sectionSystem: "系統項目（唯讀）",
        loaded: "執行中",
        stopped: "被你停止",
        notRunning: "未執行",
        readOnly: "唯讀",
        stop: "停止",
        start: "啟動",
        reveal: "在 Finder 中顯示",
        reload: "重新載入",
        failed: "命令被拒絕。"
    )

    static let uk = LaunchItemsStrings(
        title: "Елементи запуску",
        hubDescription: "Подивіться, що запускається разом із Mac, і зупиніть свої фонові агенти.",
        caption: "Ці агенти й демони запускаються без вікна. Тут можна зупинити лише ваших користувацьких агентів; нічого не видаляється.",
        sectionUser: "Ваші агенти",
        sectionSystem: "Системні елементи (лише читання)",
        loaded: "Працює",
        stopped: "Зупинено вами",
        notRunning: "Не запущено",
        readOnly: "Лише читання",
        stop: "Зупинити",
        start: "Запустити",
        reveal: "Показати у Finder",
        reload: "Оновити",
        failed: "Команду відхилено."
    )
}
