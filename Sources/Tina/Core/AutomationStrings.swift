// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct AutomationStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let addRule: String
    let when: String
    let action: String
    let turnOn: String
    let turnOff: String
    let history: String
    let empty: String
}

extension FeatureStrings {
    static func automation(_ language: AppLanguage) -> AutomationStrings {
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

extension AutomationStrings {
    static let enUS = AutomationStrings(
        title: "Automation",
        hubDescription: "Run one existing feature switch when a schedule, power, display or app event happens.",
        caption: "One trigger, one action. No chains, delays or destructive actions.",
        addRule: "Add Rule",
        when: "When",
        action: "Do",
        turnOn: "Turn on",
        turnOff: "Turn off",
        history: "Recent runs",
        empty: "No runs yet."
    )

    static let ptBR = AutomationStrings(
        title: "Automação",
        hubDescription: "Execute um interruptor de recurso existente quando ocorrer um evento de horário, energia, monitor ou app.",
        caption: "Um gatilho, uma ação. Sem cadeias, atrasos ou ações destrutivas.",
        addRule: "Adicionar regra",
        when: "Quando",
        action: "Fazer",
        turnOn: "Ligar",
        turnOff: "Desligar",
        history: "Execuções recentes",
        empty: "Ainda não há execuções."
    )

    static let tr = AutomationStrings(
        title: "Otomasyon",
        hubDescription: "Zaman, güç, ekran veya uygulama olayında mevcut bir özellik anahtarını çalıştırın.",
        caption: "Bir tetikleyici, bir eylem. Zincir, gecikme veya yıkıcı eylem yok.",
        addRule: "Kural ekle",
        when: "Ne zaman",
        action: "Yap",
        turnOn: "Aç",
        turnOff: "Kapat",
        history: "Son çalışmalar",
        empty: "Henüz çalışma yok."
    )

    static let ru = AutomationStrings(
        title: "Автоматизация",
        hubDescription: "Включайте или выключайте существующую функцию по расписанию, питанию, экрану или запуску приложения.",
        caption: "Один триггер, одно действие. Без цепочек, задержек и разрушительных действий.",
        addRule: "Добавить правило",
        when: "Когда",
        action: "Действие",
        turnOn: "Включить",
        turnOff: "Выключить",
        history: "Недавние запуски",
        empty: "Запусков пока нет."
    )

    static let es = AutomationStrings(
        title: "Automatización",
        hubDescription: "Ejecuta un interruptor de función existente ante un evento de horario, energía, pantalla o app.",
        caption: "Un disparador, una acción. Sin cadenas, retrasos ni acciones destructivas.",
        addRule: "Añadir regla",
        when: "Cuando",
        action: "Hacer",
        turnOn: "Activar",
        turnOff: "Desactivar",
        history: "Ejecuciones recientes",
        empty: "Aún no hay ejecuciones."
    )

    static let sk = AutomationStrings(
        title: "Automatizácia",
        hubDescription: "Spustite existujúci prepínač funkcie pri udalosti času, napájania, obrazovky alebo aplikácie.",
        caption: "Jeden spúšťač, jedna akcia. Bez reťazcov, oneskorení a ničivých akcií.",
        addRule: "Pridať pravidlo",
        when: "Keď",
        action: "Urobiť",
        turnOn: "Zapnúť",
        turnOff: "Vypnúť",
        history: "Nedávne spustenia",
        empty: "Zatiaľ žiadne spustenia."
    )

    static let de = AutomationStrings(
        title: "Automatisierung",
        hubDescription: "Schalten Sie eine vorhandene Funktion bei Zeit-, Netzteil-, Bildschirm- oder App-Ereignissen.",
        caption: "Ein Auslöser, eine Aktion. Keine Ketten, Verzögerungen oder destruktiven Aktionen.",
        addRule: "Regel hinzufügen",
        when: "Wenn",
        action: "Aktion",
        turnOn: "Einschalten",
        turnOff: "Ausschalten",
        history: "Letzte Ausführungen",
        empty: "Noch keine Ausführungen."
    )

    static let fr = AutomationStrings(
        title: "Automatisation",
        hubDescription: "Activez ou désactivez une fonction existante lors d’un événement horaire, d’alimentation, d’écran ou d’app.",
        caption: "Un déclencheur, une action. Pas de chaînes, de délais ni d’actions destructrices.",
        addRule: "Ajouter une règle",
        when: "Quand",
        action: "Action",
        turnOn: "Activer",
        turnOff: "Désactiver",
        history: "Exécutions récentes",
        empty: "Aucune exécution."
    )

    static let it = AutomationStrings(
        title: "Automazione",
        hubDescription: "Attiva o disattiva una funzione esistente a un evento di orario, alimentazione, schermo o app.",
        caption: "Un trigger, un’azione. Nessuna catena, ritardo o azione distruttiva.",
        addRule: "Aggiungi regola",
        when: "Quando",
        action: "Azione",
        turnOn: "Attiva",
        turnOff: "Disattiva",
        history: "Esecuzioni recenti",
        empty: "Nessuna esecuzione."
    )

    static let ja = AutomationStrings(
        title: "オートメーション",
        hubDescription: "時間・電源・ディスプレイ・アプリのイベントで既存の機能スイッチを実行します。",
        caption: "1 つのトリガーに 1 つのアクション。連鎖・遅延・破壊的な操作はありません。",
        addRule: "ルールを追加",
        when: "条件",
        action: "動作",
        turnOn: "オンにする",
        turnOff: "オフにする",
        history: "最近の実行",
        empty: "実行履歴はまだありません。"
    )

    static let ko = AutomationStrings(
        title: "자동화",
        hubDescription: "시간, 전원, 디스플레이, 앱 이벤트에 기존 기능 스위치를 실행합니다.",
        caption: "트리거 하나, 동작 하나. 연쇄, 지연, 파괴적 동작은 없습니다.",
        addRule: "규칙 추가",
        when: "조건",
        action: "동작",
        turnOn: "켜기",
        turnOff: "끄기",
        history: "최근 실행",
        empty: "실행 기록이 없습니다."
    )

    static let zhHans = AutomationStrings(
        title: "自动化",
        hubDescription: "在时间、电源、显示器或 App 事件发生时，执行一个现有功能开关。",
        caption: "一个触发，一个动作。不做链式、延时或破坏性操作。",
        addRule: "添加规则",
        when: "当",
        action: "执行",
        turnOn: "开启",
        turnOff: "关闭",
        history: "最近运行",
        empty: "还没有运行记录。"
    )

    static let zhTW = AutomationStrings(
        title: "自動化",
        hubDescription: "在時間、電源、顯示器或 App 事件發生時，執行一個現有功能開關。",
        caption: "一個觸發，一個動作。不做鏈式、延遲或破壞性操作。",
        addRule: "新增規則",
        when: "當",
        action: "執行",
        turnOn: "開啟",
        turnOff: "關閉",
        history: "最近執行",
        empty: "還沒有執行記錄。"
    )

    static let zhHK = AutomationStrings(
        title: "自動化",
        hubDescription: "在時間、電源、顯示器或 App 事件發生時，執行一個現有功能開關。",
        caption: "一個觸發，一個動作。不做鏈式、延遲或破壞性操作。",
        addRule: "新增規則",
        when: "當",
        action: "執行",
        turnOn: "開啟",
        turnOff: "關閉",
        history: "最近執行",
        empty: "還沒有執行記錄。"
    )

    static let uk = AutomationStrings(
        title: "Автоматизація",
        hubDescription: "Вмикайте або вимикайте наявну функцію за розкладом, живленням, екраном або запуском програми.",
        caption: "Один тригер, одна дія. Без ланцюжків, затримок і руйнівних дій.",
        addRule: "Додати правило",
        when: "Коли",
        action: "Дія",
        turnOn: "Увімкнути",
        turnOff: "Вимкнути",
        history: "Недавні запуски",
        empty: "Запусків ще немає."
    )
}
