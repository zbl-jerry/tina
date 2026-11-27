// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct UsageStatsStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let today: String
    let screenTime: String
    let keyPresses: String
    let clicks: String
    let topApps: String
    let retention: String
    /// "%d" is the number of days.
    let retentionFormat: String
    let clear: String
    let empty: String
    let privacy: String
}

extension FeatureStrings {
    static func usageStats(_ language: AppLanguage) -> UsageStatsStrings {
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

extension UsageStatsStrings {
    static let enUS = UsageStatsStrings(
        title: "Usage Statistics",
        hubDescription: "See how much time apps, the screen and your input take, counted locally.",
        caption: "Only counts and elapsed time are stored on this Mac: no key codes, typed text, window titles or file paths.",
        today: "Today",
        screenTime: "Screen time",
        keyPresses: "Key presses",
        clicks: "Clicks",
        topApps: "Top apps",
        retention: "Keep for",
        retentionFormat: "%d days",
        clear: "Clear Statistics",
        empty: "No data yet.",
        privacy: "Everything stays on this Mac."
    )

    static let ptBR = UsageStatsStrings(
        title: "Estatísticas de uso",
        hubDescription: "Veja quanto tempo apps, a tela e suas entradas ocupam, contado localmente.",
        caption: "Apenas contagens e tempo decorrido são guardados neste Mac: sem códigos de tecla, texto digitado, títulos de janela ou caminhos.",
        today: "Hoje",
        screenTime: "Tempo de tela",
        keyPresses: "Teclas",
        clicks: "Cliques",
        topApps: "Apps mais usados",
        retention: "Manter por",
        retentionFormat: "%d dias",
        clear: "Limpar estatísticas",
        empty: "Ainda não há dados.",
        privacy: "Tudo fica neste Mac."
    )

    static let tr = UsageStatsStrings(
        title: "Kullanım İstatistikleri",
        hubDescription: "Uygulamaların, ekranın ve girişin ne kadar zaman aldığını yerel olarak görün.",
        caption: "Bu Mac’te yalnızca sayımlar ve süreler saklanır: tuş kodları, yazılan metin, pencere başlıkları veya yollar yok.",
        today: "Bugün",
        screenTime: "Ekran süresi",
        keyPresses: "Tuş basımları",
        clicks: "Tıklamalar",
        topApps: "En çok kullanılan uygulamalar",
        retention: "Sakla",
        retentionFormat: "%d gün",
        clear: "İstatistikleri temizle",
        empty: "Henüz veri yok.",
        privacy: "Her şey bu Mac’te kalır."
    )

    static let ru = UsageStatsStrings(
        title: "Статистика использования",
        hubDescription: "Смотрите, сколько времени занимают приложения, экран и ввод, подсчёт локальный.",
        caption: "На этом Mac хранятся только счётчики и время: без кодов клавиш, текста, заголовков окон и путей.",
        today: "Сегодня",
        screenTime: "Время экрана",
        keyPresses: "Нажатия",
        clicks: "Клики",
        topApps: "Частые приложения",
        retention: "Хранить",
        retentionFormat: "%d дней",
        clear: "Очистить статистику",
        empty: "Данных пока нет.",
        privacy: "Всё остаётся на этом Mac."
    )

    static let es = UsageStatsStrings(
        title: "Estadísticas de uso",
        hubDescription: "Mira cuánto tiempo ocupan las apps, la pantalla y tus entradas, contado localmente.",
        caption: "En este Mac solo se guardan recuentos y tiempos: sin códigos de tecla, texto escrito, títulos de ventana ni rutas.",
        today: "Hoy",
        screenTime: "Tiempo de pantalla",
        keyPresses: "Pulsaciones",
        clicks: "Clics",
        topApps: "Apps más usadas",
        retention: "Conservar",
        retentionFormat: "%d días",
        clear: "Borrar estadísticas",
        empty: "Aún no hay datos.",
        privacy: "Todo se queda en este Mac."
    )

    static let sk = UsageStatsStrings(
        title: "Štatistiky používania",
        hubDescription: "Pozrite, koľko času zaberajú aplikácie, obrazovka a vstup, počítané lokálne.",
        caption: "Na tomto Macu sa ukladajú iba počty a časy: žiadne kódy kláves, písaný text, názvy okien ani cesty.",
        today: "Dnes",
        screenTime: "Čas obrazovky",
        keyPresses: "Stlačenia",
        clicks: "Kliknutia",
        topApps: "Najpoužívanejšie aplikácie",
        retention: "Uchovať",
        retentionFormat: "%d dní",
        clear: "Vymazať štatistiky",
        empty: "Zatiaľ žiadne dáta.",
        privacy: "Všetko zostáva na tomto Macu."
    )

    static let de = UsageStatsStrings(
        title: "Nutzungsstatistik",
        hubDescription: "Sehen Sie, wie viel Zeit Apps, Bildschirm und Eingaben brauchen – lokal gezählt.",
        caption: "Nur Zählungen und Zeit werden auf diesem Mac gespeichert: keine Tastencodes, Texte, Fenstertitel oder Pfade.",
        today: "Heute",
        screenTime: "Bildschirmzeit",
        keyPresses: "Tastenanschläge",
        clicks: "Klicks",
        topApps: "Meistgenutzte Apps",
        retention: "Behalten für",
        retentionFormat: "%d Tage",
        clear: "Statistik löschen",
        empty: "Noch keine Daten.",
        privacy: "Alles bleibt auf diesem Mac."
    )

    static let fr = UsageStatsStrings(
        title: "Statistiques d’utilisation",
        hubDescription: "Voyez le temps pris par les apps, l’écran et vos saisies, compté localement.",
        caption: "Seuls des compteurs et des durées sont stockés sur ce Mac : aucun code de touche, texte saisi, titre de fenêtre ou chemin.",
        today: "Aujourd’hui",
        screenTime: "Temps d’écran",
        keyPresses: "Frappes",
        clicks: "Clics",
        topApps: "Apps les plus utilisées",
        retention: "Conserver",
        retentionFormat: "%d jours",
        clear: "Effacer les statistiques",
        empty: "Pas encore de données.",
        privacy: "Tout reste sur ce Mac."
    )

    static let it = UsageStatsStrings(
        title: "Statistiche d’uso",
        hubDescription: "Vedi quanto tempo occupano app, schermo e input, contato localmente.",
        caption: "Su questo Mac vengono salvati solo conteggi e durate: nessun codice tasto, testo digitato, titolo di finestra o percorso.",
        today: "Oggi",
        screenTime: "Tempo di schermo",
        keyPresses: "Pressioni",
        clicks: "Clic",
        topApps: "App più usate",
        retention: "Mantieni per",
        retentionFormat: "%d giorni",
        clear: "Cancella statistiche",
        empty: "Ancora nessun dato.",
        privacy: "Tutto resta su questo Mac."
    )

    static let ja = UsageStatsStrings(
        title: "使用統計",
        hubDescription: "アプリ、画面、入力にかかった時間をこの Mac で集計して確認できます。",
        caption: "この Mac に保存するのは回数と時間だけです。キーコード、入力内容、ウインドウ名、パスは保存しません。",
        today: "今日",
        screenTime: "画面時間",
        keyPresses: "キー入力",
        clicks: "クリック",
        topApps: "よく使うアプリ",
        retention: "保存期間",
        retentionFormat: "%d 日",
        clear: "統計を消去",
        empty: "まだデータがありません。",
        privacy: "すべてこの Mac に留まります。"
    )

    static let ko = UsageStatsStrings(
        title: "사용 통계",
        hubDescription: "앱, 화면, 입력에 걸린 시간을 이 Mac에서 집계해 확인합니다.",
        caption: "이 Mac에는 횟수와 시간만 저장됩니다. 키 코드, 입력한 텍스트, 창 제목, 경로는 저장하지 않습니다.",
        today: "오늘",
        screenTime: "화면 시간",
        keyPresses: "키 입력",
        clicks: "클릭",
        topApps: "많이 쓴 앱",
        retention: "보관",
        retentionFormat: "%d일",
        clear: "통계 지우기",
        empty: "아직 데이터가 없습니다.",
        privacy: "모든 데이터는 이 Mac에만 남습니다."
    )

    static let zhHans = UsageStatsStrings(
        title: "使用统计",
        hubDescription: "查看 App、屏幕和输入占用了多少时间，全部在本机统计。",
        caption: "本机只保存次数与时长：不记录键码、输入内容、窗口标题或路径。",
        today: "今天",
        screenTime: "屏幕时间",
        keyPresses: "按键次数",
        clicks: "点击次数",
        topApps: "常用 App",
        retention: "保留",
        retentionFormat: "%d 天",
        clear: "清除统计",
        empty: "还没有数据。",
        privacy: "所有数据只留在这台 Mac。"
    )

    static let zhTW = UsageStatsStrings(
        title: "使用統計",
        hubDescription: "查看 App、螢幕與輸入佔用了多少時間，全部在本機統計。",
        caption: "本機只保存次數與時長：不記錄鍵碼、輸入內容、視窗標題或路徑。",
        today: "今天",
        screenTime: "螢幕時間",
        keyPresses: "按鍵次數",
        clicks: "點擊次數",
        topApps: "常用 App",
        retention: "保留",
        retentionFormat: "%d 天",
        clear: "清除統計",
        empty: "還沒有資料。",
        privacy: "所有資料只留在這台 Mac。"
    )

    static let zhHK = UsageStatsStrings(
        title: "使用統計",
        hubDescription: "查看 App、螢幕與輸入佔用了多少時間，全部在本機統計。",
        caption: "本機只保存次數與時長：不記錄鍵碼、輸入內容、視窗標題或路徑。",
        today: "今天",
        screenTime: "螢幕時間",
        keyPresses: "按鍵次數",
        clicks: "點擊次數",
        topApps: "常用 App",
        retention: "保留",
        retentionFormat: "%d 天",
        clear: "清除統計",
        empty: "還沒有資料。",
        privacy: "所有資料只留在這台 Mac。"
    )

    static let uk = UsageStatsStrings(
        title: "Статистика використання",
        hubDescription: "Дивіться, скільки часу займають програми, екран і введення, підрахунок локальний.",
        caption: "На цьому Mac зберігаються лише лічильники й час: без кодів клавіш, тексту, заголовків вікон і шляхів.",
        today: "Сьогодні",
        screenTime: "Час екрана",
        keyPresses: "Натискання",
        clicks: "Кліки",
        topApps: "Найчастіші програми",
        retention: "Зберігати",
        retentionFormat: "%d днів",
        clear: "Очистити статистику",
        empty: "Даних ще немає.",
        privacy: "Усе залишається на цьому Mac."
    )
}
