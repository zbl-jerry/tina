// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

/// Text for multi-window tiling. Kept apart from `WindowLayoutFeatureStrings`
/// because it is a self-contained addition: one switch covers every language
/// and the existing placement text stays untouched.
struct WindowTilingStrings {
    let title: String
    let caption: String
    let tileAll: String
    let tileRows: String
    let tileColumns: String
    let maxPerRow: String
    let maxPerColumn: String
    let limitsCaption: String
    let arrangedFormat: String
    let partialFormat: String

    static func localized(_ language: AppLanguage) -> WindowTilingStrings {
        switch language {
        case .enUS:
            return .init(title: "Tiling",
                         caption: "Arrange every window on the display of the active window. Press the same shortcut again to cycle through layouts.",
                         tileAll: "Tile all windows",
                         tileRows: "Tile in rows",
                         tileColumns: "Tile in columns",
                         maxPerRow: "Maximum windows per row",
                         maxPerColumn: "Maximum windows per column",
                         limitsCaption: "Rows and columns cycle through layouts up to these limits. Tile all uses the larger value as its row limit. Both default to 3.",
                         arrangedFormat: "Arranged %1$d windows.",
                         partialFormat: "Arranged %1$d of %2$d windows. %3$d did not respond.")
        case .ptBR:
            return .init(title: "Organização em grade",
                         caption: "Organiza todas as janelas na tela da janela ativa. Pressione o mesmo atalho novamente para alternar entre layouts.",
                         tileAll: "Organizar todas as janelas",
                         tileRows: "Organizar em linhas",
                         tileColumns: "Organizar em colunas",
                         maxPerRow: "Máximo de janelas por linha",
                         maxPerColumn: "Máximo de janelas por coluna",
                         limitsCaption: "Linhas e colunas alternam entre layouts até estes limites. Organizar todas usa o maior valor como limite de linhas. O padrão é 3.",
                         arrangedFormat: "%1$d janelas organizadas.",
                         partialFormat: "%1$d de %2$d janelas organizadas. %3$d não responderam.")
        case .tr:
            return .init(title: "Döşeme",
                         caption: "Etkin pencerenin bulunduğu ekrandaki tüm pencereleri düzenler. Aynı kısayola yeniden basarak düzenler arasında geçiş yapın.",
                         tileAll: "Tüm pencereleri döşe",
                         tileRows: "Satırlar hâlinde döşe",
                         tileColumns: "Sütunlar hâlinde döşe",
                         maxPerRow: "Satır başına en fazla pencere",
                         maxPerColumn: "Sütun başına en fazla pencere",
                         limitsCaption: "Satırlar ve sütunlar bu sınırlara kadar olan düzenler arasında geçiş yapar. Tümünü döşe, büyük değeri satır sınırı olarak kullanır. Varsayılan 3.",
                         arrangedFormat: "%1$d pencere düzenlendi.",
                         partialFormat: "%2$d pencereden %1$d tanesi düzenlendi. %3$d pencere yanıt vermedi.")
        case .ru:
            return .init(title: "Мозаика",
                         caption: "Упорядочивает все окна на экране с активным окном. Нажмите то же сочетание ещё раз, чтобы переключать раскладки.",
                         tileAll: "Упорядочить все окна",
                         tileRows: "Разложить по строкам",
                         tileColumns: "Разложить по столбцам",
                         maxPerRow: "Не больше окон в строке",
                         maxPerColumn: "Не больше окон в столбце",
                         limitsCaption: "Строки и столбцы переключают раскладки в пределах этих ограничений. Для всех окон используется большее значение как предел строк. По умолчанию 3.",
                         arrangedFormat: "Упорядочено окон: %1$d.",
                         partialFormat: "Упорядочено %1$d из %2$d окон. Не ответили: %3$d.")
        case .es:
            return .init(title: "Mosaico",
                         caption: "Organiza todas las ventanas de la pantalla de la ventana activa. Pulsa el mismo atajo otra vez para cambiar de distribución.",
                         tileAll: "Organizar todas las ventanas",
                         tileRows: "Organizar en filas",
                         tileColumns: "Organizar en columnas",
                         maxPerRow: "Máximo de ventanas por fila",
                         maxPerColumn: "Máximo de ventanas por columna",
                         limitsCaption: "Las filas y las columnas alternan distribuciones hasta estos límites. Organizar todo usa el valor mayor como límite de filas. Ambos son 3 por defecto.",
                         arrangedFormat: "%1$d ventanas organizadas.",
                         partialFormat: "%1$d de %2$d ventanas organizadas. %3$d no respondieron.")
        case .sk:
            return .init(title: "Dlaždice",
                         caption: "Usporiada všetky okná na obrazovke s aktívnym oknom. Ďalším stlačením tej istej skratky prepnete rozloženie.",
                         tileAll: "Dlaždicovať všetky okná",
                         tileRows: "Dlaždicovať v riadkoch",
                         tileColumns: "Dlaždicovať v stĺpcoch",
                         maxPerRow: "Najviac okien v riadku",
                         maxPerColumn: "Najviac okien v stĺpci",
                         limitsCaption: "Riadky a stĺpce prepínajú rozloženia do týchto limitov. Dlaždicovanie všetkých použije väčšiu hodnotu ako limit riadkov. Predvolená hodnota je 3.",
                         arrangedFormat: "Usporiadaných okien: %1$d.",
                         partialFormat: "Usporiadaných %1$d z %2$d okien. %3$d neodpovedalo.")
        case .de:
            return .init(title: "Kacheln",
                         caption: "Ordnet alle Fenster auf dem Bildschirm des aktiven Fensters an. Erneut dieselbe Tastenkombination drücken, um die Anordnung zu wechseln.",
                         tileAll: "Alle Fenster kacheln",
                         tileRows: "In Zeilen kacheln",
                         tileColumns: "In Spalten kacheln",
                         maxPerRow: "Maximale Fenster pro Zeile",
                         maxPerColumn: "Maximale Fenster pro Spalte",
                         limitsCaption: "Zeilen und Spalten wechseln zwischen Anordnungen bis zu diesen Grenzen. Alle kacheln nutzt den größeren Wert als Zeilengrenze. Beide sind standardmäßig 3.",
                         arrangedFormat: "%1$d Fenster angeordnet.",
                         partialFormat: "%1$d von %2$d Fenstern angeordnet. %3$d haben nicht reagiert.")
        case .fr:
            return .init(title: "Pavage",
                         caption: "Dispose toutes les fenêtres de l’écran de la fenêtre active. Appuyez à nouveau sur le même raccourci pour changer de disposition.",
                         tileAll: "Disposer toutes les fenêtres",
                         tileRows: "Disposer en lignes",
                         tileColumns: "Disposer en colonnes",
                         maxPerRow: "Fenêtres maximum par ligne",
                         maxPerColumn: "Fenêtres maximum par colonne",
                         limitsCaption: "Les lignes et les colonnes alternent les dispositions jusqu’à ces limites. Tout disposer utilise la valeur la plus grande comme limite de lignes. Les deux valent 3 par défaut.",
                         arrangedFormat: "%1$d fenêtres disposées.",
                         partialFormat: "%1$d fenêtres sur %2$d disposées. %3$d sans réponse.")
        case .it:
            return .init(title: "Affiancamento",
                         caption: "Dispone tutte le finestre sullo schermo della finestra attiva. Premi di nuovo la stessa scorciatoia per cambiare disposizione.",
                         tileAll: "Affianca tutte le finestre",
                         tileRows: "Affianca in righe",
                         tileColumns: "Affianca in colonne",
                         maxPerRow: "Numero massimo di finestre per riga",
                         maxPerColumn: "Numero massimo di finestre per colonna",
                         limitsCaption: "Righe e colonne alternano disposizioni fino a questi limiti. Affianca tutte usa il valore maggiore come limite di righe. Entrambi sono 3 per impostazione predefinita.",
                         arrangedFormat: "%1$d finestre disposte.",
                         partialFormat: "%1$d finestre su %2$d disposte. %3$d non hanno risposto.")
        case .ja:
            return .init(title: "タイル配置",
                         caption: "アクティブウインドウがある画面のすべてのウインドウを並べます。同じショートカットをもう一度押すと配置が切り替わります。",
                         tileAll: "すべてのウインドウを並べる",
                         tileRows: "行に並べる",
                         tileColumns: "列に並べる",
                         maxPerRow: "1行あたりの最大ウインドウ数",
                         maxPerColumn: "1列あたりの最大ウインドウ数",
                         limitsCaption: "行と列はこの上限までの配置を順に切り替えます。すべて並べるでは大きい方の値を行数の上限に使います。どちらも既定値は3です。",
                         arrangedFormat: "%1$d個のウインドウを並べました。",
                         partialFormat: "%2$d個中%1$d個のウインドウを並べました。%3$d個が応答しませんでした。")
        case .ko:
            return .init(title: "타일 배치",
                         caption: "활성 윈도우가 있는 디스플레이의 모든 윈도우를 정렬합니다. 같은 단축키를 다시 눌러 배치를 전환합니다.",
                         tileAll: "모든 윈도우 타일 배치",
                         tileRows: "행으로 타일 배치",
                         tileColumns: "열로 타일 배치",
                         maxPerRow: "행당 최대 윈도우 수",
                         maxPerColumn: "열당 최대 윈도우 수",
                         limitsCaption: "행과 열은 이 한도까지의 배치를 순환합니다. 모두 타일 배치는 더 큰 값을 행 한도로 사용합니다. 기본값은 모두 3입니다.",
                         arrangedFormat: "윈도우 %1$d개를 정렬했습니다.",
                         partialFormat: "윈도우 %2$d개 중 %1$d개를 정렬했습니다. %3$d개가 응답하지 않았습니다.")
        case .zhHans:
            return .init(title: "平铺",
                         caption: "把当前窗口所在显示器上的所有窗口排好。再次按同一快捷键可切换布局。",
                         tileAll: "平铺所有窗口",
                         tileRows: "按行平铺",
                         tileColumns: "按列平铺",
                         maxPerRow: "每行最多窗口数",
                         maxPerColumn: "每列最多窗口数",
                         limitsCaption: "按行和按列会在这两个上限内循环切换布局。平铺所有窗口以较大值作为行数上限。两者默认都是 3。",
                         arrangedFormat: "已排好 %1$d 个窗口。",
                         partialFormat: "已排好 %2$d 个窗口中的 %1$d 个。%3$d 个未响应。")
        case .zhTW:
            return .init(title: "並排",
                         caption: "把目前視窗所在顯示器上的所有視窗排好。再按一次相同快速鍵可切換配置。",
                         tileAll: "並排所有視窗",
                         tileRows: "依行並排",
                         tileColumns: "依欄並排",
                         maxPerRow: "每行最多視窗數",
                         maxPerColumn: "每欄最多視窗數",
                         limitsCaption: "依行與依欄會在這兩個上限內循環切換配置。並排所有視窗以較大值作為列數上限。兩者預設都是 3。",
                         arrangedFormat: "已排好 %1$d 個視窗。",
                         partialFormat: "已排好 %2$d 個視窗中的 %1$d 個。%3$d 個未回應。")
        case .zhHK:
            return .init(title: "並排",
                         caption: "把目前視窗所在顯示器上的所有視窗排好。再按一次相同快捷鍵可切換配置。",
                         tileAll: "並排所有視窗",
                         tileRows: "依行並排",
                         tileColumns: "依欄並排",
                         maxPerRow: "每行最多視窗數",
                         maxPerColumn: "每欄最多視窗數",
                         limitsCaption: "依行與依欄會在這兩個上限內循環切換配置。並排所有視窗以較大值作為列數上限。兩者預設都是 3。",
                         arrangedFormat: "已排好 %1$d 個視窗。",
                         partialFormat: "已排好 %2$d 個視窗中的 %1$d 個。%3$d 個未回應。")
        case .uk:
            return .init(title: "Мозаїка",
                         caption: "Упорядковує всі вікна на екрані з активним вікном. Натисніть те саме скорочення ще раз, щоб змінити розкладку.",
                         tileAll: "Упорядкувати всі вікна",
                         tileRows: "Розкласти по рядках",
                         tileColumns: "Розкласти по стовпцях",
                         maxPerRow: "Не більше вікон у рядку",
                         maxPerColumn: "Не більше вікон у стовпці",
                         limitsCaption: "Рядки та стовпці перемикають розкладки в межах цих обмежень. Для всіх вікон використовується більше значення як межа рядків. Типово 3.",
                         arrangedFormat: "Упорядковано вікон: %1$d.",
                         partialFormat: "Упорядковано %1$d з %2$d вікон. Не відповіли: %3$d.")
        }
    }
}
