// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

struct ShortcutSettingsStrings {
    let active: String
    let inactive: String
    let superKeyAlternativeFormat: String
    /// Summary above the page when one or more registrations failed.
    let unavailableCountFormat: String
    let retry: String
}

extension FeatureStrings {
    static func shortcuts(_ language: AppLanguage) -> ShortcutSettingsStrings {
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

extension ShortcutSettingsStrings {
    static let enUS = ShortcutSettingsStrings(
        active: "Active",
        inactive: "Inactive",
        superKeyAlternativeFormat: "or %@",
        unavailableCountFormat: "%d shortcuts couldn’t be registered",
        retry: "Try Again"
    )

    static let ptBR = ShortcutSettingsStrings(
        active: "Ativo",
        inactive: "Inativo",
        superKeyAlternativeFormat: "ou %@",
        unavailableCountFormat: "%d atalhos não puderam ser registrados",
        retry: "Tentar novamente"
    )

    static let tr = ShortcutSettingsStrings(
        active: "Etkin",
        inactive: "Etkin değil",
        superKeyAlternativeFormat: "veya %@",
        unavailableCountFormat: "%d kısayol kaydedilemedi",
        retry: "Yeniden dene"
    )

    static let ru = ShortcutSettingsStrings(
        active: "Активно",
        inactive: "Неактивно",
        superKeyAlternativeFormat: "или %@",
        unavailableCountFormat: "Не удалось зарегистрировать %d сочетаний",
        retry: "Повторить"
    )

    static let es = ShortcutSettingsStrings(
        active: "Activo",
        inactive: "Inactivo",
        superKeyAlternativeFormat: "o %@",
        unavailableCountFormat: "%d atajos no se pudieron registrar",
        retry: "Reintentar"
    )

    static let sk = ShortcutSettingsStrings(
        active: "Aktívna",
        inactive: "Neaktívna",
        superKeyAlternativeFormat: "alebo %@",
        unavailableCountFormat: "Nepodarilo sa zaregistrovať %d skratiek",
        retry: "Skúsiť znova"
    )

    static let de = ShortcutSettingsStrings(
        active: "Aktiv",
        inactive: "Inaktiv",
        superKeyAlternativeFormat: "oder %@",
        unavailableCountFormat: "%d Tastenkürzel konnten nicht registriert werden",
        retry: "Erneut versuchen"
    )

    static let fr = ShortcutSettingsStrings(
        active: "Actif",
        inactive: "Inactif",
        superKeyAlternativeFormat: "ou %@",
        unavailableCountFormat: "%d raccourcis n’ont pas pu être enregistrés",
        retry: "Réessayer"
    )

    static let it = ShortcutSettingsStrings(
        active: "Attiva",
        inactive: "Inattiva",
        superKeyAlternativeFormat: "oppure %@",
        unavailableCountFormat: "Impossibile registrare %d scorciatoie",
        retry: "Riprova"
    )

    static let ja = ShortcutSettingsStrings(
        active: "有効",
        inactive: "無効",
        superKeyAlternativeFormat: "または %@",
        unavailableCountFormat: "%d 個のショートカットを登録できませんでした",
        retry: "再試行"
    )

    static let ko = ShortcutSettingsStrings(
        active: "활성",
        inactive: "비활성",
        superKeyAlternativeFormat: "또는 %@",
        unavailableCountFormat: "%d개의 단축키를 등록하지 못했습니다",
        retry: "다시 시도"
    )

    static let zhHans = ShortcutSettingsStrings(
        active: "已启用",
        inactive: "未启用",
        superKeyAlternativeFormat: "或 %@",
        unavailableCountFormat: "%d 个快捷键未能注册",
        retry: "重试"
    )

    static let zhTW = ShortcutSettingsStrings(
        active: "已啟用",
        inactive: "未啟用",
        superKeyAlternativeFormat: "或 %@",
        unavailableCountFormat: "%d 個快速鍵未能註冊",
        retry: "重試"
    )

    static let zhHK = ShortcutSettingsStrings(
        active: "已啟用",
        inactive: "未啟用",
        superKeyAlternativeFormat: "或 %@",
        unavailableCountFormat: "%d 個快速鍵未能註冊",
        retry: "重試"
    )
    static let uk = ShortcutSettingsStrings(
        active: "Активно",
        inactive: "Неактивно",
        superKeyAlternativeFormat: "або %@",
        unavailableCountFormat: "Не вдалося зареєструвати %d комбінацій",
        retry: "Спробувати ще раз"
    )
}
