// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct InputRemapStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let addRule: String
    let from: String
    let to: String
    let exceptIn: String
    let permission: String
    let failed: String
}

extension FeatureStrings {
    static func inputRemap(_ language: AppLanguage) -> InputRemapStrings {
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

extension InputRemapStrings {
    static let enUS = InputRemapStrings(
        title: "Input Remapping",
        hubDescription: "Map one key to another key or shortcut, with optional per-app exceptions.",
        caption: "Only single key-to-key mappings. Macros, recorded sequences and scroll remapping are not part of this tool.",
        addRule: "Add Rule",
        from: "From",
        to: "To",
        exceptIn: "Except in",
        permission: "Needs Accessibility to rewrite keys. Nothing is changed without it.",
        failed: "The rule could not be saved."
    )

    static let ptBR = InputRemapStrings(
        title: "Remapeamento de entrada",
        hubDescription: "Mapeie uma tecla para outra tecla ou atalho, com exceções por app.",
        caption: "Apenas mapeamentos de uma tecla para outra. Macros, sequências gravadas e remapeamento de rolagem não fazem parte desta ferramenta.",
        addRule: "Adicionar regra",
        from: "De",
        to: "Para",
        exceptIn: "Exceto em",
        permission: "Precisa de Acessibilidade para reescrever teclas. Nada muda sem ela.",
        failed: "A regra não pôde ser salva."
    )

    static let tr = InputRemapStrings(
        title: "Giriş Yeniden Eşleme",
        hubDescription: "Bir tuşu başka bir tuşa veya kısayola eşleyin, uygulama istisnalarıyla.",
        caption: "Yalnızca tek tuş-tuş eşlemeleri. Makrolar, kaydedilmiş diziler ve kaydırma eşlemesi bu araca dahil değildir.",
        addRule: "Kural ekle",
        from: "Şuradan",
        to: "Şuraya",
        exceptIn: "Şunun dışında",
        permission: "Tuşları yeniden yazmak için Erişilebilirlik gerekir. O olmadan hiçbir şey değişmez.",
        failed: "Kural kaydedilemedi."
    )

    static let ru = InputRemapStrings(
        title: "Переназначение ввода",
        hubDescription: "Назначьте одну клавишу другой клавише или сочетанию, с исключениями для приложений.",
        caption: "Только одиночные переназначения клавиш. Макросы, записанные последовательности и переназначение прокрутки сюда не входят.",
        addRule: "Добавить правило",
        from: "Из",
        to: "В",
        exceptIn: "Кроме",
        permission: "Для перезаписи клавиш нужен Доступ к управлению компьютером. Без него ничего не меняется.",
        failed: "Не удалось сохранить правило."
    )

    static let es = InputRemapStrings(
        title: "Remapeo de entrada",
        hubDescription: "Asigna una tecla a otra tecla o atajo, con excepciones por app.",
        caption: "Solo asignaciones de tecla a tecla. Las macros, secuencias grabadas y el remapeo del desplazamiento no forman parte de esta herramienta.",
        addRule: "Añadir regla",
        from: "Desde",
        to: "Hasta",
        exceptIn: "Excepto en",
        permission: "Requiere Accesibilidad para reescribir teclas. Sin ella no cambia nada.",
        failed: "No se pudo guardar la regla."
    )

    static let sk = InputRemapStrings(
        title: "Premapovanie vstupu",
        hubDescription: "Priraďte klávesu inej klávese alebo skratke, s výnimkami pre aplikácie.",
        caption: "Iba priradenia klávesa-klávesa. Makrá, zaznamenané sekvencie a premapovanie posúvania sem nepatria.",
        addRule: "Pridať pravidlo",
        from: "Z",
        to: "Na",
        exceptIn: "Okrem",
        permission: "Na prepisovanie kláves je potrebné Zjednodušenie ovládania. Bez neho sa nič nezmení.",
        failed: "Pravidlo sa nepodarilo uložiť."
    )

    static let de = InputRemapStrings(
        title: "Eingabe-Neubelegung",
        hubDescription: "Ordnen Sie eine Taste einer anderen Taste oder einem Kurzbefehl zu, mit Ausnahmen pro App.",
        caption: "Nur einzelne Taste-zu-Taste-Zuordnungen. Makros, aufgezeichnete Folgen und Scroll-Neubelegung gehören nicht dazu.",
        addRule: "Regel hinzufügen",
        from: "Von",
        to: "Nach",
        exceptIn: "Außer in",
        permission: "Benötigt Bedienungshilfen, um Tasten umzuschreiben. Ohne sie ändert sich nichts.",
        failed: "Die Regel konnte nicht gespeichert werden."
    )

    static let fr = InputRemapStrings(
        title: "Remappage des entrées",
        hubDescription: "Associez une touche à une autre touche ou à un raccourci, avec des exceptions par app.",
        caption: "Uniquement des associations touche à touche. Les macros, séquences enregistrées et le remappage du défilement ne font pas partie de cet outil.",
        addRule: "Ajouter une règle",
        from: "De",
        to: "Vers",
        exceptIn: "Sauf dans",
        permission: "Nécessite l’accessibilité pour réécrire les touches. Rien ne change sans elle.",
        failed: "La règle n’a pas pu être enregistrée."
    )

    static let it = InputRemapStrings(
        title: "Rimappatura input",
        hubDescription: "Associa un tasto a un altro tasto o a una scorciatoia, con eccezioni per app.",
        caption: "Solo associazioni tasto-tasto. Macro, sequenze registrate e rimappatura dello scorrimento non fanno parte di questo strumento.",
        addRule: "Aggiungi regola",
        from: "Da",
        to: "A",
        exceptIn: "Tranne in",
        permission: "Richiede Accessibilità per riscrivere i tasti. Senza di essa nulla cambia.",
        failed: "Impossibile salvare la regola."
    )

    static let ja = InputRemapStrings(
        title: "入力の再割り当て",
        hubDescription: "1 つのキーを別のキーやショートカットに割り当てます。アプリごとの除外も可能です。",
        caption: "キーからキーへの単一の割り当てのみです。マクロ、記録したシーケンス、スクロールの再割り当ては含みません。",
        addRule: "ルールを追加",
        from: "元",
        to: "先",
        exceptIn: "除外",
        permission: "キーを書き換えるにはアクセシビリティが必要です。なければ何も変わりません。",
        failed: "ルールを保存できませんでした。"
    )

    static let ko = InputRemapStrings(
        title: "입력 재매핑",
        hubDescription: "한 키를 다른 키나 단축키로 매핑합니다. 앱별 예외를 둘 수 있습니다.",
        caption: "키-키 단일 매핑만 지원합니다. 매크로, 기록된 시퀀스, 스크롤 재매핑은 포함되지 않습니다.",
        addRule: "규칙 추가",
        from: "원본",
        to: "대상",
        exceptIn: "예외",
        permission: "키를 다시 쓰려면 손쉬운 사용 권한이 필요합니다. 없으면 아무것도 바뀌지 않습니다.",
        failed: "규칙을 저장하지 못했습니다."
    )

    static let zhHans = InputRemapStrings(
        title: "输入重映射",
        hubDescription: "把一个按键映射为另一个按键或快捷键，可按 App 排除。",
        caption: "只支持单键到单键/快捷键的映射。宏、录制序列和滚轮重映射不在本工具范围内。",
        addRule: "添加规则",
        from: "从",
        to: "到",
        exceptIn: "例外",
        permission: "重写按键需要辅助功能权限。没有权限时不会改变任何按键。",
        failed: "规则无法保存。"
    )

    static let zhTW = InputRemapStrings(
        title: "輸入重映射",
        hubDescription: "把一個按鍵映射為另一個按鍵或快速鍵，可依 App 排除。",
        caption: "只支援單鍵到單鍵/快速鍵的映射。巨集、錄製序列與滾輪重映射不在本工具範圍內。",
        addRule: "新增規則",
        from: "從",
        to: "到",
        exceptIn: "例外",
        permission: "重寫按鍵需要輔助使用權限。沒有權限時不會改變任何按鍵。",
        failed: "規則無法儲存。"
    )

    static let zhHK = InputRemapStrings(
        title: "輸入重映射",
        hubDescription: "把一個按鍵映射為另一個按鍵或快速鍵，可依 App 排除。",
        caption: "只支援單鍵到單鍵/快速鍵的映射。巨集、錄製序列與滾輪重映射不在本工具範圍內。",
        addRule: "新增規則",
        from: "從",
        to: "到",
        exceptIn: "例外",
        permission: "重寫按鍵需要輔助使用權限。沒有權限時不會改變任何按鍵。",
        failed: "規則無法儲存。"
    )

    static let uk = InputRemapStrings(
        title: "Перепризначення вводу",
        hubDescription: "Призначте одну клавішу іншій клавіші або комбінації, з винятками для програм.",
        caption: "Лише поодинокі перепризначення клавіш. Макроси, записані послідовності й перепризначення прокрутки сюди не входять.",
        addRule: "Додати правило",
        from: "З",
        to: "У",
        exceptIn: "Крім",
        permission: "Для перезапису клавіш потрібен Доступ до керування комп’ютером. Без нього нічого не змінюється.",
        failed: "Не вдалося зберегти правило."
    )
}
