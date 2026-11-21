// SPDX-License-Identifier: MIT
// Copyright (C) 2026 Vorssaint

import Foundation

/// Strings for display presets. Same contract as the other FeatureStrings
/// structs: memberwise init in declaration order, one static per language, all
/// in this file, and no em dash in visible text.
struct DisplayPresetStrings {
    let title: String
    let caption: String
    let saveCurrent: String
    let empty: String
    let apply: String
    let update: String
    let edit: String
    let newTitle: String
    let editTitle: String
    let nameLabel: String
    let namePlaceholder: String
    let iconLabel: String
    let shortcutLabel: String
    let autoTitle: String
    let autoToggle: String
    let autoCaption: String
    let autoDisplay: String
    let autoWhen: String
    let autoConnected: String
    let autoDisconnected: String
    let delete: String
    let deleteTitle: String
    let deleteBody: String
    let cancel: String
    let saveButton: String
    let defaultName: String
    let appliedFormat: String
    let failuresTitle: String
    let failureNotConnected: String
    let failureResolutionUnsupported: String
    let failureResolutionFailed: String
    let failureBrightnessUnavailable: String
    let failureVolumeUnavailable: String
    let failureMainDisplay: String
}

extension FeatureStrings {
    static func displayPreset(_ language: AppLanguage) -> DisplayPresetStrings {
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

extension DisplayPresetStrings {
    static let enUS = DisplayPresetStrings(
        title: "Display presets",
        caption: "Save the current displays as a preset and bring the arrangement back with one click.",
        saveCurrent: "Save current setup",
        empty: "No presets yet. Save the current setup to create one.",
        apply: "Apply",
        update: "Update from current",
        edit: "Edit",
        newTitle: "New display preset",
        editTitle: "Edit display preset",
        nameLabel: "Name",
        namePlaceholder: "Desk",
        iconLabel: "Icon",
        shortcutLabel: "Shortcut",
        autoTitle: "Automatic",
        autoToggle: "Apply on display change",
        autoCaption: "Applies this preset when the chosen display connects or disconnects.",
        autoDisplay: "Display",
        autoWhen: "When it",
        autoConnected: "connects",
        autoDisconnected: "disconnects",
        delete: "Delete",
        deleteTitle: "Delete this preset?",
        deleteBody: "The saved display settings are removed. The current displays are not changed.",
        cancel: "Cancel",
        saveButton: "Save",
        defaultName: "Preset",
        appliedFormat: "Applied “%1$@”.",
        failuresTitle: "Some items were not applied:",
        failureNotConnected: "%1$@ is not connected.",
        failureResolutionUnsupported: "%1$@ does not support the saved resolution.",
        failureResolutionFailed: "Could not change the resolution of %1$@.",
        failureBrightnessUnavailable: "%1$@ has no brightness control.",
        failureVolumeUnavailable: "%1$@ has no speaker control.",
        failureMainDisplay: "Could not make %1$@ the main display."
    )

    static let ptBR = DisplayPresetStrings(
        title: "Predefinições de tela",
        caption: "Salve as telas atuais como uma predefinição e restaure o arranjo com um clique.",
        saveCurrent: "Salvar configuração atual",
        empty: "Ainda não há predefinições. Salve a configuração atual para criar uma.",
        apply: "Aplicar",
        update: "Atualizar com a atual",
        edit: "Editar",
        newTitle: "Nova predefinição de tela",
        editTitle: "Editar predefinição de tela",
        nameLabel: "Nome",
        namePlaceholder: "Mesa",
        iconLabel: "Ícone",
        shortcutLabel: "Atalho",
        autoTitle: "Automático",
        autoToggle: "Aplicar ao mudar as telas",
        autoCaption: "Aplica esta predefinição quando a tela escolhida for conectada ou desconectada.",
        autoDisplay: "Tela",
        autoWhen: "Quando ela",
        autoConnected: "conecta",
        autoDisconnected: "desconecta",
        delete: "Excluir",
        deleteTitle: "Excluir esta predefinição?",
        deleteBody: "As configurações salvas serão removidas. As telas atuais não serão alteradas.",
        cancel: "Cancelar",
        saveButton: "Salvar",
        defaultName: "Predefinição",
        appliedFormat: "“%1$@” aplicada.",
        failuresTitle: "Alguns itens não foram aplicados:",
        failureNotConnected: "%1$@ não está conectada.",
        failureResolutionUnsupported: "%1$@ não suporta a resolução salva.",
        failureResolutionFailed: "Não foi possível alterar a resolução de %1$@.",
        failureBrightnessUnavailable: "%1$@ não tem controle de brilho.",
        failureVolumeUnavailable: "%1$@ não tem controle de alto-falantes.",
        failureMainDisplay: "Não foi possível tornar %1$@ a tela principal."
    )

    static let tr = DisplayPresetStrings(
        title: "Ekran ön ayarları",
        caption: "Mevcut ekranları ön ayar olarak kaydedin ve düzeni tek tıkla geri getirin.",
        saveCurrent: "Mevcut kurulumu kaydet",
        empty: "Henüz ön ayar yok. Oluşturmak için mevcut kurulumu kaydedin.",
        apply: "Uygula",
        update: "Mevcut durumla güncelle",
        edit: "Düzenle",
        newTitle: "Yeni ekran ön ayarı",
        editTitle: "Ekran ön ayarını düzenle",
        nameLabel: "Ad",
        namePlaceholder: "Masa",
        iconLabel: "Simge",
        shortcutLabel: "Kısayol",
        autoTitle: "Otomatik",
        autoToggle: "Ekran değişince uygula",
        autoCaption: "Seçilen ekran bağlandığında veya ayrıldığında bu ön ayarı uygular.",
        autoDisplay: "Ekran",
        autoWhen: "O",
        autoConnected: "bağlandığında",
        autoDisconnected: "ayrıldığında",
        delete: "Sil",
        deleteTitle: "Bu ön ayar silinsin mi?",
        deleteBody: "Kaydedilen ekran ayarları kaldırılır. Mevcut ekranlar değişmez.",
        cancel: "Vazgeç",
        saveButton: "Kaydet",
        defaultName: "Ön ayar",
        appliedFormat: "“%1$@” uygulandı.",
        failuresTitle: "Bazı öğeler uygulanamadı:",
        failureNotConnected: "%1$@ bağlı değil.",
        failureResolutionUnsupported: "%1$@ kaydedilen çözünürlüğü desteklemiyor.",
        failureResolutionFailed: "%1$@ çözünürlüğü değiştirilemedi.",
        failureBrightnessUnavailable: "%1$@ için parlaklık denetimi yok.",
        failureVolumeUnavailable: "%1$@ için hoparlör denetimi yok.",
        failureMainDisplay: "%1$@ ana ekran yapılamadı."
    )

    static let ru = DisplayPresetStrings(
        title: "Профили экранов",
        caption: "Сохраните текущие экраны как профиль и верните их расположение одним щелчком.",
        saveCurrent: "Сохранить текущую настройку",
        empty: "Профилей пока нет. Сохраните текущую настройку, чтобы создать первый.",
        apply: "Применить",
        update: "Обновить по текущему",
        edit: "Изменить",
        newTitle: "Новый профиль экранов",
        editTitle: "Изменить профиль экранов",
        nameLabel: "Название",
        namePlaceholder: "Рабочий стол",
        iconLabel: "Значок",
        shortcutLabel: "Сочетание клавиш",
        autoTitle: "Автоматически",
        autoToggle: "Применять при смене экранов",
        autoCaption: "Применяет профиль, когда выбранный экран подключается или отключается.",
        autoDisplay: "Экран",
        autoWhen: "Когда он",
        autoConnected: "подключается",
        autoDisconnected: "отключается",
        delete: "Удалить",
        deleteTitle: "Удалить этот профиль?",
        deleteBody: "Сохранённые настройки экранов будут удалены. Текущие экраны не изменятся.",
        cancel: "Отмена",
        saveButton: "Сохранить",
        defaultName: "Профиль",
        appliedFormat: "«%1$@» применён.",
        failuresTitle: "Некоторые элементы не применены:",
        failureNotConnected: "%1$@ не подключён.",
        failureResolutionUnsupported: "%1$@ не поддерживает сохранённое разрешение.",
        failureResolutionFailed: "Не удалось изменить разрешение %1$@.",
        failureBrightnessUnavailable: "Для %1$@ нет управления яркостью.",
        failureVolumeUnavailable: "Для %1$@ нет управления динамиками.",
        failureMainDisplay: "Не удалось сделать %1$@ основным экраном."
    )

    static let es = DisplayPresetStrings(
        title: "Preajustes de pantalla",
        caption: "Guarda las pantallas actuales como un preajuste y recupera la disposición con un clic.",
        saveCurrent: "Guardar configuración actual",
        empty: "Aún no hay preajustes. Guarda la configuración actual para crear uno.",
        apply: "Aplicar",
        update: "Actualizar con la actual",
        edit: "Editar",
        newTitle: "Nuevo preajuste de pantalla",
        editTitle: "Editar preajuste de pantalla",
        nameLabel: "Nombre",
        namePlaceholder: "Escritorio",
        iconLabel: "Icono",
        shortcutLabel: "Atajo",
        autoTitle: "Automático",
        autoToggle: "Aplicar al cambiar las pantallas",
        autoCaption: "Aplica este preajuste cuando la pantalla elegida se conecta o se desconecta.",
        autoDisplay: "Pantalla",
        autoWhen: "Cuando se",
        autoConnected: "conecta",
        autoDisconnected: "desconecta",
        delete: "Eliminar",
        deleteTitle: "¿Eliminar este preajuste?",
        deleteBody: "Se quitan los ajustes guardados. Las pantallas actuales no cambian.",
        cancel: "Cancelar",
        saveButton: "Guardar",
        defaultName: "Preajuste",
        appliedFormat: "Se aplicó “%1$@”.",
        failuresTitle: "Algunos elementos no se aplicaron:",
        failureNotConnected: "%1$@ no está conectada.",
        failureResolutionUnsupported: "%1$@ no admite la resolución guardada.",
        failureResolutionFailed: "No se pudo cambiar la resolución de %1$@.",
        failureBrightnessUnavailable: "%1$@ no tiene control de brillo.",
        failureVolumeUnavailable: "%1$@ no tiene control de altavoces.",
        failureMainDisplay: "No se pudo convertir %1$@ en la pantalla principal."
    )

    static let sk = DisplayPresetStrings(
        title: "Profily obrazoviek",
        caption: "Uložte aktuálne obrazovky ako profil a obnovte ich usporiadanie jedným kliknutím.",
        saveCurrent: "Uložiť aktuálne nastavenie",
        empty: "Zatiaľ nemáte žiadny profil. Uložte aktuálne nastavenie a vytvorte ho.",
        apply: "Použiť",
        update: "Aktualizovať podľa aktuálneho",
        edit: "Upraviť",
        newTitle: "Nový profil obrazoviek",
        editTitle: "Upraviť profil obrazoviek",
        nameLabel: "Názov",
        namePlaceholder: "Pracovný stôl",
        iconLabel: "Ikona",
        shortcutLabel: "Skratka",
        autoTitle: "Automaticky",
        autoToggle: "Použiť pri zmene obrazoviek",
        autoCaption: "Použije tento profil, keď sa zvolená obrazovka pripojí alebo odpojí.",
        autoDisplay: "Obrazovka",
        autoWhen: "Keď sa",
        autoConnected: "pripojí",
        autoDisconnected: "odpojí",
        delete: "Zmazať",
        deleteTitle: "Zmazať tento profil?",
        deleteBody: "Uložené nastavenia obrazoviek sa odstránia. Aktuálne obrazovky sa nezmenia.",
        cancel: "Zrušiť",
        saveButton: "Uložiť",
        defaultName: "Profil",
        appliedFormat: "Profil „%1$@“ bol použitý.",
        failuresTitle: "Niektoré položky sa nepodarilo použiť:",
        failureNotConnected: "%1$@ nie je pripojená.",
        failureResolutionUnsupported: "%1$@ nepodporuje uložené rozlíšenie.",
        failureResolutionFailed: "Nepodarilo sa zmeniť rozlíšenie %1$@.",
        failureBrightnessUnavailable: "%1$@ nemá ovládanie jasu.",
        failureVolumeUnavailable: "%1$@ nemá ovládanie reproduktorov.",
        failureMainDisplay: "Nepodarilo sa nastaviť %1$@ ako hlavnú obrazovku."
    )

    static let de = DisplayPresetStrings(
        title: "Bildschirmprofile",
        caption: "Speichern Sie die aktuellen Bildschirme als Profil und stellen Sie die Anordnung mit einem Klick wieder her.",
        saveCurrent: "Aktuelle Einrichtung speichern",
        empty: "Noch keine Profile. Speichern Sie die aktuelle Einrichtung, um eines zu erstellen.",
        apply: "Anwenden",
        update: "Aus aktueller Einrichtung aktualisieren",
        edit: "Bearbeiten",
        newTitle: "Neues Bildschirmprofil",
        editTitle: "Bildschirmprofil bearbeiten",
        nameLabel: "Name",
        namePlaceholder: "Schreibtisch",
        iconLabel: "Symbol",
        shortcutLabel: "Tastenkürzel",
        autoTitle: "Automatisch",
        autoToggle: "Bei Bildschirmänderung anwenden",
        autoCaption: "Wendet dieses Profil an, wenn der gewählte Bildschirm verbunden oder getrennt wird.",
        autoDisplay: "Bildschirm",
        autoWhen: "Wenn er",
        autoConnected: "verbunden wird",
        autoDisconnected: "getrennt wird",
        delete: "Löschen",
        deleteTitle: "Dieses Profil löschen?",
        deleteBody: "Die gespeicherten Bildschirmeinstellungen werden entfernt. Die aktuellen Bildschirme bleiben unverändert.",
        cancel: "Abbrechen",
        saveButton: "Speichern",
        defaultName: "Profil",
        appliedFormat: "„%1$@“ wurde angewendet.",
        failuresTitle: "Einige Elemente wurden nicht angewendet:",
        failureNotConnected: "%1$@ ist nicht verbunden.",
        failureResolutionUnsupported: "%1$@ unterstützt die gespeicherte Auflösung nicht.",
        failureResolutionFailed: "Die Auflösung von %1$@ konnte nicht geändert werden.",
        failureBrightnessUnavailable: "%1$@ hat keine Helligkeitssteuerung.",
        failureVolumeUnavailable: "%1$@ hat keine Lautsprechersteuerung.",
        failureMainDisplay: "%1$@ konnte nicht zum Hauptbildschirm gemacht werden."
    )

    static let fr = DisplayPresetStrings(
        title: "Préréglages d’écran",
        caption: "Enregistrez les écrans actuels comme préréglage et retrouvez leur disposition d’un clic.",
        saveCurrent: "Enregistrer la configuration actuelle",
        empty: "Aucun préréglage pour l’instant. Enregistrez la configuration actuelle pour en créer un.",
        apply: "Appliquer",
        update: "Actualiser depuis l’actuelle",
        edit: "Modifier",
        newTitle: "Nouveau préréglage d’écran",
        editTitle: "Modifier le préréglage d’écran",
        nameLabel: "Nom",
        namePlaceholder: "Bureau",
        iconLabel: "Icône",
        shortcutLabel: "Raccourci",
        autoTitle: "Automatique",
        autoToggle: "Appliquer au changement d’écran",
        autoCaption: "Applique ce préréglage lorsque l’écran choisi se connecte ou se déconnecte.",
        autoDisplay: "Écran",
        autoWhen: "Lorsqu’il",
        autoConnected: "se connecte",
        autoDisconnected: "se déconnecte",
        delete: "Supprimer",
        deleteTitle: "Supprimer ce préréglage\u{00A0}?",
        deleteBody: "Les réglages enregistrés sont supprimés. Les écrans actuels ne changent pas.",
        cancel: "Annuler",
        saveButton: "Enregistrer",
        defaultName: "Préréglage",
        appliedFormat: "«\u{00A0}%1$@\u{00A0}» appliqué.",
        failuresTitle: "Certains éléments n’ont pas été appliqués\u{00A0}:",
        failureNotConnected: "%1$@ n’est pas connecté.",
        failureResolutionUnsupported: "%1$@ ne prend pas en charge la résolution enregistrée.",
        failureResolutionFailed: "Impossible de changer la résolution de %1$@.",
        failureBrightnessUnavailable: "%1$@ n’a pas de réglage de luminosité.",
        failureVolumeUnavailable: "%1$@ n’a pas de réglage des haut-parleurs.",
        failureMainDisplay: "Impossible de faire de %1$@ l’écran principal."
    )

    static let it = DisplayPresetStrings(
        title: "Profili schermo",
        caption: "Salva gli schermi attuali come profilo e ripristina la disposizione con un clic.",
        saveCurrent: "Salva configurazione attuale",
        empty: "Non ci sono ancora profili. Salva la configurazione attuale per crearne uno.",
        apply: "Applica",
        update: "Aggiorna da quella attuale",
        edit: "Modifica",
        newTitle: "Nuovo profilo schermo",
        editTitle: "Modifica profilo schermo",
        nameLabel: "Nome",
        namePlaceholder: "Scrivania",
        iconLabel: "Icona",
        shortcutLabel: "Scorciatoia",
        autoTitle: "Automatico",
        autoToggle: "Applica al cambio di schermo",
        autoCaption: "Applica questo profilo quando lo schermo scelto si collega o si scollega.",
        autoDisplay: "Schermo",
        autoWhen: "Quando si",
        autoConnected: "collega",
        autoDisconnected: "scollega",
        delete: "Elimina",
        deleteTitle: "Eliminare questo profilo?",
        deleteBody: "Le impostazioni salvate vengono rimosse. Gli schermi attuali non cambiano.",
        cancel: "Annulla",
        saveButton: "Salva",
        defaultName: "Profilo",
        appliedFormat: "“%1$@” applicato.",
        failuresTitle: "Alcuni elementi non sono stati applicati:",
        failureNotConnected: "%1$@ non è collegato.",
        failureResolutionUnsupported: "%1$@ non supporta la risoluzione salvata.",
        failureResolutionFailed: "Impossibile cambiare la risoluzione di %1$@.",
        failureBrightnessUnavailable: "%1$@ non ha il controllo della luminosità.",
        failureVolumeUnavailable: "%1$@ non ha il controllo degli altoparlanti.",
        failureMainDisplay: "Impossibile rendere %1$@ lo schermo principale."
    )

    static let ja = DisplayPresetStrings(
        title: "ディスプレイプリセット",
        caption: "現在のディスプレイをプリセットとして保存し、配置をワンクリックで復元します。",
        saveCurrent: "現在の設定を保存",
        empty: "プリセットはまだありません。現在の設定を保存して作成します。",
        apply: "適用",
        update: "現在の状態で更新",
        edit: "編集",
        newTitle: "新しいディスプレイプリセット",
        editTitle: "ディスプレイプリセットを編集",
        nameLabel: "名前",
        namePlaceholder: "デスク",
        iconLabel: "アイコン",
        shortcutLabel: "ショートカット",
        autoTitle: "自動",
        autoToggle: "ディスプレイの変更時に適用",
        autoCaption: "選択したディスプレイが接続または切断されたときにこのプリセットを適用します。",
        autoDisplay: "ディスプレイ",
        autoWhen: "次のときに",
        autoConnected: "接続したとき",
        autoDisconnected: "切断したとき",
        delete: "削除",
        deleteTitle: "このプリセットを削除しますか？",
        deleteBody: "保存されたディスプレイ設定が削除されます。現在のディスプレイは変更されません。",
        cancel: "キャンセル",
        saveButton: "保存",
        defaultName: "プリセット",
        appliedFormat: "「%1$@」を適用しました。",
        failuresTitle: "一部の項目を適用できませんでした:",
        failureNotConnected: "%1$@ が接続されていません。",
        failureResolutionUnsupported: "%1$@ は保存された解像度に対応していません。",
        failureResolutionFailed: "%1$@ の解像度を変更できませんでした。",
        failureBrightnessUnavailable: "%1$@ に明るさの調整機能がありません。",
        failureVolumeUnavailable: "%1$@ にスピーカーの調整機能がありません。",
        failureMainDisplay: "%1$@ をメインディスプレイにできませんでした。"
    )

    static let ko = DisplayPresetStrings(
        title: "디스플레이 프리셋",
        caption: "현재 디스플레이를 프리셋으로 저장하고 한 번의 클릭으로 배치를 복원합니다.",
        saveCurrent: "현재 설정 저장",
        empty: "아직 프리셋이 없습니다. 현재 설정을 저장해 만드세요.",
        apply: "적용",
        update: "현재 상태로 업데이트",
        edit: "편집",
        newTitle: "새 디스플레이 프리셋",
        editTitle: "디스플레이 프리셋 편집",
        nameLabel: "이름",
        namePlaceholder: "책상",
        iconLabel: "아이콘",
        shortcutLabel: "단축키",
        autoTitle: "자동",
        autoToggle: "디스플레이 변경 시 적용",
        autoCaption: "선택한 디스플레이가 연결되거나 연결 해제될 때 이 프리셋을 적용합니다.",
        autoDisplay: "디스플레이",
        autoWhen: "다음 때",
        autoConnected: "연결될 때",
        autoDisconnected: "연결 해제될 때",
        delete: "삭제",
        deleteTitle: "이 프리셋을 삭제할까요?",
        deleteBody: "저장된 디스플레이 설정이 제거됩니다. 현재 디스플레이는 바뀌지 않습니다.",
        cancel: "취소",
        saveButton: "저장",
        defaultName: "프리셋",
        appliedFormat: "‘%1$@’을(를) 적용했습니다.",
        failuresTitle: "일부 항목을 적용하지 못했습니다:",
        failureNotConnected: "%1$@이(가) 연결되어 있지 않습니다.",
        failureResolutionUnsupported: "%1$@은(는) 저장된 해상도를 지원하지 않습니다.",
        failureResolutionFailed: "%1$@의 해상도를 변경하지 못했습니다.",
        failureBrightnessUnavailable: "%1$@에는 밝기 제어가 없습니다.",
        failureVolumeUnavailable: "%1$@에는 스피커 제어가 없습니다.",
        failureMainDisplay: "%1$@을(를) 주 디스플레이로 만들지 못했습니다."
    )

    static let uk = DisplayPresetStrings(
        title: "Профілі екранів",
        caption: "Збережіть поточні екрани як профіль і повертайте їхнє розташування одним клацанням.",
        saveCurrent: "Зберегти поточне налаштування",
        empty: "Профілів ще немає. Збережіть поточне налаштування, щоб створити перший.",
        apply: "Застосувати",
        update: "Оновити за поточним",
        edit: "Змінити",
        newTitle: "Новий профіль екранів",
        editTitle: "Змінити профіль екранів",
        nameLabel: "Назва",
        namePlaceholder: "Робочий стіл",
        iconLabel: "Значок",
        shortcutLabel: "Сполучення клавіш",
        autoTitle: "Автоматично",
        autoToggle: "Застосовувати при зміні екранів",
        autoCaption: "Застосовує цей профіль, коли вибраний екран підключається або відключається.",
        autoDisplay: "Екран",
        autoWhen: "Коли він",
        autoConnected: "підключається",
        autoDisconnected: "відключається",
        delete: "Видалити",
        deleteTitle: "Видалити цей профіль?",
        deleteBody: "Збережені налаштування екранів буде видалено. Поточні екрани не зміняться.",
        cancel: "Скасувати",
        saveButton: "Зберегти",
        defaultName: "Профіль",
        appliedFormat: "«%1$@» застосовано.",
        failuresTitle: "Деякі елементи не застосовано:",
        failureNotConnected: "%1$@ не підключено.",
        failureResolutionUnsupported: "%1$@ не підтримує збережену роздільність.",
        failureResolutionFailed: "Не вдалося змінити роздільність %1$@.",
        failureBrightnessUnavailable: "Для %1$@ немає керування яскравістю.",
        failureVolumeUnavailable: "Для %1$@ немає керування динаміками.",
        failureMainDisplay: "Не вдалося зробити %1$@ головним екраном."
    )

    static let zhHans = DisplayPresetStrings(
        title: "显示器预设",
        caption: "将当前显示器保存为预设，一键恢复整套布局。",
        saveCurrent: "保存当前设置",
        empty: "还没有预设。保存当前设置即可创建。",
        apply: "应用",
        update: "用当前状态更新",
        edit: "编辑",
        newTitle: "新建显示器预设",
        editTitle: "编辑显示器预设",
        nameLabel: "名称",
        namePlaceholder: "工位",
        iconLabel: "图标",
        shortcutLabel: "快捷键",
        autoTitle: "自动",
        autoToggle: "显示器变化时应用",
        autoCaption: "当所选显示器连接或断开时应用此预设。",
        autoDisplay: "显示器",
        autoWhen: "当它",
        autoConnected: "连接时",
        autoDisconnected: "断开时",
        delete: "删除",
        deleteTitle: "删除此预设？",
        deleteBody: "保存的显示器设置会被移除。当前显示器不会改变。",
        cancel: "取消",
        saveButton: "保存",
        defaultName: "预设",
        appliedFormat: "已应用“%1$@”。",
        failuresTitle: "部分项目未应用：",
        failureNotConnected: "%1$@ 未连接。",
        failureResolutionUnsupported: "%1$@ 不支持保存的分辨率。",
        failureResolutionFailed: "无法更改 %1$@ 的分辨率。",
        failureBrightnessUnavailable: "%1$@ 没有亮度控制。",
        failureVolumeUnavailable: "%1$@ 没有扬声器控制。",
        failureMainDisplay: "无法将 %1$@ 设为主显示器。"
    )

    static let zhTW = DisplayPresetStrings(
        title: "顯示器預設集",
        caption: "將目前的顯示器儲存為預設集，一鍵恢復整組配置。",
        saveCurrent: "儲存目前設定",
        empty: "尚無預設集。儲存目前設定即可建立。",
        apply: "套用",
        update: "以目前狀態更新",
        edit: "編輯",
        newTitle: "新增顯示器預設集",
        editTitle: "編輯顯示器預設集",
        nameLabel: "名稱",
        namePlaceholder: "辦公桌",
        iconLabel: "圖示",
        shortcutLabel: "快速鍵",
        autoTitle: "自動",
        autoToggle: "顯示器變更時套用",
        autoCaption: "當所選顯示器連接或中斷連接時套用此預設集。",
        autoDisplay: "顯示器",
        autoWhen: "當它",
        autoConnected: "連接時",
        autoDisconnected: "中斷連接時",
        delete: "刪除",
        deleteTitle: "刪除此預設集？",
        deleteBody: "儲存的顯示器設定會被移除。目前的顯示器不會改變。",
        cancel: "取消",
        saveButton: "儲存",
        defaultName: "預設集",
        appliedFormat: "已套用「%1$@」。",
        failuresTitle: "部分項目未套用：",
        failureNotConnected: "%1$@ 未連接。",
        failureResolutionUnsupported: "%1$@ 不支援儲存的解析度。",
        failureResolutionFailed: "無法變更 %1$@ 的解析度。",
        failureBrightnessUnavailable: "%1$@ 沒有亮度控制。",
        failureVolumeUnavailable: "%1$@ 沒有揚聲器控制。",
        failureMainDisplay: "無法將 %1$@ 設為主顯示器。"
    )

    static let zhHK = DisplayPresetStrings(
        title: "顯示器預設",
        caption: "將目前的顯示器儲存為預設，一鍵還原整組配置。",
        saveCurrent: "儲存目前設定",
        empty: "暫時沒有預設。儲存目前設定即可建立。",
        apply: "套用",
        update: "以目前狀態更新",
        edit: "編輯",
        newTitle: "新增顯示器預設",
        editTitle: "編輯顯示器預設",
        nameLabel: "名稱",
        namePlaceholder: "辦公桌",
        iconLabel: "圖示",
        shortcutLabel: "快捷鍵",
        autoTitle: "自動",
        autoToggle: "顯示器變更時套用",
        autoCaption: "當所選顯示器連接或中斷連接時套用此預設。",
        autoDisplay: "顯示器",
        autoWhen: "當它",
        autoConnected: "連接時",
        autoDisconnected: "中斷連接時",
        delete: "刪除",
        deleteTitle: "刪除此預設？",
        deleteBody: "儲存的顯示器設定會被移除。目前的顯示器不會改變。",
        cancel: "取消",
        saveButton: "儲存",
        defaultName: "預設",
        appliedFormat: "已套用「%1$@」。",
        failuresTitle: "部分項目未套用：",
        failureNotConnected: "%1$@ 未連接。",
        failureResolutionUnsupported: "%1$@ 不支援儲存的解像度。",
        failureResolutionFailed: "無法變更 %1$@ 的解像度。",
        failureBrightnessUnavailable: "%1$@ 沒有亮度控制。",
        failureVolumeUnavailable: "%1$@ 沒有揚聲器控制。",
        failureMainDisplay: "無法將 %1$@ 設為主顯示器。"
    )
}
