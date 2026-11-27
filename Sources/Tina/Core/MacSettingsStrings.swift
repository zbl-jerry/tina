// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct MacSettingsStrings {
    let title: String
    let hubDescription: String
    let caption: String
    let current: String
    let save: String
    let apply: String
    let undo: String
    let empty: String
    let failed: String
}

extension FeatureStrings {
    static func macSettings(_ language: AppLanguage) -> MacSettingsStrings {
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

extension MacSettingsStrings {
    static let enUS = MacSettingsStrings(
        title: "macOS Settings Snapshot",
        hubDescription: "Save everyday macOS settings, compare them with this Mac and apply only what differs.",
        caption: "Only user-level settings are read and written. No administrator rights, no privacy permissions, nothing system-wide.",
        current: "Current values",
        save: "Save Snapshot",
        apply: "Apply",
        undo: "Undo Last Apply",
        empty: "No snapshots yet.",
        failed: "Some values could not be written."
    )

    static let ptBR = MacSettingsStrings(
        title: "Instantâneo de configurações do macOS",
        hubDescription: "Guarde configurações do dia a dia do macOS, compare com este Mac e aplique apenas o que difere.",
        caption: "Apenas configurações de usuário são lidas e gravadas. Sem direitos de administrador, sem permissões de privacidade, nada do sistema inteiro.",
        current: "Valores atuais",
        save: "Guardar instantâneo",
        apply: "Aplicar",
        undo: "Desfazer última aplicação",
        empty: "Ainda não há instantâneos.",
        failed: "Alguns valores não puderam ser gravados."
    )

    static let tr = MacSettingsStrings(
        title: "macOS Ayarları Anlık Görüntüsü",
        hubDescription: "Günlük macOS ayarlarını kaydedin, bu Mac ile karşılaştırın ve yalnızca farklı olanları uygulayın.",
        caption: "Yalnızca kullanıcı ayarları okunur ve yazılır. Yönetici hakkı, gizlilik izni veya sistem geneli değişiklik yok.",
        current: "Geçerli değerler",
        save: "Anlık görüntü kaydet",
        apply: "Uygula",
        undo: "Son uygulamayı geri al",
        empty: "Henüz anlık görüntü yok.",
        failed: "Bazı değerler yazılamadı."
    )

    static let ru = MacSettingsStrings(
        title: "Снимок настроек macOS",
        hubDescription: "Сохраняйте повседневные настройки macOS, сравнивайте с этим Mac и применяйте только отличия.",
        caption: "Читаются и записываются только пользовательские настройки. Без прав администратора, без разрешений конфиденциальности, ничего системного.",
        current: "Текущие значения",
        save: "Сохранить снимок",
        apply: "Применить",
        undo: "Отменить последнее применение",
        empty: "Снимков пока нет.",
        failed: "Некоторые значения не удалось записать."
    )

    static let es = MacSettingsStrings(
        title: "Instantánea de ajustes de macOS",
        hubDescription: "Guarda ajustes cotidianos de macOS, compáralos con este Mac y aplica solo lo que difiere.",
        caption: "Solo se leen y escriben ajustes de usuario. Sin derechos de administrador, sin permisos de privacidad, nada para todo el sistema.",
        current: "Valores actuales",
        save: "Guardar instantánea",
        apply: "Aplicar",
        undo: "Deshacer última aplicación",
        empty: "Aún no hay instantáneas.",
        failed: "Algunos valores no se pudieron escribir."
    )

    static let sk = MacSettingsStrings(
        title: "Snímka nastavení macOS",
        hubDescription: "Uložte každodenné nastavenia macOS, porovnajte ich s týmto Macom a použite iba rozdiely.",
        caption: "Čítajú a zapisujú sa iba používateľské nastavenia. Bez práv správcu, bez povolení ochrany súkromia, nič systémové.",
        current: "Aktuálne hodnoty",
        save: "Uložiť snímku",
        apply: "Použiť",
        undo: "Vrátiť posledné použitie",
        empty: "Zatiaľ žiadne snímky.",
        failed: "Niektoré hodnoty sa nepodarilo zapísať."
    )

    static let de = MacSettingsStrings(
        title: "macOS-Einstellungs-Snapshot",
        hubDescription: "Speichern Sie alltägliche macOS-Einstellungen, vergleichen Sie sie mit diesem Mac und wenden Sie nur Abweichungen an.",
        caption: "Nur Benutzereinstellungen werden gelesen und geschrieben. Keine Administratorrechte, keine Datenschutzberechtigungen, nichts systemweit.",
        current: "Aktuelle Werte",
        save: "Snapshot speichern",
        apply: "Anwenden",
        undo: "Letzte Anwendung rückgängig",
        empty: "Noch keine Snapshots.",
        failed: "Einige Werte konnten nicht geschrieben werden."
    )

    static let fr = MacSettingsStrings(
        title: "Instantané des réglages macOS",
        hubDescription: "Enregistrez des réglages macOS du quotidien, comparez-les à ce Mac et n’appliquez que les différences.",
        caption: "Seuls des réglages utilisateur sont lus et écrits. Aucun droit d’administrateur, aucune autorisation de confidentialité, rien à l’échelle du système.",
        current: "Valeurs actuelles",
        save: "Enregistrer l’instantané",
        apply: "Appliquer",
        undo: "Annuler la dernière application",
        empty: "Aucun instantané.",
        failed: "Certaines valeurs n’ont pas pu être écrites."
    )

    static let it = MacSettingsStrings(
        title: "Istantanea impostazioni macOS",
        hubDescription: "Salva impostazioni macOS quotidiane, confrontale con questo Mac e applica solo le differenze.",
        caption: "Vengono lette e scritte solo impostazioni utente. Nessun diritto di amministratore, nessuna autorizzazione alla privacy, nulla a livello di sistema.",
        current: "Valori attuali",
        save: "Salva istantanea",
        apply: "Applica",
        undo: "Annulla ultima applicazione",
        empty: "Nessuna istantanea.",
        failed: "Alcuni valori non sono stati scritti."
    )

    static let ja = MacSettingsStrings(
        title: "macOS 設定スナップショット",
        hubDescription: "日常的な macOS 設定を保存し、この Mac と比較して差分だけを適用します。",
        caption: "読み書きするのはユーザー設定だけです。管理者権限、プライバシー許可、システム全体の変更は行いません。",
        current: "現在の値",
        save: "スナップショットを保存",
        apply: "適用",
        undo: "最後の適用を取り消す",
        empty: "スナップショットはまだありません。",
        failed: "一部の値を書き込めませんでした。"
    )

    static let ko = MacSettingsStrings(
        title: "macOS 설정 스냅샷",
        hubDescription: "일상적인 macOS 설정을 저장하고 이 Mac과 비교해 다른 항목만 적용합니다.",
        caption: "사용자 설정만 읽고 씁니다. 관리자 권한, 개인정보 보호 권한, 시스템 전체 변경은 없습니다.",
        current: "현재 값",
        save: "스냅샷 저장",
        apply: "적용",
        undo: "마지막 적용 취소",
        empty: "아직 스냅샷이 없습니다.",
        failed: "일부 값을 쓰지 못했습니다."
    )

    static let zhHans = MacSettingsStrings(
        title: "macOS 设置快照",
        hubDescription: "保存常用的 macOS 设置，与这台 Mac 对比，只应用有差异的项。",
        caption: "只读写用户级设置。不需要管理员权限，不涉及隐私权限，不修改系统级内容。",
        current: "当前值",
        save: "保存快照",
        apply: "应用",
        undo: "撤销上次应用",
        empty: "还没有快照。",
        failed: "部分值无法写入。"
    )

    static let zhTW = MacSettingsStrings(
        title: "macOS 設定快照",
        hubDescription: "儲存常用的 macOS 設定，與這台 Mac 比較，只套用有差異的項目。",
        caption: "只讀寫使用者層級設定。不需要管理員權限，不涉及隱私權限，不修改系統層級內容。",
        current: "目前值",
        save: "儲存快照",
        apply: "套用",
        undo: "復原上次套用",
        empty: "還沒有快照。",
        failed: "部分值無法寫入。"
    )

    static let zhHK = MacSettingsStrings(
        title: "macOS 設定快照",
        hubDescription: "儲存常用的 macOS 設定，與這台 Mac 比較，只套用有差異的項目。",
        caption: "只讀寫使用者層級設定。不需要管理員權限，不涉及隱私權限，不修改系統層級內容。",
        current: "目前值",
        save: "儲存快照",
        apply: "套用",
        undo: "復原上次套用",
        empty: "還沒有快照。",
        failed: "部分值無法寫入。"
    )

    static let uk = MacSettingsStrings(
        title: "Знімок налаштувань macOS",
        hubDescription: "Зберігайте повсякденні налаштування macOS, порівнюйте з цим Mac і застосовуйте лише відмінності.",
        caption: "Читаються й записуються лише користувацькі налаштування. Без прав адміністратора, без дозволів конфіденційності, нічого системного.",
        current: "Поточні значення",
        save: "Зберегти знімок",
        apply: "Застосувати",
        undo: "Скасувати останнє застосування",
        empty: "Знімків ще немає.",
        failed: "Деякі значення не вдалося записати."
    )
}
